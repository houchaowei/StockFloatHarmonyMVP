import { floatWindowManager } from '../model/FloatWindowManager'
import { CapsuleMetric, CapsuleSize } from '../model/PersonalModels'
import { personalStore } from '../model/PersonalStore'
import { quoteStore } from '../model/QuoteStore'
import { QuoteFreshness, QuoteFreshnessHelper, StockQuote, StockSymbol } from '../model/StockModels'

@Component
struct SettingSwitchRow {
  @Prop title: string = ''
  @Prop description: string = ''
  @Prop value: boolean = false
  onChange: (value: boolean) => void = () => {}

  build() {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(this.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#E7EBF2')
        Text(this.description)
          .fontSize(10)
          .fontColor('#758196')
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.value })
        .selectedColor('#346DFF')
        .onChange((value: boolean) => this.onChange(value))
    }
    .padding({ top: 10, bottom: 10 })
    .width('100%')
  }
}

@Component
export struct SettingsPage {
  @StorageLink('rotationEnabled') rotationEnabled: boolean = true
  @StorageLink('rotationIntervalSeconds') rotationIntervalSeconds: number = 4
  @StorageLink('pinnedSymbolId') pinnedSymbolId: string = ''
  @StorageLink('capsuleSize') capsuleSize: string = CapsuleSize.STANDARD
  @StorageLink('capsuleOpacity') capsuleOpacity: number = 95
  @StorageLink('capsuleMetric') capsuleMetric: string = CapsuleMetric.BOTH
  @StorageLink('privacyMode') privacyMode: boolean = false
  @StorageLink('reverseColors') reverseColors: boolean = false
  @StorageLink('autoRestoreFloat') autoRestoreFloat: boolean = true
  @StorageLink('tradingRefreshSeconds') tradingRefreshSeconds: number = 5
  @StorageLink('statusNotificationEnabled') statusNotificationEnabled: boolean = false
  @StorageLink('alertStatus') alertStatus: string = ''
  @StorageLink('watchlist') watchlist: Array<StockSymbol> = []
  @StorageLink('quotes') quotes: Array<StockQuote> = []
  @StorageLink('selectedIndex') selectedIndex: number = 0
  @StorageLink('backgroundActive') backgroundActive: boolean = true
  @StorageProp('topSafeHeight') topSafeHeight: number = 0

  private selectedButton(selected: boolean): ResourceColor {
    return selected ? '#346DFF' : '#252E3B'
  }

  private greenSelected(selected: boolean): ResourceColor {
    return selected ? '#203B34' : '#252E3B'
  }

  private async setCapsuleSize(size: CapsuleSize): Promise<void> {
    await personalStore.setCapsuleSize(size)
    await floatWindowManager.applyPresentationSettings()
  }

  private async setStatusNotification(value: boolean): Promise<void> {
    if (value) {
      const enabled: boolean = await personalStore.requestNotificationPermission()
      if (!enabled) {
        return
      }
    }
    await personalStore.setStatusNotificationEnabled(value)
    if (value) {
      const quote: StockQuote | undefined = this.quotes.find((item: StockQuote) =>
        item.symbol.id === this.selectedSymbolId())
      const freshness: QuoteFreshness = QuoteFreshnessHelper.value(
        quote, quoteStore.marketPhase(), this.backgroundActive)
      await personalStore.publishStatusQuote(quote, quoteStore.marketPhase(), freshness)
    }
  }

  private selectedSymbolId(): string {
    return this.watchlist[this.selectedIndex]?.id ?? this.watchlist[0]?.id ?? ''
  }

  private pinnedName(): string {
    if (this.pinnedSymbolId.length === 0) {
      return '未固定，按设置间隔轮播'
    }
    if (this.privacyMode) {
      return '已固定一只自选股'
    }
    return this.quotes.find((quote: StockQuote) => quote.symbol.id === this.pinnedSymbolId)?.name ?? this.pinnedSymbolId
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 4 }) {
          Text('设置')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7F9FC')
          Text('悬浮胶囊、刷新、通知和隐私')
            .fontSize(13)
            .fontColor('#8893A6')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Column({ space: 12 }) {
          Text('悬浮胶囊')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#EEF2F8')
            .width('100%')

          Text('尺寸')
            .fontSize(11)
            .fontColor('#8290A6')
            .width('100%')
          Row({ space: 8 }) {
            Button('紧凑')
              .layoutWeight(1)
              .height(42)
              .backgroundColor(this.selectedButton(this.capsuleSize === CapsuleSize.COMPACT))
              .onClick(() => this.setCapsuleSize(CapsuleSize.COMPACT))
            Button('标准')
              .layoutWeight(1)
              .height(42)
              .backgroundColor(this.selectedButton(this.capsuleSize === CapsuleSize.STANDARD))
              .onClick(() => this.setCapsuleSize(CapsuleSize.STANDARD))
            Button('大号')
              .layoutWeight(1)
              .height(42)
              .backgroundColor(this.selectedButton(this.capsuleSize === CapsuleSize.LARGE))
              .onClick(() => this.setCapsuleSize(CapsuleSize.LARGE))
          }
          .width('100%')

          Text('透明度')
            .fontSize(11)
            .fontColor('#8290A6')
            .width('100%')
          Row({ space: 8 }) {
            ForEach([70, 85, 95], (opacity: number) => {
              Button(`${opacity}%`)
                .layoutWeight(1)
                .height(42)
                .backgroundColor(this.selectedButton(this.capsuleOpacity === opacity))
                .onClick(() => personalStore.setCapsuleOpacity(opacity))
            }, (opacity: number) => opacity.toString())
          }
          .width('100%')

          Text('展示内容')
            .fontSize(11)
            .fontColor('#8290A6')
            .width('100%')
          Row({ space: 8 }) {
            Button('价格+涨跌')
              .layoutWeight(1)
              .height(42)
              .backgroundColor(this.selectedButton(this.capsuleMetric === CapsuleMetric.BOTH))
              .onClick(() => personalStore.setCapsuleMetric(CapsuleMetric.BOTH))
            Button('仅价格')
              .layoutWeight(1)
              .height(42)
              .backgroundColor(this.selectedButton(this.capsuleMetric === CapsuleMetric.PRICE))
              .onClick(() => personalStore.setCapsuleMetric(CapsuleMetric.PRICE))
          }
          .width('100%')
          Row({ space: 8 }) {
            Button('涨跌幅')
              .layoutWeight(1)
              .height(42)
              .backgroundColor(this.selectedButton(this.capsuleMetric === CapsuleMetric.PERCENT))
              .onClick(() => personalStore.setCapsuleMetric(CapsuleMetric.PERCENT))
            Button('持仓盈亏')
              .layoutWeight(1)
              .height(42)
              .backgroundColor(this.selectedButton(this.capsuleMetric === CapsuleMetric.POSITION_PROFIT))
              .onClick(() => personalStore.setCapsuleMetric(CapsuleMetric.POSITION_PROFIT))
          }
          .width('100%')

          SettingSwitchRow({
            title: '自动轮播',
            description: '胶囊收起且未固定股票时自动切换',
            value: this.rotationEnabled,
            onChange: (value: boolean) => personalStore.setRotationEnabled(value)
          })

          if (this.rotationEnabled) {
            Text('轮播间隔')
              .fontSize(11)
              .fontColor('#8290A6')
              .width('100%')
            List({ space: 8 }) {
              ForEach([2, 4, 8, 12, 30], (seconds: number) => {
                ListItem() {
                  Button(`${seconds} 秒`)
                    .height(40)
                    .fontSize(11)
                    .backgroundColor(this.selectedButton(this.rotationIntervalSeconds === seconds))
                    .onClick(() => personalStore.setRotationInterval(seconds))
                }
              }, (seconds: number) => seconds.toString())
            }
            .listDirection(Axis.Horizontal)
            .scrollBar(BarState.Off)
            .height(40)
            .width('100%')
          }

          Column({ space: 5 }) {
            Text('固定股票')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#E7EBF2')
            Text(this.pinnedName())
              .fontSize(10)
              .fontColor('#758196')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          Row({ space: 8 }) {
            Button('固定当前自选')
              .layoutWeight(1)
              .height(42)
              .enabled(this.selectedSymbolId().length > 0)
              .backgroundColor(this.pinnedSymbolId.length > 0 ? '#252E3B' : '#243554')
              .onClick(() => personalStore.setPinnedSymbol(this.selectedSymbolId()))
            if (this.pinnedSymbolId.length > 0) {
              Button('取消固定')
                .height(42)
                .onClick(() => personalStore.setPinnedSymbol(''))
            }
          }
          .width('100%')

          SettingSwitchRow({
            title: '启动时恢复悬浮',
            description: '只在上次由用户主动开启过胶囊时恢复',
            value: this.autoRestoreFloat,
            onChange: (value: boolean) => personalStore.setAutoRestoreFloat(value)
          })
        }
        .padding(16)
        .width('100%')
        .backgroundColor('#121720')
        .borderRadius(18)

        Column({ space: 12 }) {
          Text('行情与通知')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#EEF2F8')
            .width('100%')
          Text('交易时段刷新间隔')
            .fontSize(11)
            .fontColor('#8290A6')
            .width('100%')
          Row({ space: 8 }) {
            ForEach([5, 10, 30], (seconds: number) => {
              Button(`${seconds} 秒`)
                .layoutWeight(1)
                .height(42)
                .backgroundColor(this.selectedButton(this.tradingRefreshSeconds === seconds))
                .onClick(() => personalStore.setTradingRefreshSeconds(seconds))
            }, (seconds: number) => seconds.toString())
          }
          .width('100%')
          SettingSwitchRow({
            title: '常驻行情通知',
            description: '悬浮权限不可用时的降级方案',
            value: this.statusNotificationEnabled,
            onChange: (value: boolean) => this.setStatusNotification(value)
          })
          Row() {
            Column({ space: 3 }) {
              Text('通知权限')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#E7EBF2')
              Text(this.alertStatus)
                .fontSize(10)
                .fontColor('#758196')
                .maxLines(2)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Button('检查并授权')
              .height(40)
              .fontSize(11)
              .onClick(() => personalStore.requestNotificationPermission())
          }
          .width('100%')
          Text('系统实况窗不允许第三方应用直接创建；常驻通知仅作为降级展示。')
            .fontSize(10)
            .fontColor('#68758A')
            .width('100%')
        }
        .padding(16)
        .width('100%')
        .backgroundColor('#121720')
        .borderRadius(18)

        Column({ space: 6 }) {
          Text('外观与隐私')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#EEF2F8')
            .width('100%')
          SettingSwitchRow({
            title: '隐私模式',
            description: '隐藏股票名称、代码、价格、提醒阈值与持仓盈亏',
            value: this.privacyMode,
            onChange: (value: boolean) => personalStore.setPrivacyMode(value)
          })
          Text('涨跌颜色')
            .fontSize(11)
            .fontColor('#8290A6')
            .width('100%')
          Row({ space: 8 }) {
            Button('红涨绿跌')
              .layoutWeight(1)
              .height(42)
              .backgroundColor(this.greenSelected(!this.reverseColors))
              .onClick(() => personalStore.setReverseColors(false))
            Button('绿涨红跌')
              .layoutWeight(1)
              .height(42)
              .backgroundColor(this.greenSelected(this.reverseColors))
              .onClick(() => personalStore.setReverseColors(true))
          }
          .width('100%')
        }
        .padding(16)
        .width('100%')
        .backgroundColor('#121720')
        .borderRadius(18)

        Column({ space: 5 }) {
          Text('关于 StockFloat')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#DCE2EC')
          Text('个人股票悬浮助手 · 所有持仓与个性化数据保存在本机')
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
