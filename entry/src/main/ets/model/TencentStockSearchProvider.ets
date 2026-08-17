import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { StockSymbol } from './StockModels'
import { QuoteProviderError } from './TencentQuoteProvider'

export class StockSearchCandidate {
  symbol: StockSymbol
  name: string
  pinyin: string

  constructor(symbol: StockSymbol, name: string, pinyin: string) {
    this.symbol = symbol
    this.name = name
    this.pinyin = pinyin
  }
}

export class TencentStockSearchParser {
  static parse(text: string): Array<StockSearchCandidate> {
    const result: Array<StockSearchCandidate> = []
    const firstQuote: number = text.indexOf('"')
    const lastQuote: number = text.lastIndexOf('"')
    if (firstQuote < 0 || lastQuote <= firstQuote) {
      return result
    }

    const entries: Array<string> = text.substring(firstQuote + 1, lastQuote).split('^')
    entries.forEach((entry: string) => {
      const fields: Array<string> = entry.split('~')
      if (fields.length < 5 || fields[4] !== 'GP-A') {
        return
      }
      const market: string = fields[0].toLowerCase()
      if (market !== 'sh' && market !== 'sz' && market !== 'bj') {
        return
      }
      const symbol: StockSymbol | undefined = StockSymbol.parse(`${market}${fields[1]}`)
      if (symbol === undefined) {
        return
      }
      result.push(new StockSearchCandidate(symbol,
        TencentStockSearchParser.decodeUnicodeEscapes(fields[2]), fields[3].toLowerCase()))
    })
    return result
  }

  private static decodeUnicodeEscapes(value: string): string {
    let result: string = ''
    let index: number = 0
    while (index < value.length) {
      if (value.substring(index, index + 2) === '\\u' && index + 6 <= value.length) {
        const code: number = parseInt(value.substring(index + 2, index + 6), 16)
        if (Number.isFinite(code)) {
          result += String.fromCharCode(code)
          index += 6
          continue
        }
      }
      result += value.substring(index, index + 1)
      index += 1
    }
    return result
  }
}

export class TencentStockSearchProvider {
  async search(query: string): Promise<Array<StockSearchCandidate>> {
    const normalized: string = query.trim()
    if (normalized.length === 0) {
      return []
    }
    const request: http.HttpRequest = http.createHttp()
    try {
      const url: string = `https://smartbox.gtimg.cn/s3/?q=${encodeURIComponent(normalized)}&t=all`
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 6000,
        readTimeout: 10000,
        usingCache: false,
        header: {
          'User-Agent': 'StockFloatHarmonyMVP/0.3 (personal prototype)',
          'Referer': 'https://gu.qq.com/'
        }
      })
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new QuoteProviderError(`股票搜索返回 HTTP ${response.responseCode}`)
      }
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8', {
        fatal: false,
        ignoreBOM: true
      })
      const text: string = decoder.decodeToString(new Uint8Array(response.result as ArrayBuffer), { stream: false })
      return TencentStockSearchParser.parse(text)
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      throw new QuoteProviderError(businessError.message ?? '股票搜索失败')
    } finally {
      request.destroy()
    }
  }
}
