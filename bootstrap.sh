#!/bin/bash
K=${XRAY_K:-$(/opt/xray/xray x25519 | awk -F ' ' '{print $NF}')}
export PRK=${PRK:-$(echo "$K" | sed -n 1p)}
export PBK=${PBK:-$(echo "$K" | sed -n 2p)}
export UUID=${UUID:-$(/opt/xray/xray uuid)}
export SID=${SID:-$(openssl rand -hex 8)}
export XHTTP_PATH=${XHTTP_PATH:-$(openssl rand -hex 8)}
export GRPC_NAME=${GRPC_NAME:-$(openssl rand -hex 8)}
export SELFSTEAL=${SELFSTEAL:-0}   # 0 - маскировка под чужой сайт 1 - self-steal
export HY2_PLAIN=${HY2_PLAIN:-1}   # 1 - Hysteria 2 без obfs на 443/udp, 0 - не поднимать
export HY2_OBFS_PORT=${HY2_OBFS_PORT:-40443} # udp-порт для Hysteria 2 с обфускацией salamander


echo "$PBK" > /home/PBK.txt
echo "$XHTTP_PATH" > /home/XHTTP_PATH.txt
echo "$GRPC_NAME" > /home/GRPC_NAME.txt

if [ "$SELFSTEAL" = "1" ]; then
  # self-steal: REALITY ходит за чужим сайтом на локальный nginx с нашим доменом и LE-сертом
  export REALITY_TARGET="127.0.0.1:8001"
  export HY2_CERT="/etc/letsencrypt/live/${DOM}/fullchain.pem"
  export HY2_KEY="/etc/letsencrypt/live/${DOM}/privkey.pem"
  source /home/selfsteal.sh          # nginx + certbot + фоновое продление при ошибке отвалится с exit 1
  : > /home/fingerprint.txt          # пин больше не нужен у Hysteria теперь валидный сертификат
else
  # стандарт реалити копирует реальный сайт ${DOM}
  export REALITY_TARGET="${DOM}:443"
  export HY2_CERT="/etc/ssl/xray/${DOM}.crt"
  export HY2_KEY="/etc/ssl/xray/${DOM}.key"

  mkdir -p /etc/ssl/xray # весь блок с openssl ниже, для работы истерии с самоподписанным сертом

  # проверка на наличие сертификата перед его генерацией
  if [ ! -s /etc/ssl/xray/${DOM}.crt ] || [ ! -s /etc/ssl/xray/${DOM}.key ]; then
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 3650 \
      -subj "/CN=${DOM}" -addext "subjectAltName=DNS:${DOM}" \
      -keyout /etc/ssl/xray/${DOM}.key -out /etc/ssl/xray/${DOM}.crt
  fi
  openssl x509 -in /etc/ssl/xray/${DOM}.crt -noout -fingerprint -sha256 > /home/fingerprint.txt
  chmod 644 /etc/ssl/xray/${DOM}.crt; chmod 640 /etc/ssl/xray/${DOM}.key
fi

envsubst < /opt/xray/config.json_prepare_2 > /opt/xray/config.json

# HY2_PLAIN=0 - убрать Hysteria 2 без obfs с 443/udp (в классике серт самоподписанный, голый QUIC на 443 заметнее)
if [ "$HY2_PLAIN" != "1" ]; then
  jq 'del(.inbounds[] | select(.tag=="inbound-hysteria2"))' /opt/xray/config.json > /tmp/config.json \
    && mv /tmp/config.json /opt/xray/config.json
fi
exec /opt/xray/xray run -c /opt/xray/config.json   # exec: xray становится PID 1 и нормально ловит SIGTERM
