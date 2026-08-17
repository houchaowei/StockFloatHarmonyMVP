import { i18n } from '@kit.LocalizationKit'
import { QuoteCapsule } from '../components/QuoteCapsule'
import { floatWindowManager } from '../model/FloatWindowManager'
import { CapsuleDimensions, CapsuleMetric, CapsuleSize, PositionRecord, PriceAlert, PriceSeries } from '../model/PersonalModels'
import { personalStore } from '../model/PersonalStore'
import { quoteStore } from '../model/QuoteStore'
import { QuoteFreshness, QuoteFreshnessHelper, StockQuote, StockSymbol } from '../model/StockModels'

@Component
export struct WatchlistPage {
  @StorageLink('quotes') quotes: Array<StockQuote> = []
  @StorageLink('watchlist') watchlist: Array<StockSymbol> = []
  @StorageLink('selectedIndex') selectedIndex: number = 0
  @StorageLink('selectionTick') selectionTick: number = 0
  @StorageLink('quoteStatus') quoteStatus: string = '准备获取行情'
  @StorageLink('lastUpdated') lastUpdated: number = 0
  @StorageLink('refreshing') refreshing: boolean = false
  @StorageLink('floatVisible') floatVisible: boolean = false
  @StorageLink('floatStatus') floatStatus: string = '尚未开启全局悬浮胶囊'
  @StorageLink('backgroundActive') backgroundActive: boolean = true
  @StorageLink('priceAlerts') priceAlerts: Array<PriceAlert> = []
  @StorageLink('positions') positions: Array<PositionRecord> = []
  @StorageLink('priceHistory') priceHistory: Array<PriceSeries> = []
  @StorageLink('undoAvailable') undoAvailable: boolean = false
  @StorageLink('undoMessage') undoMessage: string = ''
  @StorageLink('settingsTick') settingsTick: number = 0
  @StorageLink('capsuleSize') capsuleSize: string = CapsuleSize.STANDARD
  @StorageLink('capsuleOpacity') capsuleOpacity: number = 95
  @StorageLink('capsuleMetric') capsuleMetric: string = CapsuleMetric.BOTH
  @StorageLink('privacyMode') privacyMode: boolean = false
  @StorageLink('reverseColors') reverseColors: boolean = false
  @StorageProp('topSafeHeight') topSafeHeight: number = 0

  @State inputCode: string = ''
  @State searchQuery: string = ''
  @State previewExpanded: boolean = false
  @State adding: boolean = false
  private transliterator?: i18n.Transliterator
  onOpenAlertEditor: (symbolId: string, alertId: string) => void = () => {}
  onOpenPositionEditor: (symbolId: string) => void = () => {}

  aboutToAppear(): void {
    this.previewExpanded = AppStorage.get<boolean>('previewExpanded') ?? false
    try {
      this.transliterator = i18n.Transliterator.getInstance('Han-Latin')
    } catch (error) {
      console.info('Han-Latin transliterator is unavailable; name and code search remain available.')
    }
  }

  private selectedSymbol(): StockSymbol | undefined {
    return this.watchlist[this.selectedIndex]
  }

  private selectedQuote(): StockQuote | undefined {
    const symbol: StockSymbol | undefined = this.selectedSymbol()
    return symbol === undefined ? undefined : this.quoteFor(symbol)
  }

  private quoteFor(symbol: StockSymbol): StockQuote | undefined {
    return this.quotes.find((quote: StockQuote) => quote.symbol.id === symbol.id)
  }

  private positionFor(symbolId: string): PositionRecord | undefined {
    return this.positions.find((item: PositionRecord) => item.symbolId === symbolId)
  }

  private selectedPosition(): PositionRecord | undefined {
    const symbol: StockSymbol | undefined = this.selectedSymbol()
    return symbol === undefined ? undefined : this.positionFor(symbol.id)
  }

  private selectedHistory(): Array<number> {
    const symbol: StockSymbol | undefined = this.selectedSymbol()
    if (symbol === undefined) {
      return []
    }
    return this.priceHistory.find((item: PriceSeries) => item.symbolId === symbol.id)?.prices() ?? []
  }

  private currentCapsuleSize(): CapsuleSize {
    if (this.capsuleSize === CapsuleSize.COMPACT) {
      return CapsuleSize.COMPACT
    }
    if (this.capsuleSize === CapsuleSize.LARGE) {
      return CapsuleSize.LARGE
    }
    return CapsuleSize.STANDARD
  }

  private colorFor(quote: StockQuote | undefined): ResourceColor {
    if (this.privacyMode || quote === undefined || quote.changePercent === 0) {
      return '#AAB2C1'
    }
    if (this.reverseColors) {
      return quote.changePercent > 0 ? '#21C78B' : '#FF5A63'
    }
    return quote.changePercent > 0 ? '#FF5A63' : '#21C78B'
  }

  private displayName(symbol: StockSymbol): string {
    return this.privacyMode ? '自选行情' : (this.quoteFor(symbol)?.name ?? symbol.displayCode)
  }

  private displayPrice(quote: StockQuote | undefined): string {
    if (this.privacyMode) {
      return '••••'
    }
    return quote === undefined ? '--' : quote.symbol.formatPrice(quote.price)
  }

  private freshnessFor(quote: StockQuote | undefined): QuoteFreshness {
    return QuoteFreshnessHelper.value(quote, quoteStore.marketPhase(), this.backgroundActive)
  }

  private normalizedSearch(value: string): string {
    return value.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '')
      .replace(/[^a-z0-9\u4e00-\u9fff]/g, '')
  }

  private pinyinKeys(name: string): string {
    if (this.transliterator === undefined || name.length === 0) {
      return ''
    }
    try {
      const latin: string = this.transliterator.transform(name).toLowerCase().normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
      const words: Array<string> = latin.split(/\s+/).filter((word: string) => word.length > 0)
      return `${words.join('')}${words.map((word: string) => word.substring(0, 1)).join('')}`
    } catch (error) {
      return ''
    }
  }

  private filteredWatchlist(): Array<StockSymbol> {
    const query: string = this.normalizedSearch(this.searchQuery)
    if (query.length === 0) {
      return this.watchlist
    }
    return this.watchlist.filter((symbol: StockSymbol) => {
      const quote: StockQuote | undefined = this.quoteFor(symbol)
      const name: string = quote?.name ?? ''
      return this.normalizedSearch(`${name}${symbol.id}${symbol.displayCode}${this.pinyinKeys(name)}`).includes(query)
    })
  }

  private selectSymbol(symbol: StockSymbol): void {
    const index: number = this.watchlist.findIndex((item: StockSymbol) => item.id === symbol.id)
    if (index >= 0) {
      AppStorage.set<number>('selectedIndex', index)
      this.selectionTick += 1
    }
  }

  private relatedDescription(symbol: StockSymbol): string {
    const alertCount: number = this.priceAlerts.filter((alert: PriceAlert) => alert.symbolId === symbol.id).length
    const hasPosition: boolean = this.positionFor(symbol.id) !== undefined
    if (alertCount === 0 && !hasPosition) {
      return ''
    }
    return `${alertCount} 条提醒${hasPosition ? '和 1 条本地持仓' : ''}`
  }

  private requestRemove(symbol: StockSymbol): void {
    const related: string = this.relatedDescription(symbol)
    if (related.length === 0) {
      quoteStore.removeSymbol(symbol)
      return
    }
    this.getUIContext().showAlertDialog({
      title: '删除自选股？',
      message: `该股票还有 ${related}。保留后，重新加入自选即可恢复行情关联。`,
      primaryButton: {
        value: '仅移除自选',
        action: () => quoteStore.removeSymbol(symbol)
      },
      secondaryButton: {
        value: '删除全部关联',
        fontColor: '#FF5A63',
        action: () => this.removeSymbolAndRelated(symbol)
      }
    })
  }

  private async removeSymbolAndRelated(symbol: StockSymbol): Promise<void> {
    const removedAlerts: number = await personalStore.removeAlertsForSymbol(symbol.id)
    const hadPosition: boolean = this.positionFor(symbol.id) !== undefined
    if (hadPosition) {
      await personalStore.removePosition(symbol.id)
    }
    await quoteStore.removeSymbol(symbol)
    AppStorage.set<string>('quoteStatus',
      `已删除自选及 ${removedAlerts} 条提醒${hadPosition ? '、1 条持仓' : ''}`)
  }

  private lastUpdatedText(): string {
    if (this.lastUpdated <= 0) {
      return '尚未更新'
    }
    const elapsedSeconds: number = Math.max(0, Math.floor((Date.now() - this.lastUpdated) / 1000))
    if (elapsedSeconds < 60) {
      return `${elapsedSeconds} 秒前请求`
    }
    if (elapsedSeconds < 3600) {
      return `${Math.floor(elapsedSeconds / 60)} 分钟前请求`
    }
    return `${Math.floor(elapsedSeconds / 3600)} 小时前请求`
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Column({ space: 4 }) {
            Text('StockFloat')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F7F9FC')
            Text('自选行情与悬浮胶囊')
              .fontSize(13)
              .fontColor('#8893A6')
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Button(this.refreshing ? '刷新中' : '刷新')
            .height(44)
            .enabled(!this.refreshing)
            .onClick(() => quoteStore.refresh())
        }
        .width('100%')

        Column({ space: 10 }) {
          Row() {
            Column({ space: 3 }) {
              Text('全局悬浮')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor('#EEF2F8')
              Text(this.floatStatus)
                .fontSize(12)
                .fontColor(this.floatStatus.includes('失败') || this.floatStatus.includes('缺少') ? '#FFB366' : '#8FA1BD')
                .maxLines(2)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Button(this.floatVisible ? '关闭胶囊' : '开启胶囊')
              .height(44)
              .fontColor('#FFFFFF')
              .backgroundColor(this.floatVisible ? '#3A414D' : '#346DFF')
              .onClick(() => this.floatVisible ? floatWindowManager.hide() : floatWindowManager.show())
          }
          .width('100%')
          Text('悬浮显示与后台刷新是两种状态；系统挂起后会标记“后台已暂停”。')
            .fontSize(11)
            .fontColor('#68758A')
            .width('100%')
        }
        .padding(16)
        .width('100%')
        .backgroundColor('#171D27')
        .borderRadius(18)

        Column({ space: 10 }) {
          Row() {
            Text('应用内实时预览')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#DCE2EC')
            Blank()
            Text(quoteStore.marketPhase())
              .fontSize(11)
              .fontColor('#8290A6')
          }
          .width('100%')
          QuoteCapsule({
            quote: this.selectedQuote(),
            index: this.selectedIndex,
            total: this.watchlist.length,
            status: this.quoteStatus,
            expanded: this.previewExpanded,
            version: this.selectionTick + this.settingsTick,
            positionRecord: this.selectedPosition(),
            history: this.selectedHistory(),
            marketPhase: quoteStore.marketPhase(),
            backgroundActive: this.backgroundActive,
            privacyMode: this.privacyMode,
            reverseColors: this.reverseColors,
            opacityPercent: this.capsuleOpacity,
            metricMode: this.capsuleMetric,
            onPrevious: () => quoteStore.selectPrevious(),
            onNext: () => quoteStore.selectNext(),
            onToggle: () => {
              this.previewExpanded = !this.previewExpanded
              AppStorage.set<boolean>('previewExpanded', this.previewExpanded)
            },
            onRefresh: () => quoteStore.refresh(),
            onClose: () => {
              this.previewExpanded = false
              AppStorage.set<boolean>('previewExpanded', false)
            }
          })
            .width(this.previewExpanded ? CapsuleDimensions.expandedWidth(this.currentCapsuleSize()) :
              CapsuleDimensions.collapsedWidth(this.currentCapsuleSize()))
            .height(this.previewExpanded ? CapsuleDimensions.expandedHeight(this.currentCapsuleSize()) :
              CapsuleDimensions.collapsedHeight(this.currentCapsuleSize()))
        }
        .padding(16)
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#121720')
        .borderRadius(18)

        Column({ space: 12 }) {
          Row() {
            Text('自选股')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#EEF2F8')
            Blank()
            Text(`${this.watchlist.length}/20 · 长按拖动排序`)
              .fontSize(11)
              .fontColor('#758196')
          }
          .width('100%')

          TextInput({ text: this.searchQuery, placeholder: '搜索当前自选：名称 / 拼音 / 代码' })
            .height(44)
            .fontColor('#E7EBF2')
            .placeholderColor('#68758A')
            .backgroundColor('#171D27')
            .onChange((value: string) => this.searchQuery = value)

          Row({ space: 8 }) {
            Button('涨幅排序').height(40).onClick(() => quoteStore.sortByChange(true))
            Button('跌幅排序').height(40).onClick(() => quoteStore.sortByChange(false))
            Blank()
            if (this.undoAvailable) {
              Button('撤销删除')
                .height(40)
                .fontColor('#9DB8FF')
                .onClick(() => quoteStore.undoRemove())
            }
          }
          .width('100%')

          if (this.undoAvailable) {
            Text(`${this.privacyMode ? '已删除一只自选' : this.undoMessage}，可在 6 秒内撤销`)
              .fontSize(11)
              .fontColor('#FFB366')
              .width('100%')
          }

          List({ space: 8 }) {
            ForEach(this.filteredWatchlist(), (symbol: StockSymbol) => {
              ListItem() {
                Column({ space: 8 }) {
                  Row({ space: 10 }) {
                    Text('≡')
                      .fontSize(18)
                      .fontColor(this.searchQuery.length === 0 ? '#71809A' : '#3F4858')
                      .width(24)
                    Column({ space: 3 }) {
                      Text(this.displayName(symbol))
                        .fontSize(15)
                        .fontWeight(symbol.id === this.selectedSymbol()?.id ? FontWeight.Bold : FontWeight.Medium)
                        .fontColor('#E7EBF2')
                        .maxLines(1)
                      Text(`${this.privacyMode ? '代码已隐藏' : symbol.displayCode} · ${this.freshnessFor(this.quoteFor(symbol))}`)
                        .fontSize(11)
                        .fontColor(QuoteFreshnessHelper.color(this.freshnessFor(this.quoteFor(symbol))))
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                    Column({ space: 3 }) {
                      Text(this.displayPrice(this.quoteFor(symbol)))
                        .fontSize(15)
                        .fontWeight(FontWeight.Medium)
                        .fontColor('#F2F5FA')
                      Text(this.privacyMode || this.quoteFor(symbol) === undefined ? '••••' :
                        `${this.quoteFor(symbol)?.changePercent.toFixed(2)}%`)
                        .fontSize(11)
                        .fontColor(this.colorFor(this.quoteFor(symbol)))
                    }
                    .alignItems(HorizontalAlign.End)
                  }
                  .width('100%')
                  .onClick(() => this.selectSymbol(symbol))

                  Row({ space: 8 }) {
                    Button('设提醒')
                      .height(38)
                      .fontSize(11)
                      .backgroundColor('#243554')
                      .onClick(() => this.onOpenAlertEditor(symbol.id, ''))
                    Button(this.positionFor(symbol.id) === undefined ? '记持仓' : '改持仓')
                      .height(38)
                      .fontSize(11)
                      .backgroundColor('#203B34')
                      .onClick(() => this.onOpenPositionEditor(symbol.id))
                    Blank()
                    Button('删除')
                      .height(38)
                      .fontSize(11)
                      .fontColor('#FF8990')
                      .backgroundColor('#322128')
                      .onClick(() => this.requestRemove(symbol))
                  }
                  .width('100%')
                }
                .padding(10)
                .width('100%')
                .backgroundColor(symbol.id === this.selectedSymbol()?.id ? '#222B39' : '#171D27')
                .borderRadius(12)
              }
            }, (symbol: StockSymbol) => symbol.id)
              .onMove((from: number, to: number) => {
                if (this.searchQuery.length === 0) {
                  quoteStore.moveSymbol(from, to)
                }
              })
          }
          .width('100%')
          .height(Math.max(108, Math.min(680, this.filteredWatchlist().length * 112)))

          Row({ space: 10 }) {
            TextInput({ text: this.inputCode, placeholder: '代码 / 中文名 / 拼音，如 600036、招商银行' })
              .layoutWeight(1)
              .height(44)
              .fontColor('#E7EBF2')
              .placeholderColor('#68758A')
              .backgroundColor('#171D27')
              .onChange((value: string) => this.inputCode = value)
            Button(this.adding ? '验证中' : '添加')
              .height(44)
              .enabled(!this.adding)
              .onClick(async () => {
                this.adding = true
                const added: boolean = await quoteStore.addSymbol(this.inputCode)
                if (added) {
                  this.inputCode = ''
                }
                this.adding = false
              })
          }
          .width('100%')
        }
        .padding(16)
        .width('100%')
        .backgroundColor('#121720')
        .borderRadius(18)

        Text(`${quoteStore.marketPhase()} · ${this.privacyMode ? '行情状态已隐藏' : this.quoteStatus} · ${this.lastUpdatedText()}`)
          .fontSize(11)
          .fontColor('#68758A')
          .padding({ bottom: 24 })
      }
      .padding({ left: 18, right: 18, top: this.topSafeHeight + 24 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0C1017')
  }
}
