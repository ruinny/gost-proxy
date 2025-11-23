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

# --- 2. 获取代理并生成配置文件 ---
echo "正在从 Webshare API 获取代理列表..."
API_RESPONSE=$(curl -s -H "Authorization: Token ${WEBSHARE_API_TOKEN}" "https://proxy.webshare.io/api/v2/proxy/list/?mode=direct&page=1&page_size=25")

if [ -z "${API_RESPONSE}" ]; then
    echo "致命错误：从 Webshare API 获取到的响应为空。请检查网络连接。"
    exit 1
fi

PROXY_LIST_JSON_LINES=$(echo "${API_RESPONSE}" | jq -c '.results[] | select(.country_code == "US")')

if [ -z "$PROXY_LIST_JSON_LINES" ]; then
    echo "---------- Webshare API 原始响应内容 开始 ----------"
    echo "${API_RESPONSE}"
    echo "---------- Webshare API 原始响应内容 结束 ----------"
    echo "致命错误：API 调用成功，但在返回的列表中未找到 'US' 地区的代理。"
    exit 1
fi

echo "获取代理成功，正在生成 ${CONFIG_FILE}..."

FIRST_PROXY_LINE=$(echo "$PROXY_LIST_JSON_LINES" | head -n 1)
COMMON_USERNAME=$(echo "$FIRST_PROXY_LINE" | jq -r '.username')
COMMON_PASSWORD=$(echo "$FIRST_PROXY_LINE" | jq -r '.password')

# --- 3. 生成配置文件 ---
cat <<EOF > "${CONFIG_FILE}"
# ---- DNS 解析器配置 (强制IPv4) ----
resolvers:
  - name: prefer-ipv4-resolver
    nameservers:
      - addr: 8.8.8.8
      - addr: 1.1.1.1
    prefer: ipv4

# ---- 服务和转发器配置 ----
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
    # --- 关键修复：在这里也应用解析器 ---
    resolver: prefer-ipv4-resolver
    selector:
      strategy: random
    nodes:
EOF

echo "$PROXY_LIST_JSON_LINES" | while read -r proxy_line; do
  PROXY_ADDRESS=$(echo "$proxy_line" | jq -r '.proxy_address')
  PROXY_PORT=$(echo "$proxy_line" | jq -r '.port')
  cat <<EOF >> "${CONFIG_FILE}"
      - name: http-proxy-${PROXY_ADDRESS}
        addr: ${PROXY_ADDRESS}:${PROXY_PORT}
        connector:
          type: http
          auths:
            - username: "${COMMON_USERNAME}"
              password: "${COMMON_PASSWORD}"
EOF
done

echo "配置文件生成成功。"
echo "---------- 准备使用的 gost.yml 内容 开始 ----------"
cat "${CONFIG_FILE}"
echo "---------- 准备使用的 gost.yml 内容 结束 ----------"
echo "启动 Gost 服务..."

# --- 4. 启动 Gost ---
exec /usr/local/bin/gost -C "${CONFIG_FILE}"
