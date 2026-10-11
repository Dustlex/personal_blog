#!/bin/bash
# Подключается из bootstrap.sh через source при SELFSTEAL=1
# Переменные DOM (обязательно), ACME_STAGING=1, SKIP_DNS_CHECK=1

die() { echo "[selfsteal] ERROR: $*" >&2; exit 1; }

[ -n "${DOM:-}" ] || die "DOM не указан в .env"

# Заглушка и nginx пока только :80 для ACME-challenge (проверка хосте перед выдачей сертификата)
mkdir -p /var/www/certbot /var/www/site
[ -f /var/www/site/index.html ] || cp -r /opt/site-default/. /var/www/site/
rm -f /etc/nginx/sites-enabled/default /etc/nginx/conf.d/*.conf
# ВАЖНО: envsubst только по ${DOM}, иначе съест $host/$uri в конфиге nginx
envsubst '${DOM}' < /opt/nginx/http80.conf.tpl > /etc/nginx/conf.d/00-http.conf
nginx -t || die "nginx: ошибка в конфиге :80"
nginx    || die "nginx не запустился"

# Сертификат (только если ещё нет; /etc/letsencrypt должен быть volume'ом)
if [ ! -s "/etc/letsencrypt/live/${DOM}/fullchain.pem" ]; then
  EMAIL_ARGS=(--register-unsafely-without-email)
  [ -n "${ACME_EMAIL:-}" ] && EMAIL_ARGS=(-m "$ACME_EMAIL")
  STAGING_ARGS=()
  [ "${ACME_STAGING:-0}" = "1" ] && STAGING_ARGS=(--staging)
  certbot certonly --webroot -w /var/www/certbot -d "$DOM" \
    --non-interactive --agree-tos "${EMAIL_ARGS[@]}" "${STAGING_ARGS[@]}" \
    || { echo "[selfsteal] certbot failed; пауза 10 мин (restart: always лимит LE на неудачные валидации)" >&2
         sleep 600
         die "certbot не выпустил сертификат (проверить A-запись и открытый порт 80)"; }
fi

# Включаем TLS-сайт на 127.0.0.1:8001 - это target для REALITY
envsubst '${DOM}' < /opt/nginx/tls8001.conf.tpl > /etc/nginx/conf.d/10-tls.conf
nginx -t || die "nginx: ошибка в конфиге :8001"
nginx -s reload || die "nginx reload не удался"

# 5. Раз в 3 часа watchdog nginx + certbot renew (сам ходит в LE только когда осталось <30 дней)
(
  while true; do
    sleep 3h
    { [ -s /run/nginx.pid ] && kill -0 "$(cat /run/nginx.pid)" 2>/dev/null; } || nginx
    certbot renew --quiet --deploy-hook "nginx -s reload" \
      || echo "[selfsteal] certbot renew failed" >&2
  done
) &
