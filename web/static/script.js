// 自动刷新间隔（毫秒）
const REFRESH_INTERVAL = 10000;

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', function() {
    console.log('Gost 代理池管理面板已加载');
    
    // 立即加载数据
    refreshData();
    
    // 设置自动刷新
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

// 更新系统状态
async function updateStatus() {
    try {
        const response = await fetch('/api/status');
        const data = await response.json();
        
        // 更新 Gost 状态
        const statusElement = document.getElementById('gost-status');
        if (data.gost_running) {
            statusElement.textContent = '🟢 运行中';
            statusElement.style.color = '#28a745';
        } else {
            statusElement.textContent = '🔴 已停止';
            statusElement.style.color = '#dc3545';
        }
        
        // 更新代理总数
        document.getElementById('proxy-count').textContent = `${data.proxy_count} 个`;
        
        // 更新最后更新时间
        document.getElementById('last-update').textContent = data.last_update;
        
        // 更新监听端口
        document.getElementById('listen-port').textContent = data.listen_port;
        
    } catch (error) {
        console.error('获取状态失败:', error);
        document.getElementById('gost-status').textContent = '❌ 错误';
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
        
        // 生成表格行
        tbody.innerHTML = proxies.map(proxy => {
            const statusClass = proxy.status === 'active' ? 'status-active' : 'status-inactive';
            const statusText = proxy.status === 'active' ? '🟢 活跃' : '🔴 离线';
            
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
        
        // 显示日志（最新的在上面）
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
    const timeString = now.toLocaleTimeString('zh-CN');
    document.getElementById('refresh-time').textContent = timeString;
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

// 格式化时间
function formatTime(timestamp) {
    const date = new Date(timestamp * 1000);
    return date.toLocaleString('zh-CN');
}

// 显示通知（可选功能）
function showNotification(message, type = 'info') {
    console.log(`[${type.toUpperCase()}] ${message}`);
    // 可以在这里添加更复杂的通知UI
}