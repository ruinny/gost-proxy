FROM alpine:latest

ENV GOST_VERSION=3.2.6
ENV GOST_ARCH=amd64

# 安装依赖：Gost 运行环境 + Python Flask Web 界面
RUN apk add --no-cache curl tar jq dcron procps python3 py3-pip && \
    pip3 install --no-cache-dir flask pyyaml --break-system-packages && \
    curl -L "https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/gost_${GOST_VERSION}_linux_${GOST_ARCH}.tar.gz" -o gost.tar.gz && \
    tar -zxvf gost.tar.gz && \
    mv gost /usr/local/bin/gost && \
    chmod +x /usr/local/bin/gost && \
    rm gost.tar.gz

WORKDIR /app

# 复制脚本和配置文件
COPY start.sh update_proxies.sh gost_cron .
COPY web/ ./web/

RUN chmod +x ./start.sh ./update_proxies.sh && \
    mkdir -p /etc/crontabs /app/logs && \
    mv gost_cron /etc/crontabs/root

# 暴露端口：10808 (Gost SOCKS5) 和 5000 (Web 管理界面)
EXPOSE 10808 5000

ENTRYPOINT ["./start.sh"]
