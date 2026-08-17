import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'
import { CompositeQuoteProvider } from './CompositeQuoteProvider'
import { personalStore } from './PersonalStore'
import { ChinaMarketCalendar, MarketPhase, QuoteFreshness, QuoteFreshnessHelper, StockQuote, StockSymbol } from './StockModels'
import { StockSearchCandidate, TencentStockSearchProvider } from './TencentStockSearchProvider'

const DEFAULT_WATCHLIST: string = 'sh600519,sz000001,sz300750'

export class QuoteStore {
  private static singleton: QuoteStore = new QuoteStore()
  private provider: CompositeQuoteProvider = new CompositeQuoteProvider()
  private searchProvider: TencentStockSearchProvider = new TencentStockSearchProvider()
  private dataPreferences?: preferences.Preferences
  private refreshTimer: number = -1
  private rotateTimer: number = -1
  private refreshing: boolean = false
  private failures: number = 0
  private lastCachePersistedAt: number = 0
  private lastRotateAt: number = 0
  private holidayDetectedDate: string = ''
  private removedSymbol?: StockSymbol
  private removedQuote?: StockQuote
  private removedIndex: number = -1
  private undoTimer: number = -1

  static getInstance(): QuoteStore {
    return QuoteStore.singleton
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.ensureAppStorage()
    let saved: string = DEFAULT_WATCHLIST
    try {
      this.dataPreferences = await preferences.getPreferences(context, 'stock_float_mvp')
      saved = this.dataPreferences.getSync('watchlist', DEFAULT_WATCHLIST) as string
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      AppStorage.set<string>('quoteStatus', `读取自选失败，已使用默认列表 · ${businessError.message}`)
    }
    let watchlist: Array<StockSymbol> = this.decodeWatchlist(saved)
    if (watchlist.length === 0) {
      watchlist = this.decodeWatchlist(DEFAULT_WATCHLIST)
    }
    AppStorage.set<Array<StockSymbol>>('watchlist', watchlist)
    const pinnedSymbolId: string = AppStorage.get<string>('pinnedSymbolId') ?? ''
    const pinnedIndex: number = watchlist.findIndex((symbol: StockSymbol) => symbol.id === pinnedSymbolId)
    if (pinnedIndex >= 0) {
      AppStorage.set<number>('selectedIndex', pinnedIndex)
    }
    let savedQuotes: string = ''
    try {
      if (this.dataPreferences !== undefined) {
        savedQuotes = this.dataPreferences.getSync('quote_cache', '') as string
      }
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      console.error(`Failed to read quote cache. Code: ${businessError.code}, message: ${businessError.message}`)
    }
    const cachedQuotes: Array<StockQuote> = this.decodeQuoteCache(savedQuotes)
      .filter((quote: StockQuote) => watchlist.some((symbol: StockSymbol) => symbol.id === quote.symbol.id))
    if (cachedQuotes.length > 0) {
      AppStorage.set<Array<StockQuote>>('quotes', cachedQuotes)
      const newest: number = cachedQuotes.reduce((value: number, quote: StockQuote) =>
        Math.max(value, quote.fetchedTimestamp), 0)
      AppStorage.set<number>('lastUpdated', newest)
      AppStorage.set<string>('quoteStatus', '已显示上次行情，正在更新…')
    }
  }

  start(): void {
    this.startRefreshLoop()
    this.startRotateLoop()
  }

  stop(): void {
    if (this.refreshTimer >= 0) {
      clearTimeout(this.refreshTimer)
      this.refreshTimer = -1
    }
    if (this.rotateTimer >= 0) {
      clearInterval(this.rotateTimer)
      this.rotateTimer = -1
    }
    if (this.undoTimer >= 0) {
      clearTimeout(this.undoTimer)
      this.undoTimer = -1
    }
  }

  async refresh(): Promise<void> {
    if (this.refreshing) {
      return
    }
    const watchlist: Array<StockSymbol> = AppStorage.get<Array<StockSymbol>>('watchlist') ?? []
    if (watchlist.length === 0) {
      return
    }
    this.refreshing = true
    AppStorage.set<boolean>('refreshing', true)
    AppStorage.set<string>('quoteStatus', '正在刷新…')
    try {
      const fresh: Array<StockQuote> = await this.provider.fetch(watchlist)
      this.detectTradingDayClosure(fresh)
      const old: Array<StockQuote> = AppStorage.get<Array<StockQuote>>('quotes') ?? []
      const merged: Array<StockQuote> = []
      watchlist.forEach((symbol: StockSymbol) => {
        const next: StockQuote | undefined = fresh.find((item: StockQuote) => item.symbol.id === symbol.id)
        const previous: StockQuote | undefined = old.find((item: StockQuote) => item.symbol.id === symbol.id)
        if (next !== undefined) {
          merged.push(next)
        } else if (previous !== undefined) {
          merged.push(previous)
        }
      })
      AppStorage.set<Array<StockQuote>>('quotes', merged)
      const newestFetch: number = fresh.reduce((value: number, quote: StockQuote) =>
        Math.max(value, quote.fetchedTimestamp), 0)
      AppStorage.set<number>('lastUpdated', newestFetch)
      const sourceText: string = this.sourceSummary(fresh)
      const phase: MarketPhase = this.marketPhase()
      const completeText: string = fresh.length === watchlist.length ? '行情已更新' : '部分行情沿用旧值'
      AppStorage.set<string>('quoteStatus', `${phase} · ${completeText} · ${sourceText}`)
      await this.persistQuoteCache(merged)
      await personalStore.recordQuotes(fresh)
      await personalStore.evaluateAlerts(fresh, phase)
      const selectedIndex: number = AppStorage.get<number>('selectedIndex') ?? 0
      const selectedSymbol: StockSymbol | undefined = watchlist[selectedIndex]
      const selectedQuote: StockQuote | undefined = selectedSymbol === undefined ? undefined :
        merged.find((quote: StockQuote) => quote.symbol.id === selectedSymbol.id)
      const backgroundActive: boolean = AppStorage.get<boolean>('backgroundActive') ?? true
      const freshness: QuoteFreshness = QuoteFreshnessHelper.value(selectedQuote, phase, backgroundActive)
      await personalStore.publishStatusQuote(selectedQuote, phase, freshness)
      this.failures = 0
    } catch (error) {
      this.failures += 1
      const message: string = (error as BusinessError).message
      AppStorage.set<string>('quoteStatus', `刷新失败，保留上次行情 · ${message}`)
    } finally {
      this.refreshing = false
      AppStorage.set<boolean>('refreshing', false)
    }
  }

  async addSymbol(input: string): Promise<boolean> {
    const query: string = input.trim()
    if (query.length === 0) {
      AppStorage.set<string>('quoteStatus', '请输入股票代码、中文名称或拼音')
      return false
    }
    const watchlist: Array<StockSymbol> = AppStorage.get<Array<StockSymbol>>('watchlist') ?? []
    if (watchlist.length >= 20) {
      AppStorage.set<string>('quoteStatus', '最多添加 20 只股票')
      return false
    }
    try {
      let symbol: StockSymbol | undefined = StockSymbol.parse(query)
      let resolvedName: string = ''
      if (symbol === undefined) {
        AppStorage.set<string>('quoteStatus', '正在按名称或拼音搜索股票…')
        const candidates: Array<StockSearchCandidate> = await this.searchProvider.search(query)
        const candidate: StockSearchCandidate | undefined = this.bestSearchCandidate(query, candidates)
        if (candidate === undefined) {
          AppStorage.set<string>('quoteStatus', `未找到“${query}”对应的 A 股`)
          return false
        }
        symbol = candidate.symbol
        resolvedName = candidate.name
      }
      if (symbol === undefined) {
        AppStorage.set<string>('quoteStatus', `未找到“${query}”对应的 A 股`)
        return false
      }
      const resolvedSymbol: StockSymbol = symbol
      if (watchlist.some((item: StockSymbol) => item.id === resolvedSymbol.id)) {
        AppStorage.set<string>('quoteStatus', `${resolvedName || '该股票'}已在自选中`)
        return false
      }
      AppStorage.set<string>('quoteStatus', resolvedName.length > 0 ? `正在验证 ${resolvedName}…` : '正在验证股票…')
      const quotes: Array<StockQuote> = await this.provider.fetch([resolvedSymbol])
      if (quotes.length !== 1) {
        AppStorage.set<string>('quoteStatus', '未找到该股票')
        return false
      }
      const updated: Array<StockSymbol> = watchlist.concat([resolvedSymbol])
      const currentQuotes: Array<StockQuote> = AppStorage.get<Array<StockQuote>>('quotes') ?? []
      const updatedQuotes: Array<StockQuote> = currentQuotes.concat(quotes)
      AppStorage.set<Array<StockSymbol>>('watchlist', updated)
      AppStorage.set<Array<StockQuote>>('quotes', updatedQuotes)
      AppStorage.set<number>('selectedIndex', updated.length - 1)
      AppStorage.set<string>('quoteStatus', `已添加 ${quotes[0].name}`)
      this.bumpSelectionTick()
      await this.persistWatchlist(updated)
      await this.persistQuoteCache(updatedQuotes, true)
      await personalStore.recordQuotes(quotes)
      return true
    } catch (error) {
      AppStorage.set<string>('quoteStatus', `验证失败 · ${(error as BusinessError).message}`)
      return false
    }
  }

  private bestSearchCandidate(query: string,
    candidates: Array<StockSearchCandidate>): StockSearchCandidate | undefined {
    if (candidates.length === 0) {
      return undefined
    }
    const normalized: string = query.trim().toLowerCase().replace(/\s+/g, '')
    for (let index: number = 0; index < candidates.length; index += 1) {
      const candidate: StockSearchCandidate = candidates[index]
      if (candidate.name === query.trim() || candidate.pinyin === normalized) {
        return candidate
      }
    }
    for (let index: number = 0; index < candidates.length; index += 1) {
      if (candidates[index].name.includes(query.trim())) {
        return candidates[index]
      }
    }
    return candidates[0]
  }

  async removeSymbol(symbol: StockSymbol): Promise<void> {
    const watchlist: Array<StockSymbol> = AppStorage.get<Array<StockSymbol>>('watchlist') ?? []
    if (watchlist.length <= 1) {
      AppStorage.set<string>('quoteStatus', '至少保留一只自选股')
      return
    }
    const updated: Array<StockSymbol> = watchlist.filter((item: StockSymbol) => item.id !== symbol.id)
    const quotes: Array<StockQuote> = AppStorage.get<Array<StockQuote>>('quotes') ?? []
    const oldIndex: number = AppStorage.get<number>('selectedIndex') ?? 0
    const selectedId: string = watchlist[oldIndex]?.id ?? ''
    const preservedIndex: number = updated.findIndex((item: StockSymbol) => item.id === selectedId)
    const nextIndex: number = preservedIndex >= 0 ? preservedIndex : Math.min(oldIndex, updated.length - 1)
    AppStorage.set<Array<StockSymbol>>('watchlist', updated)
    const updatedQuotes: Array<StockQuote> = quotes.filter((item: StockQuote) => item.symbol.id !== symbol.id)
    AppStorage.set<Array<StockQuote>>('quotes', updatedQuotes)
    AppStorage.set<number>('selectedIndex', nextIndex)
    this.removedSymbol = symbol
    this.removedQuote = quotes.find((item: StockQuote) => item.symbol.id === symbol.id)
    this.removedIndex = watchlist.findIndex((item: StockSymbol) => item.id === symbol.id)
    AppStorage.set<boolean>('undoAvailable', true)
    AppStorage.set<string>('undoMessage', `已删除 ${this.removedQuote?.name ?? symbol.displayCode}`)
    if ((AppStorage.get<string>('pinnedSymbolId') ?? '') === symbol.id) {
      await personalStore.setPinnedSymbol('')
    }
    if (this.undoTimer >= 0) {
      clearTimeout(this.undoTimer)
    }
    this.undoTimer = setTimeout(() => this.clearUndo(), 6000)
    this.bumpSelectionTick()
    await this.persistWatchlist(updated)
    await this.persistQuoteCache(updatedQuotes, true)
  }

  async undoRemove(): Promise<void> {
    if (this.removedSymbol === undefined || this.removedIndex < 0) {
      return
    }
    const watchlist: Array<StockSymbol> = AppStorage.get<Array<StockSymbol>>('watchlist') ?? []
    if (watchlist.some((item: StockSymbol) => item.id === this.removedSymbol?.id)) {
      this.clearUndo()
      return
    }
    const index: number = Math.min(this.removedIndex, watchlist.length)
    const updated: Array<StockSymbol> = watchlist.slice(0, index)
      .concat([this.removedSymbol])
      .concat(watchlist.slice(index))
    const quotes: Array<StockQuote> = AppStorage.get<Array<StockQuote>>('quotes') ?? []
    const updatedQuotes: Array<StockQuote> = this.removedQuote === undefined ? quotes : quotes.concat([this.removedQuote])
    AppStorage.set<Array<StockSymbol>>('watchlist', updated)
    AppStorage.set<Array<StockQuote>>('quotes', updatedQuotes)
    AppStorage.set<number>('selectedIndex', index)
    AppStorage.set<string>('quoteStatus', `已恢复 ${this.removedQuote?.name ?? this.removedSymbol.displayCode}`)
    this.bumpSelectionTick()
    await this.persistWatchlist(updated)
    await this.persistQuoteCache(updatedQuotes, true)
    this.clearUndo()
  }

  async moveSymbol(from: number, to: number): Promise<void> {
    const watchlist: Array<StockSymbol> = AppStorage.get<Array<StockSymbol>>('watchlist') ?? []
    if (from < 0 || from >= watchlist.length || to < 0 || to >= watchlist.length || from === to) {
      return
    }
    const selectedId: string = watchlist[AppStorage.get<number>('selectedIndex') ?? 0]?.id ?? ''
    const moved: StockSymbol = watchlist[from]
    const updated: Array<StockSymbol> = watchlist.filter((_item: StockSymbol, index: number) => index !== from)
    updated.splice(to, 0, moved)
    AppStorage.set<Array<StockSymbol>>('watchlist', updated)
    AppStorage.set<number>('selectedIndex', Math.max(0,
      updated.findIndex((item: StockSymbol) => item.id === selectedId)))
    AppStorage.set<string>('quoteStatus', `已调整 ${moved.displayCode} 的顺序`)
    this.bumpSelectionTick()
    await this.persistWatchlist(updated)
  }

  async sortByChange(descending: boolean): Promise<void> {
    const watchlist: Array<StockSymbol> = AppStorage.get<Array<StockSymbol>>('watchlist') ?? []
    const quotes: Array<StockQuote> = AppStorage.get<Array<StockQuote>>('quotes') ?? []
    const selectedId: string = watchlist[AppStorage.get<number>('selectedIndex') ?? 0]?.id ?? ''
    const updated: Array<StockSymbol> = watchlist.slice().sort((left: StockSymbol, right: StockSymbol) => {
      const leftValue: number = quotes.find((quote: StockQuote) => quote.symbol.id === left.id)?.changePercent ?? 0
      const rightValue: number = quotes.find((quote: StockQuote) => quote.symbol.id === right.id)?.changePercent ?? 0
      return descending ? rightValue - leftValue : leftValue - rightValue
    })
    AppStorage.set<Array<StockSymbol>>('watchlist', updated)
    AppStorage.set<number>('selectedIndex', Math.max(0,
      updated.findIndex((item: StockSymbol) => item.id === selectedId)))
    AppStorage.set<string>('quoteStatus', descending ? '已按涨幅排序' : '已按跌幅排序')
    this.bumpSelectionTick()
    await this.persistWatchlist(updated)
  }

  async moveSymbolToTop(symbol: StockSymbol): Promise<void> {
    const watchlist: Array<StockSymbol> = AppStorage.get<Array<StockSymbol>>('watchlist') ?? []
    const oldIndex: number = watchlist.findIndex((item: StockSymbol) => item.id === symbol.id)
    if (oldIndex <= 0) {
      return
    }
    const selectedIndex: number = AppStorage.get<number>('selectedIndex') ?? 0
    const selectedId: string = watchlist[selectedIndex]?.id ?? symbol.id
    const updated: Array<StockSymbol> = [symbol].concat(
      watchlist.filter((item: StockSymbol) => item.id !== symbol.id)
    )
    const nextSelectedIndex: number = updated.findIndex((item: StockSymbol) => item.id === selectedId)
    AppStorage.set<Array<StockSymbol>>('watchlist', updated)
    AppStorage.set<number>('selectedIndex', Math.max(nextSelectedIndex, 0))
    AppStorage.set<string>('quoteStatus', `已将 ${symbol.displayCode} 置顶`)
    this.bumpSelectionTick()
    await this.persistWatchlist(updated)
  }

  selectPrevious(): void {
    const watchlist: Array<StockSymbol> = AppStorage.get<Array<StockSymbol>>('watchlist') ?? []
    if (watchlist.length === 0) {
      return
    }
    const index: number = AppStorage.get<number>('selectedIndex') ?? 0
    AppStorage.set<number>('selectedIndex', (index - 1 + watchlist.length) % watchlist.length)
    this.bumpSelectionTick()
  }

  selectNext(): void {
    const watchlist: Array<StockSymbol> = AppStorage.get<Array<StockSymbol>>('watchlist') ?? []
    if (watchlist.length === 0) {
      return
    }
    const index: number = AppStorage.get<number>('selectedIndex') ?? 0
    AppStorage.set<number>('selectedIndex', (index + 1) % watchlist.length)
    this.bumpSelectionTick()
  }

  marketPhase(): MarketPhase {
    const phase: MarketPhase = ChinaMarketCalendar.phase()
    if (phase === MarketPhase.TRADING &&
      this.holidayDetectedDate === ChinaMarketCalendar.exchangeDateKey(Date.now())) {
      return MarketPhase.HOLIDAY
    }
    return phase
  }

  private ensureAppStorage(): void {
    AppStorage.setOrCreate<Array<StockSymbol>>('watchlist', [])
    AppStorage.setOrCreate<Array<StockQuote>>('quotes', [])
    AppStorage.setOrCreate<number>('selectedIndex', 0)
    AppStorage.setOrCreate<number>('selectionTick', 0)
    AppStorage.setOrCreate<string>('quoteStatus', '准备获取行情')
    AppStorage.setOrCreate<number>('lastUpdated', 0)
    AppStorage.setOrCreate<boolean>('refreshing', false)
    AppStorage.setOrCreate<boolean>('floatExpanded', false)
    AppStorage.setOrCreate<boolean>('previewExpanded', false)
    AppStorage.setOrCreate<boolean>('floatVisible', false)
    AppStorage.setOrCreate<string>('floatStatus', '尚未开启全局悬浮胶囊')
    AppStorage.setOrCreate<boolean>('backgroundActive', true)
    AppStorage.setOrCreate<boolean>('undoAvailable', false)
    AppStorage.setOrCreate<string>('undoMessage', '')
  }

  private startRefreshLoop(): void {
    if (this.refreshTimer >= 0) {
      return
    }
    // Reserve a non-negative value immediately so repeated lifecycle callbacks
    // cannot start a second loop while the first network request is in flight.
    this.refreshTimer = 0
    this.runRefreshLoop()
  }

  private startRotateLoop(): void {
    if (this.rotateTimer >= 0) {
      return
    }
    this.lastRotateAt = Date.now()
    this.rotateTimer = setInterval(() => {
      const expanded: boolean = AppStorage.get<boolean>('floatExpanded') ?? false
      const previewExpanded: boolean = AppStorage.get<boolean>('previewExpanded') ?? false
      const watchlist: Array<StockSymbol> = AppStorage.get<Array<StockSymbol>>('watchlist') ?? []
      const rotationEnabled: boolean = AppStorage.get<boolean>('rotationEnabled') ?? true
      const pinnedSymbolId: string = AppStorage.get<string>('pinnedSymbolId') ?? ''
      const interval: number = (AppStorage.get<number>('rotationIntervalSeconds') ?? 4) * 1000
      const now: number = Date.now()
      if (!expanded && !previewExpanded && rotationEnabled && pinnedSymbolId.length === 0 &&
        watchlist.length > 1 && now - this.lastRotateAt >= interval) {
        this.lastRotateAt = now
        this.selectNext()
      }
    }, 1000)
  }

  private bumpSelectionTick(): void {
    const tick: number = AppStorage.get<number>('selectionTick') ?? 0
    AppStorage.set<number>('selectionTick', tick + 1)
  }

  private async runRefreshLoop(): Promise<void> {
    await this.refresh()
    if (this.refreshTimer < 0) {
      return
    }
    const phase: MarketPhase = this.marketPhase()
    const configuredTradingInterval: number = (AppStorage.get<number>('tradingRefreshSeconds') ?? 5) * 1000
    const base: number = phase === MarketPhase.TRADING ? configuredTradingInterval :
      ChinaMarketCalendar.refreshIntervalMs(phase)
    const retry: number = this.failures === 0 ? base : Math.max(base, Math.min(60000, 5000 * Math.pow(2, this.failures)))
    this.refreshTimer = setTimeout(() => {
      this.runRefreshLoop()
    }, retry)
  }

  private decodeWatchlist(value: string): Array<StockSymbol> {
    const result: Array<StockSymbol> = []
    value.split(',').forEach((item: string) => {
      const symbol: StockSymbol | undefined = StockSymbol.parse(item)
      if (symbol !== undefined) {
        result.push(symbol)
      }
    })
    return result
  }

  private encodeQuoteCache(quotes: Array<StockQuote>): string {
    return quotes.map((quote: StockQuote) => [
      quote.symbol.id,
      quote.name.replace(/[|;]/g, ''),
      quote.price.toString(),
      quote.previousClose.toString(),
      quote.open.toString(),
      quote.high.toString(),
      quote.low.toString(),
      quote.change.toString(),
      quote.changePercent.toString(),
      quote.quoteTimestamp.toString(),
      quote.fetchedTimestamp.toString(),
      quote.source.replace(/[|;]/g, '')
    ].join('|')).join(';')
  }

  private decodeQuoteCache(value: string): Array<StockQuote> {
    const result: Array<StockQuote> = []
    value.split(';').forEach((item: string) => {
      const fields: Array<string> = item.split('|')
      if (fields.length !== 11 && fields.length !== 12) {
        return
      }
      const symbol: StockSymbol | undefined = StockSymbol.parse(fields[0])
      const price: number = Number(fields[2])
      const previousClose: number = Number(fields[3])
      const open: number = Number(fields[4])
      const high: number = Number(fields[5])
      const low: number = Number(fields[6])
      const change: number = Number(fields[7])
      const changePercent: number = Number(fields[8])
      const quoteTimestamp: number = Number(fields[9])
      const fetchedTimestamp: number = Number(fields[10])
      if (symbol === undefined || !Number.isFinite(price) || price <= 0 ||
        !Number.isFinite(previousClose) || !Number.isFinite(open) || !Number.isFinite(high) ||
        !Number.isFinite(low) || !Number.isFinite(change) || !Number.isFinite(changePercent) ||
        !Number.isFinite(quoteTimestamp) || !Number.isFinite(fetchedTimestamp)) {
        return
      }
      result.push(new StockQuote(symbol, fields[1], price, previousClose, open, high, low,
        change, changePercent, quoteTimestamp, fetchedTimestamp, fields.length === 12 ? fields[11] : '腾讯'))
    })
    return result
  }

  private async persistWatchlist(watchlist: Array<StockSymbol>): Promise<void> {
    if (this.dataPreferences === undefined) {
      return
    }
    try {
      this.dataPreferences.putSync('watchlist', watchlist.map((item: StockSymbol) => item.id).join(','))
      await this.dataPreferences.flush()
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      AppStorage.set<string>('quoteStatus', `自选已更新，但保存失败 · ${businessError.message}`)
    }
  }

  private async persistQuoteCache(quotes: Array<StockQuote>, force: boolean = false): Promise<void> {
    if (this.dataPreferences === undefined) {
      return
    }
    const now: number = Date.now()
    if (!force && now - this.lastCachePersistedAt < 60000) {
      return
    }
    try {
      this.dataPreferences.putSync('quote_cache', this.encodeQuoteCache(quotes))
      await this.dataPreferences.flush()
      this.lastCachePersistedAt = now
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      console.error(`Failed to persist quote cache. Code: ${businessError.code}, message: ${businessError.message}`)
    }
  }

  private clearUndo(): void {
    if (this.undoTimer >= 0) {
      clearTimeout(this.undoTimer)
      this.undoTimer = -1
    }
    this.removedSymbol = undefined
    this.removedQuote = undefined
    this.removedIndex = -1
    AppStorage.set<boolean>('undoAvailable', false)
    AppStorage.set<string>('undoMessage', '')
  }

  private sourceSummary(quotes: Array<StockQuote>): string {
    const sources: Array<string> = []
    quotes.forEach((quote: StockQuote) => {
      if (!sources.includes(quote.source)) {
        sources.push(quote.source)
      }
    })
    return sources.length === 0 ? '无有效数据源' : `数据源 ${sources.join('/')}`
  }

  private detectTradingDayClosure(quotes: Array<StockQuote>): void {
    const phase: MarketPhase = ChinaMarketCalendar.phase()
    const now: number = Date.now()
    const today: string = ChinaMarketCalendar.exchangeDateKey(now)
    if (phase !== MarketPhase.TRADING) {
      if (this.holidayDetectedDate !== today) {
        this.holidayDetectedDate = ''
      }
      return
    }
    const shanghaiNow: Date = new Date(now + 8 * 60 * 60 * 1000)
    const minutes: number = shanghaiNow.getUTCHours() * 60 + shanghaiNow.getUTCMinutes()
    const hasTodayQuote: boolean = quotes.some((quote: StockQuote) =>
      ChinaMarketCalendar.sameExchangeDay(quote.quoteTimestamp, now))
    if (hasTodayQuote) {
      this.holidayDetectedDate = ''
    } else if (minutes >= 9 * 60 + 35 && quotes.length > 0) {
      this.holidayDetectedDate = today
    }
  }
}

export const quoteStore: QuoteStore = QuoteStore.getInstance()
