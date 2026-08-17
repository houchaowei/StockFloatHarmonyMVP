export enum AlertKind {
  PRICE_ABOVE = 'priceAbove',
  PRICE_BELOW = 'priceBelow',
  PERCENT_UP = 'percentUp',
  PERCENT_DOWN = 'percentDown'
}

export enum AlertRepeatMode {
  ONCE = 'once',
  COOLDOWN = 'cooldown',
  DAILY = 'daily'
}

export class PriceAlert {
  id: string
  symbolId: string
  kind: AlertKind
  threshold: number
  repeatMode: AlertRepeatMode
  enabled: boolean
  cooldownMinutes: number
  lastTriggeredAt: number

  constructor(id: string, symbolId: string, kind: AlertKind, threshold: number,
    repeatMode: AlertRepeatMode = AlertRepeatMode.ONCE, enabled: boolean = true, cooldownMinutes: number = 30,
    lastTriggeredAt: number = 0) {
    this.id = id
    this.symbolId = symbolId
    this.kind = kind
    this.threshold = threshold
    this.repeatMode = repeatMode
    this.enabled = enabled
    this.cooldownMinutes = cooldownMinutes
    this.lastTriggeredAt = lastTriggeredAt
  }

  kindText(): string {
    if (this.kind === AlertKind.PRICE_ABOVE) {
      return '价格高于'
    }
    if (this.kind === AlertKind.PRICE_BELOW) {
      return '价格低于'
    }
    if (this.kind === AlertKind.PERCENT_UP) {
      return '涨幅达到'
    }
    return '跌幅达到'
  }

  thresholdText(): string {
    if (this.kind === AlertKind.PERCENT_UP || this.kind === AlertKind.PERCENT_DOWN) {
      return `${this.threshold.toFixed(2)}%`
    }
    return this.threshold.toFixed(3).replace(/0+$/, '').replace(/\.$/, '')
  }

  repeatText(): string {
    if (this.repeatMode === AlertRepeatMode.DAILY) {
      return '每日一次'
    }
    if (this.repeatMode === AlertRepeatMode.COOLDOWN) {
      return '重复提醒'
    }
    return '单次提醒'
  }
}

export class PositionRecord {
  symbolId: string
  costPrice: number
  quantity: number

  constructor(symbolId: string, costPrice: number, quantity: number) {
    this.symbolId = symbolId
    this.costPrice = costPrice
    this.quantity = quantity
  }

  totalProfit(currentPrice: number): number {
    return (currentPrice - this.costPrice) * this.quantity
  }

  todayProfit(change: number): number {
    return change * this.quantity
  }
}

export class PricePoint {
  timestamp: number
  price: number

  constructor(timestamp: number, price: number) {
    this.timestamp = timestamp
    this.price = price
  }
}

export class PriceSeries {
  symbolId: string
  points: Array<PricePoint>

  constructor(symbolId: string, points: Array<PricePoint> = []) {
    this.symbolId = symbolId
    this.points = points
  }

  prices(): Array<number> {
    return this.points.map((point: PricePoint) => point.price)
  }
}

export enum CapsuleSize {
  COMPACT = 'compact',
  STANDARD = 'standard',
  LARGE = 'large'
}

export enum CapsuleMetric {
  BOTH = 'both',
  PRICE = 'price',
  PERCENT = 'percent',
  POSITION_PROFIT = 'positionProfit'
}

export class CapsuleDimensions {
  static collapsedWidth(size: CapsuleSize): number {
    if (size === CapsuleSize.COMPACT) {
      return 170
    }
    if (size === CapsuleSize.LARGE) {
      return 224
    }
    return 186
  }

  static collapsedHeight(size: CapsuleSize): number {
    if (size === CapsuleSize.COMPACT) {
      return 52
    }
    if (size === CapsuleSize.LARGE) {
      return 68
    }
    return 54
  }

  static expandedWidth(size: CapsuleSize): number {
    if (size === CapsuleSize.COMPACT) {
      return 292
    }
    if (size === CapsuleSize.LARGE) {
      return 340
    }
    return 316
  }

  static expandedHeight(size: CapsuleSize): number {
    if (size === CapsuleSize.COMPACT) {
      return 348
    }
    if (size === CapsuleSize.LARGE) {
      return 370
    }
    return 356
  }
}
