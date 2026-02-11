#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from flask import Flask, render_template, jsonify, request
import yaml
import os
import subprocess
from datetime import datetime
from pathlib import Path

app = Flask(__name__)

# 配置路径
CONFIG_FILE = '/app/config/gost.yml'
LOG_FILE = '/app/logs/update.log'
PANEL_PASSWORD = os.environ.get('PANEL_PASSWORD', 'qwert123')

def check_gost_running():
    """检查 Gost 进程是否运行"""
    try:
        result = subprocess.run(['pidof', 'gost'], capture_output=True, text=True)
        return result.returncode == 0
    except:
        return False

def load_gost_config():
    """加载 Gost 配置文件"""
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
                return yaml.safe_load(f)
        return None
    except Exception as e:
        print(f"Error loading config: {e}")
        return None

def get_proxy_count():
    """获取代理数量"""
    config = load_gost_config()
    if config and 'chains' in config:
        for chain in config['chains']:
            if 'hops' in chain:
                for hop in chain['hops']:
                    if 'nodes' in hop:
                        return len(hop['nodes'])
    return 0

def get_last_update_time():
    """获取最后更新时间"""
    try:
        if os.path.exists(LOG_FILE):
            mtime = os.path.getmtime(LOG_FILE)
            last_update = datetime.fromtimestamp(mtime)
            now = datetime.now()
            diff = now - last_update

            if diff.seconds < 60:
                return f"{diff.seconds}秒前"
            elif diff.seconds < 3600:
                return f"{diff.seconds // 60}分钟前"
            else:
                return f"{diff.seconds // 3600}小时前"
        return "未知"
    except:
        return "未知"

def parse_proxies_from_config(config):
    """从配置中解析代理列表"""
    proxies = []
    if config and 'chains' in config:
        for chain in config['chains']:
            if 'hops' in chain:
                for hop in chain['hops']:
                    if 'nodes' in hop:
                        for node in hop['nodes']:
                            proxy_info = {
                                'name': node.get('name', 'Unknown'),
                                'addr': node.get('addr', 'Unknown'),
                                'type': node.get('connector', {}).get('type', 'Unknown'),
                                'status': 'active'
                            }
                            proxies.append(proxy_info)
    return proxies

def read_recent_logs(lines=20):
    """读取最近的日志"""
    try:
        if os.path.exists(LOG_FILE):
            with open(LOG_FILE, 'r', encoding='utf-8') as f:
                all_lines = f.readlines()
                return [line.strip() for line in all_lines[-lines:]]
        return []
    except:
        return []

@app.route('/')
def index():
    """主页面"""
    return render_template('index.html')

@app.route('/api/status')
def get_status():
    """获取系统状态"""
    return jsonify({
        'gost_running': check_gost_running(),
        'proxy_count': get_proxy_count(),
        'last_update': get_last_update_time(),
        'listen_port': 10808
    })

@app.route('/api/proxies')
def get_proxies():
    """获取代理列表"""
    config = load_gost_config()
    proxies = parse_proxies_from_config(config)
    return jsonify(proxies)

@app.route('/api/logs')
def get_logs():
    """获取最近日志"""
    logs = read_recent_logs(lines=50)
    return jsonify(logs)

@app.route('/api/config')
def get_config():
    """获取配置文件内容"""
    config = load_gost_config()
    if config:
        return jsonify(config)
    return jsonify({'error': 'Config file not found'}), 404

@app.route('/api/socks5-address')
def get_socks5_address():
    """获取 SOCKS5 代理连接地址（需要密码验证）"""
    password = request.args.get('password', '')
    if password != PANEL_PASSWORD:
        return jsonify({'error': '密码错误'}), 403

    config = load_gost_config()
    if not config or 'services' not in config:
        return jsonify({'error': '配置文件未找到'}), 404

    port = '10808'
    username = ''
    password = ''

    for service in config['services']:
        handler = service.get('handler', {})
        if handler.get('type') == 'socks5':
            addr = service.get('addr', ':10808')
            port = addr.split(':')[-1] or '10808'
            auth = handler.get('auth', {})
            username = auth.get('username', '')
            password = auth.get('password', '')
            break

    host = os.environ.get('SOCKS5_HOST', '')
    if not host:
        req_host = request.host
        # 去掉端口号，只保留主机名
        host = req_host.split(':')[0]

    if username and password:
        address = f"socks5://{username}:{password}@{host}:{port}"
    else:
        address = f"socks5://{host}:{port}"

    return jsonify({
        'address': address,
        'host': host,
        'port': port,
        'username': username,
        'has_auth': bool(username and password)
    })

if __name__ == '__main__':
    # 确保日志目录存在
    os.makedirs('/app/logs', exist_ok=True)
    # 启动 Flask 应用
    app.run(host='0.0.0.0', port=5000, debug=False)