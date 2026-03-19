#!/bin/sh

# 获取默认接口
get_default_iface() {
  iface=$(ip route | grep "default" | awk '{print $5}' | head -n 1)
  if [ -z "$iface" ]; then
    iface=$(ip link show up | grep -v "lo" | head -n 1 | awk -F': ' '{print $2}')
  fi
  echo "$iface"
}

IFACE=$(get_default_iface)

# 生成一个随机的MAC地址
generate_mac() {
  # 使用 /dev/urandom 获取随机数
  HEX1=$(hexdump -n 1 -e '1/1 "%02X"' /dev/urandom)
  HEX2=$(hexdump -n 1 -e '1/1 "%02X"' /dev/urandom)
  HEX3=$(hexdump -n 1 -e '1/1 "%02X"' /dev/urandom)
  # 保持前缀 (可以使用固定前缀，这里演示随机)
  echo "00:E0:4C:$HEX1:$HEX2:$HEX3"
}

# 获取新的MAC地址
NEW_MAC=$(generate_mac)
echo "针对接口 $IFACE 生成的新MAC地址为: $NEW_MAC"

# 使用新的MAC地址修改网卡的MAC地址
ip link set dev "$IFACE" down
ip link set dev "$IFACE" address "$NEW_MAC"
ip link set dev "$IFACE" up

# 验证修改是否成功
echo "验证修改结果:"
ip link show "$IFACE" | grep ether
