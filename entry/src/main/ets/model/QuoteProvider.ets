import { StockQuote, StockSymbol } from './StockModels'

export interface QuoteProvider {
  fetch(symbols: Array<StockSymbol>): Promise<Array<StockQuote>>
}
