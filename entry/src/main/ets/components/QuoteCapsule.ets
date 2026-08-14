import { StockQuote } from '../model/StockModels'

@Component
export struct QuoteCapsule {
  @Prop quote?: StockQuote
  @Prop index: number = 0
  @Prop total: number = 0
  @Prop status: string = '等待行情'
  @Prop expanded: boolean = false
  @Prop version: number = 0
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
    if (this.quote === undefined || this.quote.changePercent === 0) {
      return '#B7BFCE'
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
    const date: Date = new Date(this.quote.quoteTimestamp)
    const hour: string = date.getHours().toString().padStart(2, '0')
    const minute: string = date.getMinutes().toString().padStart(2, '0')
    const second: string = date.getSeconds().toString().padStart(2, '0')
    return `${hour}:${minute}:${second}`
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
            .width(26)
            .height(36)
            .onClick(() => this.onPrevious())

          Column({ space: 1 }) {
            Row({ space: 4 }) {
              Circle().width(5).height(5).fill(this.changeColor())
              Text(this.quote?.name ?? '正在加载')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F5F7FB')
                .maxLines(1)
              Text(`${this.index + 1}/${Math.max(this.total, 1)}`)
                .fontSize(8)
                .fontColor('#8E98AA')
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)

            Row({ space: 5 }) {
              Text(this.quote?.price.toFixed(2) ?? '--')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text(this.quote === undefined ? '--' : `${this.signed(this.quote.changePercent, 2)}%`)
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.changeColor())
            }
          }
          .layoutWeight(1)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .onClick(() => this.onToggle())
          .onTouch((event: TouchEvent) => this.handleDragTouch(event))
          .gesture(
            GestureGroup(GestureMode.Exclusive,
              PanGesture({ distance: 8 })
                .onActionUpdate((event: GestureEvent) => this.onDragUpdate(event.offsetX, event.offsetY))
                .onActionEnd(() => this.onDragEndHandler()),
              LongPressGesture({ repeat: false, duration: 900 })
                .onAction(() => this.onClose())
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
            .width(26)
            .height(36)
            .onClick(() => this.onNext())
        }
        .padding({ left: 5, right: 5 })
        .width('100%')
        .height('100%')
      } else {
        Column({ space: 9 }) {
          Row() {
            Column({ space: 2 }) {
              Text(this.quote?.name ?? '等待行情')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F5F7FB')
              Text(this.quote?.symbol.displayCode ?? 'StockFloat')
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

          Row({ space: 12 }) {
            Text(this.quote?.price.toFixed(2) ?? '--')
              .fontSize(32)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Column({ space: 2 }) {
              Text(this.quote === undefined ? '--' : this.signed(this.quote.change, 2))
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.changeColor())
              Text(this.quote === undefined ? '--' : `${this.signed(this.quote.changePercent, 2)}%`)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.changeColor())
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')

          Row() {
            Text(this.status)
              .fontSize(10)
              .fontColor('#AAB2C1')
              .maxLines(1)
            Blank()
            Text(`行情 ${this.quoteTime()}`)
              .fontSize(10)
              .fontColor('#697386')
          }
          .width('100%')

          Row({ space: 8 }) {
            Button('上一只').onClick(() => this.onPrevious())
            Button('刷新').onClick(() => this.onRefresh())
            Button('下一只').onClick(() => this.onNext())
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)

          Row() {
            Text('拖动吸边 · 点击收起')
              .fontSize(10)
              .fontColor('#697386')
              .width(126)
              .height(34)
              .onClick(() => this.onToggle())
              .onTouch((event: TouchEvent) => this.handleDragTouch(event))
              .gesture(
                GestureGroup(GestureMode.Exclusive,
                  PanGesture({ distance: 8 })
                    .onActionUpdate((event: GestureEvent) => this.onDragUpdate(event.offsetX, event.offsetY))
                    .onActionEnd(() => this.onDragEndHandler()),
                  LongPressGesture({ repeat: false, duration: 900 })
                    .onAction(() => this.onClose())
                )
              )
            Blank()
            Button('收起')
              .fontSize(11)
              .fontColor('#DCE2EC')
              .backgroundColor('#2B3340')
              .onClick(() => this.onToggle())
            Button('关闭')
              .fontSize(11)
              .fontColor('#FF7A82')
              .backgroundColor('#34232A')
              .onClick(() => this.onClose())
          }
          .width('100%')
        }
        .padding(18)
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F20C1017')
    .borderRadius(this.expanded ? 22 : 36)
    .border({ width: 1, color: '#52607183' })
    .shadow({ radius: 14, color: '#55000000', offsetY: 6 })
  }
}
