# Gost 动态代理池

[![GoST](https://img.shields.io/badge/Built%20with-GoST%203.2.6-blue.svg)](https://github.com/go-gost/gost)
[![Platform](https://img.shields.io/badge/Deploy-Zeabur-brightgreen)](https://zeabur.com)
[![Docker](https://img.shields.io/badge/Docker-Alpine%20Linux-0db7ed.svg)](https://hub.docker.com/_/alpine)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](https://opensource.org/licenses/MIT)

基于 [Gost v3.2.6](https://github.com/go-gost/gost) 的智能动态代理池，自动从 [Webshare.io](https://www.webshare.io/) 获取代理服务器，构建高可用的 SOCKS5 代理服务，支持定时更新和热重载。

内置 Web 管理界面（shadcn/ui 风格 + 马卡龙配色），实时监控代理状态，前台展示 SOCKS5 代理地址（密码保护）。

## 核心功能

- **动态代理池**: 自动从 Webshare API 获取最新代理列表
- **热重载**: 每 5 分钟自动更新，通过 SIGHUP 信号重载 Gost，服务不中断
- **高可用**: 多代理随机选择（random 策略），避免单点故障
- **区域筛选**: 默认筛选美国代理，可自定义国家代码
- **统一认证**: 使用 Webshare 凭证作为 SOCKS5 入口认证
- **Web 管理面板**: 实时查看代理状态、日志和配置，支持一键复制代理地址
- **密码保护**: SOCKS5 代理地址需要输入密码才能查看，防止未授权访问
- **部署友好**: 支持 Zeabur、Docker、Docker Compose 等多种部署方式

## 工作原理

```
客户端 --> SOCKS5 (:10808) --> 随机选择代理 --> Webshare 代理池 --> 目标网站
                |
         Web 管理面板 (:5000)
```

1. `start.sh` 启动时执行 `update_proxies.sh` 首次获取代理列表，生成 `gost.yml`
2. Gost 以 SOCKS5 协议监听 10808 端口，通过 chain 随机转发至 Webshare HTTP 代理
3. Cron 每 5 分钟执行 `update_proxies.sh`，更新配置后向 Gost 发送 SIGHUP 热重载
4. Flask Web 面板在 5000 端口提供状态监控、代理列表查看、日志查看和 SOCKS5 地址展示

## 快速部署

### 方式一：Zeabur 一键部署（推荐）

1. **Fork 本项目**到你的 GitHub 账户

2. **在 Zeabur 创建服务**
   - 登录 [Zeabur](https://zeabur.com/)
   - 选择 "从 GitHub 部署"
   - 选择你 Fork 的仓库

3. **配置环境变量**

   | 变量名 | 必填 | 说明 |
   |--------|------|------|
   | `WEBSHARE_API_TOKEN` | 是 | Webshare API 密钥，[获取地址](https://proxy.webshare.io/user/settings/api-key) |
   | `PANEL_PASSWORD` | 否 | Web 面板查看代理地址的密码，默认 `qwert123` |
   | `SOCKS5_HOST` | 否 | SOCKS5 地址中显示的主机名，默认取请求 Host |

4. **访问服务**
   - SOCKS5 代理：`your-domain.zeabur.app:10808`
   - Web 管理面板：`http://your-domain.zeabur.app:5000`

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
  -e PANEL_PASSWORD="your_password_here" \
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
      - PANEL_PASSWORD=qwert123
    restart: unless-stopped
```

启动服务：

```bash
docker-compose up -d
```

## 使用指南

### 获取代理凭证

1. 登录 [Webshare 控制台](https://proxy.webshare.io/)
2. 进入 [Proxy List](https://proxy.webshare.io/proxy/list)
3. 查看任意代理的 Username 和 Password（所有代理共享）

### Web 管理面板

访问 `http://your-domain:5000` 即可看到管理面板：

- **SOCKS5 代理地址**: 输入面板密码后解锁查看，支持一键复制
- **系统状态卡片**: Gost 运行状态、代理数量、最后更新时间、监听端口
- **代理列表**: 实时查看所有活跃的上游代理节点
- **日志记录**: 查看最近 50 条更新日志
- **自动刷新**: 每 10 秒自动拉取最新数据

### 代理使用示例

代理地址格式：`socks5://username:password@host:10808`

可在 Web 面板中一键复制完整地址，然后配置到你的应用中。

#### curl 测试

```bash
curl --proxy "socks5://user:pass@your-domain:10808" "https://api.ipify.org?format=json"
```

#### Python

```python
import requests

proxies = {
    'http': 'socks5://user:pass@your-domain:10808',
    'https': 'socks5://user:pass@your-domain:10808'
}

response = requests.get('https://api.ipify.org?format=json', proxies=proxies)
print(response.json())
```

## 环境变量

| 变量名 | 必填 | 默认值 | 说明 |
|--------|------|--------|------|
| `WEBSHARE_API_TOKEN` | 是 | - | Webshare API 密钥 |
| `PANEL_PASSWORD` | 否 | `qwert123` | Web 面板查看 SOCKS5 地址的密码 |
| `SOCKS5_HOST` | 否 | 请求 Host | SOCKS5 地址中显示的主机名 |

## 自定义配置

### 修改代理区域

编辑 `update_proxies.sh`：

```bash
# 使用英国代理
PROXY_LIST_JSON_LINES=$(echo "${API_RESPONSE}" | jq -c '.results[] | select(.country_code == "GB")')

# 使用所有代理（不限区域）
PROXY_LIST_JSON_LINES=$(echo "${API_RESPONSE}" | jq -c '.results[]')
```

### 修改更新频率

编辑 `gost_cron`：

```bash
# 每 10 分钟
*/10 * * * * /app/update_proxies.sh >> /proc/1/fd/1 2>> /proc/1/fd/2

# 每小时
0 * * * * /app/update_proxies.sh >> /proc/1/fd/1 2>> /proc/1/fd/2
```

### 修改监听端口

编辑 `update_proxies.sh` 中的 `addr: ":10808"` 和 `Dockerfile` 中的 `EXPOSE` 指令。

### 修改代理数量

编辑 `update_proxies.sh`：

```bash
# 获取 50 个代理
API_RESPONSE=$(curl -s -H "Authorization: ${WEBSHARE_API_TOKEN}" \
  "https://proxy.webshare.io/api/v2/proxy/list/?mode=direct&page=1&page_size=50")
```

## API 接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/` | GET | Web 管理面板页面 |
| `/api/status` | GET | 系统状态（Gost 运行状态、代理数量、更新时间） |
| `/api/proxies` | GET | 代理列表（名称、地址、类型、状态） |
| `/api/logs` | GET | 最近 50 条更新日志 |
| `/api/config` | GET | Gost 配置文件原始内容 |
| `/api/socks5-address?password=xxx` | GET | SOCKS5 代理连接地址（需密码验证） |

## 故障排查

### 容器启动失败

```bash
# 检查环境变量
docker exec gost-proxy env | grep WEBSHARE

# 查看启动日志
docker logs gost-proxy
```

### 无法连接代理

```bash
# 检查端口映射
docker port gost-proxy

# 测试本地连接
curl --proxy "socks5://user:pass@localhost:10808" "https://api.ipify.org?format=json"
```

### 代理列表未更新

```bash
# 查看更新日志
docker logs gost-proxy | grep "代理更新"

# 手动执行更新
docker exec gost-proxy /app/update_proxies.sh
```

### Web 面板无法访问

```bash
# 检查 Flask 进程
docker exec gost-proxy ps aux | grep python

# 检查端口映射
docker port gost-proxy 5000
```

## 项目结构

```
gost-proxy/
├── Dockerfile              # Docker 镜像构建（Alpine + Gost + Python Flask）
├── start.sh                # 容器启动入口（初始化 → Web → Cron → Gost）
├── update_proxies.sh       # 代理列表更新脚本（调用 Webshare API → 生成 gost.yml → 热重载）
├── gost_cron               # Cron 定时任务（每 5 分钟更新）
├── README.md               # 项目文档
└── web/                    # Web 管理面板
    ├── app.py              # Flask 后端（状态 API + SOCKS5 地址 API）
    ├── static/
    │   ├── style.css       # shadcn/ui 风格 + 马卡龙配色
    │   └── script.js       # 前端逻辑（数据刷新、密码验证、复制）
    └── templates/
        └── index.html      # 主页面模板
```

## 技术栈

| 技术 | 版本 | 用途 |
|------|------|------|
| [Gost](https://github.com/go-gost/gost) | 3.2.6 | 代理服务核心 |
| Alpine Linux | latest | 基础镜像 |
| Python Flask | latest | Web 管理面板后端 |
| dcron | - | 定时任务调度 |
| curl + jq | - | API 请求和 JSON 解析 |

## 更新日志

### v2.1.0
- Web 面板 UI 改造：shadcn/ui 风格 + 马卡龙配色
- 新增 SOCKS5 代理地址展示（密码保护 + 一键复制）
- 中文排版优化（字体、行高、字间距）
- 新增 `/api/socks5-address` 接口
- 支持 `PANEL_PASSWORD` 和 `SOCKS5_HOST` 环境变量

### v2.0.0
- 新增 Web 管理界面
- 实时代理状态监控
- 日志查看功能

### v1.0.0
- 初始版本发布
- Webshare API 集成
- 自动热重载

## 许可证

本项目采用 [MIT License](LICENSE) 开源。

## 相关链接

- [Gost 官方文档](https://gost.run/)
- [Webshare 官网](https://www.webshare.io/)
- [Zeabur 部署平台](https://zeabur.com/)

---

**注意**: 使用代理服务时请遵守当地法律法规和目标网站的服务条款。
