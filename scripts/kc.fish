#!/usr/bin/env fish

# Keep Connection - 自动检测连接状态并在断线时重拨

source utils_lib.fish

# 重试配置
set max_retry 30 # 最多重试次数

# 设置重拨后休眠时间（秒）
set sleep_time 10
set overhead_interval 3
set max_fail 3

set ping_target "https://baidu.com"

function reconnect
    echo "Network appears to be down... Reconnecting..."
    /root/generate_mac.sh
    while true
        set gateway (ip route | grep "default via" | awk '{print $3}')
        if test -n "$gateway"
            log_success "Gateway detected: $gateway"
            break
        end
    end
    /root/login.fish
    sleep 25
    /root/ip.fish
    echo "Waiting for network to stabilize..."
    sleep $sleep_time
    echo "Attempting to get new gateway address after reconnection..."
end

while true
    set count 0
    while not curl -I --connect-timeout 1 $ping_target >/dev/null 2>&1
        set count (math "$count + 1")
        if test $count -gt $max_fail
            reconnect
            break
        end
        log_info "Ping to target $ping_target failed. Failure count: $count. Retrying..."
    end
    log_success "Ping to target $ping_target successful."

    sleep $overhead_interval
end
