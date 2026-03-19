#!/bin/sh

# 获取 PPPoE 网关地址
get_gateway() {
    while true
    do
        GATEWAY=$(ip route | grep "default via" | grep "pppoe" | awk '{print $3}')
        if [ -n "$GATEWAY" ]; then
            echo "Gateway detected: $GATEWAY"
            return 0
        fi
        echo "Failed to get gateway address. Waiting for network to stabilize and retrying..."
        sleep 5
    done
}

# 初始化网关地址
get_gateway

# 设置失败次数计数器
FAIL_COUNT=0
# 设置连续失败的检测次数
MAX_FAIL=3
# 设置重拨后休眠时间（秒）
SLEEP_TIME=120
# 设置每次 ping 之间的间隔时间（1秒）
PING_INTERVAL=1

while true; do
    # 进行一次 ping 操作，仅发送一个数据包，超时设置为1秒
    if ping -c 1 -W 1 "$GATEWAY" > /dev/null 2>&1; then
        # ping 成功，重置失败计数器
        FAIL_COUNT=0
        echo "Ping to gateway $GATEWAY successful."
    else
        # ping 失败，增加失败计数器
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "Ping to gateway $GATEWAY failed. Failure count: $FAIL_COUNT"
    fi

    # 检查是否达到连续失败的最大次数
    if [ "$FAIL_COUNT" -ge "$MAX_FAIL" ]; then
        echo "Network appears to be down... Executing scripts to reconnect..."
        # 执行生成 MAC 地址脚本和重拨脚本
        /root/generate_mac.sh
        sleep 10
        /root/ipv4.sh
        # 休眠指定时间以等待网络恢复
        echo "Waiting for network to stabilize..."
        sleep "$SLEEP_TIME"
        # 重置失败计数器
        FAIL_COUNT=0
        # 重新获取网关地址
        echo "Attempting to get new gateway address after reconnection..."
        get_gateway
    fi

    # 每次 ping 之间休眠指定时间
    sleep "$PING_INTERVAL"
done