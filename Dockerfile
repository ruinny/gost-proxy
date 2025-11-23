# 使用一个轻量的 Alpine Linux 作为基础镜像
FROM alpine:latest

# 设置环境变量，方便未来更新 Gost 版本
ENV GOST_VERSION=3.2.6

# 安装必要的工具 (curl, tar) 并下载、安装 Gost
RUN apk add --no-cache curl tar && \
    # 根据 CPU 架构确定下载链接 (amd64 是 Zeabur 和绝大多数服务器的架构)
    curl -L "https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/gost-linux-amd64-${GOST_VERSION}.tar.gz" -o gost.tar.gz && \
    # 解压文件
    tar -zxvf gost.tar.gz && \
    # 将 gost 程序移动到 /usr/local/bin/ 目录下
    mv "gost-linux-amd64-${GOST_VERSION}/gost" /usr/local/bin/gost && \
    # 赋予执行权限
    chmod +x /usr/local/bin/gost && \
    # 清理工作
    rm -rf gost.tar.gz "gost-linux-amd64-${GOST_VERSION}"

# 设置工作目录
WORKDIR /app

# 将启动脚本复制到镜像中
COPY start.sh .
# 确保启动脚本有执行权限
RUN chmod +x ./start.sh

# 定义容器的入口点
ENTRYPOINT ["./start.sh"]
