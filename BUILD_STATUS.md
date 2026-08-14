# Build status

最后检查：2026-08-14

- 静态工程校验：通过
- Hvigor 6.24.4 类型检查：通过
- 本地固定行情解析：通过
- 腾讯真实行情接口：通过（贵州茅台、平安银行、宁德时代）
- ArkTS/HAP 编译：通过（HarmonyOS 6.1.1 / API 24 SDK，最低兼容 API 12）
- MVP 增强：本地行情缓存（60 秒写入节流）、今开/最高/最低、交易所时区行情时间、自选一键置顶已通过 ArkTS 类型检查和 HAP 打包
- HAP 打包：通过。仓库不提交本机签名配置，命令行验证生成 `entry-default-unsigned.hap`；真机部署前需在 DevEco 配置开发者签名与 `SYSTEM_FLOAT_WINDOW` ACL
- 悬浮球真机拖拽卡顿抖动：已修复。根因是系统拖拽 `startMoving` 要求传"窗口内像素偏移"且必须在 `onTouch` 的 `TouchType.Down` 回调中同步调用，旧实现传了屏幕全局坐标并在手势启动后才调用，导致起跳并频繁落入 16ms 节流的 `moveWindowTo` IPC 兜底。修复：`QuoteCapsule.ets` 在两处拖拽把手增加 `onTouch`（Down 传 `windowX/windowY` 启动系统拖拽，Up/Cancel 结束），`FloatWindowManager.ets` 将偏移换算为窗口内 px 并夹取到窗口尺寸、`dragActive` 防重入、系统拖拽不可用时自动回退手动拖拽
- 拖拽修复验证：静态工程校验通过、Hvigor 类型检查与 `CompileArkTS`/`PackageHap`/`SignHap` 通过（仅遗留既有的 `@Prop quote` 可选参数 WARN），修复版 HAP 已通过 hdc 安装并启动于真机 `2NP0224A08036758`
- 主界面沉浸式通栏布局：已实现（主窗口全屏布局 + `expandSafeArea`，安全区高度动态适配），ArkTS 编译与 HAP 打包校验通过
- 真机安装与运行：通过（设备 `2NP0224A08036758`，`hdc install` 成功，应用前台运行并持续拉取实时行情，无权限拒绝/崩溃）；浮窗 `TYPE_FLOAT` 的 8 项人工验收仍按 `README.md` 执行

复现已完成的检查：

```bash
node tools/verify.mjs --live
```

构建命令已完成 `CompileArkTS`、`PackageHap` 和 `PackingCheck`，结果为 `BUILD SUCCESSFUL`。下一道权威门禁是在 DevEco Studio 配置自动签名和 `SYSTEM_FLOAT_WINDOW` 调试 ACL，然后在真机完成 `README.md` 的 8 项 MVP 验收。
