import fs from 'node:fs'
import path from 'node:path'
import process from 'node:process'

const root = path.resolve(new URL('..', import.meta.url).pathname)
const required = [
  'AppScope/app.json5',
  'entry/src/main/module.json5',
  'entry/src/main/ets/model/TencentQuoteProvider.ets',
  'entry/src/main/ets/model/FloatWindowManager.ets',
  'entry/src/main/ets/pages/FloatCapsule.ets',
  'entry/src/main/ets/pages/Index.ets'
]

for (const file of required) {
  if (!fs.existsSync(path.join(root, file))) {
    throw new Error(`missing required file: ${file}`)
  }
}

const manifest = fs.readFileSync(path.join(root, 'entry/src/main/module.json5'), 'utf8')
for (const permission of [
  'ohos.permission.INTERNET',
  'ohos.permission.SYSTEM_FLOAT_WINDOW',
  'ohos.permission.KEEP_BACKGROUND_RUNNING'
]) {
  if (!manifest.includes(permission)) throw new Error(`missing permission: ${permission}`)
}

const pages = JSON.parse(fs.readFileSync(path.join(root, 'entry/src/main/resources/base/profile/main_pages.json'), 'utf8'))
for (const route of ['pages/Index', 'pages/FloatCapsule']) {
  if (!pages.src.includes(route)) throw new Error(`missing page route: ${route}`)
}

const provider = fs.readFileSync(path.join(root, 'entry/src/main/ets/model/TencentQuoteProvider.ets'), 'utf8')
for (const contract of ["TextDecoder.create('gb18030'", 'decodeToString', 'HttpDataType.ARRAY_BUFFER', 'fields[31]', 'fields[32]']) {
  if (!provider.includes(contract)) throw new Error(`provider contract missing: ${contract}`)
}

function parseLine(line) {
  const first = line.indexOf('"')
  const last = line.lastIndexOf('"')
  if (first < 0 || last <= first) return undefined
  const fields = line.substring(first + 1, last).split('~')
  if (fields.length <= 32) return undefined
  const price = Number(fields[3])
  const previousClose = Number(fields[4])
  if (!Number.isFinite(price) || !Number.isFinite(previousClose) || price <= 0) return undefined
  return {
    name: fields[1], code: fields[2], price,
    change: Number(fields[31]), changePercent: Number(fields[32]), timestamp: fields[30]
  }
}

const fixture = 'v_sh600519="1~贵州茅台~600519~1343.00~1346.50~1346.50~35060~17643~17416~1343.00~66~1342.99~5~1342.98~1~1342.97~1~1342.95~1~1343.03~1~1343.32~23~1344.20~1~1344.30~1~1344.40~5~~20260812161432~-3.50~-0.26~1356.88~1332.51";'
const quote = parseLine(fixture)
if (!quote || quote.name !== '贵州茅台' || quote.code !== '600519' || quote.price !== 1343 || quote.changePercent !== -0.26) {
  throw new Error(`quote parser fixture failed: ${JSON.stringify(quote)}`)
}

const manager = fs.readFileSync(path.join(root, 'entry/src/main/ets/model/FloatWindowManager.ets'), 'utf8')
for (const contract of ['WindowType.TYPE_FLOAT', 'moveWindowTo', 'resize', "setUIContent('pages/FloatCapsule')", 'float_on_right']) {
  if (!manager.includes(contract)) throw new Error(`float-window contract missing: ${contract}`)
}
for (const contract of ['startMoving', 'systemMoving', 'dragActive']) {
  if (!manager.includes(contract)) throw new Error(`smooth drag contract missing: ${contract}`)
}

const store = fs.readFileSync(path.join(root, 'entry/src/main/ets/model/QuoteStore.ets'), 'utf8')
for (const contract of [
  'sh600519,sz000001,sz300750',
  "preferences.getPreferences(context, 'stock_float_mvp')",
  'setInterval',
  '4000',
  'watchlist.length >= 20',
  'runRefreshLoop',
  "AppStorage.set<Array<StockQuote>>('quotes', merged)"
]) {
  if (!store.includes(contract)) throw new Error(`quote-store contract missing: ${contract}`)
}

const capsule = fs.readFileSync(path.join(root, 'entry/src/main/ets/components/QuoteCapsule.ets'), 'utf8')
for (const contract of [
  'borderRadius(this.expanded ? 22 : 36)',
  '上一只',
  '下一只',
  '刷新',
  '关闭',
  'PanGesture({ distance: 8 })',
  'LongPressGesture({ repeat: false, duration: 900 })',
  'GestureGroup(GestureMode.Exclusive',
  "Text('‹')",
  "Text('›')",
  'windowX',
  'windowY',
  'onTouch',
  'TouchType.Down',
  'onDragUpdate'
]) {
  if (!capsule.includes(contract)) throw new Error(`capsule interaction missing: ${contract}`)
}

const floatPage = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/FloatCapsule.ets'), 'utf8')
for (const contract of ['startDrag', 'endDrag', 'selectionTick', 'renderTick']) {
  if (!floatPage.includes(contract)) throw new Error(`float-page gesture missing: ${contract}`)
}
if (floatPage.includes('LongPressGesture') || floatPage.includes('PanGesture')) {
  throw new Error('float page must not own full-window gestures that can swallow capsule button taps')
}

for (const contract of ['backgroundTaskManager', 'requestSuspendDelay', 'cancelSuspendDelay', 'onAbilityBackground']) {
  if (!manager.includes(contract)) throw new Error(`background float contract missing: ${contract}`)
}

const indexPage = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8')
for (const contract of ['应用内实时预览', '开启胶囊', 'addSymbol', 'removeSymbol']) {
  if (!indexPage.includes(contract)) throw new Error(`fallback/management UI missing: ${contract}`)
}

if (process.argv.includes('--live')) {
  const response = await fetch('https://qt.gtimg.cn/q=sh600519,sz000001,sz300750', {
    headers: { Referer: 'https://gu.qq.com/', 'User-Agent': 'StockFloatHarmonyMVP/0.1 verifier' }
  })
  if (!response.ok) throw new Error(`live endpoint returned HTTP ${response.status}`)
  const text = new TextDecoder('gb18030').decode(await response.arrayBuffer())
  const liveQuotes = text.split(';').map(parseLine).filter(Boolean)
  if (liveQuotes.length !== 3 || liveQuotes.some(item => !item.name || !Number.isFinite(item.price))) {
    throw new Error(`live quote verification failed: ${JSON.stringify(liveQuotes)}`)
  }
  console.log(`live quote verification passed: ${liveQuotes.map(item => `${item.name} ${item.price}`).join(', ')}`)
}

console.log('StockFloatHarmonyMVP static verification passed')
console.log(`verified ${required.length} files, 3 permissions, 2 routes, quote parsing, TYPE_FLOAT, gestures, persistence, rotation and fallback contracts`)
