# SYSTEM_FLOAT_WINDOW 调试 ACL 速查

`ohos.permission.SYSTEM_FLOAT_WINDOW` 不是运行时弹窗授权，而是受限权限。调用 `window.createWindow({ windowType: WindowType.TYPE_FLOAT })` 返回 `201`，通常表示签名 Profile 没有把权限列入 ACL。

需要同时满足：

1. `entry/src/main/module.json5` 的 `requestPermissions` 已声明权限（本项目已完成）。
2. 调试签名 Profile 的 `acls.allowed-acls` 包含该权限。
3. 修改签名后卸载旧包，再重新签名安装，避免设备继续使用旧授权信息。

调试 Profile 关键片段：

```json5
"acls": {
  "allowed-acls": [
    "ohos.permission.SYSTEM_FLOAT_WINDOW"
  ]
}
```

不要把 SDK 内的共享模板修改当作团队长期方案；更稳妥的是生成并保存项目自己的调试签名配置。调试 ACL 不能证明应用市场会批准该权限。

