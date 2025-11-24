# Gost 动态代理池

[![GoST](https://img.shields.io/badge/Built%20with-GoST%203.2.6-blue.svg)](https://github.com/go-gost/gost)
[![Platform](https://img.shields.io/badge/Deploy-Zeabur-brightgreen)](https://zeabur.com)
[![Docker](https://img.shields.io/badge/Docker-Alpine%20Linux-0db7ed.svg)](https://hub.docker.com/_/alpine)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](https://opensource.org/licenses/MIT)

基于 [Gost v3.2.6](https://github.com/go-gost/gost) 的智能动态代理池，自动从 [Webshare.io](https://www.webshare.io/) 获取代理服务器，构建高可用的 SOCKS5 代理服务，支持定时更新和热重载。

**新增功能**：内置 Web 管理界面，实时监控代理状态！

## ✨ 核心功能

- **🔄 动态代理池**: 自动从 Webshare API 获取最新代理列表
- **🔥 热重载**: 每 5 分钟自动更新，服务不中断
- **⚡ 高可用**: 多代理随机选择，避免单点故障
- **🌍 区域筛选**: 默认筛选美国代理，可自定义
- **🔐 统一认证**: 使用 Webshare 凭证作为入口认证
- **📊 Web 管理**: 实时查看代理状态、日志和配置
- **🚀 部署友好**: 支持 Zeabur、Docker 等多种部署方式

## 🎯 工作原理

```
客户端 → SOCKS5 (:10808) → 随机选择代理 → Webshare 代理池 → 目标网站
                ↓
         Web 管理界面 (:5000)
```

系统每 5 分钟自动更新代理列表，通过 SIGHUP 信号热重载 Gost 配置，无需重启服务。

## 🚀 快速部署

### 方式一：Zeabur 一键部署（推荐）

1. **Fork 本项目**到你的 GitHub 账户

2. **在 Zeabur 创建服务**
   - 登录 [Zeabur](https://zeabur.com/)
   - 选择 "从 GitHub 部署"
   - 选择你 Fork 的仓库

3. **配置环境变量**
   
   | 变量名 | 说明 | 获取方式 |
   |--------|------|----------|
   | `WEBSHARE_API_TOKEN` | Webshare API 密钥 | [获取 API Key](https://proxy.webshare.io/user/settings/api-key) |

4. **访问服务**
   - SOCKS5 代理：`your-domain.zeabur.app:10808`
   - Web 管理界面：`http://your-domain.zeabur.app:5000`

### 方式二：Docker 本地部署

```bash
# 克隆项目
git clone https://github.com/your-username/gost-proxy.git
cd gost-proxy

# 构建镜像
docker build -t gost-proxy:latest .

# 运行容器
docker run -d \
  --name gost-proxy \
  -p 10808:10808 \
  -p 5000:5000 \
  -e WEBSHARE_API_TOKEN="your_api_token_here" \
  gost-proxy:latest

# 查看日志
docker logs -f gost-proxy
```

### 方式三：Docker Compose

创建 `docker-compose.yml`：

```yaml
version: '3.8'

services:
  gost-proxy:
    build: .
    container_name: gost-proxy
    ports:
      - "10808:10808"
      - "5000:5000"
    environment:
      - WEBSHARE_API_TOKEN=your_api_token_here
    restart: unless-stopped
```

启动服务：

```bash
docker-compose up -d
```

## 📖 使用指南

### 获取代理凭证

1. 登录 [Webshare 控制台](https://proxy.webshare.io/)
2. 进入 [Proxy List](https://proxy.webshare.io/proxy/list)
3. 查看任意代理的 Username 和 Password（所有代理共享）

### 代理配置

| 配置项 | 值 |
|--------|-----|
| **代理地址** | 你的服务域名或 IP |
| **代理端口** | `10808` |
| **协议** | SOCKS5 |
| **用户名** | Webshare 代理用户名 |
| **密码** | Webshare 代理密码 |

### 使用示例

#### 1. curl 测试

```bash
# 测试连接
curl --proxy "socks5://user:pass@your-domain:10808" "https://api.ipify.org?format=json"

# 检查 IP
curl --proxy "socks5://user:pass@your-domain:10808" "https://ifconfig.me"
```

#### 2. Python 使用

```python
import requests

proxies = {
    'http': 'socks5://user:pass@your-domain:10808',
    'https': 'socks5://user:pass@your-domain:10808'
}

response = requests.get('https://api.ipify.org?format=json', proxies=proxies)
print(response.json())
```

### Web 管理界面

访问 `http://your-domain:5000` 查看：

- **系统状态**: Gost 运行状态、代理数量、更新时间
- **代理列表**: 实时查看所有活跃代理
- **日志记录**: 查看更新日志和错误信息
- **自动刷新**: 每 10 秒自动更新数据

## 🔧 自定义配置

### 修改代理区域

编辑 [`update_proxies.sh`](update_proxies.sh:20)：

```bash
# 使用英国代理
PROXY_LIST_JSON_LINES=$(echo "${API_RESPONSE}" | jq -c '.results[] | select(.country_code == "GB")')

# 使用所有代理
PROXY_LIST_JSON_LINES=$(echo "${API_RESPONSE}" | jq -c '.results[]')
```

### 修改更新频率

编辑 [`gost_cron`](gost_cron:1)：

```bash
# 每 10 分钟
*/10 * * * * /app/update_proxies.sh >> /proc/1/fd/1 2>> /proc/1/fd/2

# 每小时
0 * * * * /app/update_proxies.sh >> /proc/1/fd/1 2>> /proc/1/fd/2
```

### 修改监听端口

编辑 [`update_proxies.sh`](update_proxies.sh:36) 中的 `addr: ":10808"` 和 [`Dockerfile`](Dockerfile) 中的 `EXPOSE` 指令。

### 修改代理数量

编辑 [`update_proxies.sh`](update_proxies.sh:12)：

```bash
# 获取 50 个代理
API_RESPONSE=$(curl -s -H "Authorization: ${WEBSHARE_API_TOKEN}" "https://proxy.webshare.io/api/v2/proxy/list/?mode=direct&page=1&page_size=50")
```

## 🐛 故障排查

### 容器启动失败

**原因**: 未设置 `WEBSHARE_API_TOKEN` 或 Token 无效

**解决**:
```bash
# 检查环境变量
docker exec gost-proxy env | grep WEBSHARE

# 查看日志
docker logs gost-proxy
```

### 无法连接代理

**原因**: 端口未映射或认证信息错误

**解决**:
```bash
# 检查端口
docker port gost-proxy

# 测试本地连接
curl --proxy "socks5://user:pass@localhost:10808" "https://api.ipify.org?format=json"
```

### 代理列表未更新

**原因**: Cron 未执行或 API 请求失败

**解决**:
```bash
# 查看日志
docker logs gost-proxy | grep "代理更新"

# 手动执行更新
docker exec gost-proxy /app/update_proxies.sh
```

### Web 界面无法访问

**原因**: 端口未映射或 Flask 未启动

**解决**:
```bash
# 检查 Flask 进程
docker exec gost-proxy ps aux | grep python

# 检查端口映射
docker port gost-proxy 5000
```

## 📁 项目结构

```
gost-proxy/
├── Dockerfile              # Docker 镜像构建
├── start.sh               # 容器启动脚本
├── update_proxies.sh      # 代理更新脚本
├── gost_cron              # Cron 定时任务
├── README.md              # 项目文档
└── web/                   # Web 管理界面
    ├── app.py            # Flask 后端
    ├── static/           # 静态资源
    │   ├── style.css    # 样式文件
    │   └── script.js    # 前端脚本
    └── templates/        # HTML 模板
        └── index.html   # 主页面
```

## 🔧 技术栈

| 技术 | 版本 | 用途 |
|------|------|------|
| [Gost](https://github.com/go-gost/gost) | 3.2.6 | 代理服务核心 |
| Alpine Linux | latest | 基础镜像 |
| Python Flask | latest | Web 管理界面 |
| dcron | - | 定时任务 |
| curl & jq | - | API 请求和 JSON 解析 |

## 📊 性能建议

- **代理数量**: 建议 10-25 个，平衡性能和可用性
- **更新频率**: 建议 5-10 分钟，避免频繁 API 请求
- **区域选择**: 选择地理位置接近的代理，降低延迟

## 📝 更新日志

### v2.0.0 (2024-11-24)
- ✨ 新增 Web 管理界面
- 📊 实时代理状态监控
- 📝 日志查看功能
- 🎨 优化代码和文档

### v1.0.0 (2024-01-01)
- 🎉 初始版本发布
- 🔄 支持 Webshare API 集成
- 🔥 实现自动热重载

## 📄 许可证

本项目采用 [MIT License](LICENSE) 开源。

## 🔗 相关链接

- [Gost 官方文档](https://gost.run/)
- [Webshare 官网](https://www.webshare.io/)
- [Zeabur 部署平台](https://zeabur.com/)

---

**注意**: 使用代理服务时请遵守当地法律法规和目标网站的服务条款。
