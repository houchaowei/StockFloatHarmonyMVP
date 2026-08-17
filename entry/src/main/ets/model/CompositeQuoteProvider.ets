import { QuoteProvider } from './QuoteProvider'
import { SinaQuoteProvider } from './SinaQuoteProvider'
import { QuoteProviderError, TencentQuoteProvider } from './TencentQuoteProvider'
import { StockQuote, StockSymbol } from './StockModels'

export class CompositeQuoteProvider implements QuoteProvider {
  private primary: TencentQuoteProvider = new TencentQuoteProvider()
  private fallback: SinaQuoteProvider = new SinaQuoteProvider()

  async fetch(symbols: Array<StockSymbol>): Promise<Array<StockQuote>> {
    let primaryQuotes: Array<StockQuote> = []
    let primaryMessage: string = ''
    try {
      primaryQuotes = await this.primary.fetch(symbols)
    } catch (error) {
      primaryMessage = (error as Error).message
    }
    const missing: Array<StockSymbol> = symbols.filter((symbol: StockSymbol) =>
      !primaryQuotes.some((quote: StockQuote) => quote.symbol.id === symbol.id))
    if (missing.length === 0) {
      return primaryQuotes
    }
    try {
      const fallbackQuotes: Array<StockQuote> = await this.fallback.fetch(missing)
      return primaryQuotes.concat(fallbackQuotes)
    } catch (error) {
      if (primaryQuotes.length > 0) {
        return primaryQuotes
      }
      const fallbackMessage: string = (error as Error).message
      throw new QuoteProviderError(`主源：${primaryMessage || '无有效行情'}；备用源：${fallbackMessage}`)
    }
  }
}
