export enum StockMarket {
  SHANGHAI = 'sh',
  SHENZHEN = 'sz',
  BEIJING = 'bj'
}

export class StockSymbol {
  code: string
  market: StockMarket

  constructor(code: string, market: StockMarket) {
    this.code = code
    this.market = market
  }

  get id(): string {
    return `${this.market}${this.code}`
  }

  get displayCode(): string {
    if (this.market === StockMarket.SHANGHAI) {
      return `沪 ${this.code}`
    }
    if (this.market === StockMarket.BEIJING) {
      return `北 ${this.code}`
    }
    return `深 ${this.code}`
  }

  static parse(input: string): StockSymbol | undefined {
    const normalized: string = input.trim().toLowerCase().replace(/\./g, '')
    const digits: string = normalized.replace(/[^0-9]/g, '')
    if (digits.length !== 6) {
      return undefined
    }

    let market: StockMarket
    if (normalized.startsWith('sh') || normalized.endsWith('sh')) {
      market = StockMarket.SHANGHAI
    } else if (normalized.startsWith('sz') || normalized.endsWith('sz')) {
      market = StockMarket.SHENZHEN
    } else if (normalized.startsWith('bj') || normalized.endsWith('bj')) {
      market = StockMarket.BEIJING
    } else if (digits.startsWith('4') || digits.startsWith('8') || digits.startsWith('92')) {
      market = StockMarket.BEIJING
    } else if (digits.startsWith('5') || digits.startsWith('6') || digits.startsWith('9')) {
      market = StockMarket.SHANGHAI
    } else {
      market = StockMarket.SHENZHEN
    }
    return new StockSymbol(digits, market)
  }
}

export class StockQuote {
  symbol: StockSymbol
  name: string
  price: number
  previousClose: number
  open: number
  high: number
  low: number
  change: number
  changePercent: number
  quoteTimestamp: number
  fetchedTimestamp: number

  constructor(symbol: StockSymbol, name: string, price: number, previousClose: number,
    open: number, high: number, low: number, change: number, changePercent: number,
    quoteTimestamp: number, fetchedTimestamp: number) {
    this.symbol = symbol
    this.name = name
    this.price = price
    this.previousClose = previousClose
    this.open = open
    this.high = high
    this.low = low
    this.change = change
    this.changePercent = changePercent
    this.quoteTimestamp = quoteTimestamp
    this.fetchedTimestamp = fetchedTimestamp
  }
}

export enum MarketPhase {
  PRE_OPEN = '盘前',
  TRADING = '交易中',
  LUNCH_BREAK = '午间休市',
  CLOSED = '已收盘',
  WEEKEND = '周末休市'
}

export class ChinaMarketCalendar {
  static phase(now: Date = new Date()): MarketPhase {
    // Always calculate against the exchange timezone, even if the phone is abroad.
    const utcTimestamp: number = now.getTime() + now.getTimezoneOffset() * 60 * 1000
    const shanghaiNow: Date = new Date(utcTimestamp + 8 * 60 * 60 * 1000)
    const weekday: number = shanghaiNow.getDay()
    if (weekday === 0 || weekday === 6) {
      return MarketPhase.WEEKEND
    }
    const minutes: number = shanghaiNow.getHours() * 60 + shanghaiNow.getMinutes()
    if (minutes >= 9 * 60 + 15 && minutes < 9 * 60 + 30) {
      return MarketPhase.PRE_OPEN
    }
    if ((minutes >= 9 * 60 + 30 && minutes < 11 * 60 + 30) ||
      (minutes >= 13 * 60 && minutes < 15 * 60)) {
      return MarketPhase.TRADING
    }
    if (minutes >= 11 * 60 + 30 && minutes < 13 * 60) {
      return MarketPhase.LUNCH_BREAK
    }
    return MarketPhase.CLOSED
  }

  static refreshIntervalMs(phase: MarketPhase): number {
    if (phase === MarketPhase.TRADING) {
      return 5000
    }
    if (phase === MarketPhase.PRE_OPEN) {
      return 30000
    }
    if (phase === MarketPhase.LUNCH_BREAK) {
      return 60000
    }
    if (phase === MarketPhase.CLOSED) {
      return 300000
    }
    return 900000
  }
}
