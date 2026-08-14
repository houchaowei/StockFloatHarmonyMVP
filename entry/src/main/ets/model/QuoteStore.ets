import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'
import { ChinaMarketCalendar, MarketPhase, StockQuote, StockSymbol } from './StockModels'
import { TencentQuoteProvider } from './TencentQuoteProvider'

const DEFAULT_WATCHLIST: string = 'sh600519,sz000001,sz300750'

export class QuoteStore {
  private static singleton: QuoteStore = new QuoteStore()
  private provider: TencentQuoteProvider = new TencentQuoteProvider()
  private dataPreferences?: preferences.Preferences
  private refreshTimer: number = -1
  private rotateTimer: number = -1
  private refreshing: boolean = false
  private failures: number = 0
  private lastCachePersistedAt: number = 0

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
      AppStorage.set<number>('lastUpdated', Date.now())
      AppStorage.set<string>('quoteStatus', fresh.length === watchlist.length ? '行情已更新' : '部分行情异常')
      await this.persistQuoteCache(merged)
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
    const symbol: StockSymbol | undefined = StockSymbol.parse(input)
    if (symbol === undefined) {
      AppStorage.set<string>('quoteStatus', '请输入 6 位 A 股代码')
      return false
    }
    const watchlist: Array<StockSymbol> = AppStorage.get<Array<StockSymbol>>('watchlist') ?? []
    if (watchlist.some((item: StockSymbol) => item.id === symbol.id)) {
      AppStorage.set<string>('quoteStatus', '该股票已在自选中')
      return false
    }
    if (watchlist.length >= 20) {
      AppStorage.set<string>('quoteStatus', '最多添加 20 只股票')
      return false
    }
    AppStorage.set<string>('quoteStatus', '正在验证股票…')
    try {
      const quotes: Array<StockQuote> = await this.provider.fetch([symbol])
      if (quotes.length !== 1) {
        AppStorage.set<string>('quoteStatus', '未找到该股票')
        return false
      }
      const updated: Array<StockSymbol> = watchlist.concat([symbol])
      const currentQuotes: Array<StockQuote> = AppStorage.get<Array<StockQuote>>('quotes') ?? []
      const updatedQuotes: Array<StockQuote> = currentQuotes.concat(quotes)
      AppStorage.set<Array<StockSymbol>>('watchlist', updated)
      AppStorage.set<Array<StockQuote>>('quotes', updatedQuotes)
      AppStorage.set<number>('selectedIndex', updated.length - 1)
      AppStorage.set<string>('quoteStatus', `已添加 ${quotes[0].name}`)
      await this.persistWatchlist(updated)
      await this.persistQuoteCache(updatedQuotes, true)
      return true
    } catch (error) {
      AppStorage.set<string>('quoteStatus', `验证失败 · ${(error as BusinessError).message}`)
      return false
    }
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
    await this.persistWatchlist(updated)
    await this.persistQuoteCache(updatedQuotes, true)
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
    return ChinaMarketCalendar.phase()
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
    this.rotateTimer = setInterval(() => {
      const expanded: boolean = AppStorage.get<boolean>('floatExpanded') ?? false
      const watchlist: Array<StockSymbol> = AppStorage.get<Array<StockSymbol>>('watchlist') ?? []
      const visible: boolean = AppStorage.get<boolean>('floatVisible') ?? false
      if (!expanded && watchlist.length > 1) {
        if (visible) {
          return
        }
        this.selectNext()
      }
    }, 4000)
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
    const phase: MarketPhase = ChinaMarketCalendar.phase()
    const base: number = ChinaMarketCalendar.refreshIntervalMs(phase)
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
      quote.fetchedTimestamp.toString()
    ].join('|')).join(';')
  }

  private decodeQuoteCache(value: string): Array<StockQuote> {
    const result: Array<StockQuote> = []
    value.split(';').forEach((item: string) => {
      const fields: Array<string> = item.split('|')
      if (fields.length !== 11) {
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
        change, changePercent, quoteTimestamp, fetchedTimestamp))
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
}

export const quoteStore: QuoteStore = QuoteStore.getInstance()
