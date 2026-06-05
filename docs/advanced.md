# 进阶:Hysteria2 / 多用户 / 订阅与自动切换

部署好基础的 VLESS-Reality 节点(`deploy.sh`)后,可按需叠加下面三项能力。
所有脚本都在 `scripts/` 下,都在**服务器上用 root 运行**。

---

## 🚀 1. Hysteria2(弱网/晚高峰提速)

**为什么要它:** Reality 走 TCP,在丢包严重的网络(晚高峰、移动网络、跨境抖动)下
速度会被 TCP 的拥塞控制拖慢。Hysteria2 走 QUIC/UDP,**抗丢包、弱网下更快更顺**。

它和 Reality **共存**,互不冲突:

```
Reality   →  TCP 443    主力,抗封最强
Hysteria2 →  UDP 8443   备用,弱网提速
```

部署:
```bash
bash scripts/deploy-hysteria2.sh
# 自定义端口/伪装域名:
PORT=8443 SNI=bing.com bash scripts/deploy-hysteria2.sh
```

> ⚠️ **两道防火墙都要放行 UDP 端口:**
> - 脚本会自动配系统 ufw;
> - 但**云厂商面板的安全组要你手动加**一条:Lightsail → 实例 → Networking →
>   Add rule → 选 **Custom / UDP / 8443**。漏了这步会连不上。

客户端导入脚本输出的 `hysteria2://...` 链接即可。因为用的是自签证书,
客户端要打开 **"允许不安全连接 / Allow Insecure / skip-cert-verify"**(链接里已带 `insecure=1`)。

---

## 🔄 2. 多用户(给家人朋友共用)

每个人一个独立 UUID,互不影响,可单独吊销:

```bash
bash scripts/add-user.sh 老婆          # 起个名字
bash scripts/add-user.sh 老爸
bash scripts/add-user.sh               # 不写名字则随机
```

脚本会打印这个用户专属的 `vless://` 链接和二维码,**发给对应的人**即可。

管理:
```bash
# 看当前有多少用户
jq '[.inbounds[]|select(.tag=="vless-in").users[]]|length' /etc/sing-box/config.json

# 吊销某人:编辑配置删掉对应 UUID,再重启
nano /etc/sing-box/config.json
systemctl restart sing-box
```

> 一台 $5 的小机器带一家人日常使用绰绰有余,人均体验仍远好于超售机场。
> 如果人多且重度看 4K,可把 Lightsail 升一档($7/$12)。

---

## 📡 3. 订阅 + 自动切换

有了多个节点(Reality 各用户 + Hysteria2)后,逐个手动导入很麻烦。
"订阅"让客户端**一个链接同步全部节点**,并能**自动测速选最快、断线自动切换**。

### 生成订阅内容
```bash
bash scripts/gen-subscription.sh
```
它会汇总本机所有节点,输出一行 Base64 订阅内容,并保存到 `/etc/sing-box/subscribe.txt`。

### 变成可订阅的 URL(选一种)

**A. GitHub Gist —— 最简单,不用服务器(推荐)**
1. 打开 https://gist.github.com ,建议选 **Secret**(私密,别人搜不到)。
2. 新建文件,把那行 Base64 粘进去保存。
3. 点 **Raw**,复制地址栏里的 raw 链接。
4. 客户端 → 添加订阅 → 粘贴 raw 链接 → 更新。

**B. 本机临时托管**
```bash
cd /etc/sing-box && python3 -m http.server 8080   # 需放行 8080
# 订阅地址: http://你的IP:8080/subscribe.txt
```
关机即失效;长期用建议装 nginx/caddy 做静态托管。

### 开启自动切换
客户端订阅成功后,把出站模式选成 **"自动选择 / URLTest / 自动测速"**:
- **v2rayN**:节点列表上方选 `自动选择 (urltest)`。
- **sing-box / NekoBox**:策略组选 `auto / urltest`。

之后客户端会定时测速,**始终走最快的那个节点,某个挂了自动切到下一个** —— 这就是"自动切换"。

---

## 进阶:sing-box 客户端配置(手动玩法)

如果你想用 sing-box 内核自己写客户端配置实现自动切换,参考下面的 `outbounds` 片段
(把占位符换成你节点的真实值):

```jsonc
{
  "outbounds": [
    {
      "type": "selector",          // 手动切换组
      "tag": "PROXY",
      "outbounds": ["auto", "reality", "hy2"],
      "default": "auto"
    },
    {
      "type": "urltest",           // 自动测速择优 + 故障转移
      "tag": "auto",
      "outbounds": ["reality", "hy2"],
      "url": "https://www.gstatic.com/generate_204",
      "interval": "3m",
      "tolerance": 50
    },
    {
      "type": "vless",
      "tag": "reality",
      "server": "你的IP",
      "server_port": 443,
      "uuid": "你的UUID",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "www.microsoft.com",
        "utls": { "enabled": true, "fingerprint": "chrome" },
        "reality": { "enabled": true, "public_key": "你的公钥", "short_id": "你的shortId" }
      }
    },
    {
      "type": "hysteria2",
      "tag": "hy2",
      "server": "你的IP",
      "server_port": 8443,
      "password": "你的密码",
      "tls": { "enabled": true, "server_name": "bing.com", "insecure": true, "alpn": ["h3"] }
    }
  ]
}
```

---

## 元数据文件说明

`deploy.sh` / `deploy-hysteria2.sh` 会把节点参数存到 **`/etc/sing-box/meta.env`**,
供 `add-user.sh`、`gen-subscription.sh` 复用。误删了就重跑对应部署脚本即可重建。
