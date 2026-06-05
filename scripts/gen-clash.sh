#!/usr/bin/env bash
#
# 生成一份【完整的 Clash / Mihomo 配置 YAML】。
# 适用于 Clash Verge / Clash Meta / FlClash 等 Mihomo 内核客户端。
# 把输出内容放到 GitHub Gist (raw 链接), 即可当订阅链接导入, 操作和机场一样。
#
# 用法 (root):  bash gen-clash.sh
#
set -euo pipefail

CONFIG="/etc/sing-box/config.json"
META="/etc/sing-box/meta.env"
OUT="/etc/sing-box/clash.yaml"

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; NC='\033[0m'
die() { echo -e "${RED}[x]${NC} $*" >&2; exit 1; }

[ -f "$CONFIG" ] || die "找不到 $CONFIG, 请先运行 deploy.sh"
[ -f "$META" ]   || die "找不到 $META"
command -v jq >/dev/null 2>&1 || { apt-get update -y >/dev/null && apt-get install -y jq >/dev/null; }
# shellcheck disable=SC1090
source "$META"

PROXIES=""
NAMES=""

# --- Reality 节点 (取第一个 UUID 作为主节点) ---
if [ -n "${REALITY_PBK:-}" ]; then
  UUID="$(jq -r '(.inbounds[]|select(.tag=="vless-in").users[0].uuid) // empty' "$CONFIG")"
  if [ -n "$UUID" ]; then
    PROXIES+="  - name: \"Reality\"
    type: vless
    server: ${SERVER_IP}
    port: ${REALITY_PORT}
    uuid: ${UUID}
    network: tcp
    udp: true
    tls: true
    flow: xtls-rprx-vision
    servername: ${REALITY_SNI}
    client-fingerprint: chrome
    reality-opts:
      public-key: ${REALITY_PBK}
      short-id: ${REALITY_SID}
"
    NAMES+="      - Reality
"
  fi
fi

# --- Hysteria2 节点 (若部署过) ---
if [ -n "${HY2_PASSWORD:-}" ]; then
  PROXIES+="  - name: \"Hysteria2\"
    type: hysteria2
    server: ${SERVER_IP}
    port: ${HY2_PORT}
    password: ${HY2_PASSWORD}
    sni: ${HY2_SNI}
    skip-cert-verify: true
    alpn:
      - h3
"
  NAMES+="      - Hysteria2
"
fi

[ -n "$PROXIES" ] || die "没找到任何节点"

cat > "$OUT" <<EOF
# Clash / Mihomo 配置 - 由 gen-clash.sh 自动生成
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
ipv6: false

dns:
  enable: true
  enhanced-mode: fake-ip
  nameserver:
    - 223.5.5.5
    - 8.8.8.8

proxies:
${PROXIES}
proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
${NAMES}      - DIRECT
  - name: "自动选择"
    type: url-test
    url: https://www.gstatic.com/generate_204
    interval: 180
    tolerance: 50
    proxies:
${NAMES}
rules:
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
EOF

echo
echo "=================================================================="
echo -e "${GRN}Clash 配置已生成: ${OUT}${NC}"
echo "=================================================================="
echo "把下面【整段 YAML】复制走:"
echo "------------------------------------------------------------------"
cat "$OUT"
echo "------------------------------------------------------------------"
echo
echo -e "${YLW}两种用法, 任选其一:${NC}"
echo
echo "【A. 当订阅链接用 (推荐, 和机场操作一样)】"
echo "  1. 打开 https://gist.github.com (建议 Secret 私密)"
echo "  2. 文件名填 clash.yaml, 把上面整段粘进去, 保存"
echo "  3. 点 Raw, 复制地址栏链接"
echo "  4. Clash Verge -> 订阅 -> 粘进'订阅文件链接'框 -> 导入"
echo
echo "【B. 直接存成本地文件】"
echo "  把上面 YAML 存成 clash.yaml, Clash Verge -> 订阅 -> 新建 -> 本地 -> 导入"
echo "=================================================================="
echo "导入后: 代理页选中节点 -> 首页打开 Tun模式或系统代理 -> 测试"
echo "=================================================================="
