#!/bin/sh

MAC_FILE="./mac"

# 获取默认接口
get_default_iface() {
  iface=$(ip route | grep "default" | awk '{print $5}' | head -n 1)
  if [ -z "$iface" ]; then
    iface=$(ip link show up | grep -v "lo" | head -n 1 | awk -F': ' '{print $2}')
  fi
  echo "$iface"
}

IFACE=$(get_default_iface)

# 获取当前MAC地址并保存到文件
save_mac() {
    CURRENT_MAC=$(ip link show "$IFACE" | grep ether | awk '{print $2}')
    echo "当前的MAC地址 ($IFACE) 是: $CURRENT_MAC"
    echo "$CURRENT_MAC" > "$MAC_FILE"
    echo "已保存当前MAC地址到 $MAC_FILE"
}

# 从文件中恢复MAC地址
restore_mac() {
    if [ -f "$MAC_FILE" ]; then
        SAVED_MAC=$(cat "$MAC_FILE")
        echo "从文件恢复MAC地址: $SAVED_MAC"
        ip link set dev "$IFACE" down
        ip link set dev "$IFACE" address "$SAVED_MAC"
        ip link set dev "$IFACE" up
        echo "已恢复MAC地址到 $IFACE"
    else
        echo "MAC文件不存在: $MAC_FILE，无法恢复"
    fi
}

# 检查参数并执行对应的操作
if [ "$1" = "save" ]; then
    save_mac
elif [ "$1" = "restore" ]; then
    restore_mac
else
    echo "用法: $0 {save|restore}"
    echo "save: 保存当前的MAC地址"
    echo "restore: 恢复之前保存的MAC地址"
fi

