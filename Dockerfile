# 使用一个轻量的 Alpine Linux 作为基础镜像
FROM alpine:latest

# 设置环境变量
ENV GOST_VERSION=3.2.6
ENV GOST_ARCH=amd64

# 安装必要的工具: curl, tar, jq, dcron (cron daemon), procps (for pidof)
RUN apk add --no-cache curl tar jq dcron procps && \
    curl -L "https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/gost_${GOST_VERSION}_linux_${GOST_ARCH}.tar.gz" -o gost.tar.gz && \
    tar -zxvf gost.tar.gz && \
    mv gost /usr/local/bin/gost && \
    chmod +x /usr/local/bin/gost && \
    rm gost.tar.gz

# 设置工作目录
WORKDIR /app

# 复制所有需要的脚本和配置文件
COPY start.sh update_proxies.sh gost_cron .
# 确保脚本是可执行的
RUN chmod +x ./start.sh ./update_proxies.sh

# 设置 Cron 任务
RUN mkdir -p /etc/crontabs && \
    mv gost_cron /etc/crontabs/root

# 定义容器的入口点
ENTRYPOINT ["./start.sh"]
