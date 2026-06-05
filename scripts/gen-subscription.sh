#!/usr/bin/env bash
#
# 生成「订阅内容」: 把本机所有节点(Reality 各用户 + Hysteria2)汇总成一份
# base64 订阅, 客户端订阅后可一键同步全部节点, 并自动测速择优(自动切换)。
#
# 用法 (root):  bash gen-subscription.sh
#
set -euo pipefail

CONFIG="/etc/sing-box/config.json"
META="/etc/sing-box/meta.env"
OUT="/etc/sing-box/subscribe.txt"

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; NC='\033[0m'
die() { echo -e "${RED}[x]${NC} $*" >&2; exit 1; }

[ -f "$CONFIG" ] || die "找不到 $CONFIG, 请先运行 deploy.sh"
[ -f "$META" ]   || die "找不到 $META"
command -v jq >/dev/null 2>&1 || { apt-get update -y >/dev/null && apt-get install -y jq >/dev/null; }
# shellcheck disable=SC1090
source "$META"

links=""

# --- Reality: 每个 UUID 生成一条 ---
if [ -n "${REALITY_PBK:-}" ]; then
  while IFS= read -r uuid; do
    [ -n "$uuid" ] || continue
    links+="vless://${uuid}@${SERVER_IP}:${REALITY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${REALITY_SNI}&fp=chrome&pbk=${REALITY_PBK}&sid=${REALITY_SID}&type=tcp#Reality-${SERVER_IP}"$'\n'
  done < <(jq -r '(.inbounds[]|select(.tag=="vless-in").users[].uuid) // empty' "$CONFIG")
fi

# --- Hysteria2 ---
if [ -n "${HY2_PASSWORD:-}" ]; then
  links+="hysteria2://${HY2_PASSWORD}@${SERVER_IP}:${HY2_PORT}/?insecure=1&sni=${HY2_SNI}#Hy2-${SERVER_IP}"$'\n'
fi

[ -n "$links" ] || die "没找到任何节点"

# base64 编码(订阅标准格式)
printf '%s' "$links" | base64 -w0 > "$OUT" 2>/dev/null || printf '%s' "$links" | base64 | tr -d '\n' > "$OUT"

echo
echo "=================================================================="
echo -e "${GRN}订阅内容已生成: ${OUT}${NC}"
echo "=================================================================="
echo "包含的节点 (明文预览):"
echo "------------------------------------------------------------------"
printf '%s' "$links"
echo "------------------------------------------------------------------"
echo
echo "Base64 订阅内容 (一整行, 复制它去托管):"
echo
cat "$OUT"; echo
echo
echo "=================================================================="
echo -e "${YLW}怎么变成可订阅的 URL? 两种办法:${NC}"
echo
echo "【最简单·无需服务器】GitHub Gist:"
echo "  1. 打开 https://gist.github.com (建议设为 Secret 私密)"
echo "  2. 新建文件, 把上面那行 Base64 粘进去, 保存"
echo "  3. 点 Raw, 复制浏览器地址栏的 raw 链接"
echo "  4. 客户端里 '添加订阅' 粘贴该 raw 链接 -> 更新"
echo
echo "【进阶·用本机托管】临时起一个静态服务:"
echo "  cd /etc/sing-box && python3 -m http.server 8080"
echo "  订阅地址即: http://${SERVER_IP}:8080/subscribe.txt"
echo "  (需在防火墙放行 8080; 关机即失效, 长期用请配 nginx/caddy)"
echo "=================================================================="
echo "客户端订阅后, 选 '自动选择/URLTest' 模式, 即可自动用最快的节点并断线自动切换。"
echo "=================================================================="
