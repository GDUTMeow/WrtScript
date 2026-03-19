function log_info
    printf "\033[36m%s %s\033[0m\n" "[INFO]" (string join " " $argv) >&2
end

function log_error
    printf "\033[31m%s %s\033[0m\n" "[ERROR]" (string join " " $argv) >&2
end

function log_success
    printf "\033[32m%s %s\033[0m\n" "[SUCCESS]" (string join " " $argv) >&2
end

function get_default_iface
    # 获取默认路由对应的网卡
    set -l iface (ip route | grep "default" | awk '{print $5}' | head -n 1)
    if test -z "$iface"
        # 回退到第一个非回环网卡
        set iface (ip link show up | grep -v "lo" | head -n 1 | awk -F': ' '{print $2}')
    end
    echo $iface
end