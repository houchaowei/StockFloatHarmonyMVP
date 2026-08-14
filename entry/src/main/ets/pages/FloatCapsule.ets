import { QuoteCapsule } from '../components/QuoteCapsule'
import { floatWindowManager } from '../model/FloatWindowManager'
import { quoteStore } from '../model/QuoteStore'
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
  @State renderTick: number = 0
  private rotateTimer: number = -1

  aboutToAppear(): void {
    this.startRotateTimer()
  }

  aboutToDisappear(): void {
    this.stopRotateTimer()
  }

  private startRotateTimer(): void {
    if (this.rotateTimer >= 0) {
      return
    }
    this.rotateTimer = setInterval(() => {
      if (!this.expanded && this.watchlist.length > 1) {
        quoteStore.selectNext()
        this.renderTick += 1
      }
    }, 4000)
  }

  private stopRotateTimer(): void {
    if (this.rotateTimer < 0) {
      return
    }
    clearInterval(this.rotateTimer)
    this.rotateTimer = -1
  }

  private selectedQuote(): StockQuote | undefined {
    const _stateVersion: number = this.selectionTick + this.renderTick
    if (_stateVersion < 0) {
      return undefined
    }
    const symbol: StockSymbol | undefined = this.watchlist[this.selectedIndex]
    if (symbol === undefined) {
      return undefined
    }
    return this.quotes.find((quote: StockQuote) => quote.symbol.id === symbol.id)
  }

  build() {
    Stack() {
      QuoteCapsule({
        quote: this.selectedQuote(),
        index: this.selectedIndex,
        total: this.watchlist.length,
        status: `${quoteStore.marketPhase()} · ${this.quoteStatus}`,
        expanded: this.expanded,
        version: this.selectionTick + this.renderTick,
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
