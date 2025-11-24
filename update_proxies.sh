#!/bin/sh
set -e

CONFIG_DIR="/app/config"
CONFIG_FILE="${CONFIG_DIR}/gost.yml"
TEMP_CONFIG_FILE="${CONFIG_FILE}.tmp"
LOG_FILE="/app/logs/update.log"

# 日志函数
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "开始更新代理列表..."

# 获取代理列表
API_RESPONSE=$(curl -s -H "Authorization: ${WEBSHARE_API_TOKEN}" "https://proxy.webshare.io/api/v2/proxy/list/?mode=direct&page=1&page_size=25")

if [ -z "${API_RESPONSE}" ]; then
    log_message "错误：API 响应为空"
    exit 1
fi

PROXY_LIST_JSON_LINES=$(echo "${API_RESPONSE}" | jq -c '.results[] | select(.country_code == "US")')

if [ -z "$PROXY_LIST_JSON_LINES" ]; then
    log_message "错误：未找到美国代理"
    exit 1
fi

PROXY_COUNT=$(echo "$PROXY_LIST_JSON_LINES" | wc -l)
log_message "找到 ${PROXY_COUNT} 个美国代理"

FIRST_PROXY_LINE=$(echo "$PROXY_LIST_JSON_LINES" | head -n 1)
COMMON_USERNAME=$(echo "$FIRST_PROXY_LINE" | jq -r '.username')
COMMON_PASSWORD=$(echo "$FIRST_PROXY_LINE" | jq -r '.password')

# 生成配置文件
cat <<EOF > "${TEMP_CONFIG_FILE}"
services:
  - name: socks5-entry-point
    addr: ":10808"
    handler:
      type: socks5
      auth:
          username: "${COMMON_USERNAME}"
          password: "${COMMON_PASSWORD}"
      chain: random-http-exit
    listener:
      type: tcp
chains:
- name: random-http-exit
  hops:
  - name: random-http-hop
    strategy: random 
    nodes: 
EOF

# 循环遍历每个代理，将其作为 node 添加到配置文件中
echo "$PROXY_LIST_JSON_LINES" | while read -r proxy_line; do
  PROXY_ADDRESS=$(echo "$proxy_line" | jq -r '.proxy_address')
  PROXY_PORT=$(echo "$proxy_line" | jq -r '.port')
  cat <<EOF >> "${TEMP_CONFIG_FILE}"
    - name: http-proxy-${PROXY_ADDRESS}
      addr: ${PROXY_ADDRESS}:${PROXY_PORT}
      connector:
        type: http
        auth:
            username: "${COMMON_USERNAME}"
            password: "${COMMON_PASSWORD}"
EOF
done

# 原子性替换配置文件
mv "${TEMP_CONFIG_FILE}" "${CONFIG_FILE}"
log_message "配置文件生成成功"

# 热重载 Gost
GOST_PID=$(pidof gost || true)

if [ -n "$GOST_PID" ]; then
    log_message "向 Gost 进程 (PID: $GOST_PID) 发送 SIGHUP 信号"
    kill -HUP "$GOST_PID"
    log_message "热重载完成"
else
    log_message "Gost 进程未运行（首次启动时正常）"
fi

log_message "代理更新完成，共 ${PROXY_COUNT} 个代理"
