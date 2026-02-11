// 自动刷新间隔（毫秒）
const REFRESH_INTERVAL = 10000;

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', function() {
    refreshData();
    setInterval(refreshData, REFRESH_INTERVAL);
});

// 刷新所有数据
async function refreshData() {
    await Promise.all([
        updateStatus(),
        updateProxies(),
        updateLogs()
    ]);
    updateRefreshTime();
}

// 解锁 SOCKS5 地址（密码验证）
async function unlockSocks5() {
    const passwordInput = document.getElementById('panel-password');
    const password = passwordInput.value.trim();
    if (!password) {
        passwordInput.focus();
        return;
    }

    try {
        const response = await fetch('/api/socks5-address?password=' + encodeURIComponent(password));
        const data = await response.json();

        if (response.status === 403) {
            showToast('密码错误，请重试');
            passwordInput.value = '';
            passwordInput.focus();
            return;
        }

        if (data.error) {
            showToast(data.error);
            return;
        }

        // 验证成功，切换显示
        document.getElementById('socks5-address').textContent = data.address;
        document.getElementById('socks5-auth').style.display = 'none';
        document.getElementById('socks5-reveal').style.display = 'block';
        const badge = document.getElementById('socks5-badge');
        badge.textContent = '已解锁';
        badge.classList.remove('badge-locked');
        badge.classList.add('badge-unlocked');
    } catch (error) {
        console.error('验证失败:', error);
        showToast('网络错误，请重试');
    }
}

// 一键复制 SOCKS5 地址
async function copySocks5Address() {
    const address = document.getElementById('socks5-address').textContent;
    if (!address || address === '加载中...' || address === '加载失败') return;

    try {
        await navigator.clipboard.writeText(address);
        showToast('已复制到剪贴板');
    } catch {
        // fallback
        const textarea = document.createElement('textarea');
        textarea.value = address;
        textarea.style.position = 'fixed';
        textarea.style.opacity = '0';
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
        showToast('已复制到剪贴板');
    }
}

// Toast 提示
function showToast(message) {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.classList.add('show');
    setTimeout(() => toast.classList.remove('show'), 2000);
}

// 更新系统状态
async function updateStatus() {
    try {
        const response = await fetch('/api/status');
        const data = await response.json();

        const statusElement = document.getElementById('gost-status');
        if (data.gost_running) {
            statusElement.textContent = '运行中';
            statusElement.style.color = '#2E7D32';
        } else {
            statusElement.textContent = '已停止';
            statusElement.style.color = '#C62828';
        }

        document.getElementById('proxy-count').textContent = data.proxy_count + ' 个';
        document.getElementById('last-update').textContent = data.last_update;
        document.getElementById('listen-port').textContent = data.listen_port;

    } catch (error) {
        console.error('获取状态失败:', error);
        document.getElementById('gost-status').textContent = '错误';
    }
}

// 更新代理列表
async function updateProxies() {
    try {
        const response = await fetch('/api/proxies');
        const proxies = await response.json();

        const tbody = document.getElementById('proxy-list');

        if (proxies.length === 0) {
            tbody.innerHTML = '<tr><td colspan="4" class="loading">暂无代理数据</td></tr>';
            return;
        }

        tbody.innerHTML = proxies.map(proxy => {
            const statusClass = proxy.status === 'active' ? 'status-active' : 'status-inactive';
            const statusText = proxy.status === 'active' ? '活跃' : '离线';

            return `
                <tr>
                    <td>${escapeHtml(proxy.name)}</td>
                    <td>${escapeHtml(proxy.addr)}</td>
                    <td>${escapeHtml(proxy.type.toUpperCase())}</td>
                    <td><span class="status-badge ${statusClass}">${statusText}</span></td>
                </tr>
            `;
        }).join('');

    } catch (error) {
        console.error('获取代理列表失败:', error);
        document.getElementById('proxy-list').innerHTML =
            '<tr><td colspan="4" class="loading">加载失败</td></tr>';
    }
}

// 更新日志
async function updateLogs() {
    try {
        const response = await fetch('/api/logs');
        const logs = await response.json();

        const logsContent = document.getElementById('logs-content');

        if (logs.length === 0) {
            logsContent.textContent = '暂无日志记录';
            return;
        }

        logsContent.textContent = logs.reverse().join('\n');

    } catch (error) {
        console.error('获取日志失败:', error);
        document.getElementById('logs-content').textContent = '日志加载失败';
    }
}

// 只刷新日志
async function refreshLogs() {
    await updateLogs();
    updateRefreshTime();
}

// 更新刷新时间
function updateRefreshTime() {
    const now = new Date();
    document.getElementById('refresh-time').textContent = now.toLocaleTimeString('zh-CN');
}

// HTML 转义函数（防止 XSS）
function escapeHtml(text) {
    const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    };
    return text.replace(/[&<>"']/g, m => map[m]);
}
