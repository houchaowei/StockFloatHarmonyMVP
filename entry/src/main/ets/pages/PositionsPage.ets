import { PositionRecord } from '../model/PersonalModels'
import { StockQuote, StockSymbol } from '../model/StockModels'

@Component
export struct PositionsPage {
  @StorageLink('positions') positions: Array<PositionRecord> = []
  @StorageLink('watchlist') watchlist: Array<StockSymbol> = []
  @StorageLink('quotes') quotes: Array<StockQuote> = []
  @StorageLink('selectedIndex') selectedIndex: number = 0
  @StorageLink('positionStatus') positionStatus: string = '持仓数据仅保存在本机'
  @StorageLink('privacyMode') privacyMode: boolean = false
  @StorageLink('reverseColors') reverseColors: boolean = false
  @StorageProp('topSafeHeight') topSafeHeight: number = 0
  onOpenEditor: (symbolId: string) => void = () => {}

  private quoteFor(symbolId: string): StockQuote | undefined {
    return this.quotes.find((quote: StockQuote) => quote.symbol.id === symbolId)
  }

  private nameFor(symbolId: string): string {
    if (this.privacyMode) {
      return '本地持仓'
    }
    return this.quoteFor(symbolId)?.name ?? symbolId
  }

  private codeFor(symbolId: string): string {
    if (this.privacyMode) {
      return '代码已隐藏'
    }
    const symbol: StockSymbol | undefined = this.watchlist.find((item: StockSymbol) => item.id === symbolId)
    return symbol?.displayCode ?? `${symbolId} · 已移出自选`
  }

  private totalCost(): number {
    return this.positions.reduce((sum: number, item: PositionRecord) => sum + item.costPrice * item.quantity, 0)
  }

  private marketValue(item: PositionRecord): number {
    const quote: StockQuote | undefined = this.quoteFor(item.symbolId)
    return quote === undefined ? 0 : quote.price * item.quantity
  }

  private totalMarketValue(): number {
    return this.positions.reduce((sum: number, item: PositionRecord) => sum + this.marketValue(item), 0)
  }

  private profit(item: PositionRecord): number {
    const quote: StockQuote | undefined = this.quoteFor(item.symbolId)
    return quote === undefined ? 0 : item.totalProfit(quote.price)
  }

  private totalProfit(): number {
    return this.positions.reduce((sum: number, item: PositionRecord) => sum + this.profit(item), 0)
  }

  private todayProfit(): number {
    return this.positions.reduce((sum: number, item: PositionRecord) => {
      const quote: StockQuote | undefined = this.quoteFor(item.symbolId)
      return sum + (quote === undefined ? 0 : item.todayProfit(quote.change))
    }, 0)
  }

  private money(value: number): string {
    return this.privacyMode ? '••••' : value.toFixed(2)
  }

  private marketValueText(item: PositionRecord): string {
    if (this.privacyMode) {
      return '••••'
    }
    return this.quoteFor(item.symbolId) === undefined ? '--' : this.marketValue(item).toFixed(2)
  }

  private profitText(item: PositionRecord): string {
    if (this.privacyMode) {
      return '••••'
    }
    if (this.quoteFor(item.symbolId) === undefined) {
      return '暂无行情'
    }
    const value: number = this.profit(item)
    return `${value >= 0 ? '+' : ''}${value.toFixed(2)}`
  }

  private missingQuoteCount(): number {
    return this.positions.filter((item: PositionRecord) => this.quoteFor(item.symbolId) === undefined).length
  }

  private profitColor(value: number): ResourceColor {
    if (this.privacyMode || value === 0) {
      return '#AAB2C1'
    }
    if (this.reverseColors) {
      return value > 0 ? '#21C78B' : '#FF5A63'
    }
    return value > 0 ? '#FF5A63' : '#21C78B'
  }

  private defaultSymbolId(): string {
    return this.watchlist[this.selectedIndex]?.id ?? this.watchlist[0]?.id ?? ''
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Column({ space: 4 }) {
            Text('本地持仓')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F7F9FC')
            Text('成本、市值和盈亏仅在本机计算')
              .fontSize(13)
              .fontColor('#8893A6')
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Button('新增持仓')
            .height(44)
            .enabled(this.watchlist.length > 0)
            .backgroundColor('#346DFF')
            .onClick(() => this.onOpenEditor(this.defaultSymbolId()))
        }
        .width('100%')

        Column({ space: 14 }) {
          Row() {
            Column({ space: 4 }) {
              Text(this.missingQuoteCount() > 0 ? '可估算市值' : '当前市值')
                .fontSize(11)
                .fontColor('#8290A6')
              Text(this.money(this.totalMarketValue()))
                .fontSize(26)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F7F9FC')
            }
            .alignItems(HorizontalAlign.Start)
            Blank()
            Column({ space: 4 }) {
              Text('累计盈亏')
                .fontSize(11)
                .fontColor('#8290A6')
              Text(this.money(this.totalProfit()))
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.profitColor(this.totalProfit()))
            }
            .alignItems(HorizontalAlign.End)
          }
          .width('100%')
          Row() {
            Text(`总成本 ${this.money(this.totalCost())}`)
              .fontSize(12)
              .fontColor('#AAB5C6')
            Blank()
            Text(`今日 ${this.money(this.todayProfit())}`)
              .fontSize(12)
              .fontColor(this.profitColor(this.todayProfit()))
          }
          .width('100%')
        }
        .padding(18)
        .width('100%')
        .backgroundColor('#171D27')
        .borderRadius(18)

        if (this.positions.length === 0) {
          Column({ space: 12 }) {
            Text('▣')
              .fontSize(34)
              .fontColor('#4D5B70')
            Text('还没有本地持仓')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#DCE2EC')
            Text('录入成本价和数量后，胶囊也可显示持仓盈亏')
              .fontSize(12)
              .fontColor('#758196')
            Button('录入第一笔持仓')
              .height(44)
              .enabled(this.watchlist.length > 0)
              .backgroundColor('#346DFF')
              .onClick(() => this.onOpenEditor(this.defaultSymbolId()))
          }
          .padding(32)
          .width('100%')
          .backgroundColor('#121720')
          .borderRadius(18)
        }

        if (this.positions.length > 0) {
          Column({ space: 10 }) {
            Row() {
              Text('持仓明细')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor('#EEF2F8')
              Blank()
              Text(`${this.positions.length} 只`)
                .fontSize(11)
                .fontColor('#758196')
            }
            .width('100%')

            ForEach(this.positions, (position: PositionRecord) => {
              Column({ space: 10 }) {
                Row() {
                  Column({ space: 4 }) {
                    Text(this.nameFor(position.symbolId))
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#E7EBF2')
                    Text(`${this.codeFor(position.symbolId)} · ${this.privacyMode ? '数量已隐藏' : `${position.quantity} 股`}`)
                      .fontSize(11)
                      .fontColor('#758196')
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  Column({ space: 4 }) {
                    Text(this.marketValueText(position))
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#F2F5FA')
                    Text(this.profitText(position))
                      .fontSize(11)
                      .fontColor(this.profitColor(this.profit(position)))
                  }
                  .alignItems(HorizontalAlign.End)
                }
                .width('100%')
                Row() {
                  Text(this.privacyMode ? '成本价 ••••' : `成本价 ${position.costPrice}`)
                    .fontSize(11)
                    .fontColor('#8290A6')
                  Blank()
                  Button('编辑持仓')
                    .height(38)
                    .fontSize(11)
                    .backgroundColor('#243554')
                    .onClick(() => this.onOpenEditor(position.symbolId))
                }
                .width('100%')
              }
              .padding(14)
              .width('100%')
              .backgroundColor('#171D27')
              .borderRadius(12)
            }, (position: PositionRecord) => position.symbolId)
          }
          .padding(16)
          .width('100%')
          .backgroundColor('#121720')
          .borderRadius(18)
        }

        Column({ space: 5 }) {
          Text('本地数据说明')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#AAB5C6')
          Text(`${this.positionStatus}；不会上传、同步或发起交易。`)
            .fontSize(10)
            .fontColor('#68758A')
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ bottom: 24 })
        .width('100%')
      }
      .padding({ left: 18, right: 18, top: this.topSafeHeight + 24 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0C1017')
  }
}
