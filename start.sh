#!/bin/sh

set -e

CONFIG_DIR="/app/config"
CONFIG_FILE="${CONFIG_DIR}/gost.yml"

# --- 1. 检查环境变量 ---
if [ -z "${WEBSHARE_API_TOKEN}" ]; then
  echo "致命错误：环境变量 WEBSHARE_API_TOKEN 未设置。"
  exit 1
fi

echo "正在创建配置目录: ${CONFIG_DIR}"
mkdir -p "${CONFIG_DIR}"

# --- 2. 首次启动时获取配置 ---
echo "Waiting for network to be ready..."
# 新增: 等待 3 秒，给容器网络环境一点缓冲时间
sleep 3

echo "Performing initial proxy list fetch on startup..."
# 如果 update_proxies.sh 失败 (exit 1), 整个脚本会因为 set -e 而中止
/app/update_proxies.sh

# --- 3. 启动前的最后检查 ---
# 新增: 检查配置文件是否成功生成且不为空
if [ ! -s "${CONFIG_FILE}" ]; then
    echo "致命错误：配置文件 ${CONFIG_FILE} 未能成功生成或为空。"
    exit 1
fi
echo "配置文件已成功生成。"

# --- 4. 启动 Cron 服务 ---
echo "Starting cron daemon in the background..."
crond -f &

# --- 5. 启动 Gost 服务 ---
echo "Starting Gost service in the foreground..."
# 使用 exec 可以让 gost 成为 PID 1 进程，更好地接收信号
exec /usr/local/bin/gost -C "${CONFIG_FILE}" -D 
