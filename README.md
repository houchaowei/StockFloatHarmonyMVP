# StockFloat HarmonyOS MVP

基于 MIT 开源项目 `StockFloatMVP` 思路实现的 HarmonyOS NEXT / ArkTS A 股全局悬浮胶囊原型。

## 已实现

- `WindowType.TYPE_FLOAT` 全局悬浮窗口，主应用退到后台后仍可显示
- 186 × 54vp 收起胶囊和 304 × 264vp 展开卡片
- 拖动、边界限制、松手自动吸附左右边缘、位置持久化
- 单击中间行情区展开；展开后可收起、刷新、切换股票和关闭
- 长按胶囊 900ms 关闭
- 腾讯公开行情接口，`ArrayBuffer + GB18030` 解码（API 12 `decodeToString`）
- 股票名称、现价、涨跌额、涨跌幅及行情时间解析
- 默认自选：贵州茅台 `600519`、平安银行 `000001`、宁德时代 `300750`
- 6 位股票代码在线验证和添加、最多 20 只、删除及本地保存
- 收起时每 4 秒轮播；交易中 5 秒刷新，盘前/午休/收盘/周末自动降频
- 请求失败指数退避并保留上次有效行情
- 最近一次有效行情会缓存到本地，离线重启时先展示缓存再尝试更新
- 展开卡片展示今开、最高、最低，行情时间固定按交易所时区显示
- 自选股支持一键置顶，排序随自选列表持久化
- 全局权限不可用时仍可在主页面使用完整胶囊预览

## 运行

建议环境：DevEco Studio 6.1.1 或更新版本，HarmonyOS NEXT API 12+，真机优先。本项目以 API 24 编译、最低兼容 API 12。

1. 用 DevEco Studio 打开本目录。
2. 等待 Sync 完成，在 **File → Project Structure → Signing Configs** 配置自动签名或调试签名。
3. 按下面“全局悬浮权限”配置调试 ACL。
4. 连接 HarmonyOS NEXT 手机，运行 `entry`。
5. 首屏行情出现后点击“开启胶囊”，再把应用退到后台验证全局显示。

项目没有提交某台电脑特有的签名文件或 SDK 路径。第一次打开时 DevEco 可能会更新构建配置，这是正常的。

## 全局悬浮权限

全局胶囊依赖：

```json5
{ "name": "ohos.permission.SYSTEM_FLOAT_WINDOW" }
```

该权限是 `system_basic` 受限权限，普通应用仅在 `module.json5` 声明还不够。开发调试时需要把它加入调试 Profile 的 ACL。官方提供两种调试方式，均不能直接用于应用市场发布；正式发布需要申请相应发布证书/权限资质。

DevEco / SDK 版本的具体界面可能不同。通用流程是：

1. 找到当前 HarmonyOS SDK 使用的调试 `HarmonyAppProvision` 模板或 Profile。
2. 在 `acls.allowed-acls` 中加入 `ohos.permission.SYSTEM_FLOAT_WINDOW`。
3. 重新签名并安装应用。

示意：

```json5
{
  "acls": {
    "allowed-acls": [
      "ohos.permission.SYSTEM_FLOAT_WINDOW"
    ]
  }
}
```

如果没有 ACL，应用不会崩溃：首页会显示“缺少 SYSTEM_FLOAT_WINDOW ACL”，此时可以先用“应用内实时预览”验收行情和交互。

## MVP 验收

1. 启动后 10 秒内能看到三只默认自选的名称和价格。
2. 输入 `600036` 并添加，在线验证后出现“招商银行”。
3. 收起的胶囊每 4 秒切换一次；展开后停止轮播。
4. 开启全局胶囊后退到桌面或其他应用，胶囊仍显示。
5. 拖动胶囊，松手后吸附左右边缘；重启应用后位置被恢复。
6. 点击行情区展开，测试上一只、下一只、刷新、收起和关闭。
7. 断网后刷新，界面保留最后价格并显示失败状态；恢复网络后可以手动刷新。
8. 长按胶囊约 900ms，窗口关闭。
9. 展开胶囊可看到今开、最高、最低，时间与 A 股交易所时区一致。
10. 将任意非首位自选股置顶并重启应用，顺序应保持；断网重启时先显示本地缓存行情。

## 自动验证

无需 DevEco 的结构与解析测试：

```bash
node tools/verify.mjs
```

连真实腾讯接口一起验证：

```bash
node tools/verify.mjs --live
```

设备构建可在 DevEco Terminal 中执行：

```bash
hvigorw assembleHap
```

如果终端找不到 `hvigorw`，直接使用 DevEco 的 **Build → Build Hap(s)/APP(s) → Build Hap(s)**。本仓库保留的是可由 IDE 同步的 Hvigor 项目文件，不绑定本地 wrapper 缓存。

构建成功后，未签名 HAP 位于 `entry/build/default/outputs/default/entry-default-unsigned.hap`，它不能直接安装。请由 DevEco 使用你的开发者证书自动签名后部署到手机。

## 代码结构

```text
entry/src/main/ets/
├── components/QuoteCapsule.ets       胶囊和展开卡片 UI
├── entryability/EntryAbility.ets     应用入口和生命周期
├── model/FloatWindowManager.ets      TYPE_FLOAT、拖动、吸边、持久化
├── model/QuoteStore.ets              自选、缓存、刷新、轮播、失败退避
├── model/StockModels.ets             股票模型和交易阶段
├── model/TencentQuoteProvider.ets    行情请求、GB18030 解码、解析
├── pages/FloatCapsule.ets             全局悬浮窗口页面
└── pages/Index.ets                    启动、管理和降级预览页面
```

## 数据与发布限制

腾讯公开行情接口只用于个人 MVP 验证。它没有向本项目提供商业展示或再分发授权，可能限流、变更或停止服务。公开发布、售卖或上架前必须替换为取得书面授权的行情供应商，并复核交易日历、后台策略、隐私说明和应用市场悬浮窗审核要求。

本应用不包含登录、交易或券商连接，界面信息不构成投资建议。详情见 `THIRD_PARTY_NOTICES.md`。

## 与原版的关系

参考实现：`/Users/houchaowei/Documents/github/StockFloatMVP`。本项目保留了其数据源隔离、交易阶段刷新、失败保留旧值、轮播和自选持久化设计，并把 macOS 圆形窗口重新实现为 HarmonyOS 手机胶囊式全局窗口。
