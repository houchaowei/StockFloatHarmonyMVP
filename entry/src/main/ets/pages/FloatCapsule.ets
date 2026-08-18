import { QuoteCapsule } from '../components/QuoteCapsule'
import { floatWindowManager } from '../model/FloatWindowManager'
import { quoteStore } from '../model/QuoteStore'
import { PositionRecord, PriceSeries } from '../model/PersonalModels'
import { StockQuote, StockSymbol } from '../model/StockModels'

@Entry
@Component
struct FloatCapsule {
  @StorageLink('quotes') quotes: Array<StockQuote> = []
  @StorageLink('watchlist') watchlist: Array<StockSymbol> = []
  @StorageLink('selectedIndex') selectedIndex: number = 0
  @StorageLink('selectionTick') selectionTick: number = 0
  @StorageLink('quoteStatus') quoteStatus: string = '等待行情'
  @StorageLink('floatExpanded') expanded: boolean = false
  @StorageLink('priceHistory') priceHistory: Array<PriceSeries> = []
  @StorageLink('positions') positions: Array<PositionRecord> = []
  @StorageLink('settingsTick') settingsTick: number = 0
  @StorageLink('backgroundActive') backgroundActive: boolean = true
  @StorageProp('privacyMode') privacyMode: boolean = false
  @StorageProp('reverseColors') reverseColors: boolean = false
  @StorageProp('capsuleOpacity') capsuleOpacity: number = 95
  @StorageProp('capsuleMetric') capsuleMetric: string = 'both'
  @StorageProp('capsuleBackground') capsuleBackground: string = 'black'
  @State renderTick: number = 0

  private selectedSymbol(): StockSymbol | undefined {
    return this.watchlist[this.selectedIndex]
  }

  private selectedQuote(): StockQuote | undefined {
    const _stateVersion: number = this.selectionTick + this.renderTick + this.settingsTick
    if (_stateVersion < 0) {
      return undefined
    }
    const symbol: StockSymbol | undefined = this.watchlist[this.selectedIndex]
    if (symbol === undefined) {
      return undefined
    }
    return this.quotes.find((quote: StockQuote) => quote.symbol.id === symbol.id)
  }

  private selectedPosition(): PositionRecord | undefined {
    const symbol: StockSymbol | undefined = this.selectedSymbol()
    return symbol === undefined ? undefined :
      this.positions.find((item: PositionRecord) => item.symbolId === symbol.id)
  }

  private selectedHistory(): Array<number> {
    const symbol: StockSymbol | undefined = this.selectedSymbol()
    if (symbol === undefined) {
      return []
    }
    return this.priceHistory.find((item: PriceSeries) => item.symbolId === symbol.id)?.prices() ?? []
  }

  build() {
    Stack() {
      QuoteCapsule({
        quote: this.selectedQuote(),
        index: this.selectedIndex,
        total: this.watchlist.length,
        status: `${quoteStore.marketPhase()} · ${this.quoteStatus}`,
        expanded: this.expanded,
        version: this.selectionTick + this.renderTick + this.settingsTick,
        positionRecord: this.selectedPosition(),
        history: this.selectedHistory(),
        marketPhase: quoteStore.marketPhase(),
        backgroundActive: this.backgroundActive,
        privacyMode: this.privacyMode,
        reverseColors: this.reverseColors,
        opacityPercent: this.capsuleOpacity,
        metricMode: this.capsuleMetric,
        backgroundStyle: this.capsuleBackground,
        onPrevious: () => {
          quoteStore.selectPrevious()
          this.renderTick += 1
        },
        onNext: () => {
          quoteStore.selectNext()
          this.renderTick += 1
        },
        onToggle: () => floatWindowManager.toggleExpanded(),
        onRefresh: () => quoteStore.refresh(),
        onClose: () => floatWindowManager.hide(),
        onDragStartHandler: (windowX: number, windowY: number) => floatWindowManager.startDrag(windowX, windowY),
        onDragUpdate: (offsetX: number, offsetY: number) => floatWindowManager.dragBy(offsetX, offsetY),
        onDragEndHandler: () => floatWindowManager.endDrag()
      })
    }
    .width('100%')
    .height('100%')
  }
}
