server {
    listen 80;
    server_name ${DOM};
    server_tokens off;
    access_log off;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    location / {
        return 301 https://${DOM}$request_uri;
    }
}
