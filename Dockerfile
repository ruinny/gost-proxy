# 使用一个轻量的 Alpine Linux 作为基础镜像
FROM alpine:latest

# 安装 gost 和 curl、bash
# gost 官方提供了方便的安装脚本
RUN apk add --no-cache curl bash && \
    bash <(curl -fsSL https://github.com/go-gost/gost/raw/master/install.sh) --install && \
    # 清理工作
    rm -rf /tmp/*

# 设置工作目录
WORKDIR /app

# 将启动脚本复制到镜像中，并确保它有执行权限
COPY start.sh .
RUN chmod +x ./start.sh

# 定义容器的入口点，当容器启动时会执行这个脚本
ENTRYPOINT ["./start.sh"]
