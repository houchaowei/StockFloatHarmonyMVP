import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { QuoteProvider } from './QuoteProvider'
import { QuoteProviderError } from './TencentQuoteProvider'
import { StockQuote, StockSymbol } from './StockModels'

export class SinaQuoteParser {
  static parse(text: string, fetchedAt: number = Date.now()): Array<StockQuote> {
    const result: Array<StockQuote> = []
    text.split(';').forEach((line: string) => {
      const quote: StockQuote | undefined = SinaQuoteParser.parseLine(line, fetchedAt)
      if (quote !== undefined) {
        result.push(quote)
      }
    })
    return result
  }

  private static parseLine(line: string, fetchedAt: number): StockQuote | undefined {
    const marker: string = 'hq_str_'
    const markerIndex: number = line.indexOf(marker)
    const equalsIndex: number = line.indexOf('=')
    const firstQuote: number = line.indexOf('"')
    const lastQuote: number = line.lastIndexOf('"')
    if (markerIndex < 0 || equalsIndex <= markerIndex || firstQuote < 0 || lastQuote <= firstQuote) {
      return undefined
    }
    const symbol: StockSymbol | undefined = StockSymbol.parse(
      line.substring(markerIndex + marker.length, equalsIndex).trim())
    const fields: Array<string> = line.substring(firstQuote + 1, lastQuote).split(',')
    if (symbol === undefined || fields.length < 32 || fields[0].length === 0) {
      return undefined
    }
    const open: number = Number(fields[1])
    const previousClose: number = Number(fields[2])
    const price: number = Number(fields[3])
    const high: number = Number(fields[4])
    const low: number = Number(fields[5])
    if (!Number.isFinite(price) || price <= 0 || !Number.isFinite(previousClose) || previousClose <= 0) {
      return undefined
    }
    const change: number = price - previousClose
    const percent: number = change / previousClose * 100
    return new StockQuote(symbol, fields[0], price, previousClose,
      Number.isFinite(open) ? open : 0,
      Number.isFinite(high) ? high : 0,
      Number.isFinite(low) ? low : 0,
      change, percent, SinaQuoteParser.parseTimestamp(fields[30], fields[31]), fetchedAt, '新浪')
  }

  private static parseTimestamp(date: string, time: string): number {
    if (date.length !== 10 || time.length < 8) {
      return 0
    }
    const timestamp: number = new Date(`${date}T${time.substring(0, 8)}+08:00`).getTime()
    return Number.isFinite(timestamp) ? timestamp : 0
  }
}

export class SinaQuoteProvider implements QuoteProvider {
  async fetch(symbols: Array<StockSymbol>): Promise<Array<StockQuote>> {
    if (symbols.length === 0) {
      throw new QuoteProviderError('没有需要查询的股票')
    }
    const query: string = symbols.map((symbol: StockSymbol) => symbol.id).join(',')
    const request: http.HttpRequest = http.createHttp()
    try {
      const response: http.HttpResponse = await request.request(`https://hq.sinajs.cn/list=${query}`, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 6000,
        readTimeout: 10000,
        usingCache: false,
        header: {
          'User-Agent': 'StockFloatHarmonyMVP/0.3 (personal prototype)',
          'Referer': 'https://finance.sina.com.cn/'
        }
      })
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new QuoteProviderError(`备用行情返回 HTTP ${response.responseCode}`)
      }
      const decoder: util.TextDecoder = util.TextDecoder.create('gb18030', {
        fatal: false,
        ignoreBOM: true
      })
      const text: string = decoder.decodeToString(new Uint8Array(response.result as ArrayBuffer), { stream: false })
      const quotes: Array<StockQuote> = SinaQuoteParser.parse(text)
      if (quotes.length === 0) {
        throw new QuoteProviderError('备用行情没有返回可识别的数据')
      }
      return quotes
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      throw new QuoteProviderError(businessError.message ?? '备用行情请求失败')
    } finally {
      request.destroy()
    }
  }
}
