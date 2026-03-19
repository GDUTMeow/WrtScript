#!/usr/bin/env fish

# Keep Connection - 自动检测连接状态并在断线时重拨

source utils_lib.fish

# 配置
set overhead_interval 1 # 检测间隔
set check_url "http://connect.rom.miui.com/generate_204"

function reconnect
    log_info "Network appears to be down... Reconnecting..."
    sh generate_mac.sh

    while true
        set gateway (ip route | grep "default via" | awk '{print $3}')
        if test -n "$gateway"
            log_success "Gateway detected: $gateway"
            break
        end
        sleep 1
    end

    fish login.fish
    sleep 3
    # fish ip.fish

    log_info "Waiting for network to stabilize..."
    log_info "Attempting to get new gateway address after reconnection..."
end

while true
    set http_code (curl -I -s -o /dev/null -w "%{http_code}" $check_url 2>/dev/null)

    if test "$http_code" = 204
        log_success "Connection check to $check_url successful."
        sleep $overhead_interval
    else
        if test "$http_code" = 302
            log_info "Detected captive portal (HTTP 302). Attempting to login..."
        else
            log_info "Connection check failed (HTTP $http_code). Reconnecting..."
        end

        reconnect

        # 登录/重连后多等一会儿，确保网关状态同步
        log_info "Post-reconnect cooldown..."
        sleep 5
    end
end
