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

  get priceDigits(): number {
    // A-share stocks normally use two decimals. Exchange-traded funds and
    // convertible bonds commonly require three decimals.
    if (this.code.startsWith('1') || this.code.startsWith('5')) {
      return 3
    }
    return 2
  }

  formatPrice(value: number): string {
    return value.toFixed(this.priceDigits)
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
  source: string

  constructor(symbol: StockSymbol, name: string, price: number, previousClose: number,
    open: number, high: number, low: number, change: number, changePercent: number,
    quoteTimestamp: number, fetchedTimestamp: number, source: string = '腾讯') {
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
    this.source = source
  }
}

export enum MarketPhase {
  PRE_OPEN = '盘前',
  TRADING = '交易中',
  LUNCH_BREAK = '午间休市',
  CLOSED = '已收盘',
  WEEKEND = '周末休市',
  HOLIDAY = '交易日休市'
}

export class ChinaMarketCalendar {
  static exchangeDateKey(timestamp: number): string {
    const date: Date = new Date(timestamp + 8 * 60 * 60 * 1000)
    const year: string = date.getUTCFullYear().toString()
    const month: string = (date.getUTCMonth() + 1).toString().padStart(2, '0')
    const day: string = date.getUTCDate().toString().padStart(2, '0')
    return `${year}${month}${day}`
  }

  static sameExchangeDay(left: number, right: number): boolean {
    if (left <= 0 || right <= 0) {
      return false
    }
    return ChinaMarketCalendar.exchangeDateKey(left) === ChinaMarketCalendar.exchangeDateKey(right)
  }

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
    if (phase === MarketPhase.HOLIDAY) {
      return 900000
    }
    return 900000
  }
}

export enum QuoteFreshness {
  LIVE = '实时',
  DELAYED = '稍有延迟',
  STALE = '行情已过期',
  CACHED = '离线缓存',
  CLOSED = '收盘行情',
  PAUSED = '后台已暂停',
  UNAVAILABLE = '暂无行情'
}

export class QuoteFreshnessHelper {
  static value(quote: StockQuote | undefined, phase: MarketPhase, backgroundActive: boolean,
    now: number = Date.now()): QuoteFreshness {
    if (quote === undefined) {
      return QuoteFreshness.UNAVAILABLE
    }
    if (!backgroundActive && phase === MarketPhase.TRADING) {
      return QuoteFreshness.PAUSED
    }
    const fetchedAge: number = Math.max(0, now - quote.fetchedTimestamp)
    if (fetchedAge > 30 * 60 * 1000) {
      return QuoteFreshness.CACHED
    }
    if (phase === MarketPhase.CLOSED || phase === MarketPhase.WEEKEND || phase === MarketPhase.HOLIDAY ||
      phase === MarketPhase.LUNCH_BREAK || phase === MarketPhase.PRE_OPEN) {
      return QuoteFreshness.CLOSED
    }
    const quoteAge: number = Math.max(0, now - quote.quoteTimestamp)
    if (!ChinaMarketCalendar.sameExchangeDay(quote.quoteTimestamp, now) || quoteAge > 2 * 60 * 1000) {
      return QuoteFreshness.STALE
    }
    if (quoteAge > 30 * 1000) {
      return QuoteFreshness.DELAYED
    }
    return QuoteFreshness.LIVE
  }

  static color(freshness: QuoteFreshness): string {
    if (freshness === QuoteFreshness.LIVE) {
      return '#4AD7A5'
    }
    if (freshness === QuoteFreshness.DELAYED || freshness === QuoteFreshness.CLOSED) {
      return '#F3B85B'
    }
    if (freshness === QuoteFreshness.UNAVAILABLE) {
      return '#778398'
    }
    return '#FF8990'
  }
}
