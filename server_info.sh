#!/bin/bash
set -euo pipefail

CFG=$(docker compose exec -T blog cat /opt/xray/config.json)
IP=$(curl -s -4 https://ip.sb || curl -s -4 https://ifconfig.me)
DOM=$(echo "$CFG" | jq -r '.inbounds[] | select(.tag=="inbound-443") | .streamSettings.realitySettings.serverNames[0]')
UUID=$(echo "$CFG" | jq -r '.inbounds[] | select(.tag=="inbound-443") | .settings.clients[0].id')
SID=$(echo "$CFG" | jq -r '.inbounds[] | select(.tag=="inbound-443") | .streamSettings.realitySettings.shortIds[0]')
PRK=$(echo "$CFG" | jq -r '.inbounds[] | select(.tag=="inbound-443") | .streamSettings.realitySettings.privateKey')
XPATH=$(echo "$CFG" | jq -r '.inbounds[] | select(.tag=="inbound-xhttp") | .streamSettings.xhttpSettings.path' | sed 's#^/##' )
GNAME=$(echo "$CFG" | jq -r '.inbounds[] | select(.tag=="inbound-grpc") | .streamSettings.grpcSettings.serviceName')
PBK=$(docker compose exec -T blog cat /home/PBK.txt)

# режим определяется по target - локальный адрес = self-steal
TARGET=$(echo "$CFG" | jq -r '.inbounds[] | select(.tag=="inbound-443") | .streamSettings.realitySettings.target')
case "$TARGET" in
  127.0.0.1:*) MODE=1 ;; # 1 - selfsteal режим
  *)           MODE=0 ;; # 0 - reality под чужой сайт
esac

PIN=""
if [ "$MODE" = "0" ]; then
  PIN=$(docker compose exec -T blog cat /home/fingerprint.txt | sed 's/.*=//; s/://g' | tr 'A-F' 'a-f' | tr -d '\r\n') # отпечаток серта истерии
fi

PIN_PARAM=""
if [ -n "$PIN" ]; then PIN_PARAM="&pinSHA256=${PIN}"; fi

HY2_PLAIN_ON=$(echo "$CFG" | jq '[.inbounds[] | select(.tag=="inbound-hysteria2")] | length')
OBFS_PORT=$(echo "$CFG" | jq -r '.inbounds[] | select(.tag=="inbound-hysteria2-obfs") | .port')

echo ""

echo "SELFSTEAL=$MODE"
echo "DOM=$DOM"
echo "UUID=$UUID"
echo "SID=$SID"
echo "PRK=$PRK"
echo "PBK=$PBK"
echo "XHTTP_PATH=$XPATH"
echo "GRPC_NAME=$GNAME"
echo "HY2_OBFS_PORT=$OBFS_PORT"

echo ""
echo ""
echo "YOU CAN COPY ALL LINKS BELOW AT ONCE AND PASTE THEM INTO THE SUBSCRIPTION URL FIELD IN HAPP"

echo ""

echo "vless://${UUID}@${IP}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${DOM}&fp=firefox&pbk=${PBK}&sid=${SID}&type=tcp&alpn=h2,http/1.1#${DOM}-Vision"

echo ""

echo "vless://${UUID}@${IP}:8443?encryption=none&security=reality&sni=${DOM}&fp=firefox&pbk=${PBK}&sid=${SID}&type=xhttp&path=%2F${XPATH}&mode=packet-up&alpn=h2#${DOM}-XHTTP-packet"

echo ""

echo "vless://${UUID}@${IP}:8443?encryption=none&security=reality&sni=${DOM}&fp=firefox&pbk=${PBK}&sid=${SID}&type=xhttp&path=%2F${XPATH}&mode=stream-up&alpn=h2#${DOM}-XHTTP-stream"

echo ""

echo "vless://${UUID}@${IP}:2053?encryption=none&security=reality&sni=${DOM}&fp=firefox&pbk=${PBK}&sid=${SID}&type=grpc&serviceName=${GNAME}&mode=gun#${DOM}-gRPC"

echo ""

# self-steal: валидный LE-сертификат, пин не нужен (PIN_PARAM пустой)
if [ "$HY2_PLAIN_ON" -gt 0 ]; then
  echo "hysteria2://${UUID}@${IP}:443/?sni=${DOM}&insecure=0${PIN_PARAM}#${DOM}-Hysteria2"
  echo ""
fi

echo "hysteria2://${UUID}@${IP}:${OBFS_PORT}/?sni=${DOM}&insecure=0${PIN_PARAM}&obfs=salamander&obfs-password=${SID}#${DOM}-Hysteria2-obfs"

echo ""
