#!/bin/sh

# 设置 shell 在遇到错误时立即退出
set -e

# 定义配置文件路径 (与您原来的脚本保持一致)
CONFIG_DIR="/app/config"
CONFIG_FILE="${CONFIG_DIR}/gost.yml"

# --- 1. 检查环境变量 ---
# 从环境变量中获取 Webshare API Token，如果不存在则报错退出
if [ -z "${WEBSHARE_API_TOKEN}" ]; then
  echo "错误：环境变量 WEBSHARE_API_TOKEN 未设置。"
  echo "请在 Zeabur 的变量设置中添加您的 Webshare API Token。"
  exit 1
fi

echo "正在创建配置目录: ${CONFIG_DIR}"
mkdir -p "${CONFIG_DIR}"

# --- 2. 获取代理并生成配置文件 ---
echo "正在从 Webshare API 获取代理列表..."

# 使用 curl 请求 API，并将过滤后的 'US' 代理 JSON 存储在变量中
# jq -c '.results[] | select(.country_code == "US")' 会将每个符合条件的代理对象输出为一行
PROXY_LIST_JSON_LINES=$(curl -s -H "Authorization: Token ${WEBSHARE_API_TOKEN}" "https://proxy.webshare.io/api/v2/proxy/list?mode=direct&page=1&page_size=25" | jq -c '.results[] | select(.country_code == "US")')

# 检查是否获取到代理
if [ -z "$PROXY_LIST_JSON_LINES" ]; then
    echo "错误：未能从 API 获取到任何 'US' 地区的代理，请检查您的 API Token 或账户状态。"
    exit 1
fi

echo "获取代理成功，正在生成 ${CONFIG_FILE}..."

# 从第一行代理数据中提取通用用户名和密码
FIRST_PROXY_LINE=$(echo "$PROXY_LIST_JSON_LINES" | head -n 1)
COMMON_USERNAME=$(echo "$FIRST_PROXY_LINE" | jq -r '.username')
COMMON_PASSWORD=$(echo "$FIRST_PROXY_LINE" | jq -r '.password')

# 使用 cat 和 EOF 创建配置文件的静态部分，直接写入目标文件
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
    selector:
      strategy: random
    nodes:
EOF

# --- 3. 动态追加代理节点 ---
# 逐行读取代理 JSON，生成 nodes 列表并追加到配置文件中
echo "$PROXY_LIST_JSON_LINES" | while read -r proxy_line; do
  PROXY_ADDRESS=$(echo "$proxy_line" | jq -r '.proxy_address')
  PROXY_PORT=$(echo "$proxy_line" | jq -r '.port')
  
  # 使用 cat 和 EOF 追加每个节点，注意 '>>' 是追加操作
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
# 执行 gost，-C 指定配置文件路径 (与您原来的脚本保持一致)
# 使用 exec，这样 gost 会替换 sh 进程，成为容器的主进程
exec /usr/local/bin/gost -C "${CONFIG_FILE}"
