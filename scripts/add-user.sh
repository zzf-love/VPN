#!/usr/bin/env bash
#
# 给 VLESS-Reality 节点新增一个用户(给家人/朋友共用)。
# 每个用户一个独立 UUID, 互不影响, 可单独吊销。
#
# 用法 (root):
#   bash add-user.sh 老婆          # 起个名字方便记
#   bash add-user.sh               # 不填名字则用随机名
#
set -euo pipefail

CONFIG="/etc/sing-box/config.json"
META="/etc/sing-box/meta.env"
NAME="${1:-user-$(openssl rand -hex 3)}"

RED='\033[0;31m'; GRN='\033[0;32m'; NC='\033[0m'
die() { echo -e "${RED}[x]${NC} $*" >&2; exit 1; }

[ "$(id -u)" = "0" ] || die "请用 root 运行"
[ -f "$CONFIG" ] || die "找不到 $CONFIG, 请先运行 deploy.sh"
[ -f "$META" ]   || die "找不到 $META, 请先运行 deploy.sh"
command -v jq >/dev/null 2>&1 || { apt-get update -y >/dev/null && apt-get install -y jq qrencode >/dev/null; }

# shellcheck disable=SC1090
source "$META"

UUID="$(sing-box generate uuid)"

# 把新用户加到 VLESS 入站 (tag = vless-in) 的 users 数组
tmp="$(mktemp)"
jq --arg uuid "$UUID" \
   '(.inbounds[] | select(.tag=="vless-in") | .users) += [{"uuid":$uuid,"flow":"xtls-rprx-vision"}]' \
   "$CONFIG" > "$tmp"
mv "$tmp" "$CONFIG"

sing-box check -c "$CONFIG" || die "配置自检失败 (新用户未生效)"
systemctl restart sing-box

LINK="vless://${UUID}@${SERVER_IP}:${REALITY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${REALITY_SNI}&fp=chrome&pbk=${REALITY_PBK}&sid=${REALITY_SID}&type=tcp#${NAME}"

echo
echo "=================================================================="
echo -e "${GRN}已新增用户: ${NAME}${NC}"
echo "UUID: ${UUID}"
echo "------------------------------------------------------------------"
echo "把下面这条链接发给 TA (注意保密, 这等于一把钥匙):"
echo
echo "${LINK}"
echo
qrencode -t ANSIUTF8 "${LINK}" 2>/dev/null || true
echo "=================================================================="
echo "查看当前所有用户数: jq '[.inbounds[]|select(.tag==\"vless-in\").users[]]|length' $CONFIG"
echo "如需吊销某用户: 编辑 $CONFIG 删掉对应 UUID, 再 systemctl restart sing-box"
echo "=================================================================="
