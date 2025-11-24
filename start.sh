#!/bin/sh
set -e

CONFIG_DIR="/app/config"
CONFIG_FILE="${CONFIG_DIR}/gost.yml"

# 检查环境变量
if [ -z "${WEBSHARE_API_TOKEN}" ]; then
  echo "错误：环境变量 WEBSHARE_API_TOKEN 未设置"
  exit 1
fi

echo "创建配置目录: ${CONFIG_DIR}"
mkdir -p "${CONFIG_DIR}"

# 等待网络就绪
echo "等待网络就绪..."
sleep 3

# 首次启动时获取代理配置
echo "执行初始代理列表获取..."
/app/update_proxies.sh

# 验证配置文件
if [ ! -s "${CONFIG_FILE}" ]; then
    echo "错误：配置文件生成失败"
    exit 1
fi
echo "配置文件生成成功"

# 启动 Web 管理界面
echo "启动 Web 管理界面 (端口 5000)..."
cd /app/web
python3 app.py &
WEB_PID=$!
echo "Web 界面已启动 (PID: ${WEB_PID})"

# 启动 Cron 定时任务
echo "启动 Cron 定时任务..."
crond -f &

# 启动 Gost 代理服务
echo "启动 Gost 代理服务 (端口 10808)..."
exec /usr/local/bin/gost -C "${CONFIG_FILE}" -D
