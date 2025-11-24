# START OF FILE Dockerfile
FROM alpine:latest

# 设置构建参数，允许构建时覆盖
ARG GOST_VERSION=3.3.0

# 安装必要的工具
# ca-certificates: 用于 HTTPS
# tzdata: 用于设置时区
# libcap: 用于赋予非 root 用户绑定端口权限(可选，此处保持简单暂不配置)
RUN apk add --no-cache curl tar jq dcron procps ca-certificates tzdata bash

# 设置时区 (默认为上海，可根据需要修改)
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 自动检测架构并下载对应版本的 Gost
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
        x86_64) GOST_ARCH="amd64" ;; \
        aarch64) GOST_ARCH="arm64" ;; \
        armv7l) GOST_ARCH="armv7" ;; \
        *) echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac && \
    echo "Downloading Gost v${GOST_VERSION} for ${GOST_ARCH}..." && \
    curl -L "https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/gost_${GOST_VERSION}_linux_${GOST_ARCH}.tar.gz" -o gost.tar.gz && \
    tar -zxvf gost.tar.gz && \
    mv gost /usr/local/bin/gost && \
    chmod +x /usr/local/bin/gost && \
    rm gost.tar.gz README* LICENSE*

WORKDIR /app

# 复制脚本
COPY start.sh update_proxies.sh gost_cron ./
RUN chmod +x ./start.sh ./update_proxies.sh

# 设置 Cron
RUN mkdir -p /etc/crontabs && \
    cp gost_cron /etc/crontabs/root && \
    chmod 0644 /etc/crontabs/root

# 暴露端口 (根据实际使用情况修改，Zeabur 会自动识别)
EXPOSE 8080

ENTRYPOINT ["./start.sh"]
# END OF FILE Dockerfile
