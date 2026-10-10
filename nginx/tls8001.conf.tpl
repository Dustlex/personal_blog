# слушается только loopback - наружу этот порт не смотрит, к нему ходит REALITY (target)
server {
    listen 127.0.0.1:8001 ssl http2;
    server_name ${DOM};
    server_tokens off;
    access_log off;

    ssl_certificate     /etc/letsencrypt/live/${DOM}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOM}/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;   # REALITY требует TLS 1.3 на target

    root /var/www/site;
    index index.html;
    location / {
        try_files $uri $uri/ =404;
    }
}
