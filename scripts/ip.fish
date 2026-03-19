#!/usr/bin/env fish

# Cloudflare Dynamic DNS Updater (IPv4 & IPv6)
# 自动更新 Cloudflare DNS 记录为当前 default route 的 IP 地址
# 支持同时更新 IPv4 (A 记录) 和 IPv6 (AAAA 记录)
# 如果不需要更新某种类型的记录，请将对应的域名设为空，ID 可以留空以启用自动检测

source utils_lib.fish

# Cloudflare Zone ID
# DNS 配置主界面(https://dash.cloudflare.com/<ACCOUNT_ID>/<DOMAIN>) > API
# set ZONE_ID

# Cloudflare API Token
# set TOKEN

# IPv4 配置 (如果不需要 IPv4 更新，请将这些变量设为空)
# RECORD_ID 可以通过 API 获取
# set IPV4_DOMAIN 
# 留空以启用自动检测
# set IPV4_RECORD_ID 

# IPv6 配置 (如果不需要 IPv6 更新，请将这些变量设为空)
# set IPV6_DOMAIN
# 留空以启用自动检测
# set IPV6_RECORD_ID 

# DNS 记录配置
set DNS_TTL 120
set DNS_PROXIED false


function validate_ip
    
    set -l regex_A '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    set -l regex_AAAA '^([0-9A-Fa-f]{0,4}:){2,7}[0-9A-Fa-f]{0,4}$'

    set -l type $argv[1]
    set -l ip $argv[2]
    set -l regex (eval echo \${regex_$type})
    string match -q -r $regex $ip
end

function get_ip
    set -l type $argv[1]
    switch $type
        case A
            set ip (ip -4 route | grep "default" | awk '{print $NF}')
        case AAAA
            set ip (ip -6 addr show scope global | grep inet6 | head -1 | awk '{print $2}' | cut -d'/' -f1)
    end
    test -n "$ip"; or begin log_error "获取 $type 地址失败: $ip"; return 1; end
    validate_ip $type $ip; or begin log_error "$type 地址格式无效: $ip"; return 1; end
    echo $ip
end

function get_dns_record
    set -l type $argv[1]
    set -l id $argv[2]
    set -l url https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$id

    log_info "获取 $type 记录..."
    curl -s -X GET $url -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" | read -l response; or begin log_error "请求失败"; return 1; end
    string match -q '*"success":true*' $response; or begin log_error "Cloudflare API 错误: $response"; return 1; end

    set -l ip (echo $response | sed -n 's/.*"content":"\([^" ]*\)".*/\1/p')

    test -n "$ip"; or begin log_error "未提取到 IP"; return 1; end
    validate_ip $type $ip; or begin log_error "IP 格式无效: $ip"; return 1; end
    echo $ip
end

function update_cloudflare_dns_record
    set -l record_type $argv[1]  # "A" 或 "AAAA"
    set -l domain $argv[2]
    set -l record_id $argv[3]
    set -l new_ip $argv[4]
    
    set -l api_url "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id"
    
    log_info "正在更新 Cloudflare $record_type 记录..."
    
    # 构建 JSON 数据
    set -l json_data (printf '{
        "type": "%s",
        "name": "%s",
        "content": "%s",
        "ttl": %d,
        "proxied": %s
    }' $record_type $domain $new_ip $DNS_TTL $DNS_PROXIED)

    # 发送 API 请求
    set -l response (curl -s -X PUT "$api_url" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data "$json_data" 2>/dev/null)

    # 检查 curl 命令是否执行成功
    if test $status -ne 0
        log_error "网络请求失败，无法连接到 Cloudflare API"
        return 1
    end

    # 检查 API 响应是否为空
    if test -z "$response"
        log_error "Cloudflare API 返回空响应"
        return 1
    end

    # 检查请求是否成功
    if string match -q "*\"success\":true*" $response
        log_success "Cloudflare $record_type 记录更新成功"
        log_success "域名: $domain"
        log_success "新 IP: $new_ip"
        log_success "TTL: $DNS_TTL 秒"
        return 0
    else
        log_error "Cloudflare $record_type 记录更新失败"

        # 尝试解析错误信息
        set -l error_msg (echo $response | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
        if test -n "$error_msg"
            log_error "错误信息: $error_msg"
        end

        # 检查常见错误原因
        if string match -q "*authentication*" $response
            log_error "认证失败，请检查 TOKEN 是否正确"
        else if string match -q "*not found*" $response
            log_error "DNS 记录未找到，请检查 Record ID 是否正确"
        else if string match -q "*invalid*" $response
            log_error "请求参数无效，请检查配置"
        end

        log_error "完整响应内容: $response"
        return 1
    end
end  # update_cloudflare_dns_record 函数结束

# =============================================================================
# 自动检测并更新 Record ID
# =============================================================================
function auto_detect_record_id
    # 参数: record_type, domain, record_id_var_name
    set -l record_type $argv[1]
    set -l domain $argv[2]
    set -l record_id_var_name $argv[3]

    if test -z "$domain"
        # 未配置域名， nothing to do
        return 1
    end

    # 如果运行时已经有 Record ID，则直接返回
    set -l existing_id (eval echo \$$record_id_var_name)
    if test -n "$existing_id"
        echo $existing_id
        return 0
    end

    log_info "检测到 $record_type 域名 '$domain' 无 Record ID，尝试自动获取..."
    set -l list_url "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?per_page=200&order=type&direction=asc&type=$record_type&name=$domain"
    set -l resp (curl -s -G "$list_url" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json")

    # 提取第一个匹配记录的 ID
    set -l id (echo $resp | awk -F'"id":' '{print $2}' | cut -d '"' -f2 | head -n 1)
    if test -n "$id"
        log_success "$record_type Record ID 获取成功: $id"
        # 确保变量定义未被注释
        sed -i "s@^#\s*set $record_id_var_name@set $record_id_var_name@" (status --current-filename)
        # 更新运行时变量
        set $record_id_var_name $id
        # 自我更新脚本文件中对应行
        sed -i "s@set $record_id_var_name.*@set $record_id_var_name \"$id\"@" (status --current-filename)
        # 返回 id 以便调用处捕获
        echo $id
        return 0
    else
        log_error "未能获取 $record_type Record ID，请手动配置变量 $record_id_var_name"
        return 1
    end
end

# =============================================================================
# 主程序
# =============================================================================

log_info "开始检查 Cloudflare DNS 记录更新..."

set -l record_var_names IPV4_RECORD_ID IPV6_RECORD_ID

# 支持的记录类型数组
set -l types A AAAA
set -l domains $IPV4_DOMAIN $IPV6_DOMAIN
set -l record_ids $IPV4_RECORD_ID $IPV6_RECORD_ID

for i in (seq (count $types))
    set -l type $types[$i]
    set -l domain $domains[$i]
    set -l record_id $record_ids[$i]
    set -l record_var_name $record_var_names[$i]

    if test -z "$domain"
        log_info "$type 记录域名未配置，跳过"
        continue
    end

    # 自动检测并更新 Record ID（如果需要），并捕获返回的 id
    if test -z "$record_id"
        set -l detected_id (auto_detect_record_id $type $domain $record_var_name)
        if test $status -ne 0 -o -z "$detected_id"
            log_error "$type Record ID 未找到，跳过 $domain"
            continue
        end
        set record_id $detected_id
    end

    log_info "=== 处理 $type 记录 ($domain) ==="
    # 获取本地 IP
    set -l local_ip (get_ip $type)
    if test $status -ne 0
        log_error "获取本地 $type 地址失败，跳过"
        continue
    end
    log_info "本地 $type 地址: $local_ip"

    # 获取远程记录
    set -l remote_ip (get_dns_record $type $record_id)
    if test $status -ne 0
        log_error "获取远程 $type 记录失败，跳过"
        continue
    end
    log_info "远程 $type 记录: $remote_ip"

    if test "$local_ip" = "$remote_ip"
        log_info "$type 地址无变化，跳过更新"
        continue
    end

    log_info "$type 地址变化，更新记录"
    if update_cloudflare_dns_record $type $domain $record_id $local_ip
        log_success "$type 记录更新成功: $local_ip"
    else
        log_error "$type 记录更新失败"
    end
end
