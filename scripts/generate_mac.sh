#!/bin/sh

# 生成一个随机的MAC地址
generate_mac() {
  # 固定的前缀，格式为 aa:bb:cc
  # PREFIX=""
  
  # 使用 /dev/urandom 获取随机数
  HEX1=$(hexdump -n 1 -e '1/1 "%02X"' /dev/urandom)
  HEX2=$(hexdump -n 1 -e '1/1 "%02X"' /dev/urandom)
  HEX3=$(hexdump -n 1 -e '1/1 "%02X"' /dev/urandom)
  echo "$PREFIX:$HEX1:$HEX2:$HEX3"
}

# 获取新的MAC地址
NEW_MAC=$(generate_mac)
echo "生成的新MAC地址为: $NEW_MAC"

# 使用新的MAC地址修改eth0的MAC地址
ip link set dev eth0 down
ip link set dev eth0 address $NEW_MAC
ip link set dev eth0 up

# 验证修改是否成功
ip link show eth0 | grep ether
