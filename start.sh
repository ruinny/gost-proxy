#!/bin/sh

# 设置 shell 在遇到错误时立即退出
set -e

# 定义配置文件路径
CONFIG_DIR="/app/config"
CONFIG_FILE="${CONFIG_DIR}/gost.yml"

# --- 1. 检查环境变量 ---
if [ -z "${WEBSHARE_API_TOKEN}" ]; then
  echo "致命错误：环境变量 WEBSHARE_API_TOKEN 未设置。"
  exit 1
fi

echo "正在创建配置目录: ${CONFIG_DIR}"
mkdir -p "${CONFIG_DIR}"

# --- 2. 首次启动时，立即执行一次更新以获取初始配置 ---
echo "Performing initial proxy list fetch on startup..."
/app/update_proxies.sh

# --- 3. 启动 Cron 服务 ---
echo "Starting cron daemon in the background..."
# -f 在前台运行 crond，但我们用 & 把它放到后台
crond -f &

# --- 4. 启动 Gost 服务 ---
echo "Starting Gost service in the foreground..."
# 这里不再使用 exec，让 shell 脚本作为主进程等待 gost 结束
/usr/local/bin/gost -C "${CONFIG_FILE}"
