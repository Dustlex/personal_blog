FROM ubuntu:22.04 AS OS
USER root
WORKDIR /home
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
 ca-certificates \
 wget \
 unzip \
 systemctl \
 gettext \
 openssl \
 vim \
 nginx \
 certbot \
 jq \
 && rm -rf /var/lib/apt/lists/*
RUN wget https://github.com/XTLS/Xray-core/releases/download/v26.9.30/Xray-linux-64.zip --no-check-certificate && \
 mkdir /opt/xray && \
 unzip ./Xray-linux-64.zip -d /opt/xray && \
 chmod +x /opt/xray/xray
COPY ./config_2.json /opt/xray/config.json_prepare_2
COPY ./bootstrap.sh /home/bootstrap.sh
COPY ./selfsteal.sh /home/selfsteal.sh
COPY ./nginx/ /opt/nginx/
COPY ./site/ /opt/site-default/
RUN chmod +x /home/bootstrap.sh
CMD ["/bin/bash", "/home/bootstrap.sh"]
