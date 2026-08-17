import { PositionRecord } from '../model/PersonalModels'
import { personalStore } from '../model/PersonalStore'
import { StockQuote, StockSymbol } from '../model/StockModels'

@Component
export struct PositionEditorPage {
  @StorageLink('positions') positions: Array<PositionRecord> = []
  @StorageLink('watchlist') watchlist: Array<StockSymbol> = []
  @StorageLink('quotes') quotes: Array<StockQuote> = []
  @StorageLink('positionStatus') positionStatus: string = '持仓数据仅保存在本机'
  @StorageLink('privacyMode') privacyMode: boolean = false
  @StorageLink('reverseColors') reverseColors: boolean = false
  @StorageProp('topSafeHeight') topSafeHeight: number = 0
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0

  @Prop initialSymbolId: string = ''
  @State selectedSymbolId: string = ''
  @State costInput: string = ''
  @State quantityInput: string = ''
  @State saving: boolean = false
  onBack: () => void = () => {}

  aboutToAppear(): void {
    this.selectedSymbolId = this.initialSymbolId.length > 0 ? this.initialSymbolId : (this.watchlist[0]?.id ?? '')
    this.loadInputs()
  }

  private positionFor(symbolId: string): PositionRecord | undefined {
    return this.positions.find((item: PositionRecord) => item.symbolId === symbolId)
  }

  private quoteFor(symbolId: string): StockQuote | undefined {
    return this.quotes.find((quote: StockQuote) => quote.symbol.id === symbolId)
  }

  private loadInputs(): void {
    const position: PositionRecord | undefined = this.positionFor(this.selectedSymbolId)
    this.costInput = position === undefined ? '' : position.costPrice.toString()
    this.quantityInput = position === undefined ? '' : position.quantity.toString()
  }

  private selectSymbol(symbolId: string): void {
    this.selectedSymbolId = symbolId
    this.loadInputs()
  }

  private symbolLabel(symbol: StockSymbol): string {
    if (this.privacyMode) {
      const index: number = this.watchlist.findIndex((item: StockSymbol) => item.id === symbol.id)
      return `自选 ${index + 1}`
    }
    return this.quoteFor(symbol.id)?.name ?? symbol.displayCode
  }

  private selectedName(): string {
    if (this.privacyMode) {
      return '本地持仓'
    }
    return this.quoteFor(this.selectedSymbolId)?.name ?? this.selectedSymbolId
  }

  private selectedCode(): string {
    if (this.privacyMode) {
      return '代码已隐藏'
    }
    const symbol: StockSymbol | undefined = this.watchlist.find((item: StockSymbol) => item.id === this.selectedSymbolId)
    return symbol?.displayCode ?? `${this.selectedSymbolId} · 已移出自选`
  }

  private currentPriceText(): string {
    if (this.privacyMode) {
      return '••••'
    }
    const quote: StockQuote | undefined = this.quoteFor(this.selectedSymbolId)
    return quote === undefined ? '--' : quote.symbol.formatPrice(quote.price)
  }

  private previewProfit(): number | undefined {
    const quote: StockQuote | undefined = this.quoteFor(this.selectedSymbolId)
    const cost: number = Number(this.costInput)
    const quantity: number = Number(this.quantityInput)
    if (quote === undefined || !Number.isFinite(cost) || !Number.isFinite(quantity) || cost <= 0 || quantity <= 0) {
      return undefined
    }
    return (quote.price - cost) * quantity
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

  private async save(): Promise<void> {
    if (this.saving) {
      return
    }
    this.saving = true
    const saved: boolean = await personalStore.savePosition(
      this.selectedSymbolId, Number(this.costInput), Number(this.quantityInput))
    this.saving = false
    if (saved) {
      this.onBack()
    }
  }

  private requestDelete(): void {
    if (this.positionFor(this.selectedSymbolId) === undefined) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: '删除这笔本地持仓？',
      message: '删除后不可恢复，不会影响自选股和价格提醒。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#FF5A63',
        action: () => {
          personalStore.removePosition(this.selectedSymbolId)
          this.onBack()
        }
      }
    })
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row({ space: 12 }) {
          Button('‹')
            .width(44)
            .height(44)
            .fontSize(28)
            .backgroundColor('#252E3B')
            .accessibilityText('返回持仓列表')
            .onClick(() => this.onBack())
          Column({ space: 3 }) {
            Text(this.positionFor(this.selectedSymbolId) === undefined ? '新增持仓' : '编辑持仓')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F7F9FC')
            Text('成本与数量仅保存在本机')
              .fontSize(12)
              .fontColor('#8893A6')
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        Column({ space: 10 }) {
          Text('持仓股票')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#AAB5C6')
            .width('100%')
          List({ space: 8 }) {
            ForEach(this.watchlist, (symbol: StockSymbol) => {
              ListItem() {
                Button(this.symbolLabel(symbol))
                  .height(40)
                  .fontSize(11)
                  .fontColor('#F2F5FA')
                  .backgroundColor(symbol.id === this.selectedSymbolId ? '#346DFF' : '#252E3B')
                  .onClick(() => this.selectSymbol(symbol.id))
              }
            }, (symbol: StockSymbol) => symbol.id)
          }
          .listDirection(Axis.Horizontal)
          .scrollBar(BarState.Off)
          .height(40)
          .width('100%')
          Row() {
            Column({ space: 4 }) {
              Text(this.selectedName())
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor('#EEF2F8')
              Text(this.selectedCode())
                .fontSize(11)
                .fontColor('#758196')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Column({ space: 4 }) {
              Text('当前价')
                .fontSize(10)
                .fontColor('#8290A6')
              Text(this.currentPriceText())
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F7F9FC')
            }
            .alignItems(HorizontalAlign.End)
          }
          .padding(14)
          .width('100%')
          .backgroundColor('#171D27')
          .borderRadius(12)
        }
        .padding(16)
        .width('100%')
        .backgroundColor('#121720')
        .borderRadius(18)

        Column({ space: 12 }) {
          Text('持仓信息')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#EEF2F8')
            .width('100%')
          TextInput({ text: this.costInput, placeholder: '成本价' })
            .height(48)
            .type(InputType.NUMBER_DECIMAL)
            .fontColor('#E7EBF2')
            .backgroundColor('#171D27')
            .onChange((value: string) => this.costInput = value)
          TextInput({ text: this.quantityInput, placeholder: '持仓数量' })
            .height(48)
            .type(InputType.NUMBER_DECIMAL)
            .fontColor('#E7EBF2')
            .backgroundColor('#171D27')
            .onChange((value: string) => this.quantityInput = value)

          if (this.previewProfit() !== undefined) {
            Row() {
              Text('按当前行情估算累计盈亏')
                .fontSize(12)
                .fontColor('#8290A6')
              Blank()
              Text(this.privacyMode ? '••••' : (this.previewProfit()?.toFixed(2) ?? '--'))
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.profitColor(this.previewProfit() ?? 0))
            }
            .padding(14)
            .width('100%')
            .backgroundColor('#171D27')
            .borderRadius(12)
          }
          if (this.privacyMode) {
            Text('隐私模式已开启；此处输入的成本与数量仅保存在本机，其他页面会隐藏。')
              .fontSize(11)
              .fontColor('#8290A6')
              .width('100%')
          }
        }
        .padding(16)
        .width('100%')
        .backgroundColor('#121720')
        .borderRadius(18)

        Button(this.saving ? '保存中' : '保存本地持仓')
          .height(50)
          .enabled(!this.saving && this.selectedSymbolId.length > 0)
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#346DFF')
          .onClick(() => this.save())

        if (this.positionFor(this.selectedSymbolId) !== undefined) {
          Button('删除这笔持仓')
            .height(46)
            .fontColor('#FF8990')
            .backgroundColor('#322128')
            .onClick(() => this.requestDelete())
        }

        Text(`${this.positionStatus}；不会上传、同步或发起交易。`)
          .fontSize(10)
          .fontColor('#68758A')
          .padding({ bottom: this.bottomSafeHeight + 24 })
      }
      .padding({ left: 18, right: 18, top: this.topSafeHeight + 20 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0C1017')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
