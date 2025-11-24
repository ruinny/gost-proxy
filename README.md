# Gost 动态代理 (Gost Dynamic Proxy)

[![GoST](https://img.shields.io/badge/Built%20with-GoST-blue.svg)](https://github.com/go-gost/gost)
[![Platform](https://img.shields.io/badge/Deploy-Zeabur-brightgreen)](https://zeabur.com)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](https://opensource.org/licenses/MIT)

一个基于 [Gost](https://github.com/go-gost/gost) 的动态代理池项目。它能自动从 [Webshare.io](https://www.webshare.io/) 获取代理服务器列表，构建一个高可用的 SOCKS5 代理服务，并支持定时自动更新代理列表，实现无中断热重载。

这个项目特别适合部署在 [Zeabur](https://zeabur.com/)、Heroku、Railway 等支持 Dockerfile 的 PaaS 平台。

## 核心功能

- **动态代理池**: 启动时和定时从 Webshare API 获取最新的代理列表。
- **自动热重载**: 定时任务（Cron）会定期更新代理列表，并向 Gost 发送 `SIGHUP` 信号以重新加载配置，整个过程服务不会中断。
- **高可用出口**: 将获取到的多个代理作为出口节点，并使用 `random` 策略随机选择，避免单点故障。
- **区域筛选**: 脚本默认只筛选美国（US）的代理服务器作为出口。
- **统一认证**: 使用 Webshare 账户的通用凭证作为 SOCKS5 服务的入口认证，方便客户端连接。
- **部署友好**: 通过 Shell 脚本自动化所有流程，简化了在 PaaS 平台上的部署。

## 工作原理

整个服务由几个关键部分协同工作：

1.  **`start.sh` (启动脚本)**:
    *   检查 `WEBSHARE_API_TOKEN` 环境变量是否存在。
    *   在首次启动时，立即执行 `update_proxies.sh` 来生成初始的 Gost 配置文件。
    *   启动 `cron` 后台守护进程，用于定时执行更新任务。
    *   在前台启动 `gost` 主服务，加载配置文件。

2.  **`update_proxies.sh` (更新脚本)**:
    *   通过 `curl` 调用 Webshare API，获取代理列表。
    *   使用 `jq` 解析 JSON 响应，筛选出所有位于美国的代理。
    *   基于这些代理信息，动态生成一个 `gost.yml` 配置文件。该文件定义了一个 SOCKS5 入口服务和多个 HTTP 出口节点。
    *   将新配置**原子性地**替换旧配置文件，防止在更新过程中出现配置错乱。
    *   找到正在运行的 `gost` 进程，并向其发送 `SIGHUP` 信号，触发配置热重载。

3.  **Gost 服务**:
    *   监听在 `10808` 端口，提供 SOCKS5 代理服务。
    *   当收到客户端请求时，会从配置好的多个 Webshare 代理节点中**随机选择一个**来转发请求。

### 数据流

```
客户端 -> (SOCKS5 认证) -> 本服务 :10808 -> [随机选择一个] -> Webshare HTTP 代理 -> 目标网站
```

## 部署指南

本项目非常适合一键部署。以 [Zeabur](https://zeabur.com/) 平台为例：

1.  **Fork 本项目**
    将此 GitHub 仓库 Fork 到你自己的账户下。

2.  **在 Zeabur 中创建服务**
    *   登录 Zeabur 控制台，点击 "部署新服务"。
    *   选择 "从 GitHub 部署"，并授权 Zeabur 访问你的仓库。
    *   选择你刚刚 Fork 的 `gost-proxy` 仓库。

3.  **配置环境变量**
    这是最关键的一步。在服务的 "变量" 设置页面，添加以下环境变量：
    *   **`WEBSHARE_API_TOKEN`**: 你的 Webshare API 密钥。请访问你的 [Webshare 账户](https://proxy.webshare.io/user/settings/api-key) 获取。

4.  **部署**
    配置完成后，Zeabur 会自动开始构建和部署。等待部署成功即可。

## 如何使用

部署成功后，你将得到一个 SOCKS5 代理服务。你需要从 Webshare 获取你的代理凭证（用户名和密码），它们对于你账户下的所有代理都是通用的。

- **代理地址**: 你的服务域名 (例如 `gost-proxy.zeabur.app`)
- **代理端口**: `10808`
- **协议**: SOCKS5
- **用户名**: 你的 Webshare 代理用户名
- **密码**: 你的 Webshare 代理密码

### 示例 (使用 `curl`)

假设你的服务域名是 `my-proxy.zeabur.app`，Webshare 用户名是 `myuser`，密码是 `mypass`。

```bash
curl --proxy "socks5://myuser:mypass@my-proxy.zeabur.app:10808" "https://www.google.com"
```

## 技术细节

### 脚本分析

- **`start.sh`**:
  - `set -e`: 确保任何命令失败时脚本都会立即退出，增强了可靠性。
  - `exec /usr/local/bin/gost ...`: 使用 `exec` 启动 `gost`，让 `gost` 进程取代 shell 进程成为主进程 (PID 1)。这使得 `gost` 可以正确接收来自容器运行时的 `SIGTERM` 等信号，实现优雅停机。
  - `crond -f &`: 在后台启动 cron 服务，`-f` 参数使其在前台运行（但在 `&` 的作用下转入后台），确保 cron 进程在容器中持续存在。

- **`update_proxies.sh`**:
  - **原子性配置更新**: 脚本首先将新配置写入一个临时文件 (`gost.yml.tmp`)，成功生成后再通过 `mv` 命令覆盖旧文件。这是一个原子操作，可以防止 `gost` 在文件被写入的过程中读取到一个不完整的配置文件。
  - **热重载机制**: `kill -HUP $(pidof gost)` 是实现无中断更新的关键。`SIGHUP` 信号通知 `gost` 重新加载其配置文件，而不会断开现有的连接。
  - **健壮性检查**: 脚本在多个环节进行了检查，例如 API 响应是否为空、是否找到了 US 代理等，如果发生意外，会立即退出，避免生成错误的配置。

## 许可证

本项目采用 [MIT License](LICENSE) 开源。
