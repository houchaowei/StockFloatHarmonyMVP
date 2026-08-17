import { PriceAlert } from '../model/PersonalModels'
import { personalStore } from '../model/PersonalStore'
import { StockQuote, StockSymbol } from '../model/StockModels'

@Component
export struct AlertsPage {
  @StorageLink('priceAlerts') priceAlerts: Array<PriceAlert> = []
  @StorageLink('watchlist') watchlist: Array<StockSymbol> = []
  @StorageLink('quotes') quotes: Array<StockQuote> = []
  @StorageLink('alertStatus') alertStatus: string = '提醒仅在行情刷新运行期间触发'
  @StorageLink('privacyMode') privacyMode: boolean = false
  @StorageProp('topSafeHeight') topSafeHeight: number = 0
  @State filter: string = 'all'
  onOpenEditor: (symbolId: string, alertId: string) => void = () => {}

  private visibleAlerts(): Array<PriceAlert> {
    if (this.filter === 'enabled') {
      return this.priceAlerts.filter((alert: PriceAlert) => alert.enabled)
    }
    if (this.filter === 'disabled') {
      return this.priceAlerts.filter((alert: PriceAlert) => !alert.enabled)
    }
    return this.priceAlerts
  }

  private alertSymbolIds(): Array<string> {
    const result: Array<string> = []
    this.visibleAlerts().forEach((alert: PriceAlert) => {
      if (!result.includes(alert.symbolId)) {
        result.push(alert.symbolId)
      }
    })
    return result
  }

  private alertsFor(symbolId: string): Array<PriceAlert> {
    return this.visibleAlerts().filter((alert: PriceAlert) => alert.symbolId === symbolId)
  }

  private quoteFor(symbolId: string): StockQuote | undefined {
    return this.quotes.find((quote: StockQuote) => quote.symbol.id === symbolId)
  }

  private nameFor(symbolId: string): string {
    if (this.privacyMode) {
      return '自选行情'
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

  private enabledCount(): number {
    return this.priceAlerts.filter((alert: PriceAlert) => alert.enabled).length
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Column({ space: 4 }) {
            Text('价格提醒')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F7F9FC')
            Text('集中管理所有股票触发规则')
              .fontSize(13)
              .fontColor('#8893A6')
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Button('新建提醒')
            .height(44)
            .enabled(this.watchlist.length > 0)
            .backgroundColor('#346DFF')
            .onClick(() => this.onOpenEditor('', ''))
        }
        .width('100%')

        Column({ space: 10 }) {
          Row() {
            Column({ space: 3 }) {
              Text(`已启用 ${this.enabledCount()} 条`)
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor('#EEF2F8')
              Text(this.alertStatus)
                .fontSize(11)
                .fontColor(this.alertStatus.includes('未开启') || this.alertStatus.includes('失败') ? '#FFB366' : '#8290A6')
                .maxLines(2)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Button('通知授权')
              .height(40)
              .fontSize(11)
              .onClick(() => personalStore.requestNotificationPermission())
          }
          .width('100%')
          Text('提醒由本机刷新行情时判断；系统挂起、无网络或刷新停止时不保证触发。')
            .fontSize(11)
            .fontColor('#FFB366')
            .width('100%')
        }
        .padding(16)
        .width('100%')
        .backgroundColor('#171D27')
        .borderRadius(18)

        Row({ space: 8 }) {
          Button(`全部 ${this.priceAlerts.length}`)
            .height(40)
            .fontSize(11)
            .backgroundColor(this.filter === 'all' ? '#346DFF' : '#252E3B')
            .onClick(() => this.filter = 'all')
          Button(`已启用 ${this.enabledCount()}`)
            .height(40)
            .fontSize(11)
            .backgroundColor(this.filter === 'enabled' ? '#346DFF' : '#252E3B')
            .onClick(() => this.filter = 'enabled')
          Button(`已停用 ${this.priceAlerts.length - this.enabledCount()}`)
            .height(40)
            .fontSize(11)
            .backgroundColor(this.filter === 'disabled' ? '#346DFF' : '#252E3B')
            .onClick(() => this.filter = 'disabled')
        }
        .width('100%')

        if (this.visibleAlerts().length === 0) {
          Column({ space: 12 }) {
            Text('◎')
              .fontSize(34)
              .fontColor('#4D5B70')
            Text(this.priceAlerts.length === 0 ? '还没有价格提醒' : '当前筛选下没有提醒')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#DCE2EC')
            Text('可以为股票设置到价、涨幅或跌幅提醒')
              .fontSize(12)
              .fontColor('#758196')
            if (this.priceAlerts.length === 0) {
              Button('创建第一条提醒')
                .height(44)
                .backgroundColor('#346DFF')
                .onClick(() => this.onOpenEditor('', ''))
            }
          }
          .padding(32)
          .width('100%')
          .backgroundColor('#121720')
          .borderRadius(18)
        }

        ForEach(this.alertSymbolIds(), (symbolId: string) => {
          Column({ space: 10 }) {
            Row() {
              Column({ space: 3 }) {
                Text(this.nameFor(symbolId))
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#EEF2F8')
                Text(`${this.codeFor(symbolId)} · ${this.alertsFor(symbolId).length} 条规则`)
                  .fontSize(11)
                  .fontColor('#758196')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Button('添加')
                .height(38)
                .fontSize(11)
                .enabled(this.watchlist.some((symbol: StockSymbol) => symbol.id === symbolId))
                .onClick(() => this.onOpenEditor(symbolId, ''))
            }
            .width('100%')

            ForEach(this.alertsFor(symbolId), (alert: PriceAlert) => {
              Row({ space: 8 }) {
                Column({ space: 4 }) {
                  Text(`${alert.kindText()} ${this.privacyMode ? '••••' : alert.thresholdText()}`)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#DCE2EC')
                  Text(`${alert.repeatText()} · ${alert.enabled ? '已启用' : '已停用'}`)
                    .fontSize(10)
                    .fontColor(alert.enabled ? '#4AD7A5' : '#778398')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Button(alert.enabled ? '停用' : '启用')
                  .height(38)
                  .fontSize(11)
                  .onClick(() => personalStore.toggleAlert(alert))
                Button('编辑')
                  .height(38)
                  .fontSize(11)
                  .backgroundColor('#243554')
                  .onClick(() => this.onOpenEditor(alert.symbolId, alert.id))
              }
              .padding(12)
              .width('100%')
              .backgroundColor('#171D27')
              .borderRadius(12)
            }, (alert: PriceAlert) => alert.id)
          }
          .padding(16)
          .width('100%')
          .backgroundColor('#121720')
          .borderRadius(18)
        }, (symbolId: string) => symbolId)

        Text('隐私模式下股票名称和提醒阈值会在列表中隐藏。')
          .fontSize(10)
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
