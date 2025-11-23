# 使用一个轻量的 Alpine Linux 作为基础镜像
FROM alpine:latest

# 设置环境变量，方便未来更新 Gost 版本和架构
ENV GOST_VERSION=3.2.6
ENV GOST_ARCH=amd64

# 安装必要的工具 (curl, tar) 和新增的 JSON 处理工具 (jq)
RUN apk add --no-cache curl tar jq && \
    # 根据环境变量构建下载 URL
    curl -L "https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/gost_${GOST_VERSION}_linux_${GOST_ARCH}.tar.gz" -o gost.tar.gz && \
    # 解压归档文件
    tar -zxvf gost.tar.gz && \
    # 将解压出的 'gost' 可执行文件移动到系统路径中
    mv gost /usr/local/bin/gost && \
    # 赋予其执行权限
    chmod +x /usr/local/bin/gost && \
    # 清理下载的临时文件
    rm gost.tar.gz

# 设置工作目录
WORKDIR /app

# 将启动脚本复制到镜像中
COPY start.sh .
# 确保启动脚本是可执行的
RUN chmod +x ./start.sh

# 定义容器的入口点
ENTRYPOINT ["./start.sh"]
