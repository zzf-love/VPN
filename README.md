# 自建抗审查节点工具包 (VLESS-Reality)

一套面向新手的"自己的 VPN"部署工具包。用一台海外 VPS + 一键脚本,
搭出一个**比第三方机场更快、更稳、更难被封**的私人节点。

> 为什么不用传统 VPN(WireGuard/OpenVPN)?
> 它们的流量特征太明显,在有网络审查的环境里容易被识别和阻断 —— 这正是
> "总断连"的根源。本工具包用 **VLESS + Reality** 协议,把流量伪装成访问
> 微软等大网站的正常 HTTPS,审查系统**无法区分真假**,因此极稳。

---

## 整体流程(15 分钟搞定)

```
① 买一台海外 VPS  →  ② 跑一键脚本  →  ③ 手机/电脑装客户端,扫码导入  →  ④ 上网
```

---

## ① 买服务器(唯一需要花钱的一步)

挑选要点:
- **地区**:选审查范围之外、且离你近的机房 —— 日本、新加坡、香港、美西。
- **配置**:翻墙用 1 核 1G 足够,关键看**带宽**和 **IP 质量**。
- **商家参考**(按 IP 抗封口碑):搬瓦工(Bandwagon)、Vultr、亚马逊 Lightsail、DigitalOcean。
- **系统**:安装时选 **Debian 12** 或 **Ubuntu 22.04**(本脚本只适配 Debian/Ubuntu 系)。

> 预算:大多 $5/月 上下。先买月付,不满意随时换。

买完你会拿到三样东西:**服务器 IP、root 密码(或 SSH key)、SSH 端口(通常 22)**。

---

## ② 一键部署

### 2.1 连上服务器

- **Windows**:用自带的 PowerShell 或下载 [Termius](https://termius.com/) / PuTTY。
- **Mac/Linux**:直接开终端。

```bash
ssh root@你的服务器IP
# 首次会问 yes/no,输入 yes,再粘贴密码(粘贴时屏幕不显示,正常)
```

### 2.2 运行脚本

把本仓库的 `scripts/deploy.sh` 传到服务器并执行,任选一种方式:

**方式 A — 直接从仓库拉取(推荐)**
```bash
# 把下面 URL 换成你 push 后的 raw 地址
curl -fsSL https://raw.githubusercontent.com/zzf-love/vpn/claude/optimistic-cannon-tGEft/scripts/deploy.sh -o deploy.sh
bash deploy.sh
```

**方式 B — 手动粘贴**
```bash
nano deploy.sh        # 粘贴 scripts/deploy.sh 全部内容,Ctrl+O 保存, Ctrl+X 退出
bash deploy.sh
```

可选自定义(不填用默认值):
```bash
PORT=443 SNI=www.microsoft.com bash deploy.sh
```

脚本跑完会打印一段 `vless://...` 链接和一个二维码 —— **这就是你的钥匙,妥善保存,别外传**。

---

## ③ 装客户端,导入节点

| 平台 | 推荐客户端 | 导入方式 |
|------|-----------|---------|
| Windows | [v2rayN](https://github.com/2dust/v2rayN/releases) | 复制链接 → 从剪贴板导入 |
| Android | [sing-box](https://github.com/SagerNet/sing-box/releases) / NekoBox | 扫二维码 或 粘贴链接 |
| iOS | Shadowrocket / sing-box(需外区 App Store 账号) | 扫二维码 |
| macOS | sing-box / v2rayN-mac | 粘贴链接 |

导入后选中节点 → 开启 → 浏览器测试能否打开被屏蔽的网站。详见 [`docs/client.md`](docs/client.md)。

---

## ④ 日常维护

在服务器上:
```bash
systemctl status sing-box     # 看运行状态
journalctl -u sing-box -e     # 看日志(排错)
systemctl restart sing-box    # 重启
```

**万一某天连不上了?** 大概率是服务器 IP 被封。处理顺序:
1. 先确认不是本地网络问题(切手机热点试试)。
2. 在 VPS 后台**换一个 IP**(多数商家支持,几块钱或免费),换完重跑脚本即可。
   —— 这就是自建相比第三方机场最大的优势:**主动权在你手里**。

---

## 常见问题

**Q:这违法吗 / 安全吗?**
A:本工具用于个人访问信息、保护公共 WiFi 下的流量隐私。请遵守你所在地的法律法规,
节点仅供自己使用,不要公开分享或转售。

**Q:速度还是不理想?**
A:① 换更近/更优的机房;② 试试 Hysteria2 协议(基于 UDP,弱网下更快,见
`docs/` 后续补充);③ 检查 VPS 带宽是否被限速。

**Q:能给家人朋友一起用吗?**
A:可以,在 `config.json` 的 `users` 数组里多加几个 UUID 即可,人均体验仍远好于超售机场。

---

## 进阶玩法(可选)

部署好基础节点后,按需叠加,详见 [`docs/advanced.md`](docs/advanced.md):

- 🚀 **Hysteria2 提速**:`bash scripts/deploy-hysteria2.sh` —— 加一个 UDP 节点,
  晚高峰/弱网比 Reality 更顺,与 Reality 共存。
- 🔄 **多用户共用**:`bash scripts/add-user.sh 老婆` —— 给家人各发一把独立钥匙。
- 📡 **订阅 + 自动切换**:`bash scripts/gen-subscription.sh` —— 一个链接同步全部节点,
  客户端自动测速选最快、断线自动切换。

## 目录结构

```
.
├── README.md                  # 本文件,总指南
├── scripts/
│   ├── deploy.sh              # ① 一键部署 VLESS-Reality(主力)
│   ├── deploy-hysteria2.sh   # ② 叠加 Hysteria2(弱网提速)
│   ├── add-user.sh           # ③ 新增用户(多人共用)
│   └── gen-subscription.sh   # ④ 生成订阅(自动切换)
└── docs/
    ├── client.md             # 各平台客户端详细配置
    └── advanced.md           # 进阶:Hysteria2 / 多用户 / 订阅
```
