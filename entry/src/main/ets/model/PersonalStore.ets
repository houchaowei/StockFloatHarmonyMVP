import { common, wantAgent, WantAgent } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'
import { notificationManager } from '@kit.NotificationKit'
import { AlertKind, AlertRepeatMode, CapsuleBackground, CapsuleMetric, CapsuleSize, PositionRecord, PriceAlert, PricePoint, PriceSeries } from './PersonalModels'
import { MarketPhase, StockQuote } from './StockModels'
import { ApplicationTheme } from './ApplicationTheme'

const STATUS_NOTIFICATION_ID: number = 9100
const APP_BUNDLE_NAME: string = 'com.stockfloat.stock.mvp'
const APP_ABILITY_NAME: string = 'EntryAbility'

export class PersonalStore {
  private static singleton: PersonalStore = new PersonalStore()
  private context?: common.UIAbilityContext
  private dataPreferences?: preferences.Preferences
  private lastHistoryPersistedAt: number = 0
  private launchWantAgent?: WantAgent

  static getInstance(): PersonalStore {
    return PersonalStore.singleton
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context
    this.ensureStorage()
    try {
      this.dataPreferences = await preferences.getPreferences(context, 'stock_float_mvp')
      AppStorage.set<boolean>('rotationEnabled', this.dataPreferences.getSync('rotation_enabled', true) as boolean)
      AppStorage.set<number>('rotationIntervalSeconds', this.dataPreferences.getSync('rotation_interval', 4) as number)
      AppStorage.set<string>('pinnedSymbolId', this.dataPreferences.getSync('pinned_symbol', '') as string)
      AppStorage.set<string>('capsuleSize', this.dataPreferences.getSync('capsule_size', CapsuleSize.STANDARD) as string)
      AppStorage.set<number>('capsuleOpacity', this.dataPreferences.getSync('capsule_opacity', 95) as number)
      AppStorage.set<string>('capsuleMetric', this.dataPreferences.getSync('capsule_metric', CapsuleMetric.BOTH) as string)
      AppStorage.set<string>('capsuleBackground',
        this.dataPreferences.getSync('capsule_background', CapsuleBackground.BLACK) as string)
      AppStorage.set<boolean>('privacyMode', this.dataPreferences.getSync('privacy_mode', false) as boolean)
      AppStorage.set<boolean>('reverseColors', this.dataPreferences.getSync('reverse_colors', false) as boolean)
      AppStorage.set<boolean>('autoRestoreFloat', this.dataPreferences.getSync('auto_restore_float', true) as boolean)
      AppStorage.set<boolean>('floatUserEnabled', this.dataPreferences.getSync('float_user_enabled', false) as boolean)
      AppStorage.set<number>('tradingRefreshSeconds', this.dataPreferences.getSync('trading_refresh_seconds', 5) as number)
      AppStorage.set<boolean>('statusNotificationEnabled',
        this.dataPreferences.getSync('status_notification_enabled', false) as boolean)
      AppStorage.set<Array<PriceAlert>>('priceAlerts', this.decodeAlerts(
        this.dataPreferences.getSync('price_alerts_v1', '') as string))
      AppStorage.set<Array<PositionRecord>>('positions', this.decodePositions(
        this.dataPreferences.getSync('positions_v1', '') as string))
      AppStorage.set<Array<PriceSeries>>('priceHistory', this.decodeHistory(
        this.dataPreferences.getSync('price_history_v1', '') as string))
      const enabled: boolean = notificationManager.isNotificationEnabledSync()
      AppStorage.set<string>('alertStatus', enabled ? '系统通知已开启' : '通知未授权，提醒规则仍会保存')
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      AppStorage.set<string>('alertStatus', `个性化设置读取失败 · ${businessError.message}`)
    }
  }

  capsuleSize(): CapsuleSize {
    const value: string = AppStorage.get<string>('capsuleSize') ?? CapsuleSize.STANDARD
    if (value === CapsuleSize.COMPACT) {
      return CapsuleSize.COMPACT
    }
    if (value === CapsuleSize.LARGE) {
      return CapsuleSize.LARGE
    }
    return CapsuleSize.STANDARD
  }

  shouldRestoreFloat(): boolean {
    return (AppStorage.get<boolean>('autoRestoreFloat') ?? true) &&
      (AppStorage.get<boolean>('floatUserEnabled') ?? false)
  }

  async setFloatUserEnabled(value: boolean): Promise<void> {
    AppStorage.set<boolean>('floatUserEnabled', value)
    await this.persistValue('float_user_enabled', value)
  }

  async setRotationEnabled(value: boolean): Promise<void> {
    AppStorage.set<boolean>('rotationEnabled', value)
    await this.persistValue('rotation_enabled', value)
    this.bumpSettings()
  }

  async setRotationInterval(seconds: number): Promise<void> {
    const safe: number = Math.min(30, Math.max(2, seconds))
    AppStorage.set<number>('rotationIntervalSeconds', safe)
    await this.persistValue('rotation_interval', safe)
    this.bumpSettings()
  }

  async setPinnedSymbol(symbolId: string): Promise<void> {
    AppStorage.set<string>('pinnedSymbolId', symbolId)
    await this.persistValue('pinned_symbol', symbolId)
    this.bumpSettings()
  }

  async setCapsuleSize(size: CapsuleSize): Promise<void> {
    AppStorage.set<string>('capsuleSize', size)
    await this.persistValue('capsule_size', size)
    this.bumpSettings()
  }

  async setCapsuleOpacity(value: number): Promise<void> {
    const safe: number = Math.min(100, Math.max(60, value))
    AppStorage.set<number>('capsuleOpacity', safe)
    await this.persistValue('capsule_opacity', safe)
    this.bumpSettings()
  }

  async setCapsuleMetric(value: CapsuleMetric): Promise<void> {
    AppStorage.set<string>('capsuleMetric', value)
    await this.persistValue('capsule_metric', value)
    this.bumpSettings()
  }

  async setCapsuleBackground(value: CapsuleBackground): Promise<void> {
    AppStorage.set<string>('capsuleBackground', value)
    await this.persistValue('capsule_background', value)
    this.bumpSettings()
    await this.applyWindowTheme(value)
  }

  private async applyWindowTheme(value: CapsuleBackground): Promise<void> {
    try {
      await ApplicationTheme.applyWindow(value)
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      console.info(`Window theme will apply on next launch. Code: ${businessError.code}, message: ${businessError.message}`)
    }
  }

  async setPrivacyMode(value: boolean): Promise<void> {
    AppStorage.set<boolean>('privacyMode', value)
    await this.persistValue('privacy_mode', value)
    this.bumpSettings()
  }

  async setReverseColors(value: boolean): Promise<void> {
    AppStorage.set<boolean>('reverseColors', value)
    await this.persistValue('reverse_colors', value)
    this.bumpSettings()
  }

  async setAutoRestoreFloat(value: boolean): Promise<void> {
    AppStorage.set<boolean>('autoRestoreFloat', value)
    await this.persistValue('auto_restore_float', value)
    this.bumpSettings()
  }

  async setTradingRefreshSeconds(value: number): Promise<void> {
    const safe: number = Math.min(60, Math.max(5, value))
    AppStorage.set<number>('tradingRefreshSeconds', safe)
    await this.persistValue('trading_refresh_seconds', safe)
    this.bumpSettings()
  }

  async setStatusNotificationEnabled(value: boolean): Promise<void> {
    AppStorage.set<boolean>('statusNotificationEnabled', value)
    await this.persistValue('status_notification_enabled', value)
    this.bumpSettings()
    if (!value) {
      try {
        await notificationManager.cancel(STATUS_NOTIFICATION_ID)
      } catch (error) {
        const businessError: BusinessError = error as BusinessError
        console.info(`Status notification was not active. Code: ${businessError.code}`)
      }
    }
  }

  async requestNotificationPermission(): Promise<boolean> {
    if (this.context === undefined) {
      AppStorage.set<string>('alertStatus', '通知上下文尚未初始化')
      return false
    }
    try {
      if (notificationManager.isNotificationEnabledSync()) {
        AppStorage.set<string>('alertStatus', '系统通知已开启')
        return true
      }
      await notificationManager.requestEnableNotification(this.context)
      AppStorage.set<string>('alertStatus', '系统通知已开启')
      return true
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      AppStorage.set<string>('alertStatus', `通知未开启 · ${businessError.message}`)
      return false
    }
  }

  async addAlert(symbolId: string, kind: AlertKind, threshold: number, repeatMode: AlertRepeatMode): Promise<boolean> {
    if (symbolId.length === 0 || !Number.isFinite(threshold) || threshold <= 0) {
      AppStorage.set<string>('alertStatus', '请输入有效的提醒阈值')
      return false
    }
    const alerts: Array<PriceAlert> = AppStorage.get<Array<PriceAlert>>('priceAlerts') ?? []
    const id: string = `${symbolId}-${kind}-${Date.now()}`
    const updated: Array<PriceAlert> = alerts.concat([
      new PriceAlert(id, symbolId, kind, threshold, repeatMode, true, 30, 0)
    ])
    AppStorage.set<Array<PriceAlert>>('priceAlerts', updated)
    const modeText: string = repeatMode === AlertRepeatMode.DAILY ? '每日一次' :
      (repeatMode === AlertRepeatMode.COOLDOWN ? '重复提醒（30 分钟冷却）' : '单次提醒')
    AppStorage.set<string>('alertStatus', `已添加${modeText}`)
    await this.persistAlerts(updated)
    return true
  }

  async updateAlert(alertId: string, symbolId: string, kind: AlertKind, threshold: number,
    repeatMode: AlertRepeatMode): Promise<boolean> {
    if (alertId.length === 0 || symbolId.length === 0 || !Number.isFinite(threshold) || threshold <= 0) {
      AppStorage.set<string>('alertStatus', '请输入有效的提醒阈值')
      return false
    }
    const alerts: Array<PriceAlert> = AppStorage.get<Array<PriceAlert>>('priceAlerts') ?? []
    if (!alerts.some((item: PriceAlert) => item.id === alertId)) {
      AppStorage.set<string>('alertStatus', '未找到要编辑的提醒')
      return false
    }
    const updated: Array<PriceAlert> = alerts.map((item: PriceAlert) => item.id === alertId ?
      new PriceAlert(item.id, symbolId, kind, threshold, repeatMode, item.enabled, item.cooldownMinutes, 0) :
      new PriceAlert(item.id, item.symbolId, item.kind, item.threshold, item.repeatMode,
        item.enabled, item.cooldownMinutes, item.lastTriggeredAt))
    AppStorage.set<Array<PriceAlert>>('priceAlerts', updated)
    AppStorage.set<string>('alertStatus', '提醒已更新')
    await this.persistAlerts(updated)
    return true
  }

  async toggleAlert(alert: PriceAlert): Promise<void> {
    const alerts: Array<PriceAlert> = AppStorage.get<Array<PriceAlert>>('priceAlerts') ?? []
    const updated: Array<PriceAlert> = alerts.map((item: PriceAlert) => new PriceAlert(
      item.id, item.symbolId, item.kind, item.threshold, item.repeatMode,
      item.id === alert.id ? !item.enabled : item.enabled, item.cooldownMinutes, item.lastTriggeredAt
    ))
    AppStorage.set<Array<PriceAlert>>('priceAlerts', updated)
    await this.persistAlerts(updated)
  }

  async removeAlert(alert: PriceAlert): Promise<void> {
    const alerts: Array<PriceAlert> = AppStorage.get<Array<PriceAlert>>('priceAlerts') ?? []
    const updated: Array<PriceAlert> = alerts.filter((item: PriceAlert) => item.id !== alert.id)
    AppStorage.set<Array<PriceAlert>>('priceAlerts', updated)
    await this.persistAlerts(updated)
  }

  async removeAlertsForSymbol(symbolId: string): Promise<number> {
    const alerts: Array<PriceAlert> = AppStorage.get<Array<PriceAlert>>('priceAlerts') ?? []
    const updated: Array<PriceAlert> = alerts.filter((item: PriceAlert) => item.symbolId !== symbolId)
    const removedCount: number = alerts.length - updated.length
    if (removedCount > 0) {
      AppStorage.set<Array<PriceAlert>>('priceAlerts', updated)
      AppStorage.set<string>('alertStatus', `已删除 ${removedCount} 条关联提醒`)
      await this.persistAlerts(updated)
    }
    return removedCount
  }

  async evaluateAlerts(quotes: Array<StockQuote>, phase: MarketPhase): Promise<void> {
    if (phase !== MarketPhase.TRADING) {
      return
    }
    const alerts: Array<PriceAlert> = AppStorage.get<Array<PriceAlert>>('priceAlerts') ?? []
    const updated: Array<PriceAlert> = alerts.map((item: PriceAlert) => new PriceAlert(
      item.id, item.symbolId, item.kind, item.threshold, item.repeatMode,
      item.enabled, item.cooldownMinutes, item.lastTriggeredAt
    ))
    let changed: boolean = false
    for (let index: number = 0; index < updated.length; index += 1) {
      const alert: PriceAlert = updated[index]
      if (!alert.enabled) {
        continue
      }
      const quote: StockQuote | undefined = quotes.find((item: StockQuote) => item.symbol.id === alert.symbolId)
      if (quote === undefined || !this.matches(alert, quote)) {
        continue
      }
      const now: number = Date.now()
      if (alert.repeatMode === AlertRepeatMode.DAILY && alert.lastTriggeredAt > 0 &&
        this.sameExchangeDay(alert.lastTriggeredAt, now)) {
        continue
      }
      if (alert.repeatMode === AlertRepeatMode.COOLDOWN && alert.lastTriggeredAt > 0 &&
        now - alert.lastTriggeredAt < alert.cooldownMinutes * 60 * 1000) {
        continue
      }
      alert.lastTriggeredAt = now
      if (alert.repeatMode === AlertRepeatMode.ONCE) {
        alert.enabled = false
      }
      changed = true
      await this.publishAlert(alert, quote)
    }
    if (changed) {
      AppStorage.set<Array<PriceAlert>>('priceAlerts', updated)
      await this.persistAlerts(updated)
    }
  }

  async savePosition(symbolId: string, costPrice: number, quantity: number): Promise<boolean> {
    if (symbolId.length === 0 || !Number.isFinite(costPrice) || costPrice <= 0 ||
      !Number.isFinite(quantity) || quantity <= 0) {
      AppStorage.set<string>('positionStatus', '请输入有效的成本价和持仓数量')
      return false
    }
    const positions: Array<PositionRecord> = AppStorage.get<Array<PositionRecord>>('positions') ?? []
    const updated: Array<PositionRecord> = positions
      .filter((item: PositionRecord) => item.symbolId !== symbolId)
      .concat([new PositionRecord(symbolId, costPrice, quantity)])
    AppStorage.set<Array<PositionRecord>>('positions', updated)
    AppStorage.set<string>('positionStatus', '持仓已仅保存到本机')
    await this.persistPositions(updated)
    return true
  }

  async removePosition(symbolId: string): Promise<void> {
    const positions: Array<PositionRecord> = AppStorage.get<Array<PositionRecord>>('positions') ?? []
    const updated: Array<PositionRecord> = positions.filter((item: PositionRecord) => item.symbolId !== symbolId)
    AppStorage.set<Array<PositionRecord>>('positions', updated)
    AppStorage.set<string>('positionStatus', '已删除本地持仓')
    await this.persistPositions(updated)
  }

  positionFor(symbolId: string): PositionRecord | undefined {
    const positions: Array<PositionRecord> = AppStorage.get<Array<PositionRecord>>('positions') ?? []
    return positions.find((item: PositionRecord) => item.symbolId === symbolId)
  }

  async recordQuotes(quotes: Array<StockQuote>): Promise<void> {
    const history: Array<PriceSeries> = AppStorage.get<Array<PriceSeries>>('priceHistory') ?? []
    const updated: Array<PriceSeries> = history.map((series: PriceSeries) => new PriceSeries(
      series.symbolId,
      series.points.map((point: PricePoint) => new PricePoint(point.timestamp, point.price))
    ))
    quotes.forEach((quote: StockQuote) => {
      if (quote.quoteTimestamp <= 0 || quote.price <= 0) {
        return
      }
      let series: PriceSeries | undefined = updated.find((item: PriceSeries) => item.symbolId === quote.symbol.id)
      if (series === undefined) {
        series = new PriceSeries(quote.symbol.id)
        updated.push(series)
      }
      const last: PricePoint | undefined = series.points[series.points.length - 1]
      if (last !== undefined && !this.sameExchangeDay(last.timestamp, quote.quoteTimestamp)) {
        series.points = []
      }
      const currentLast: PricePoint | undefined = series.points[series.points.length - 1]
      if (currentLast === undefined || currentLast.timestamp !== quote.quoteTimestamp) {
        series.points = series.points.concat([new PricePoint(quote.quoteTimestamp, quote.price)]).slice(-48)
      }
    })
    AppStorage.set<Array<PriceSeries>>('priceHistory', updated)
    const now: number = Date.now()
    if (now - this.lastHistoryPersistedAt >= 60000) {
      await this.persistHistory(updated)
      this.lastHistoryPersistedAt = now
    }
  }

  historyFor(symbolId: string): Array<number> {
    const history: Array<PriceSeries> = AppStorage.get<Array<PriceSeries>>('priceHistory') ?? []
    return history.find((item: PriceSeries) => item.symbolId === symbolId)?.prices() ?? []
  }

  async publishStatusQuote(quote: StockQuote | undefined, phase: MarketPhase, freshness: string): Promise<void> {
    if (!(AppStorage.get<boolean>('statusNotificationEnabled') ?? false) || quote === undefined) {
      return
    }
    const privacy: boolean = AppStorage.get<boolean>('privacyMode') ?? false
    const title: string = privacy ? 'StockFloat 行情' : `${quote.name} ${quote.symbol.displayCode}`
    const text: string = privacy ? `${phase} · 行情 ${this.exchangeTime(quote.quoteTimestamp)} · ${freshness}` :
      `${quote.symbol.formatPrice(quote.price)}  ${this.signed(quote.changePercent)}% · 行情 ${this.exchangeTime(quote.quoteTimestamp)} · ${freshness}`
    try {
      const request: notificationManager.NotificationRequest = {
        id: STATUS_NOTIFICATION_ID,
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        isOngoing: true,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: text,
            additionalText: '点击通知可返回应用管理悬浮胶囊'
          }
        }
      }
      const launchAgent: WantAgent | undefined = await this.appLaunchWantAgent()
      if (launchAgent !== undefined) {
        request.wantAgent = launchAgent
      }
      await notificationManager.publish(request)
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      AppStorage.set<string>('alertStatus', `常驻行情通知失败 · ${businessError.message}`)
    }
  }

  private ensureStorage(): void {
    AppStorage.setOrCreate<boolean>('rotationEnabled', true)
    AppStorage.setOrCreate<number>('rotationIntervalSeconds', 4)
    AppStorage.setOrCreate<string>('pinnedSymbolId', '')
    AppStorage.setOrCreate<string>('capsuleSize', CapsuleSize.STANDARD)
    AppStorage.setOrCreate<number>('capsuleOpacity', 95)
    AppStorage.setOrCreate<string>('capsuleMetric', CapsuleMetric.BOTH)
    AppStorage.setOrCreate<string>('capsuleBackground', CapsuleBackground.BLACK)
    AppStorage.setOrCreate<boolean>('privacyMode', false)
    AppStorage.setOrCreate<boolean>('reverseColors', false)
    AppStorage.setOrCreate<boolean>('autoRestoreFloat', true)
    AppStorage.setOrCreate<boolean>('floatUserEnabled', false)
    AppStorage.setOrCreate<number>('tradingRefreshSeconds', 5)
    AppStorage.setOrCreate<boolean>('statusNotificationEnabled', false)
    AppStorage.setOrCreate<Array<PriceAlert>>('priceAlerts', [])
    AppStorage.setOrCreate<Array<PositionRecord>>('positions', [])
    AppStorage.setOrCreate<Array<PriceSeries>>('priceHistory', [])
    AppStorage.setOrCreate<string>('alertStatus', '提醒仅在行情刷新运行期间触发')
    AppStorage.setOrCreate<string>('positionStatus', '持仓数据仅保存在本机')
    AppStorage.setOrCreate<number>('settingsTick', 0)
  }

  private bumpSettings(): void {
    const tick: number = AppStorage.get<number>('settingsTick') ?? 0
    AppStorage.set<number>('settingsTick', tick + 1)
  }

  private matches(alert: PriceAlert, quote: StockQuote): boolean {
    if (alert.kind === AlertKind.PRICE_ABOVE) {
      return quote.price >= alert.threshold
    }
    if (alert.kind === AlertKind.PRICE_BELOW) {
      return quote.price <= alert.threshold
    }
    if (alert.kind === AlertKind.PERCENT_UP) {
      return quote.changePercent >= alert.threshold
    }
    return quote.changePercent <= -Math.abs(alert.threshold)
  }

  private async publishAlert(alert: PriceAlert, quote: StockQuote): Promise<void> {
    const privateMode: boolean = AppStorage.get<boolean>('privacyMode') ?? false
    const title: string = privateMode ? 'StockFloat 提醒已触发' : `${quote.name} · ${alert.kindText()}`
    const text: string = privateMode ? '打开应用查看行情详情' :
      `当前 ${quote.symbol.formatPrice(quote.price)}，涨跌幅 ${this.signed(quote.changePercent)}%`
    try {
      const request: notificationManager.NotificationRequest = {
        id: this.notificationId(alert.id),
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: text,
            additionalText: alert.repeatMode === AlertRepeatMode.DAILY ? '每日提醒 · 今日不再重复' :
              (alert.repeatMode === AlertRepeatMode.COOLDOWN ? '重复提醒 · 30 分钟冷却' : '单次提醒已自动停用')
          }
        }
      }
      const launchAgent: WantAgent | undefined = await this.appLaunchWantAgent()
      if (launchAgent !== undefined) {
        request.wantAgent = launchAgent
      }
      await notificationManager.publish(request)
      AppStorage.set<string>('alertStatus', privateMode ? '行情提醒已触发' : `${quote.name}提醒已触发`)
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      AppStorage.set<string>('alertStatus', `提醒触发但通知发送失败 · ${businessError.message}`)
    }
  }

  private notificationId(value: string): number {
    let result: number = 17
    for (let index: number = 0; index < value.length; index += 1) {
      result = (result * 31 + value.charCodeAt(index)) % 800000
    }
    return 10000 + Math.abs(result)
  }

  private async appLaunchWantAgent(): Promise<WantAgent | undefined> {
    if (this.launchWantAgent !== undefined) {
      return this.launchWantAgent
    }
    try {
      this.launchWantAgent = await wantAgent.getWantAgent({
        wants: [{
          bundleName: APP_BUNDLE_NAME,
          abilityName: APP_ABILITY_NAME
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 9100,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      })
      return this.launchWantAgent
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      console.error(`Failed to create notification entry. Code: ${businessError.code}, message: ${businessError.message}`)
      return undefined
    }
  }

  private signed(value: number): string {
    return `${value > 0 ? '+' : ''}${value.toFixed(2)}`
  }

  private exchangeTime(timestamp: number): string {
    if (timestamp <= 0) {
      return '--:--'
    }
    const date: Date = new Date(timestamp + 8 * 60 * 60 * 1000)
    return `${date.getUTCHours().toString().padStart(2, '0')}:${date.getUTCMinutes().toString().padStart(2, '0')}`
  }

  private sameExchangeDay(left: number, right: number): boolean {
    const leftDate: Date = new Date(left + 8 * 60 * 60 * 1000)
    const rightDate: Date = new Date(right + 8 * 60 * 60 * 1000)
    return leftDate.getUTCFullYear() === rightDate.getUTCFullYear() &&
      leftDate.getUTCMonth() === rightDate.getUTCMonth() && leftDate.getUTCDate() === rightDate.getUTCDate()
  }

  private encodeAlerts(alerts: Array<PriceAlert>): string {
    return alerts.map((alert: PriceAlert) => [
      alert.id, alert.symbolId, alert.kind, alert.threshold.toString(), alert.repeatMode,
      alert.enabled ? '1' : '0', alert.cooldownMinutes.toString(), alert.lastTriggeredAt.toString()
    ].join('|')).join(';')
  }

  private decodeAlerts(value: string): Array<PriceAlert> {
    const result: Array<PriceAlert> = []
    value.split(';').forEach((item: string) => {
      const fields: Array<string> = item.split('|')
      const threshold: number = Number(fields[3])
      if (fields.length !== 8 || !Number.isFinite(threshold) || threshold <= 0) {
        return
      }
      const kind: AlertKind = fields[2] as AlertKind
      let repeatMode: AlertRepeatMode = fields[4] as AlertRepeatMode
      if (fields[4] === '1') {
        repeatMode = AlertRepeatMode.COOLDOWN
      } else if (fields[4] === '0') {
        repeatMode = AlertRepeatMode.ONCE
      }
      result.push(new PriceAlert(fields[0], fields[1], kind, threshold, repeatMode,
        fields[5] === '1', Number(fields[6]) || 30, Number(fields[7]) || 0))
    })
    return result
  }

  private encodePositions(positions: Array<PositionRecord>): string {
    return positions.map((item: PositionRecord) =>
      [item.symbolId, item.costPrice.toString(), item.quantity.toString()].join('|')).join(';')
  }

  private decodePositions(value: string): Array<PositionRecord> {
    const result: Array<PositionRecord> = []
    value.split(';').forEach((item: string) => {
      const fields: Array<string> = item.split('|')
      const cost: number = Number(fields[1])
      const quantity: number = Number(fields[2])
      if (fields.length === 3 && Number.isFinite(cost) && cost > 0 && Number.isFinite(quantity) && quantity > 0) {
        result.push(new PositionRecord(fields[0], cost, quantity))
      }
    })
    return result
  }

  private encodeHistory(history: Array<PriceSeries>): string {
    return history.map((series: PriceSeries) => `${series.symbolId}|${series.points.map((point: PricePoint) =>
      `${point.timestamp}:${point.price}`).join(',')}`).join(';')
  }

  private decodeHistory(value: string): Array<PriceSeries> {
    const result: Array<PriceSeries> = []
    value.split(';').forEach((item: string) => {
      const separator: number = item.indexOf('|')
      if (separator <= 0) {
        return
      }
      const points: Array<PricePoint> = []
      item.substring(separator + 1).split(',').forEach((encoded: string) => {
        const fields: Array<string> = encoded.split(':')
        const timestamp: number = Number(fields[0])
        const price: number = Number(fields[1])
        if (fields.length === 2 && Number.isFinite(timestamp) && Number.isFinite(price) && price > 0) {
          points.push(new PricePoint(timestamp, price))
        }
      })
      result.push(new PriceSeries(item.substring(0, separator), points.slice(-48)))
    })
    return result
  }

  private async persistAlerts(alerts: Array<PriceAlert>): Promise<void> {
    await this.persistValue('price_alerts_v1', this.encodeAlerts(alerts))
  }

  private async persistPositions(positions: Array<PositionRecord>): Promise<void> {
    await this.persistValue('positions_v1', this.encodePositions(positions))
  }

  private async persistHistory(history: Array<PriceSeries>): Promise<void> {
    await this.persistValue('price_history_v1', this.encodeHistory(history))
  }

  private async persistValue(key: string, value: string | number | boolean): Promise<void> {
    if (this.dataPreferences === undefined) {
      return
    }
    try {
      this.dataPreferences.putSync(key, value)
      await this.dataPreferences.flush()
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      console.error(`Failed to persist ${key}. Code: ${businessError.code}, message: ${businessError.message}`)
    }
  }
}

export const personalStore: PersonalStore = PersonalStore.getInstance()
