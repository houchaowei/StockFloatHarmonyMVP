import { QuoteCapsule } from '../components/QuoteCapsule'
import { floatWindowManager } from '../model/FloatWindowManager'
import { quoteStore } from '../model/QuoteStore'
import { StockQuote, StockSymbol } from '../model/StockModels'

@Entry
@Component
struct Index {
  @StorageLink('quotes') quotes: Array<StockQuote> = []
  @StorageLink('watchlist') watchlist: Array<StockSymbol> = []
  @StorageLink('selectedIndex') selectedIndex: number = 0
  @StorageLink('quoteStatus') quoteStatus: string = '准备获取行情'
  @StorageLink('refreshing') refreshing: boolean = false
  @StorageLink('floatVisible') floatVisible: boolean = false
  @StorageLink('floatStatus') floatStatus: string = '尚未开启全局悬浮胶囊'
  @StorageProp('topSafeHeight') topSafeHeight: number = 0
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0
  @State inputCode: string = ''
  @State previewExpanded: boolean = false
  @State adding: boolean = false

  private selectedQuote(): StockQuote | undefined {
    const symbol: StockSymbol | undefined = this.watchlist[this.selectedIndex]
    if (symbol === undefined) {
      return undefined
    }
    return this.quotes.find((quote: StockQuote) => quote.symbol.id === symbol.id)
  }

  private quoteFor(symbol: StockSymbol): StockQuote | undefined {
    return this.quotes.find((quote: StockQuote) => quote.symbol.id === symbol.id)
  }

  private colorFor(quote: StockQuote | undefined): ResourceColor {
    if (quote === undefined || quote.changePercent === 0) {
      return '#AAB2C1'
    }
    return quote.changePercent > 0 ? '#FF5A63' : '#21C78B'
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
            Text('鸿蒙全局股票悬浮胶囊 · MVP')
              .fontSize(13)
              .fontColor('#8893A6')
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Button(this.refreshing ? '刷新中' : '刷新')
            .enabled(!this.refreshing)
            .onClick(() => quoteStore.refresh())
        }
        .width('100%')

        Column({ space: 10 }) {
          Row() {
            Text('全局悬浮')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#EEF2F8')
            Blank()
            Button(this.floatVisible ? '关闭胶囊' : '开启胶囊')
              .fontColor('#FFFFFF')
              .backgroundColor(this.floatVisible ? '#3A414D' : '#346DFF')
              .onClick(() => {
                if (this.floatVisible) {
                  floatWindowManager.hide()
                } else {
                  floatWindowManager.show()
                }
              })
          }
          .width('100%')

          Text(this.floatStatus)
            .fontSize(12)
            .fontColor(this.floatStatus.includes('缺少') || this.floatStatus.includes('失败') ? '#FFB366' : '#8FA1BD')
            .width('100%')
          Text('提示：全局窗口需要受限权限 ACL；无权限时仍可用下方预览验证行情与胶囊交互。')
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
            version: this.selectedIndex,
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
            .width(this.previewExpanded ? 304 : 186)
            .height(this.previewExpanded ? 246 : 54)
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
            Text(`${this.watchlist.length}/20`)
              .fontSize(12)
              .fontColor('#758196')
          }
          .width('100%')

          ForEach(this.watchlist, (symbol: StockSymbol, index: number) => {
            Row({ space: 12 }) {
              Column({ space: 3 }) {
                Text(this.quoteFor(symbol)?.name ?? symbol.displayCode)
                  .fontSize(15)
                  .fontWeight(index === this.selectedIndex ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor('#E7EBF2')
                Text(symbol.displayCode)
                  .fontSize(10)
                  .fontColor('#68758A')
              }
              .alignItems(HorizontalAlign.Start)
              .onClick(() => AppStorage.set<number>('selectedIndex', index))

              Blank()

              Column({ space: 3 }) {
                Text(this.quoteFor(symbol)?.price.toFixed(2) ?? '--')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#F2F5FA')
                Text(this.quoteFor(symbol) === undefined ? '--' : `${this.quoteFor(symbol)?.changePercent.toFixed(2)}%`)
                  .fontSize(11)
                  .fontColor(this.colorFor(this.quoteFor(symbol)))
              }
              .alignItems(HorizontalAlign.End)

              Button('删除')
                .fontSize(11)
                .fontColor('#FF8990')
                .backgroundColor('#322128')
                .onClick(() => quoteStore.removeSymbol(symbol))
            }
            .padding(12)
            .width('100%')
            .backgroundColor(index === this.selectedIndex ? '#222B39' : '#171D27')
            .borderRadius(12)
          }, (symbol: StockSymbol) => symbol.id)

          Row({ space: 10 }) {
            TextInput({ text: this.inputCode, placeholder: '输入 6 位代码，如 600036' })
              .layoutWeight(1)
              .height(44)
              .fontColor('#E7EBF2')
              .placeholderColor('#68758A')
              .backgroundColor('#121720')
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

        Text(`${quoteStore.marketPhase()} · ${this.quoteStatus}`)
          .fontSize(11)
          .fontColor('#68758A')
          .padding({ bottom: this.bottomSafeHeight + 24 })
      }
      .padding({ left: 18, right: 18, top: this.topSafeHeight + 24 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0C1017')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
