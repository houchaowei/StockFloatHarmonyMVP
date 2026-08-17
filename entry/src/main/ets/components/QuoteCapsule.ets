import { MiniSparkline } from './MiniSparkline'
import { CapsuleMetric, PositionRecord } from '../model/PersonalModels'
import { ChinaMarketCalendar, MarketPhase, QuoteFreshness, QuoteFreshnessHelper, StockQuote } from '../model/StockModels'

@Component
export struct QuoteCapsule {
  @Prop quote: StockQuote | undefined = undefined
  @Prop index: number = 0
  @Prop total: number = 0
  @Prop status: string = '等待行情'
  @Prop expanded: boolean = false
  @Prop version: number = 0
  @Prop positionRecord: PositionRecord | undefined = undefined
  @Prop history: Array<number> = []
  @Prop marketPhase: MarketPhase = MarketPhase.CLOSED
  @Prop backgroundActive: boolean = true
  @Prop privacyMode: boolean = false
  @Prop reverseColors: boolean = false
  @Prop opacityPercent: number = 95
  @Prop metricMode: string = CapsuleMetric.BOTH
  onPrevious: () => void = () => {}
  onNext: () => void = () => {}
  onToggle: () => void = () => {}
  onRefresh: () => void = () => {}
  onClose: () => void = () => {}
  onDragStartHandler: (windowX: number, windowY: number) => void = (_windowX: number, _windowY: number) => {}
  onDragUpdate: (offsetX: number, offsetY: number) => void = (_offsetX: number, _offsetY: number) => {}
  onDragEndHandler: () => void = () => {}

  // 系统拖拽(startMoving)要求在 onTouch 的 TouchType.Down 回调里同步调用，
  // 且坐标必须是"窗口内"坐标；抬手(Up/Cancel)时结束拖拽并吸边。
  private handleDragTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down && event.touches.length > 0) {
      const touch: TouchObject = event.touches[0]
      this.onDragStartHandler(touch.windowX, touch.windowY)
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.onDragEndHandler()
    }
  }

  private changeColor(): ResourceColor {
    if (this.privacyMode || this.quote === undefined || this.quote.changePercent === 0) {
      return '#B7BFCE'
    }
    if (this.reverseColors) {
      return this.quote.changePercent > 0 ? '#21C78B' : '#FF5A63'
    }
    return this.quote.changePercent > 0 ? '#FF5A63' : '#21C78B'
  }

  private signed(value: number, digits: number): string {
    const prefix: string = value > 0 ? '+' : ''
    return `${prefix}${value.toFixed(digits)}`
  }

  private quoteTime(): string {
    if (this.quote === undefined || this.quote.quoteTimestamp <= 0) {
      return '--:--:--'
    }
    const date: Date = new Date(this.quote.quoteTimestamp + 8 * 60 * 60 * 1000)
    const hour: string = date.getUTCHours().toString().padStart(2, '0')
    const minute: string = date.getUTCMinutes().toString().padStart(2, '0')
    const second: string = date.getUTCSeconds().toString().padStart(2, '0')
    if (!ChinaMarketCalendar.sameExchangeDay(this.quote.quoteTimestamp, Date.now())) {
      const month: string = (date.getUTCMonth() + 1).toString().padStart(2, '0')
      const day: string = date.getUTCDate().toString().padStart(2, '0')
      return `${month}-${day} ${hour}:${minute}`
    }
    return `${hour}:${minute}:${second}`
  }

  private priceMetric(value: number | undefined): string {
    if (this.privacyMode) {
      return '••••'
    }
    return value === undefined || value <= 0 ? '--' :
      (this.quote?.symbol.formatPrice(value) ?? value.toFixed(2))
  }

  private displayName(): string {
    return this.privacyMode ? '自选行情' : (this.quote?.name ?? '正在加载')
  }

  private displayPrice(): string {
    if (this.privacyMode) {
      return '••••'
    }
    if (this.quote === undefined) {
      return '--'
    }
    if (this.metricMode === CapsuleMetric.PERCENT) {
      return `${this.signed(this.quote.changePercent, 2)}%`
    }
    if (this.metricMode === CapsuleMetric.POSITION_PROFIT && this.positionRecord !== undefined) {
      return this.signed(this.positionRecord.totalProfit(this.quote.price), 2)
    }
    return this.quote.symbol.formatPrice(this.quote.price)
  }

  private displayChange(): string {
    if (this.privacyMode) {
      return '••••'
    }
    if (this.quote === undefined) {
      return '--'
    }
    if (this.metricMode === CapsuleMetric.PRICE) {
      return ''
    }
    if (this.metricMode === CapsuleMetric.PERCENT) {
      return '涨跌幅'
    }
    if (this.metricMode === CapsuleMetric.POSITION_PROFIT) {
      return this.positionRecord === undefined ? '未设置持仓' :
        `今日 ${this.signed(this.positionRecord.todayProfit(this.quote.change), 2)}`
    }
    return `${this.signed(this.quote.changePercent, 2)}%`
  }

  private expandedPrice(): string {
    if (this.privacyMode) {
      return '••••'
    }
    return this.quote === undefined ? '--' : this.quote.symbol.formatPrice(this.quote.price)
  }

  private expandedPercent(): string {
    if (this.privacyMode) {
      return '••••'
    }
    return this.quote === undefined ? '--' : `${this.signed(this.quote.changePercent, 2)}%`
  }

  private freshness(): QuoteFreshness {
    return QuoteFreshnessHelper.value(this.quote, this.marketPhase, this.backgroundActive)
  }

  private capsuleBackgroundColor(): ResourceColor {
    if (this.opacityPercent >= 95) {
      return '#F20C1017'
    }
    if (this.opacityPercent >= 85) {
      return '#D90C1017'
    }
    return '#B30C1017'
  }

  private positionProfitText(): string {
    if (this.positionRecord === undefined || this.quote === undefined) {
      return ''
    }
    if (this.privacyMode) {
      return '持仓盈亏 ••••'
    }
    const profit: number = this.positionRecord.totalProfit(this.quote.price)
    return `持仓盈亏 ${this.signed(profit, 2)}  今日 ${this.signed(this.positionRecord.todayProfit(this.quote.change), 2)}`
  }

  build() {
    Column() {
      if (!this.expanded) {
        Row() {
          Stack() {
            Circle()
              .width(24)
              .height(24)
              .fill('#26303DDD')
            Text('‹')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#BFC9D8')
          }
            .width(44)
            .height(44)
            .accessibilityText('上一只股票')
            .onClick(() => this.onPrevious())

          Column({ space: 1 }) {
            Row({ space: 4 }) {
              Circle().width(5).height(5).fill(this.changeColor())
              Text(this.displayName())
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F5F7FB')
                .maxLines(1)
              Text(`${this.index + 1}/${Math.max(this.total, 1)}`)
                .fontSize(10)
                .fontColor('#8E98AA')
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)

            Row({ space: 5 }) {
              Text(this.displayPrice())
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text(this.displayChange())
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.changeColor())
            }
          }
          .layoutWeight(1)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .accessibilityText('点击展开行情，拖动可移动悬浮胶囊')
          .onClick(() => this.onToggle())
          .onTouch((event: TouchEvent) => this.handleDragTouch(event))
          .gesture(
            GestureGroup(GestureMode.Exclusive,
              PanGesture({ distance: 8 })
                .onActionUpdate((event: GestureEvent) => this.onDragUpdate(event.offsetX, event.offsetY))
                .onActionEnd(() => this.onDragEndHandler()),
              LongPressGesture({ repeat: false, duration: 700 })
                .onAction(() => this.onToggle())
            )
          )

          Stack() {
            Circle()
              .width(24)
              .height(24)
              .fill('#26303DDD')
            Text('›')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#BFC9D8')
          }
            .width(44)
            .height(44)
            .accessibilityText('下一只股票')
            .onClick(() => this.onNext())
        }
        .padding({ left: 5, right: 5 })
        .width('100%')
        .height('100%')
      } else {
        Column() {
          Row() {
            Text('≡')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#697386')
            Column({ space: 2 }) {
              Text(this.displayName())
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F5F7FB')
              Text(this.privacyMode ? '代码已隐藏' : (this.quote?.symbol.displayCode ?? 'StockFloat'))
                .fontSize(10)
                .fontColor('#8E98AA')
            }
            .alignItems(HorizontalAlign.Start)
            Blank()
            Text(`${this.index + 1} / ${Math.max(this.total, 1)}`)
              .fontSize(11)
              .fontColor('#8E98AA')
          }
          .width('100%')
          .height(52)
          .padding({ left: 18, right: 18 })
          .accessibilityText('拖动可移动展开悬浮窗')
          .onTouch((event: TouchEvent) => this.handleDragTouch(event))
          .gesture(
            PanGesture({ distance: 8 })
              .onActionUpdate((event: GestureEvent) => this.onDragUpdate(event.offsetX, event.offsetY))
              .onActionEnd(() => this.onDragEndHandler())
          )

          Scroll() {
            Column({ space: 9 }) {
              Row({ space: 12 }) {
                Text(this.expandedPrice())
                  .fontSize(32)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
                Column({ space: 2 }) {
                  Text(this.privacyMode || this.quote === undefined ? '••••' : this.signed(this.quote.change, 2))
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.changeColor())
                  Text(this.expandedPercent())
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.changeColor())
                }
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')

              MiniSparkline({
                values: this.history,
                lineColor: this.changeColor(),
                hidden: this.privacyMode
              })

              Row() {
                Text(`今开 ${this.priceMetric(this.quote?.open)}`)
                  .fontSize(10)
                  .fontColor('#98A4B7')
                Blank()
                Text(`最高 ${this.priceMetric(this.quote?.high)}`)
                  .fontSize(10)
                  .fontColor('#FF8990')
                Blank()
                Text(`最低 ${this.priceMetric(this.quote?.low)}`)
                  .fontSize(10)
                  .fontColor('#5DDBAA')
              }
              .width('100%')

              if (this.positionRecord !== undefined) {
                Text(this.positionProfitText())
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.changeColor())
                  .width('100%')
                  .maxLines(1)
              }

              Row() {
                Row({ space: 4 }) {
                  Circle().width(6).height(6).fill(QuoteFreshnessHelper.color(this.freshness()))
                  Text(`${this.freshness()} · ${this.quote?.source ?? '--'}`)
                    .fontSize(10)
                    .fontColor('#AAB2C1')
                    .maxLines(1)
                }
                Blank()
                Text(`行情 ${this.quoteTime()}`)
                  .fontSize(10)
                  .fontColor('#697386')
              }
              .width('100%')

              Row({ space: 8 }) {
                Button('上一只').height(40).accessibilityText('上一只股票').onClick(() => this.onPrevious())
                Button('刷新').height(40).accessibilityText('刷新当前行情').onClick(() => this.onRefresh())
                Button('下一只').height(40).accessibilityText('下一只股票').onClick(() => this.onNext())
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)

              Row() {
                Text('顶部拖动 · 松手吸边')
                  .fontSize(10)
                  .fontColor('#697386')
                Blank()
                Button('收起')
                  .fontSize(11)
                  .fontColor('#DCE2EC')
                  .backgroundColor('#2B3340')
                  .accessibilityText('收起行情卡片')
                  .onClick(() => this.onToggle())
                Button('关闭')
                  .fontSize(11)
                  .fontColor('#FF7A82')
                  .backgroundColor('#34232A')
                  .accessibilityText('关闭全局悬浮胶囊')
                  .onClick(() => this.onClose())
              }
              .width('100%')
            }
            .padding({ left: 18, right: 18, bottom: 18 })
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.capsuleBackgroundColor())
    .borderRadius(this.expanded ? 22 : 36)
    .border({ width: 1, color: '#52607183' })
    .shadow({ radius: 14, color: '#55000000', offsetY: 6 })
  }
}
