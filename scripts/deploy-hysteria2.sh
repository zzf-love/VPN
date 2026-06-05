#!/usr/bin/env bash
#
# 给现有 sing-box 增加一个 Hysteria2 (UDP) 入站。
# Hysteria2 基于 QUIC/UDP, 在丢包严重的弱网、晚高峰下通常比 TCP 的 Reality 更快更顺。
#
# 它会和 deploy.sh 装好的 VLESS-Reality 节点【共存】:
#   Reality  -> TCP 443  (主力, 抗封)
#   Hysteria2-> UDP 8443 (弱网/晚高峰备用, 客户端可自动择优)
#
# 用法 (root):  bash deploy-hysteria2.sh
#
set -euo pipefail

PORT="${PORT:-8443}"             # Hysteria2 端口 (UDP)
SNI="${SNI:-bing.com}"           # 自签证书用的伪装域名, 客户端会以 insecure 模式跳过校验
CONFIG="/etc/sing-box/config.json"

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GRN}[+]${NC} $*"; }
warn() { echo -e "${YLW}[!]${NC} $*"; }
die()  { echo -e "${RED}[x]${NC} $*" >&2; exit 1; }

[ "$(id -u)" = "0" ] || die "请用 root 运行"
command -v sing-box >/dev/null 2>&1 || die "未检测到 sing-box, 请先运行 deploy.sh"
command -v jq >/dev/null 2>&1 || { apt-get update -y >/dev/null && apt-get install -y jq qrencode openssl >/dev/null; }

# ---------- 自签证书 ----------
info "生成自签 TLS 证书..."
mkdir -p /etc/sing-box
if [ ! -f /etc/sing-box/hy2.key ]; then
  openssl ecparam -genkey -name prime256v1 -out /etc/sing-box/hy2.key
  openssl req -new -x509 -days 3650 -key /etc/sing-box/hy2.key \
    -out /etc/sing-box/hy2.crt -subj "/CN=${SNI}" >/dev/null 2>&1
fi

PASSWORD="$(openssl rand -base64 16 | tr -d '/+=' | head -c 20)"

# ---------- 构造 Hysteria2 inbound ----------
read -r -d '' HY2_INBOUND <<EOF || true
{
  "type": "hysteria2",
  "tag": "hy2-in",
  "listen": "::",
  "listen_port": ${PORT},
  "users": [ { "password": "${PASSWORD}" } ],
  "tls": {
    "enabled": true,
    "alpn": ["h3"],
    "certificate_path": "/etc/sing-box/hy2.crt",
    "key_path": "/etc/sing-box/hy2.key"
  }
}
EOF

# ---------- 合并进现有 config.json ----------
info "把 Hysteria2 入站合并进配置..."
if [ -f "$CONFIG" ]; then
  # 先删掉同名旧的 hy2-in, 再追加, 保证可重复运行
  tmp="$(mktemp)"
  jq --argjson hy2 "$HY2_INBOUND" \
     '.inbounds |= (map(select(.tag != "hy2-in")) + [$hy2])' \
     "$CONFIG" > "$tmp"
  mv "$tmp" "$CONFIG"
else
  cat > "$CONFIG" <<EOF
{
  "log": { "level": "warn", "timestamp": true },
  "inbounds": [ ${HY2_INBOUND} ],
  "outbounds": [ { "type": "direct", "tag": "direct" } ]
}
EOF
fi

sing-box check -c "$CONFIG" || die "配置自检失败"
systemctl restart sing-box
sleep 1
systemctl is-active --quiet sing-box || die "服务启动失败, 看 journalctl -u sing-box -e"

# ---------- 放行 UDP 端口 ----------
command -v ufw >/dev/null 2>&1 && ufw allow "${PORT}/udp" >/dev/null 2>&1 || true

# ---------- 记录元数据 ----------
IP="$(curl -fsSL4 https://api.ipify.org 2>/dev/null || curl -fsSL https://ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
# 更新 meta.env 里的 HY2_* 字段
touch /etc/sing-box/meta.env
sed -i '/^HY2_/d;/^SERVER_IP=/d' /etc/sing-box/meta.env
cat >> /etc/sing-box/meta.env <<EOF
SERVER_IP=${IP}
HY2_PORT=${PORT}
HY2_SNI=${SNI}
HY2_PASSWORD=${PASSWORD}
EOF

LINK="hysteria2://${PASSWORD}@${IP}:${PORT}/?insecure=1&sni=${SNI}#MyHy2-${IP}"

echo
echo "=================================================================="
echo -e "${GRN}Hysteria2 已上线 (与 Reality 共存)${NC}"
echo "=================================================================="
echo "服务器 IP : ${IP}"
echo "端口(UDP) : ${PORT}"
echo "密码      : ${PASSWORD}"
echo "SNI       : ${SNI} (自签证书, 客户端需开启 '允许不安全/insecure')"
echo "------------------------------------------------------------------"
echo "客户端导入链接:"
echo
echo "${LINK}"
echo
qrencode -t ANSIUTF8 "${LINK}" 2>/dev/null || true
echo "=================================================================="
echo "⚠️  务必去【云厂商面板的安全组/防火墙】放行 UDP ${PORT} 端口!"
echo "    (Lightsail: 实例 -> Networking -> 加一条 Custom/UDP/${PORT})"
echo "=================================================================="
