@Component
export struct MiniSparkline {
  @Prop values: Array<number> = []
  @Prop lineColor: ResourceColor = '#4B7CFF'
  @Prop hidden: boolean = false

  private chartPoints(): Array<Array<number>> {
    if (this.values.length < 2) {
      return []
    }
    const width: number = 250
    const height: number = 38
    const minValue: number = this.values.reduce((value: number, item: number) => Math.min(value, item), this.values[0])
    const maxValue: number = this.values.reduce((value: number, item: number) => Math.max(value, item), this.values[0])
    const range: number = Math.max(0.001, maxValue - minValue)
    return this.values.map((value: number, index: number) => [
      index / Math.max(1, this.values.length - 1) * width,
      height - (value - minValue) / range * (height - 4) - 2
    ])
  }

  build() {
    Stack() {
      if (this.hidden) {
        Text('隐私模式 · 走势已隐藏')
          .fontSize(11)
          .fontColor('#697386')
      } else if (this.values.length >= 2) {
        Polyline({ width: 250, height: 42 })
          .points(this.chartPoints())
          .fill('#00000000')
          .stroke(this.lineColor)
          .strokeWidth(2)
      } else {
        Text('走势采样中')
          .fontSize(11)
          .fontColor('#697386')
      }
    }
    .width('100%')
    .height(42)
    .backgroundColor('#301D2633')
    .borderRadius(10)
  }
}
