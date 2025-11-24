#!/bin/bash
# START OF FILE start.sh

echo "Starting Gost Proxy Container..."

# 1. 启动 Cron 守护进程 (后台运行)
# -s: 前台运行 (不使用，我们需要它在后台)
# -L: 日志级别
crond -b -L /var/log/crond.log
echo "Cron daemon started."

# 2. 首次运行更新脚本，确保启动时有配置文件
if [ ! -f "/app/gost.yaml" ] && [ -z "$GOST_CONFIG" ]; then
    echo "Config not found, running update_proxies.sh for the first time..."
    ./update_proxies.sh
fi

# 3. 启动 Gost
# 使用 exec 让 gost 替换当前 shell 成为 PID 1，接收系统信号
echo "Starting Gost..."
exec gost -C /app/gost.yaml
# END OF FILE start.sh
