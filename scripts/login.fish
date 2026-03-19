#!/usr/bin/env fish

source utils_lib.fish

# 如果你采用 PPPOE 方案则不用设置账号和密码
# set user_account ""
# set password ""

# 动态获取默认接口
set -l iface (get_default_iface)
# 使用 awk 替代 grep -oP 提取 IP
set -l ip_address (ip -4 addr show $iface | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -n 1)

# 检查是否成功获取到 IP 地址
if test -z "$ip_address"
    log_error "无法获取接口 $iface 的 IP 地址"
    exit 1
end

log_info "获取到的 IP 地址 ($iface): $ip_address"

if test -n "$user_account"; and test -n "$password"
    echo 正在尝试登录...
    curl "http://10.0.3.2:801/eportal/portal/login?callback=dr1004&login_method=1&user_account=%2C0%2C$user_account&user_password=$password&wlan_user_ip=$ip_address&wlan_user_ipv6=&wlan_ac_ip=172.16.254.2&wlan_ac_name=&jsVersion=4.1.3&terminal_type=1&lang=zh-cn&v=6985&lang=zh" \
        -H 'Accept: */*' \
        -H 'Accept-Language: zh-CN,zh;q=0.9' \
        -H 'Connection: keep-alive' \
        -H 'Referer: http://10.0.3.2/' \
        -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36' \
        --insecure
end
