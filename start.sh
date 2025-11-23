#!/bin/sh

# 设置 shell 在遇到错误时立即退出
set -e

# 定义配置文件路径
CONFIG_DIR="/app/config"
CONFIG_FILE="${CONFIG_DIR}/gost.yml"

# 从环境变量中获取 N8N Webhook URL
# 如果环境变量未设置，则打印错误并退出
if [ -z "${N8N_WEBHOOK_URL}" ]; then
  echo "错误：环境变量 N8N_WEBHOOK_URL 未设置。"
  exit 1
fi

echo "正在创建配置目录: ${CONFIG_DIR}"
mkdir -p "${CONFIG_DIR}"

echo "正在从 ${N8N_WEBHOOK_URL} 下载最新的 gost.yml..."
# 使用 curl 下载配置，-f 表示失败时不输出错误页面，-s 静默模式，-L 跟随重定向
if ! curl -fsSL -o "${CONFIG_FILE}" "${N8N_WEBHOOK_URL}"; then
  echo "错误：无法下载配置文件。请检查 Webhook URL 和网络连接。"
  exit 1
fi

# 检查下载的文件是否为空
if [ ! -s "${CONFIG_FILE}" ]; then
    echo "错误：下载的配置文件为空。"
    exit 1
fi

echo "配置文件下载成功。"
echo "启动 Gost 服务..."

# 执行 gost，-C 指定配置文件路径
# 使用 exec，这样 gost 会替换 sh 进程，成为容器的主进程 (PID 1)
exec /usr/local/bin/gost -C "${CONFIG_FILE}"
