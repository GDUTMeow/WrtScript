#!/bin/ash

# OpenWrt 备份与恢复管理脚本
# 支持命令行参数快速备份：--owrt-backup --config-backup --iptables-backup --firewall-backup --all-backup

# 定义备份目录
BACKUP_DIR="/mnt/usb1-1"

# 系统参数
OPENWRT_MMC="/dev/mmcblk0"
FIREWALL_CONFIG="/etc/config/firewall"

# 备份子目录
OPENWRT_BACKUP_DIR="$BACKUP_DIR/openwrt-backup"
OPENWRT_CONFIG_BACKUP_DIR="$BACKUP_DIR/openwrt-config-backup"
IPTABLES_BACKUP_DIR="$BACKUP_DIR/iptables-backup"
FIREWALL_BACKUP_DIR="$BACKUP_DIR/firewall-backup"

# 初始化目录
mkdir -p $OPENWRT_BACKUP_DIR $OPENWRT_CONFIG_BACKUP_DIR $IPTABLES_BACKUP_DIR $FIREWALL_BACKUP_DIR

# 获取当前日期
CURRENT_DATE=$(date +%Y%m%d)

# 定义颜色代码
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

# 时间戳函数
get_timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

#######################################
# 核心备份功能函数
#######################################

backup_full_image() {
  echo -e "${BLUE}[$(get_timestamp)] [1/4] 开始备份系统镜像...${RESET}"
  local temp_bin="$OPENWRT_BACKUP_DIR/temp_${CURRENT_DATE}.bin"
  local backup_file="$OPENWRT_BACKUP_DIR/openwrt-backup-${CURRENT_DATE}.tar.gz"
  
  # 创建磁盘镜像
  if ! dd if="$OPENWRT_MMC" of="$temp_bin" bs=1M; then
    echo -e "${RED}[$(get_timestamp)] 错误：磁盘镜像创建失败！${RESET}"
    return 1
  fi
  
  # 压缩备份
  if tar -czf "$backup_file" -C "$OPENWRT_BACKUP_DIR" $(basename $temp_bin); then
    md5sum $backup_file > ${backup_file}.md5
    echo -e "${GREEN}[$(get_timestamp)] 系统镜像备份成功：${backup_file}${RESET}"
  else
    echo -e "${RED}[$(get_timestamp)] 错误：压缩备份失败！${RESET}"
  fi
  rm -f $temp_bin
}

restore_full_image() {
  echo -e "${BLUE}[$(get_timestamp)] [系统恢复] 请选择备份文件：${RESET}"
  ls -lh $OPENWRT_BACKUP_DIR/openwrt-backup-*.tar.gz 2>/dev/null || { echo -e "${RED}[$(get_timestamp)] 未找到备份文件！${RESET}"; return; }
  
  read -p "请输入要恢复的文件名: " backup_file
  local full_path="$OPENWRT_BACKUP_DIR/$backup_file"
  
  # 验证文件
  [ ! -f "$full_path" ] && echo -e "${RED}[$(get_timestamp)] 文件不存在！${RESET}" && return
  [ ! -f "${full_path}.md5" ] && echo -e "${YELLOW}[$(get_timestamp)] 警告：未找到MD5校验文件${RESET}" || (md5sum -c "${full_path}.md5" || { echo -e "${RED}[$(get_timestamp)] MD5校验失败！${RESET}"; return; })
  
  # 确认操作
  read -p "确定要恢复系统镜像吗？此操作不可逆！[y/N]: " confirm
  [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && return
  
  # 解压并恢复
  echo -e "${BLUE}[$(get_timestamp)] 正在解压镜像文件...${RESET}"
  local temp_bin="${full_path%.tar.gz}.bin"
  tar -xzf "$full_path" -C "$OPENWRT_BACKUP_DIR" || { echo -e "${RED}[$(get_timestamp)] 解压失败！${RESET}"; return; }
  
  echo -e "${BLUE}[$(get_timestamp)] 正在写入系统镜像...${RESET}"
  if dd if="$temp_bin" of="$OPENWRT_MMC" bs=1M; then
    echo -e "${GREEN}[$(get_timestamp)] 系统恢复成功，请重启设备！${RESET}"
  else
    echo -e "${RED}[$(get_timestamp)] 镜像写入失败！${RESET}"
  fi
  rm -f $temp_bin
}

backup_config() {
  echo -e "${BLUE}[$(get_timestamp)] [2/4] 备份系统配置...${RESET}"
  local backup_file="$OPENWRT_CONFIG_BACKUP_DIR/openwrt-config-backup-${CURRENT_DATE}.bak"
  if sysupgrade -b $backup_file; then
    md5sum $backup_file > ${backup_file}.md5
    echo -e "${GREEN}[$(get_timestamp)] 系统配置备份成功：${backup_file}${RESET}"
  else
    echo -e "${RED}[$(get_timestamp)] 错误：配置备份失败！${RESET}"
  fi
}

restore_config() {
  echo -e "${BLUE}[$(get_timestamp)] [配置恢复] 请选择备份文件：${RESET}"
  ls -lh $OPENWRT_CONFIG_BACKUP_DIR/openwrt-config-backup-*.bak 2>/dev/null || { echo -e "${RED}[$(get_timestamp)] 未找到备份文件！${RESET}"; return; }
  
  read -p "请输入要恢复的文件名: " backup_file
  local full_path="$OPENWRT_CONFIG_BACKUP_DIR/$backup_file"
  
  # 验证文件
  [ ! -f "$full_path" ] && echo -e "${RED}[$(get_timestamp)] 文件不存在！${RESET}" && return
  [ ! -f "${full_path}.md5" ] && echo -e "${YELLOW}[$(get_timestamp)] 警告：未找到MD5校验文件${RESET}" || (md5sum -c "${full_path}.md5" || { echo -e "${RED}[$(get_timestamp)] MD5校验失败！${RESET}"; return; })
  
  # 确认操作
  read -p "确定要恢复系统配置吗？[y/N]: " confirm
  [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && return
  
  # 创建临时备份
  local current_backup="$OPENWRT_CONFIG_BACKUP_DIR/current_config_$(date +%H%M%S).bak"
  sysupgrade -b $current_backup || { echo -e "${RED}[$(get_timestamp)] 当前配置备份失败，已中止恢复！${RESET}"; return; }
  
  # 执行恢复
  if sysupgrade -r $full_path; then
    echo -e "${GREEN}[$(get_timestamp)] 配置恢复成功，正在重启网络服务...${RESET}"
    /etc/init.d/network restart
  else
    echo -e "${RED}[$(get_timestamp)] 配置恢复失败！${RESET}"
  fi
}

backup_iptables() {
  echo -e "${BLUE}[$(get_timestamp)] [3/4] 备份iptables规则...${RESET}"
  local backup_file="$IPTABLES_BACKUP_DIR/iptables-backup-${CURRENT_DATE}.bak"
  if iptables-save > $backup_file; then
    md5sum $backup_file > ${backup_file}.md5
    echo -e "${GREEN}[$(get_timestamp)] iptables备份成功：${backup_file}${RESET}"
  else
    echo -e "${RED}[$(get_timestamp)] 错误：iptables备份失败！${RESET}"
  fi
}

restore_iptables() {
  echo -e "${BLUE}[$(get_timestamp)] [iptables恢复] 请选择备份文件：${RESET}"
  ls -lh $IPTABLES_BACKUP_DIR/iptables-backup-*.bak 2>/dev/null || { echo -e "${RED}[$(get_timestamp)] 未找到备份文件！${RESET}"; return; }
  
  read -p "请输入要恢复的文件名: " backup_file
  local full_path="$IPTABLES_BACKUP_DIR/$backup_file"
  
  # 验证文件
  [ ! -f "$full_path" ] && echo -e "${RED}[$(get_timestamp)] 文件不存在！${RESET}" && return
  [ ! -f "${full_path}.md5" ] && echo -e "${YELLOW}[$(get_timestamp)] 警告：未找到MD5校验文件${RESET}" || (md5sum -c "${full_path}.md5" || { echo -e "${RED}[$(get_timestamp)] MD5校验失败！${RESET}"; return; })
  
  # 确认操作
  read -p "确定要恢复iptables规则吗？[y/N]: " confirm
  [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && return
  
  if iptables-restore < $full_path; then
    echo -e "${GREEN}[$(get_timestamp)] iptables规则恢复成功！${RESET}"
  else
    echo -e "${RED}[$(get_timestamp)] 规则恢复失败，请检查文件格式！${RESET}"
  fi
}

backup_firewall() {
  echo -e "${BLUE}[$(get_timestamp)] [4/4] 备份防火墙配置...${RESET}"
  local backup_file="$FIREWALL_BACKUP_DIR/firewall-backup-${CURRENT_DATE}.bak"
  if cp $FIREWALL_CONFIG $backup_file; then
    md5sum $backup_file > ${backup_file}.md5
    echo -e "${GREEN}[$(get_timestamp)] 防火墙配置备份成功：${backup_file}${RESET}"
  else
    echo -e "${RED}[$(get_timestamp)] 错误：防火墙配置备份失败！${RESET}"
  fi
}

restore_firewall() {
  echo -e "${BLUE}[$(get_timestamp)] [防火墙恢复] 请选择备份文件：${RESET}"
  ls -lh $FIREWALL_BACKUP_DIR/firewall-backup-*.bak 2>/dev/null || { echo -e "${RED}[$(get_timestamp)] 未找到备份文件！${RESET}"; return; }
  
  read -p "请输入要恢复的文件名: " backup_file
  local full_path="$FIREWALL_BACKUP_DIR/$backup_file"
  
  # 验证文件
  [ ! -f "$full_path" ] && echo -e "${RED}[$(get_timestamp)] 文件不存在！${RESET}" && return
  [ ! -f "${full_path}.md5" ] && echo -e "${YELLOW}[$(get_timestamp)] 警告：未找到MD5校验文件${RESET}" || (md5sum -c "${full_path}.md5" || { echo -e "${RED}[$(get_timestamp)] MD5校验失败！${RESET}"; return; })
  
  # 确认操作
  read -p "确定要恢复防火墙配置吗？[y/N]: " confirm
  [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && return
  
  # 备份当前配置
  local current_backup="$FIREWALL_BACKUP_DIR/current_firewall_$(date +%H%M%S).bak"
  cp $FIREWALL_CONFIG $current_backup || { echo -e "${RED}[$(get_timestamp)] 当前配置备份失败，已中止恢复！${RESET}"; return; }
  
  if cp $full_path $FIREWALL_CONFIG; then
    echo -e "${GREEN}[$(get_timestamp)] 防火墙配置恢复成功，正在重启服务...${RESET}"
    /etc/init.d/firewall restart
  else
    echo -e "${RED}[$(get_timestamp)] 配置恢复失败！${RESET}"
  fi
}

#######################################
# 命令行参数处理
#######################################

print_banner() {
  echo -e "${YELLOW}"
  echo "                    _              _   _ _       _"
  echo "  _____      ___ __| |_      _   _| |_(_) |  ___| |__"
  echo " / _ \ \ /\ / / '__| __|____| | | | __| | | / __| '_ \\"
  echo "| (_) \ V  V /| |  | ||_____| |_| | |_| | |_\__ \ | | |"
  echo " \___/ \_/\_/ |_|   \__|     \__,_|\__|_|_(_)___/_| |_|"
  echo -e "${RESET}"
  echo -e "${BLUE}            —— OpenWrt备份工具 @GamerNoTitle${RESET}"
  echo -e "${BLUE}               https://bili33.top${RESET}\n"
}

if [ $# -gt 0 ]; then
  print_banner
  echo -e "${GREEN}[$(get_timestamp)] 检测到命令行参数，进入快速备份模式...${RESET}"
  
  # 处理多个参数
  for param in "$@"; do
    case $param in
      --owrt-backup)    backup_full_image ;;
      --config-backup)  backup_config ;;
      --iptables-backup) backup_iptables ;;
      --firewall-backup) backup_firewall ;;
      --all-backup)
        backup_full_image
        backup_config
        backup_iptables
        backup_firewall
        ;;
      *) echo -e "${RED}[$(get_timestamp)] 错误：未知参数 $param${RESET}"; exit 1 ;;
    esac
  done
  exit 0
fi

#######################################
# 交互式菜单系统
#######################################

show_menu() {
  clear
  print_banner
  echo -e "${YELLOW}======================= owrt-util.sh ========================${RESET}"
  echo -e "${YELLOW}                 OpenWrt 备份与恢复管理脚本                  ${RESET}"
  echo -e "${YELLOW}                    https://bili33.top                       ${RESET}"
  echo -e "${YELLOW}=============================================================${RESET}"
  echo "1. 完整系统备份 (磁盘镜像)"
  echo "2. 系统配置备份"
  echo "3. iptables规则备份"
  echo "4. 防火墙配置备份"
  echo "5. 一键全量备份"
  echo -e "${YELLOW}-------------------------------------------------------------${RESET}"
  echo "6. 恢复系统镜像"
  echo "7. 恢复系统配置"
  echo "8. 恢复iptables规则"
  echo "9. 恢复防火墙配置"
  echo -e "${YELLOW}-------------------------------------------------------------${RESET}"
  echo "0. 退出"
  echo -e "${YELLOW}=============================================================${RESET}"
  echo -n "请输入选择: "
}


while true; do
  show_menu
  read choice
  case $choice in
    1) backup_full_image ;;
    2) backup_config ;;
    3) backup_iptables ;;
    4) backup_firewall ;;
    5)
      backup_full_image
      backup_config
      backup_iptables
      backup_firewall
      ;;
    6) restore_full_image ;;
    7) restore_config ;;
    8) restore_iptables ;;
    9) restore_firewall ;;
    0) exit 0 ;;
    *) echo -e "${RED}[$(get_timestamp)] 无效输入，请重新选择！${RESET}" ;;
  esac
  echo -e "\n${BLUE}[$(get_timestamp)] 按回车返回菜单...${RESET}"
  read
done