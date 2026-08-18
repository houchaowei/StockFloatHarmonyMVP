import { AlertKind, AlertRepeatMode, PriceAlert } from '../model/PersonalModels'
import { personalStore } from '../model/PersonalStore'
import { StockQuote, StockSymbol } from '../model/StockModels'
import { ApplicationTheme } from '../model/ApplicationTheme'

@Component
export struct AlertEditorPage {
  @StorageLink('capsuleBackground') capsuleBackground: string = 'black'
  @StorageLink('priceAlerts') priceAlerts: Array<PriceAlert> = []
  @StorageLink('watchlist') watchlist: Array<StockSymbol> = []
  @StorageLink('quotes') quotes: Array<StockQuote> = []
  @StorageLink('alertStatus') alertStatus: string = '提醒仅在行情刷新运行期间触发'
  @StorageLink('privacyMode') privacyMode: boolean = false
  @StorageProp('topSafeHeight') topSafeHeight: number = 0
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0

  @Prop initialSymbolId: string = ''
  @Prop alertId: string = ''
  @State selectedSymbolId: string = ''
  @State alertKind: AlertKind = AlertKind.PRICE_ABOVE
  @State repeatMode: AlertRepeatMode = AlertRepeatMode.ONCE
  @State thresholdInput: string = ''
  @State saving: boolean = false
  onBack: () => void = () => {}

  aboutToAppear(): void {
    const alert: PriceAlert | undefined = this.editingAlert()
    if (alert !== undefined) {
      this.selectedSymbolId = alert.symbolId
      this.alertKind = alert.kind
      this.repeatMode = alert.repeatMode
      this.thresholdInput = alert.threshold.toString()
      return
    }
    this.selectedSymbolId = this.initialSymbolId.length > 0 ? this.initialSymbolId : (this.watchlist[0]?.id ?? '')
  }

  private editingAlert(): PriceAlert | undefined {
    return this.priceAlerts.find((alert: PriceAlert) => alert.id === this.alertId)
  }

  private quoteFor(symbolId: string): StockQuote | undefined {
    return this.quotes.find((quote: StockQuote) => quote.symbol.id === symbolId)
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
      return '自选行情'
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

  private kindSelected(kind: AlertKind): ResourceColor {
    return this.alertKind === kind ? ApplicationTheme.color(this.capsuleBackground, '#346DFF') : ApplicationTheme.color(this.capsuleBackground, '#252E3B')
  }

  private repeatSelected(mode: AlertRepeatMode): ResourceColor {
    return this.repeatMode === mode ? ApplicationTheme.color(this.capsuleBackground, '#203B34') : ApplicationTheme.color(this.capsuleBackground, '#252E3B')
  }

  private unitText(): string {
    return this.alertKind === AlertKind.PERCENT_UP || this.alertKind === AlertKind.PERCENT_DOWN ? '%' : '元'
  }

  private async save(): Promise<void> {
    if (this.saving) {
      return
    }
    this.saving = true
    const saved: boolean = this.alertId.length > 0 ?
      await personalStore.updateAlert(this.alertId, this.selectedSymbolId, this.alertKind,
        Number(this.thresholdInput), this.repeatMode) :
      await personalStore.addAlert(this.selectedSymbolId, this.alertKind,
        Number(this.thresholdInput), this.repeatMode)
    this.saving = false
    if (saved) {
      this.onBack()
    }
  }

  private requestDelete(): void {
    const alert: PriceAlert | undefined = this.editingAlert()
    if (alert === undefined) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: '删除这条提醒？',
      message: '删除后将不再检查该触发条件。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: ApplicationTheme.color(this.capsuleBackground, '#FF5A63'),
        action: () => {
          personalStore.removeAlert(alert)
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
            .backgroundColor(ApplicationTheme.color(this.capsuleBackground, '#252E3B'))
            .accessibilityText('返回提醒列表')
            .onClick(() => this.onBack())
          Column({ space: 3 }) {
            Text(this.alertId.length > 0 ? '编辑提醒' : '新建提醒')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(ApplicationTheme.color(this.capsuleBackground, '#F7F9FC'))
            Text('设置到价或涨跌幅触发条件')
              .fontSize(12)
              .fontColor(ApplicationTheme.color(this.capsuleBackground, '#8893A6'))
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        Column({ space: 10 }) {
          Text('提醒对象')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(ApplicationTheme.color(this.capsuleBackground, '#AAB5C6'))
            .width('100%')
          List({ space: 8 }) {
            ForEach(this.watchlist, (symbol: StockSymbol) => {
              ListItem() {
                Button(this.symbolLabel(symbol))
                  .height(40)
                  .fontSize(11)
                  .fontColor(ApplicationTheme.color(this.capsuleBackground, '#F2F5FA'))
                  .backgroundColor(symbol.id === this.selectedSymbolId ? ApplicationTheme.color(this.capsuleBackground, '#346DFF') : ApplicationTheme.color(this.capsuleBackground, '#252E3B'))
                  .onClick(() => this.selectedSymbolId = symbol.id)
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
                .fontColor(ApplicationTheme.color(this.capsuleBackground, '#EEF2F8'))
              Text(this.selectedCode())
                .fontSize(11)
                .fontColor(ApplicationTheme.color(this.capsuleBackground, '#758196'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Text(this.currentPriceText())
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(ApplicationTheme.color(this.capsuleBackground, '#F7F9FC'))
          }
          .padding(14)
          .width('100%')
          .backgroundColor(ApplicationTheme.color(this.capsuleBackground, '#171D27'))
          .borderRadius(12)
        }
        .padding(16)
        .width('100%')
        .backgroundColor(ApplicationTheme.color(this.capsuleBackground, '#121720'))
        .borderRadius(18)

        Column({ space: 12 }) {
          Text('触发条件')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(ApplicationTheme.color(this.capsuleBackground, '#EEF2F8'))
            .width('100%')
          Row({ space: 8 }) {
            Button('价格高于')
              .layoutWeight(1)
              .height(44)
              .backgroundColor(this.kindSelected(AlertKind.PRICE_ABOVE))
              .onClick(() => this.alertKind = AlertKind.PRICE_ABOVE)
            Button('价格低于')
              .layoutWeight(1)
              .height(44)
              .backgroundColor(this.kindSelected(AlertKind.PRICE_BELOW))
              .onClick(() => this.alertKind = AlertKind.PRICE_BELOW)
          }
          .width('100%')
          Row({ space: 8 }) {
            Button('涨幅达到')
              .layoutWeight(1)
              .height(44)
              .backgroundColor(this.kindSelected(AlertKind.PERCENT_UP))
              .onClick(() => this.alertKind = AlertKind.PERCENT_UP)
            Button('跌幅达到')
              .layoutWeight(1)
              .height(44)
              .backgroundColor(this.kindSelected(AlertKind.PERCENT_DOWN))
              .onClick(() => this.alertKind = AlertKind.PERCENT_DOWN)
          }
          .width('100%')
          Row({ space: 8 }) {
            TextInput({ text: this.thresholdInput, placeholder: `请输入阈值（${this.unitText()}）` })
              .layoutWeight(1)
              .height(48)
              .type(InputType.NUMBER_DECIMAL)
              .fontSize(15)
              .fontColor(ApplicationTheme.color(this.capsuleBackground, '#E7EBF2'))
              .placeholderColor(ApplicationTheme.color(this.capsuleBackground, '#AEB8C8'))
              .placeholderFont({ size: 14 })
              .backgroundColor(ApplicationTheme.color(this.capsuleBackground, '#171D27'))
              .onChange((value: string) => this.thresholdInput = value)
            Text(this.unitText())
              .fontSize(14)
              .fontColor(ApplicationTheme.color(this.capsuleBackground, '#AAB5C6'))
              .width(28)
          }
          .width('100%')
          if (this.privacyMode) {
            Text('隐私模式已开启；此处输入的阈值仅保存在本机，列表中会隐藏。')
              .fontSize(11)
              .fontColor(ApplicationTheme.color(this.capsuleBackground, '#8290A6'))
              .width('100%')
          }
        }
        .padding(16)
        .width('100%')
        .backgroundColor(ApplicationTheme.color(this.capsuleBackground, '#121720'))
        .borderRadius(18)

        Column({ space: 12 }) {
          Text('提醒频率')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(ApplicationTheme.color(this.capsuleBackground, '#EEF2F8'))
            .width('100%')
          Button('单次提醒 · 触发后停用')
            .height(44)
            .backgroundColor(this.repeatSelected(AlertRepeatMode.ONCE))
            .onClick(() => this.repeatMode = AlertRepeatMode.ONCE)
          Button('重复提醒 · 30 分钟冷却')
            .height(44)
            .backgroundColor(this.repeatSelected(AlertRepeatMode.COOLDOWN))
            .onClick(() => this.repeatMode = AlertRepeatMode.COOLDOWN)
          Button('每日提醒 · 每个交易日一次')
            .height(44)
            .backgroundColor(this.repeatSelected(AlertRepeatMode.DAILY))
            .onClick(() => this.repeatMode = AlertRepeatMode.DAILY)
        }
        .padding(16)
        .width('100%')
        .backgroundColor(ApplicationTheme.color(this.capsuleBackground, '#121720'))
        .borderRadius(18)

        Text('提醒依赖本机行情刷新，系统挂起、断网或应用停止刷新时不保证触发。')
          .fontSize(11)
          .fontColor(ApplicationTheme.color(this.capsuleBackground, '#FFB366'))
          .width('100%')

        Button(this.saving ? '保存中' : '保存提醒')
          .height(50)
          .enabled(!this.saving && this.selectedSymbolId.length > 0)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(ApplicationTheme.color(this.capsuleBackground, '#346DFF'))
          .onClick(() => this.save())

        if (this.alertId.length > 0) {
          Button('删除这条提醒')
            .height(46)
            .fontColor(ApplicationTheme.color(this.capsuleBackground, '#FF8990'))
            .backgroundColor(ApplicationTheme.color(this.capsuleBackground, '#322128'))
            .onClick(() => this.requestDelete())
        }

        Text(this.alertStatus)
          .fontSize(10)
          .fontColor(ApplicationTheme.color(this.capsuleBackground, '#68758A'))
          .padding({ bottom: this.bottomSafeHeight + 24 })
      }
      .padding({ left: 18, right: 18, top: this.topSafeHeight + 20 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ApplicationTheme.color(this.capsuleBackground, '#0C1017'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
