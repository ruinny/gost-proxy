#!/bin/sh

# 设置 shell 在遇到错误时立即退出
set -e

# 定义配置文件路径
CONFIG_DIR="/app/config"
CONFIG_FILE="${CONFIG_DIR}/gost.yml"
TEMP_CONFIG_FILE="${CONFIG_FILE}.tmp"

echo "[$(date)] Running proxy update script..."

# --- 1. 获取代理并生成临时配置文件 ---
API_RESPONSE=$(curl -s -H "Authorization: ${WEBSHARE_API_TOKEN}" "https://proxy.webshare.io/api/v2/proxy/list/?mode=direct&page=1&page_size=25")

if [ -z "${API_RESPONSE}" ]; then
    echo "[$(date)] ERROR: API response was empty. Skipping update."
    exit 0
fi

PROXY_LIST_JSON_LINES=$(echo "${API_RESPONSE}" | jq -c '.results[] | select(.country_code == "US")')

if [ -z "$PROXY_LIST_JSON_LINES" ]; then
    echo "[$(date)] ERROR: No 'US' proxies found in API response. Skipping update."
    exit 0
fi

FIRST_PROXY_LINE=$(echo "$PROXY_LIST_JSON_LINES" | head -n 1)
COMMON_USERNAME=$(echo "$FIRST_PROXY_LINE" | jq -r '.username')
COMMON_PASSWORD=$(echo "$FIRST_PROXY_LINE" | jq -r '.password')

# --- 2. 写入临时配置文件 ---
cat <<EOF > "${TEMP_CONFIG_FILE}"
resolvers:
  - name: prefer-ipv4-resolver
    nameservers:
      - addr: 8.8.8.8
      - addr: 1.1.1.1
    prefer: ipv4
services:
  - name: socks5-entry-point
    addr: ":10808"
    handler:
      type: socks5
      auths:
        - username: "${COMMON_USERNAME}"
          password: "${COMMON_PASSWORD}"
    resolver: prefer-ipv4-resolver
    forwarder:
      name: random-http-exit
forwarders:
  - name: random-http-exit
    resolver: prefer-ipv4-resolver
    selector:
      strategy: random
    nodes:
EOF

echo "$PROXY_LIST_JSON_LINES" | while read -r proxy_line; do
  PROXY_ADDRESS=$(echo "$proxy_line" | jq -r '.proxy_address')
  PROXY_PORT=$(echo "$proxy_line" | jq -r '.port')
  cat <<EOF >> "${TEMP_CONFIG_FILE}"
      - name: http-proxy-${PROXY_ADDRESS}
        addr: ${PROXY_ADDRESS}:${PROXY_PORT}
        connector:
          type: http
          auths:
            - username: "${COMMON_USERNAME}"
              password: "${COMMON_PASSWORD}"
EOF
done

# --- 3. 原子性替换配置文件 ---
mv "${TEMP_CONFIG_FILE}" "${CONFIG_FILE}"
echo "[$(date)] Successfully generated new config file."

# --- 4. 热重载 Gost ---
# 查找 gost 进程的 PID。
# 使用 '|| true' 来确保即使 pidof 失败 (找不到进程)，脚本也不会因 'set -e' 而退出。
GOST_PID=$(pidof gost || true)

if [ -n "$GOST_PID" ]; then
    echo "[$(date)] Found Gost process with PID: $GOST_PID. Sending SIGHUP for hot reload."
    kill -HUP "$GOST_PID"
    echo "[$(date)] SIGHUP signal sent."
else
    # 首次启动时会进入这个分支
    echo "[$(date)] WARNING: Gost process not found. Skipping hot reload (this is normal on initial startup)."
fi
