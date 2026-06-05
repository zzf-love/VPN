# 客户端配置详解

部署脚本结束时会输出一段链接,形如:

```
vless://<UUID>@<服务器IP>:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=<公钥>&sid=<shortId>&type=tcp#MyReality
```

把它导入下面任一客户端即可。**这串链接等同于密码,不要发到群里或截图外传。**

---

## Windows — v2rayN

1. 到 [v2rayN releases](https://github.com/2dust/v2rayN/releases) 下载 `v2rayN-windows-64.zip`,解压运行 `v2rayN.exe`。
2. 复制部署脚本输出的 `vless://` 链接。
3. v2rayN 菜单:**服务器 → 从剪贴板导入批量 URL**。
4. 右下角托盘图标右键 → **系统代理 → 自动配置系统代理**。
5. 选中刚导入的节点(双击),浏览器测试。

---

## Android — sing-box 官方 App

1. 到 [sing-box releases](https://github.com/SagerNet/sing-box/releases) 下载 APK,或在 Google Play 搜 "sing-box"。
2. 打开 App → 右上角 **+ → 扫描二维码**(扫脚本输出的二维码),或选"从剪贴板导入"。
3. 回主界面,点底部开关连接。
4. 首次会请求"VPN 权限",允许即可。

> 备选:NekoBox(界面更丰富)。导入方式一致。

---

## iOS — Shadowrocket

> iOS 客户端需要**非中国区 Apple ID**(美区/日区等)才能下载。

1. App Store(外区)搜 **Shadowrocket**,$2.99 购买安装。
2. 复制链接 → 打开 Shadowrocket,首页顶部会提示"是否添加剪贴板中的节点",点添加。
   或点右上 **+**,类型选 VLESS 手动填。
3. 顶部开关打开,允许 VPN 权限。

免费替代:**sing-box** iOS 版(App Store 外区免费),扫码导入。

---

## macOS

- **sing-box-mac** 或 **v2rayN-mac**:导入方式同 Windows / Android,粘贴链接即可。

---

## 字段对照表(手动填写时参考)

| 客户端字段 | 值来源 |
|-----------|--------|
| 地址 / Address | 服务器 IP |
| 端口 / Port | 443(或你自定义的 PORT) |
| 用户 ID / UUID | 脚本输出的 UUID |
| 流控 / Flow | `xtls-rprx-vision` |
| 传输 / Network | `tcp` |
| 安全 / Security | `reality` |
| SNI / 伪装域名 | `www.microsoft.com`(或你设的 SNI) |
| 指纹 / Fingerprint | `chrome` |
| PublicKey / pbk | 脚本输出的公钥 |
| shortId / sid | 脚本输出的 shortId |

---

## 连不上时的排查顺序

1. **本地问题?** 切手机热点 / 换个网络再试,排除是你本地网络抖动。
2. **服务在跑吗?** SSH 上服务器执行 `systemctl status sing-box`,不是 active 就 `systemctl restart sing-box`。
3. **端口通吗?** 确认 VPS 服务商后台的"防火墙/安全组"放行了你的端口(443)。脚本只能配系统 ufw,云厂商面板的安全组要手动开。
4. **字段对不上?** 客户端的 UUID / 公钥 / shortId / SNI 必须和服务器**完全一致**,差一个字符都连不上。
5. **IP 被封了?** 前面都正常却就是不通 —— 在 VPS 后台换 IP,换完重跑 `deploy.sh`。
