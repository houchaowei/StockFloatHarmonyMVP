import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { StockQuote, StockSymbol } from './StockModels'

export class QuoteProviderError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'QuoteProviderError'
  }
}

export class TencentQuoteParser {
  static parse(text: string, fetchedAt: number = Date.now()): Array<StockQuote> {
    const result: Array<StockQuote> = []
    const lines: Array<string> = text.split(';')
    lines.forEach((line: string) => {
      const quote: StockQuote | undefined = TencentQuoteParser.parseLine(line, fetchedAt)
      if (quote !== undefined) {
        result.push(quote)
      }
    })
    return result
  }

  private static parseLine(line: string, fetchedAt: number): StockQuote | undefined {
    const firstQuote: number = line.indexOf('"')
    const lastQuote: number = line.lastIndexOf('"')
    if (firstQuote < 0 || lastQuote <= firstQuote) {
      return undefined
    }

    const fields: Array<string> = line.substring(firstQuote + 1, lastQuote).split('~')
    if (fields.length <= 32) {
      return undefined
    }
    const symbol: StockSymbol | undefined = StockSymbol.parse(fields[2])
    const price: number = Number(fields[3])
    const previousClose: number = Number(fields[4])
    if (symbol === undefined || !Number.isFinite(price) || !Number.isFinite(previousClose) || price <= 0) {
      return undefined
    }

    const calculatedChange: number = price - previousClose
    const calculatedPercent: number = previousClose === 0 ? 0 : calculatedChange / previousClose * 100
    const suppliedChange: number = Number(fields[31])
    const suppliedPercent: number = Number(fields[32])
    return new StockQuote(
      symbol,
      fields[1],
      price,
      previousClose,
      Number.isFinite(suppliedChange) ? suppliedChange : calculatedChange,
      Number.isFinite(suppliedPercent) ? suppliedPercent : calculatedPercent,
      TencentQuoteParser.parseQuoteTimestamp(fields[30]),
      fetchedAt
    )
  }

  private static parseQuoteTimestamp(value: string): number {
    if (value.length < 14) {
      return 0
    }
    const iso: string = `${value.substring(0, 4)}-${value.substring(4, 6)}-${value.substring(6, 8)}` +
      `T${value.substring(8, 10)}:${value.substring(10, 12)}:${value.substring(12, 14)}+08:00`
    const timestamp: number = new Date(iso).getTime()
    return Number.isFinite(timestamp) ? timestamp : 0
  }
}

export class TencentQuoteProvider {
  async fetch(symbols: Array<StockSymbol>): Promise<Array<StockQuote>> {
    if (symbols.length === 0) {
      throw new QuoteProviderError('没有需要查询的股票')
    }
    const query: string = symbols.map((symbol: StockSymbol) => symbol.id).join(',')
    const request: http.HttpRequest = http.createHttp()
    try {
      const response: http.HttpResponse = await request.request(`https://qt.gtimg.cn/q=${query}`, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 6000,
        readTimeout: 10000,
        usingCache: false,
        header: {
          'User-Agent': 'StockFloatHarmonyMVP/0.1 (personal prototype)',
          'Referer': 'https://gu.qq.com/'
        }
      })
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new QuoteProviderError(`行情服务返回 HTTP ${response.responseCode}`)
      }
      const bytes: Uint8Array = new Uint8Array(response.result as ArrayBuffer)
      const decoder: util.TextDecoder = util.TextDecoder.create('gb18030', {
        fatal: false,
        ignoreBOM: true
      })
      const text: string = decoder.decodeToString(bytes, { stream: false })
      const quotes: Array<StockQuote> = TencentQuoteParser.parse(text)
      if (quotes.length === 0) {
        throw new QuoteProviderError('行情服务没有返回可识别的数据')
      }
      return quotes
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      throw new QuoteProviderError(businessError.message ?? '行情请求失败')
    } finally {
      request.destroy()
    }
  }
}
