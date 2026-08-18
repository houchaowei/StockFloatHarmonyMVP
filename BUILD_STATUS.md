# Build status

最后检查：2026-08-18

## v0.3.1 已完成

- 应用内页面、输入框、底部导航、系统栏和悬浮胶囊共用黑色/白色背景设置，切换后立即生效并持久化。
- 底部导航改为四项等宽独立布局和统一 SVG 图标，规避真机字体字形基线造成的错位。
- 暗色输入框统一提高 placeholder 对比度并调整输入字号。
- 真机返回短时任务校验错误 `9900001/9900002` 时停止重复申请、标记后台暂停并显示可理解的系统限制状态。

- 仓库签名配置保持可移植的空配置，不包含本机路径、证书或口令；本机通过 Git 忽略的签名文件安全注入。
- 腾讯主行情源与新浪备用行情源均有独立 GB18030 解析器；主源部分缺失时仅请求缺失股票。
- 行情按股票显示实时、延迟、过期、缓存、收盘和后台暂停状态；旧行情不再被全局“刚更新”状态掩盖。
- 交易时段收到的行情日期不是当日时，自动识别交易日休市并降至 15 分钟刷新。
- 到价和涨跌幅提醒支持单次、30 分钟冷却重复、每日一次；使用系统普通通知并如实展示后台限制。
- 胶囊支持三档尺寸、三档透明度、四种展示指标、固定股票、轮播/刷新间隔、涨跌颜色和启动恢复。
- 自选支持名称/拼音/代码过滤、长按拖动排序、涨跌排序和 6 秒删除撤销。
- 持仓成本与数量仅保存本机；胶囊展示累计/今日盈亏；隐私模式遮挡名称、代码、价格与盈亏。
- 每只股票保留当日最近 48 个不同时间点的本地行情采样，并在展开卡片绘制迷你走势。
- 可选常驻行情通知作为悬浮权限不可用时的降级方案。
- 悬浮窗监听显示区域变化，横竖屏/分屏/折叠形态变化后重新调整尺寸、位置和边界。
- 胶囊左右操作热区扩大到 44vp，补充无障碍说明；长按不再执行破坏性的关闭操作。
- 主应用改为“自选 / 提醒 / 持仓 / 设置”四个底部入口；提醒与持仓均有独立新建/编辑二级页面和系统返回处理。
- 提醒页支持全部/启用/停用筛选，持仓页提供本地汇总；删除仍有关联数据的自选股时可选择保留或同时清理提醒与持仓。

## 已通过的门禁

- `node tools/verify.mjs`：通过。覆盖安全签名、双源解析、行情新鲜度、提醒阈值、持久化、底部导航与二级页面 UI 合同。
- `node tools/verify.mjs --live`：通过。2026-08-18 已验证腾讯主源和新浪备用源均可返回并解析贵州茅台、平安银行、宁德时代真实行情。
- Hvigor 6.24.4 类型检查：通过。
- `CompileArkTS`、`PackageHap`、`PackingCheck`：通过，无 ArkTS 警告。
- v0.3.1 Release 已签名 HAP：`entry/build/default/outputs/default/entry-default-signed.hap`。
- Release SHA-256：`d050ee0ea5167776535fe239ebcd47b9c502208b68cc87245100bf9225b4ffab`。
- 本机 Hvigor 已执行 `SignHap`，无 `No signingConfig found` 提示；证书路径和口令仅存在于 Git 忽略的 `.signing/local-signing.json`。

## 真机门禁

2026-08-17 已在连接的 HarmonyOS 真机完成签名包安装及 `EntryAbility` 启动，应用进程正常运行；当时安装版本为 `0.3.0`，调试 Profile 已包含 `SYSTEM_FLOAT_WINDOW` ACL。v0.3.1 已完成同配置 Release 签名构建，待安装包发布后复测统一主题与底栏布局。

仓库不提交本机签名配置。当前开发机使用 `.signing/local-signing.json` 进行安全的本地签名；换电脑后仍需在 DevEco Studio 配置开发者签名与 `SYSTEM_FLOAT_WINDOW` 调试 ACL，再按 `README.md` 的 12 项功能验收执行。

## 可复现命令

```bash
node tools/verify.mjs
node tools/verify.mjs --live
```

DevEco Studio 内可直接执行 `Build Hap(s)`；或使用 IDE 自带 Hvigor：

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
NODE_HOME=/Applications/DevEco-Studio.app/Contents/tools/node \
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/bin/hvigor.js assembleHap --no-daemon
```
