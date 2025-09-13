#!/usr/bin/env fish

# 如果你采用 PPPOE 方案则不用设置账号和密码
# set user_account ""
# set password ""

# 获取 eth0 接口的 IPv4 地址
set -l ip_address (ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

# 检查是否成功获取到 IP 地址
if test -z "$ip_address"
    echo "错误: 无法获取 eth0 接口的 IP 地址"
    exit 1
end

echo "获取到的 IP 地址: $ip_address"

if test -n "$user_account"; and test -n "$password"
    # 执行 curl 命令，将 IP 地址替换到相应位置
    curl "http://10.0.3.2:801/eportal/portal/login?callback=dr1004&login_method=1&user_account=%2C0%2C$user_account&user_password=$password&wlan_user_ip=$ip_address&wlan_user_ipv6=&wlan_ac_ip=172.16.254.2&wlan_ac_name=&jsVersion=4.1.3&terminal_type=1&lang=zh-cn&v=6985&lang=zh" \
    -H 'Accept: */*' \
    -H 'Accept-Language: zh-CN,zh;q=0.9' \
    -H 'Connection: keep-alive' \
    -H 'Referer: http://10.0.3.2/' \
    -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36' \
    --insecure
end
