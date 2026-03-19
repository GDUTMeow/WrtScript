#!/bin/sh

# Cloudflare API 相关信息
# Cloudflare 的 Zone ID
CF_ZONE_ID=""
# Cloudflare 的 DNS 记录 ID
CF_RECORD_ID=""
# Cloudflare API Token，换成你自己的
CF_TOKEN=""
# Cloudflare 域名，换成你自己的，这个是你要访问的域名
CF_DOMAIN=""
# Cloudflare API 端点
CF_API="https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID"

# 获取 PPPoE 拨号的内网 IP 地址
INTERNAL_IP=$(ip -4 addr show pppoe-wan | awk '/inet/ {print $2}' | cut -d'/' -f1 | head -n 1)

# 判断是否获取到 IP 地址
if [ -z "$INTERNAL_IP" ]; then
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] 未能获取 PPPoE 内网 IP 地址"
  exit 1
fi

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] 当前 PPPoE 内网 IP 地址为：$INTERNAL_IP"

# 获取 Cloudflare 上的现有 DNS 记录 IP 地址
CURRENT_IP=$(curl -s -X GET "$CF_API" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" | \
  sed -n 's/.*"content":"\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\)".*/\1/p')

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Cloudflare 上的 IP 地址为：$CURRENT_IP"

# 检查是否需要更新
if [ "$INTERNAL_IP" = "$CURRENT_IP" ]; then
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Cloudflare 上的 IP 地址与当前 PPPoE 拨号的 IP 地址相同，无需更新。"
  exit 0
fi

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Cloudflare 上的 IP 地址为：$CURRENT_IP，正在更新为：$INTERNAL_IP"

# 构建 Cloudflare API 请求的 JSON 数据
DATA=$(cat <<EOF
{
  "type": "A",
  "name": "$CF_DOMAIN",
  "content": "$INTERNAL_IP",
  "ttl": 120,
  "proxied": false
}
EOF
)

# 使用 curl 发送请求到 Cloudflare 更新 DNS 记录
RESPONSE=$(curl -s -X PUT "$CF_API" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  --data "$DATA")

# 检查请求是否成功
if echo "$RESPONSE" | grep -q '"success":true'; then
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] Cloudflare DNS 记录更新成功：$INTERNAL_IP"
else
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] Cloudflare DNS 记录更新失败"
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] 响应内容：$RESPONSE"
  exit 1
fi
