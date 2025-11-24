#!/bin/sh

set -e

CONFIG_DIR="/app/config"
CONFIG_FILE="${CONFIG_DIR}/gost.yml"
TEMP_CONFIG_FILE="${CONFIG_FILE}.tmp"

echo "[$(date)] Running proxy update script..."

# --- 1. 获取代理并生成临时配置文件 ---
API_RESPONSE=$(curl -s -H "Authorization: ${WEBSHARE_API_TOKEN}" "https://proxy.webshare.io/api/v2/proxy/list/?mode=direct&page=1&page_size=25")

# 如果 API 响应为空，则以失败状态退出
if [ -z "${API_RESPONSE}" ]; then
    echo "[$(date)] ERROR: API response was empty. Aborting."
    exit 1
fi

PROXY_LIST_JSON_LINES=$(echo "${API_RESPONSE}" | jq -c '.results[] | select(.country_code == "US")')

# 如果找不到美国代理，则以失败状态退出
if [ -z "$PROXY_LIST_JSON_LINES" ]; then
    echo "[$(date)] ERROR: No 'US' proxies found in API response. Aborting."
    exit 1
fi

FIRST_PROXY_LINE=$(echo "$PROXY_LIST_JSON_LINES" | head -n 1)
COMMON_USERNAME=$(echo "$FIRST_PROXY_LINE" | jq -r '.username')
COMMON_PASSWORD=$(echo "$FIRST_PROXY_LINE" | jq -r '.password')

# --- 2. 写入临时配置文件 ---
cat <<EOF > "${TEMP_CONFIG_FILE}"
services:
  - name: socks5-entry-point
    addr: ":10808"
    handler:
      type: socks5
      auths:
        - username: "${COMMON_USERNAME}"
          password: "${COMMON_PASSWORD}"
    forwarder:
      name: random-http-exit
forwarders:
  - name: random-http-exit
    selector:
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
          auths:
            - username: "${COMMON_USERNAME}"
              password: "${COMMON_PASSWORD}"
EOF
done

# --- 3. 原子性替换配置文件 ---
mv "${TEMP_CONFIG_FILE}" "${CONFIG_FILE}"
echo "[$(date)] Successfully generated new config file."

# --- 4. 热重载 Gost ---
GOST_PID=$(pidof gost || true)

if [ -n "$GOST_PID" ]; then
    echo "[$(date)] Found Gost process with PID: $GOST_PID. Sending SIGHUP for hot reload."
    kill -HUP "$GOST_PID"
    echo "[$(date)] SIGHUP signal sent."
else
    echo "[$(date)] WARNING: Gost process not found. Skipping hot reload (this is normal on initial startup)."
fi
