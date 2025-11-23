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

# --- 2. 获取代理并增加详细调试 ---
echo "正在从 Webshare API 获取代理列表..."

# 首先，获取 API 的原始响应并存储在变量中
API_RESPONSE=$(curl -s -H "Authorization: Token ${WEBSHARE_API_TOKEN}" "https://proxy.webshare.io/api/v2/proxy/list?mode=direct&page=1&page_size=25")

# 新增：打印 API 的原始响应，这是最重要的调试信息！
echo "---------- Webshare API 原始响应内容 开始 ----------"
echo "${API_RESPONSE}"
echo "---------- Webshare API 原始响应内容 结束 ----------"

# 检查原始响应是否为空，这通常意味着网络问题或 curl 失败
if [ -z "${API_RESPONSE}" ]; then
    echo "致命错误：从 Webshare API 获取到的响应为空。请检查网络连接。"
    exit 1
fi

# 现在，基于获取到的响应进行过滤
PROXY_LIST_JSON_LINES=$(echo "${API_RESPONSE}" | jq -c '.results[] | select(.country_code == "US")')

# 检查过滤后的结果是否为空
if [ -z "$PROXY_LIST_JSON_LINES" ]; then
    echo "致命错误：API 调用成功，但在返回的列表中未找到 'US' 地区的代理。"
    echo "请检查您的 Webshare 账户是否包含 US 地区的代理，或者 API 是否返回了错误信息（见上方原始响应）。"
    exit 1
fi

echo "获取代理成功，正在生成 ${CONFIG_FILE}..."

# --- 3. 生成配置文件 (此部分逻辑不变) ---
FIRST_PROXY_LINE=$(echo "$PROXY_LIST_JSON_LINES" | head -n 1)
COMMON_USERNAME=$(echo "$FIRST_PROXY_LINE" | jq -r '.username')
COMMON_PASSWORD=$(echo "$FIRST_PROXY_LINE" | jq -r '.password')

cat <<EOF > "${CONFIG_FILE}"
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
echo "启动 Gost 服务..."

# --- 4. 启动 Gost ---
exec /usr/local/bin/gost -C "${CONFIG_FILE}"
