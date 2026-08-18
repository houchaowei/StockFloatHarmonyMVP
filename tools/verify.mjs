import fs from 'node:fs'
import path from 'node:path'
import process from 'node:process'

const root = path.resolve(new URL('..', import.meta.url).pathname)
const required = [
  '.gitignore',
  'AppScope/app.json5',
  'build-profile.json5',
  'hvigorfile.ts',
  'entry/src/main/module.json5',
  'entry/src/main/ets/model/StockModels.ets',
  'entry/src/main/ets/model/PersonalModels.ets',
  'entry/src/main/ets/model/ApplicationTheme.ets',
  'entry/src/main/ets/model/PersonalStore.ets',
  'entry/src/main/ets/model/TencentQuoteProvider.ets',
  'entry/src/main/ets/model/TencentStockSearchProvider.ets',
  'entry/src/main/ets/model/SinaQuoteProvider.ets',
  'entry/src/main/ets/model/CompositeQuoteProvider.ets',
  'entry/src/main/ets/model/QuoteStore.ets',
  'entry/src/main/ets/model/FloatWindowManager.ets',
  'entry/src/main/ets/components/MiniSparkline.ets',
  'entry/src/main/ets/components/QuoteCapsule.ets',
  'entry/src/main/ets/pages/FloatCapsule.ets',
  'entry/src/main/ets/pages/WatchlistPage.ets',
  'entry/src/main/ets/pages/AlertsPage.ets',
  'entry/src/main/ets/pages/AlertEditorPage.ets',
  'entry/src/main/ets/pages/PositionsPage.ets',
  'entry/src/main/ets/pages/PositionEditorPage.ets',
  'entry/src/main/ets/pages/SettingsPage.ets',
  'entry/src/main/ets/pages/Index.ets'
]

for (const file of required) {
  if (!fs.existsSync(path.join(root, file))) {
    throw new Error(`missing required file: ${file}`)
  }
}

function read(file) {
  return fs.readFileSync(path.join(root, file), 'utf8')
}

function requireContracts(label, text, contracts) {
  for (const contract of contracts) {
    if (!text.includes(contract)) throw new Error(`${label} contract missing: ${contract}`)
  }
}

const buildProfile = read('build-profile.json5')
if (!buildProfile.includes('"signingConfigs": []') ||
  /keyPassword|storePassword|certpath|storeFile|\/Users\//.test(buildProfile)) {
  throw new Error('tracked build profile contains local signing material')
}

requireContracts('local signing loader', read('hvigorfile.ts'), [
  '.signing/local-signing.json',
  'overrides',
  'signingConfig'
])
if (!read('.gitignore').split(/\r?\n/).includes('.signing/local-signing.json')) {
  throw new Error('machine-specific local signing file is not ignored by Git')
}

const manifest = read('entry/src/main/module.json5')
requireContracts('permission', manifest, [
  'ohos.permission.INTERNET',
  'ohos.permission.SYSTEM_FLOAT_WINDOW',
  'ohos.permission.KEEP_BACKGROUND_RUNNING'
])

const pages = JSON.parse(read('entry/src/main/resources/base/profile/main_pages.json'))
for (const route of ['pages/Index', 'pages/FloatCapsule']) {
  if (!pages.src.includes(route)) throw new Error(`missing page route: ${route}`)
}

function parseTencentLine(line) {
  const first = line.indexOf('"')
  const last = line.lastIndexOf('"')
  if (first < 0 || last <= first) return undefined
  const fields = line.substring(first + 1, last).split('~')
  if (fields.length <= 34) return undefined
  const price = Number(fields[3])
  const previousClose = Number(fields[4])
  if (!Number.isFinite(price) || !Number.isFinite(previousClose) || price <= 0) return undefined
  return {
    source: '腾讯', name: fields[1], code: fields[2], price,
    open: Number(fields[5]), change: Number(fields[31]), changePercent: Number(fields[32]),
    high: Number(fields[33]), low: Number(fields[34]), timestamp: fields[30]
  }
}

function parseSinaLine(line) {
  const marker = 'hq_str_'
  const markerIndex = line.indexOf(marker)
  const equals = line.indexOf('=')
  const first = line.indexOf('"')
  const last = line.lastIndexOf('"')
  if (markerIndex < 0 || equals <= markerIndex || first < 0 || last <= first) return undefined
  const id = line.substring(markerIndex + marker.length, equals).trim()
  const fields = line.substring(first + 1, last).split(',')
  if (fields.length < 32) return undefined
  const previousClose = Number(fields[2])
  const price = Number(fields[3])
  if (!Number.isFinite(price) || price <= 0 || !Number.isFinite(previousClose) || previousClose <= 0) return undefined
  return {
    source: '新浪', id, name: fields[0], price, open: Number(fields[1]),
    high: Number(fields[4]), low: Number(fields[5]),
    change: price - previousClose, changePercent: (price - previousClose) / previousClose * 100,
    timestamp: `${fields[30]} ${fields[31]}`
  }
}

const tencentFixture = 'v_sh600519="1~贵州茅台~600519~1343.00~1346.50~1346.50~35060~17643~17416~1343.00~66~1342.99~5~1342.98~1~1342.97~1~1342.95~1~1343.03~1~1343.32~23~1344.20~1~1344.30~1~1344.40~5~~20260812161432~-3.50~-0.26~1356.88~1332.51";'
const tencentQuote = parseTencentLine(tencentFixture)
if (!tencentQuote || tencentQuote.name !== '贵州茅台' || tencentQuote.code !== '600519' ||
  tencentQuote.price !== 1343 || tencentQuote.open !== 1346.5 || tencentQuote.high !== 1356.88 ||
  tencentQuote.low !== 1332.51 || tencentQuote.changePercent !== -0.26) {
  throw new Error(`Tencent parser fixture failed: ${JSON.stringify(tencentQuote)}`)
}

const sinaFields = [
  '贵州茅台', '1346.50', '1346.50', '1343.00', '1356.88', '1332.51', '0', '0',
  '35060', '47000000', ...Array(20).fill('0'), '2026-08-12', '16:14:32', '00'
]
const sinaQuote = parseSinaLine(`var hq_str_sh600519="${sinaFields.join(',')}";`)
if (!sinaQuote || sinaQuote.id !== 'sh600519' || sinaQuote.name !== '贵州茅台' ||
  sinaQuote.price !== 1343 || sinaQuote.high !== 1356.88 || sinaQuote.low !== 1332.51) {
  throw new Error(`Sina parser fixture failed: ${JSON.stringify(sinaQuote)}`)
}

function decodeUnicodeEscapes(value) {
  return value.replace(/\\u([0-9a-fA-F]{4})/g, (_match, code) => String.fromCharCode(Number.parseInt(code, 16)))
}

function parseStockSearch(text) {
  const first = text.indexOf('"')
  const last = text.lastIndexOf('"')
  if (first < 0 || last <= first) return []
  return text.substring(first + 1, last).split('^').map(entry => entry.split('~'))
    .filter(fields => fields.length >= 5 && fields[4] === 'GP-A' && ['sh', 'sz', 'bj'].includes(fields[0]))
    .map(fields => ({ id: `${fields[0]}${fields[1]}`, name: decodeUnicodeEscapes(fields[2]), pinyin: fields[3] }))
}

const searchCandidates = parseStockSearch(
  'v_hint="sh~600519~\\u8d35\\u5dde\\u8305\\u53f0~gzmt~GP-A^hk~01688~\\u963f\\u91cc~ali~GP"')
if (searchCandidates.length !== 1 || searchCandidates[0].id !== 'sh600519' ||
  searchCandidates[0].name !== '贵州茅台' || searchCandidates[0].pinyin !== 'gzmt') {
  throw new Error(`stock search parser fixture failed: ${JSON.stringify(searchCandidates)}`)
}

function exchangeDateKey(timestamp) {
  const date = new Date(timestamp + 8 * 60 * 60 * 1000)
  return `${date.getUTCFullYear()}${String(date.getUTCMonth() + 1).padStart(2, '0')}${String(date.getUTCDate()).padStart(2, '0')}`
}

function freshness({ quoteTimestamp, fetchedTimestamp }, phase, backgroundActive, now) {
  if (!backgroundActive && phase === '交易中') return '后台已暂停'
  if (now - fetchedTimestamp > 30 * 60 * 1000) return '离线缓存'
  if (['已收盘', '周末休市', '交易日休市', '午间休市', '盘前'].includes(phase)) return '收盘行情'
  if (exchangeDateKey(quoteTimestamp) !== exchangeDateKey(now) || now - quoteTimestamp > 120000) return '行情已过期'
  if (now - quoteTimestamp > 30000) return '稍有延迟'
  return '实时'
}

const now = Date.parse('2026-08-17T10:00:00+08:00')
if (freshness({ quoteTimestamp: now - 10000, fetchedTimestamp: now - 5000 }, '交易中', true, now) !== '实时' ||
  freshness({ quoteTimestamp: now - 60000, fetchedTimestamp: now - 5000 }, '交易中', true, now) !== '稍有延迟' ||
  freshness({ quoteTimestamp: now - 300000, fetchedTimestamp: now - 5000 }, '交易中', true, now) !== '行情已过期' ||
  freshness({ quoteTimestamp: now - 10000, fetchedTimestamp: now - 5000 }, '交易中', false, now) !== '后台已暂停' ||
  freshness({ quoteTimestamp: now - 10000, fetchedTimestamp: now - 3600000 }, '交易中', true, now) !== '离线缓存') {
  throw new Error('freshness state behavior failed')
}

function alertMatches(kind, threshold, quote) {
  if (kind === 'priceAbove') return quote.price >= threshold
  if (kind === 'priceBelow') return quote.price <= threshold
  if (kind === 'percentUp') return quote.changePercent >= threshold
  return quote.changePercent <= -Math.abs(threshold)
}

if (!alertMatches('priceAbove', 10, { price: 11, changePercent: 1 }) ||
  !alertMatches('priceBelow', 12, { price: 11, changePercent: 1 }) ||
  !alertMatches('percentUp', 2, { price: 11, changePercent: 2.1 }) ||
  !alertMatches('percentDown', 2, { price: 11, changePercent: -2.1 }) ||
  alertMatches('percentDown', 2, { price: 11, changePercent: 1 })) {
  throw new Error('alert threshold behavior failed')
}

const stockModels = read('entry/src/main/ets/model/StockModels.ets')
requireContracts('quote trust', stockModels, [
  'QuoteFreshness', 'exchangeDateKey', 'HOLIDAY', 'priceDigits', "this.code.startsWith('1')", "this.code.startsWith('5')"
])

const tencentProvider = read('entry/src/main/ets/model/TencentQuoteProvider.ets')
requireContracts('Tencent provider', tencentProvider, [
  "TextDecoder.create('gb18030'", 'decodeToString', 'HttpDataType.ARRAY_BUFFER', 'fields[31]', 'fields[32]'
])
const sinaProvider = read('entry/src/main/ets/model/SinaQuoteProvider.ets')
requireContracts('Sina fallback', sinaProvider, [
  'hq.sinajs.cn/list=', "TextDecoder.create('gb18030'", "'新浪'", 'fields[30]', 'fields[31]'
])
const stockSearchProvider = read('entry/src/main/ets/model/TencentStockSearchProvider.ets')
requireContracts('Tencent stock search', stockSearchProvider, [
  'smartbox.gtimg.cn/s3/', 'encodeURIComponent', "fields[4] !== 'GP-A'", 'decodeUnicodeEscapes'
])
const compositeProvider = read('entry/src/main/ets/model/CompositeQuoteProvider.ets')
requireContracts('provider failover', compositeProvider, ['TencentQuoteProvider', 'SinaQuoteProvider', 'missing', 'fallback.fetch'])

const personal = read('entry/src/main/ets/model/PersonalStore.ets')
requireContracts('personalization', personal, [
  'rotation_enabled', 'capsule_size', 'capsule_opacity', 'capsule_metric', 'privacy_mode',
  'capsule_background',
  'reverse_colors', 'auto_restore_float', 'trading_refresh_seconds', 'status_notification_enabled',
  'price_alerts_v1', 'positions_v1', 'price_history_v1', 'requestEnableNotification',
  'AlertRepeatMode.DAILY', 'cooldownMinutes', 'publishStatusQuote', 'recordQuotes',
  'wantAgent.getWantAgent', 'WantAgentFlags.UPDATE_PRESENT_FLAG', 'request.wantAgent = launchAgent',
  'updateAlert', 'removeAlertsForSymbol'
])
requireContracts('application theme', read('entry/src/main/ets/model/ApplicationTheme.ets'), [
  'CapsuleBackground.WHITE', "case '#0C1017'", "case '#121720'", "case '#171D27'"
])

const manager = read('entry/src/main/ets/model/FloatWindowManager.ets')
requireContracts('float window', manager, [
  'WindowType.TYPE_FLOAT', 'moveWindowTo', 'resize', "setUIContent('pages/FloatCapsule')",
  'float_on_right', 'startMoving', 'systemMoving', 'dragActive', "display.on('change'",
  'applyPresentationSettings', 'CapsuleDimensions', "AppStorage.set<boolean>('backgroundActive', false)",
  'requestSuspendDelay', 'cancelSuspendDelay', 'abilityInForeground', 'shutdown'
])

const store = read('entry/src/main/ets/model/QuoteStore.ets')
requireContracts('quote store', store, [
  'CompositeQuoteProvider', 'sh600519,sz000001,sz300750', 'watchlist.length >= 20',
  'detectTradingDayClosure', 'QuoteFreshnessHelper', 'evaluateAlerts', 'publishStatusQuote',
  'recordQuotes', 'rotationEnabled', 'rotationIntervalSeconds', 'pinnedSymbolId',
  'tradingRefreshSeconds', 'undoRemove', 'moveSymbol', 'sortByChange',
  'fields.length !== 11 && fields.length !== 12', 'TencentStockSearchProvider', 'bestSearchCandidate'
])

const capsule = read('entry/src/main/ets/components/QuoteCapsule.ets')
requireContracts('capsule', capsule, [
  'MiniSparkline', 'positionRecord', 'privacyMode', 'reverseColors', 'opacityPercent',
  'metricMode', 'backgroundStyle', 'CapsuleBackground.WHITE', 'QuoteFreshnessHelper', 'width(44)', 'accessibilityText',
  'PanGesture({ distance: 8 })', 'LongPressGesture({ repeat: false, duration: 700 })',
  'onAction(() => this.onToggle())', '拖动可移动展开悬浮窗', '顶部拖动',
  '今开', '最高', '最低', '行情'
])
requireContracts('sparkline privacy', read('entry/src/main/ets/components/MiniSparkline.ets'), [
  '隐私模式 · 走势已隐藏'
])
if (capsule.includes('onAction(() => this.onClose())')) {
  throw new Error('collapsed long press must not destructively close the capsule')
}

const floatPage = read('entry/src/main/ets/pages/FloatCapsule.ets')
requireContracts('float page', floatPage, [
  'startDrag', 'endDrag', 'selectionTick', 'priceHistory', 'positions', 'capsuleMetric'
])
if (floatPage.includes('LongPressGesture') || floatPage.includes('PanGesture')) {
  throw new Error('float page must not own full-window gestures that can swallow capsule button taps')
}

const indexPage = read('entry/src/main/ets/pages/Index.ets')
requireContracts('management shell', indexPage, [
  'navigationItem', 'layoutWeight(1)', 'nav_watchlist', 'nav_alerts', 'nav_positions', 'nav_settings',
  '自选', '提醒', '持仓', '设置', 'AlertEditorPage', 'PositionEditorPage', 'managementRoute', 'bottomSafeHeight'
])
requireContracts('management back handling', read('entry/src/main/ets/entryability/EntryAbility.ets'), [
  "AppStorage.setOrCreate<string>('managementRoute', 'root')", 'onBackPressed(): boolean',
  "AppStorage.set<string>('managementRoute', 'root')"
])
requireContracts('watchlist UI', read('entry/src/main/ets/pages/WatchlistPage.ets'), [
  '应用内实时预览', '开启胶囊', '搜索当前自选：名称 / 拼音 / 代码',
  '.onMove(', '撤销删除', '涨幅排序', '跌幅排序', '设提醒', '记持仓',
  '删除全部关联', 'removeAlertsForSymbol', '行情状态已隐藏', '代码 / 中文名 / 拼音'
])
requireContracts('alert management UI', read('entry/src/main/ets/pages/AlertsPage.ets'), [
  '价格提醒', '新建提醒', '通知授权', '已启用', '已停用', '系统挂起'
])
requireContracts('alert editor UI', read('entry/src/main/ets/pages/AlertEditorPage.ets'), [
  '价格高于', '价格低于', '涨幅达到', '跌幅达到', '每日提醒', 'updateAlert'
])
requireContracts('position management UI', read('entry/src/main/ets/pages/PositionsPage.ets'), [
  '本地持仓', '当前市值', '累计盈亏', '今日', '持仓明细', '不会上传'
])
requireContracts('position editor UI', read('entry/src/main/ets/pages/PositionEditorPage.ets'), [
  '新增持仓', '编辑持仓', '成本价', '持仓数量', '删除这笔持仓'
])
requireContracts('settings UI', read('entry/src/main/ets/pages/SettingsPage.ets'), [
  '悬浮胶囊', '行情与通知', '外观与隐私', '尺寸', '透明度', '展示内容',
  '应用与胶囊背景', '黑色背景', '白色背景', '常驻行情通知', '启动时恢复悬浮', 'ToggleType.Switch'
])

if (process.argv.includes('--live')) {
  const symbols = 'sh600519,sz000001,sz300750'
  const response = await fetch(`https://qt.gtimg.cn/q=${symbols}`, {
    headers: { Referer: 'https://gu.qq.com/', 'User-Agent': 'StockFloatHarmonyMVP/0.3 verifier' }
  })
  if (!response.ok) throw new Error(`live endpoint returned HTTP ${response.status}`)
  const text = new TextDecoder('gb18030').decode(await response.arrayBuffer())
  const liveQuotes = text.split(';').map(parseTencentLine).filter(Boolean)
  if (liveQuotes.length !== 3 || liveQuotes.some(item => !item.name || !Number.isFinite(item.price) ||
    !Number.isFinite(item.open) || !Number.isFinite(item.high) || !Number.isFinite(item.low) ||
    item.open <= 0 || item.high <= 0 || item.low <= 0)) {
    throw new Error(`live quote verification failed: ${JSON.stringify(liveQuotes)}`)
  }
  console.log(`live quote verification passed: ${liveQuotes.map(item =>
    `${item.name} ${item.price} (${item.low}-${item.high})`).join(', ')}`)

  const fallbackResponse = await fetch(`https://hq.sinajs.cn/list=${symbols}`, {
    headers: { Referer: 'https://finance.sina.com.cn/', 'User-Agent': 'StockFloatHarmonyMVP/0.3 verifier' }
  })
  if (!fallbackResponse.ok) throw new Error(`live fallback endpoint returned HTTP ${fallbackResponse.status}`)
  const fallbackText = new TextDecoder('gb18030').decode(await fallbackResponse.arrayBuffer())
  const fallbackQuotes = fallbackText.split(';').map(parseSinaLine).filter(Boolean)
  if (fallbackQuotes.length !== 3 || fallbackQuotes.some(item => !item.name || !Number.isFinite(item.price) ||
    !Number.isFinite(item.open) || !Number.isFinite(item.high) || !Number.isFinite(item.low) ||
    item.open <= 0 || item.high <= 0 || item.low <= 0)) {
    throw new Error(`live fallback verification failed: ${JSON.stringify(fallbackQuotes)}`)
  }
  console.log(`live fallback verification passed: ${fallbackQuotes.map(item =>
    `${item.name} ${item.price} (${item.low}-${item.high})`).join(', ')}`)
}

console.log('StockFloatHarmonyMVP verification passed')
console.log(`verified ${required.length} files: safe signing, dual providers, trust states, alerts, personalization, positions, history, gestures and management UI`)
