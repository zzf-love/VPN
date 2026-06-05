#!/usr/bin/env bash
#
# 一键部署 VLESS-Reality 抗审查节点 (基于 sing-box)
# 适用系统: Debian 10+ / Ubuntu 20.04+ (amd64 / arm64)
#
# 用法:  在你的海外 VPS 上, 用 root 执行:
#   bash deploy.sh
#
# 脚本会自动:
#   1. 安装最新版 sing-box
#   2. 生成 UUID / Reality 密钥对 / short-id
#   3. 写好配置并以 systemd 常驻运行
#   4. 放行防火墙端口
#   5. 打印客户端导入链接 + 二维码
#
set -euo pipefail

# ---------- 可调参数 ----------
PORT="${PORT:-443}"                 # 节点端口, 默认 443
SNI="${SNI:-www.microsoft.com}"     # 伪装域名(偷证书的目标网站), 需是支持 TLS1.3 的大站
# ------------------------------

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GRN}[+]${NC} $*"; }
warn() { echo -e "${YLW}[!]${NC} $*"; }
die()  { echo -e "${RED}[x]${NC} $*" >&2; exit 1; }

[ "$(id -u)" = "0" ] || die "请用 root 运行:  sudo bash deploy.sh"

# ---------- 检测架构 ----------
case "$(uname -m)" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) die "暂不支持的 CPU 架构: $(uname -m)" ;;
esac

info "安装依赖..."
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y >/dev/null
  apt-get install -y curl tar jq qrencode >/dev/null
else
  die "此脚本目前只适配 Debian/Ubuntu 系。其它系统请看 docs/ 里的手动步骤。"
fi

# ---------- 下载 sing-box ----------
info "获取最新版 sing-box..."
VER="$(curl -fsSL https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r '.tag_name' | sed 's/^v//')"
[ -n "$VER" ] && [ "$VER" != "null" ] || die "无法获取 sing-box 版本号, 检查服务器网络/出口是否能访问 GitHub"

TARBALL="sing-box-${VER}-linux-${ARCH}.tar.gz"
URL="https://github.com/SagerNet/sing-box/releases/download/v${VER}/${TARBALL}"
info "下载 ${TARBALL} ..."
tmp="$(mktemp -d)"
curl -fSL "$URL" -o "$tmp/$TARBALL" || die "下载失败: $URL"
tar -xzf "$tmp/$TARBALL" -C "$tmp"
install -m 755 "$tmp/sing-box-${VER}-linux-${ARCH}/sing-box" /usr/local/bin/sing-box
rm -rf "$tmp"
info "sing-box 已安装: $(sing-box version | head -n1)"

# ---------- 生成密钥 ----------
info "生成 UUID 与 Reality 密钥..."
UUID="$(sing-box generate uuid)"
KEYS="$(sing-box generate reality-keypair)"
PRIVATE_KEY="$(echo "$KEYS" | awk '/PrivateKey/ {print $2}')"
PUBLIC_KEY="$(echo "$KEYS"  | awk '/PublicKey/  {print $2}')"
SHORT_ID="$(openssl rand -hex 8)"

# ---------- 写配置 ----------
info "写入配置 /etc/sing-box/config.json ..."
mkdir -p /etc/sing-box
cat > /etc/sing-box/config.json <<EOF
{
  "log": { "level": "warn", "timestamp": true },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": ${PORT},
      "users": [
        { "uuid": "${UUID}", "flow": "xtls-rprx-vision" }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${SNI}",
        "reality": {
          "enabled": true,
          "handshake": { "server": "${SNI}", "server_port": 443 },
          "private_key": "${PRIVATE_KEY}",
          "short_id": ["${SHORT_ID}"]
        }
      }
    }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" }
  ]
}
EOF

# 校验配置
sing-box check -c /etc/sing-box/config.json || die "配置自检失败, 请把上面的报错发我"

# ---------- systemd 服务 ----------
info "配置开机自启动..."
cat > /etc/systemd/system/sing-box.service <<'EOF'
[Unit]
Description=sing-box service
After=network.target nss-lookup.target

[Service]
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sing-box >/dev/null 2>&1
systemctl restart sing-box
sleep 1
systemctl is-active --quiet sing-box || die "服务启动失败, 运行 journalctl -u sing-box -e 查看日志"

# ---------- 放行防火墙 ----------
if command -v ufw >/dev/null 2>&1; then
  ufw allow "${PORT}" >/dev/null 2>&1 || true
fi

# ---------- 取出口 IP ----------
IP="$(curl -fsSL4 https://api.ipify.org 2>/dev/null || curl -fsSL https://ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"

# ---------- 生成客户端链接 ----------
LINK="vless://${UUID}@${IP}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp#MyReality-${IP}"

echo
echo "=================================================================="
echo -e "${GRN}部署成功! 节点已运行。${NC}"
echo "=================================================================="
echo "服务器 IP : ${IP}"
echo "端口      : ${PORT}"
echo "UUID      : ${UUID}"
echo "公钥(pbk) : ${PUBLIC_KEY}"
echo "shortId   : ${SHORT_ID}"
echo "SNI       : ${SNI}"
echo "------------------------------------------------------------------"
echo "客户端导入链接 (复制到 v2rayN / sing-box / Shadowrocket 即可):"
echo
echo "${LINK}"
echo
echo "------------------------------------------------------------------"
echo "扫码导入 (手机客户端):"
qrencode -t ANSIUTF8 "${LINK}" 2>/dev/null || warn "未能生成二维码, 直接用上面的链接"
echo "=================================================================="
echo "常用命令:"
echo "  查看状态:  systemctl status sing-box"
echo "  查看日志:  journalctl -u sing-box -e"
echo "  重启:      systemctl restart sing-box"
echo "=================================================================="
