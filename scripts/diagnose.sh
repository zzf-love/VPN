#!/usr/bin/env bash
#
# 服务器端自检: 在服务器本机直接连自己的 Reality 节点并尝试上网。
# 这样可以【排除 GFW / 跨境网络】, 单独判断 Reality 配置本身对不对。
#
#   结果 OK  -> 配置没问题, 问题在 中国->新加坡 的网络链路(换端口/换IP/加Hysteria2)
#   结果 失败 -> 配置/握手目标/时间 有问题, 按提示修
#
# 用法 (root):  bash diagnose.sh
#
set -euo pipefail
META="/etc/sing-box/meta.env"
CONFIG="/etc/sing-box/config.json"
SB="/usr/local/bin/sing-box"

GRN='\033[0;32m'; RED='\033[0;31m'; YLW='\033[1;33m'; NC='\033[0m'
[ -f "$META" ] && . "$META" || { echo "找不到 $META, 先跑 deploy.sh"; exit 1; }

echo "=================== 1. 系统时间(Reality 对时间敏感) ==================="
date
timedatectl 2>/dev/null | grep -Ei 'synchronized|NTP' || true
echo
echo "=================== 2. sing-box 服务状态 ==================="
systemctl is-active sing-box && echo "服务: 运行中" || echo -e "${RED}服务未运行!${NC}"
echo
echo "=================== 3. 服务器能否到达握手目标 ${REALITY_SNI} ==================="
curl -sI --max-time 6 "https://${REALITY_SNI}" -o /dev/null -w "可达, 状态码:%{http_code}\n" || echo -e "${RED}到达 ${REALITY_SNI} 失败 -> 这就是 Reality 失败的原因!${NC}"
echo
echo "=================== 4. 本机回环自连 Reality 隧道测试 ==================="
UUID="$(command -v jq >/dev/null && jq -r '(.inbounds[]|select(.tag=="vless-in").users[0].uuid)' "$CONFIG" 2>/dev/null || true)"
[ -z "$UUID" ] && UUID="$(grep -o '"uuid"[^,]*' "$CONFIG" | head -1 | grep -oE '[0-9a-f-]{36}')"
cat > /tmp/_diag_cli.json <<EOF
{ "log":{"level":"error"},
  "inbounds":[{"type":"mixed","listen":"127.0.0.1","listen_port":2080}],
  "outbounds":[{"type":"vless","server":"127.0.0.1","server_port":${REALITY_PORT},
    "uuid":"${UUID}","flow":"xtls-rprx-vision",
    "tls":{"enabled":true,"server_name":"${REALITY_SNI}",
      "utls":{"enabled":true,"fingerprint":"chrome"},
      "reality":{"enabled":true,"public_key":"${REALITY_PBK}","short_id":"${REALITY_SID}"}}}] }
EOF
"$SB" run -c /tmp/_diag_cli.json >/tmp/_diag.log 2>&1 &
DPID=$!
sleep 3
CODE="$(curl -s --socks5-hostname 127.0.0.1:2080 -o /dev/null -w '%{http_code}' --max-time 12 https://www.gstatic.com/generate_204 2>/dev/null || echo 000)"
OUTIP="$(curl -s --socks5-hostname 127.0.0.1:2080 --max-time 12 https://api.ipify.org 2>/dev/null || echo '-')"
kill $DPID 2>/dev/null
echo "隧道访问 gstatic 状态码: ${CODE}"
echo "经隧道查到的出口IP: ${OUTIP}"
grep -i 'reality' /tmp/_diag.log | tail -2 || true
echo
echo "=================== 结论 ==================="
if [ "$CODE" = "204" ]; then
  echo -e "${GRN}✅ Reality 配置完全正常! 服务器本机能跑通隧道。${NC}"
  echo "   => 问题在 中国->新加坡 的网络链路被干扰。建议:"
  echo "      a) 换个不那么敏感的端口(如 8443/2053/2083)重部署"
  echo "      b) 加 Hysteria2(UDP)做备用: bash deploy-hysteria2.sh"
  echo "      c) 在 Lightsail 后台换一个 IP 再试"
else
  echo -e "${RED}❌ 服务器本机自连都失败(状态码 ${CODE})。是配置/握手目标/时间问题。${NC}"
  echo "   最常见修复: 换一个更可靠的握手目标域名重部署, 例如:"
  echo "      SNI=www.apple.com  bash deploy.sh"
  echo "   或同时怀疑系统时间不同步(看上面第1节是否 synchronized)。"
fi
rm -f /tmp/_diag_cli.json