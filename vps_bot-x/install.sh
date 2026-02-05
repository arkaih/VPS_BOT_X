#!/bin/bash
# VPS 遥控器 (Sentinel-X) 安装向导
# 版本: V6.8 (修复根目录运行时的递归复制 Bug)

# 定义颜色
GREEN='\033[0;32m'
SKY='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${SKY}==============================================${NC}"
echo -e "     VPS 遥控器 (Sentinel-X) 安装向导 V6.8     "
echo -e "${SKY}==============================================${NC}"
echo ""

# ✅ Root 权限检查
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误: 请使用 root 用户运行此脚本!${NC}"
   exit 1
fi

# ✅ 路径定义
SOURCE_DIR=$(cd $(dirname $0); pwd)
TARGET_DIR="/root/vps_bot-x"

echo -e "${GREEN}>>> [1/6] 检查系统环境...${NC}"
# 增加 -qq 防止刷屏，增加 DEBIAN_FRONTEND 防止弹窗
export DEBIAN_FRONTEND=noninteractive

# Python 版本检查
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}未检测到 Python3，正在安装...${NC}"
    apt update -y > /dev/null 2>&1
    apt install -y python3 python3-pip > /dev/null 2>&1
fi
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo -e "${SKY}    系统版本: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)${NC}"
echo -e "${SKY}    Python 版本: $PYTHON_VERSION${NC}"

echo -e "${GREEN}>>> [2/6] 正在安装系统依赖...${NC}"
apt update -y > /dev/null 2>&1
apt install -y curl nano git vnstat nethogs iptables net-tools > /dev/null 2>&1

# 配置 vnstat
systemctl enable vnstat > /dev/null 2>&1
systemctl restart vnstat > /dev/null 2>&1

echo -e "${GREEN}>>> [3/6] 同步代码并安装 Python 库...${NC}"

# ✅✅✅ 核心修复：防根目录复制逻辑 ✅✅✅
mkdir -p "$TARGET_DIR"

# 只有当当前目录下存在 main.py 时，才认为是本地安装包
if [ -f "$SOURCE_DIR/main.py" ] && [ "$SOURCE_DIR" != "$TARGET_DIR" ]; then
    echo -e "${SKY}    检测到本地安装包，正在同步...${NC}"
    cp -r "$SOURCE_DIR"/* "$TARGET_DIR/"
    
# 如果本地没有代码，强制去 GitHub 拉取
elif [ ! -f "$TARGET_DIR/main.py" ]; then
    echo -e "${SKY}    本地无代码，正在从 GitHub 克隆...${NC}"
    TEMP_DIR=$(mktemp -d)
    # 克隆整个仓库
    git clone --depth 1 https://github.com/MEILOI/VPS_BOT_X.git "$TEMP_DIR" > /dev/null 2>&1
    
    # 检查 clone 是否成功
    if [ -d "$TEMP_DIR/vps_bot-x" ]; then
        cp -r "$TEMP_DIR/vps_bot-x/"* "$TARGET_DIR/"
    else
        echo -e "${RED}错误: GitHub 拉取失败或仓库结构不对！${NC}"
        echo -e "${YELLOW}请检查网络或仓库地址。${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    rm -rf "$TEMP_DIR"
else
    echo -e "${GREEN}    ✓ 目标目录已有代码，执行增量更新${NC}"
fi

# 安装依赖
pip3 install python-telegram-bot psutil requests netifaces schedule --break-system-packages > /dev/null 2>&1

echo -e "${GREEN}>>> [4/6] 配置初始化...${NC}"
CONFIG_FILE="/root/sentinel_config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}未检测到配置文件，开始引导...${NC}"
    read -p "请输入 Bot Token: " INPUT_TOKEN
    read -p "请输入管理员 User ID: " INPUT_ID
    read -p "服务器备注 (如: 搬瓦工): " INPUT_NAME
    INPUT_NAME=${INPUT_NAME:-MyVPS}

    cat > "$CONFIG_FILE" <<EOF
{
  "bot_token": "${INPUT_TOKEN}",
  "admin_id": ${INPUT_ID},
  "server_remark": "${INPUT_NAME}",
  "ban_threshold": 5,
  "ban_duration": "permanent",
  "daily_report_times": ["08:00", "20:00"],
  "traffic_limit_gb": 1024,
  "billing_day": 1,
  "daily_warn_gb": 50,
  "traffic_daily_report": true,
  "backup_paths": ["${TARGET_DIR}"],
  "backup_exclude": ["*.log", "*.tmp", "__pycache__", "cache"],
  "auto_backup": {"mode": "off", "time": "03:00"}
}
EOF
else
    echo -e "${GREEN}    ✓ 检测到现有配置，已跳过初始化${NC}"
fi

echo -e "${GREEN}>>> [5/6] 注册系统服务...${NC}"

cat > /etc/systemd/system/vpsbot.service <<EOF
[Unit]
Description=VPS Remote Controller Bot X
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${TARGET_DIR}
ExecStart=/usr/bin/python3 ${TARGET_DIR}/main.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vpsbot > /dev/null 2>&1
systemctl restart vpsbot

echo -e "${GREEN}>>> [6/6] 安装快捷指令 'kk'...${NC}"

cat > /usr/bin/kk <<EOFKK
#!/bin/bash
while true; do
    clear
    if systemctl is-active --quiet vpsbot; then
        STATUS_TEXT="\033[0;32m● 运行中 (Running)\033[0m"
    else
        STATUS_TEXT="\033[0;31m● 已停止 (Stopped)\033[0m"
    fi

    echo -e "\033[0;36m==============================\033[0m"
    echo -e "     VPS 遥控器-X 控制台 作者:thex        "
    echo -e "     当前状态: \${STATUS_TEXT}"
    echo -e "\033[0;36m==============================\033[0m"
    echo -e "  [1] 启动  [2] 重启  [3] 停止"
    echo -e "  [4] 日志  [5] 配置  [0] 退出"
    echo -e "  [6] 更新代码 (V6.8)"
    read -p "请选择: " choice
    case \$choice in
        1) systemctl start vpsbot; echo "正在启动..." ;;
        2) systemctl restart vpsbot; echo "正在重启..." ;;
        3) systemctl stop vpsbot; echo "正在停止..." ;;
        4) journalctl -u vpsbot -f -n 50 ;;
        5) nano /root/sentinel_config.json ;;
        6) bash <(curl -fsSL https://raw.githubusercontent.com/MEILOI/VPS_BOT_X/main/vps_bot-x/install.sh) ;;
        0) exit 0 ;;
        *) echo "无效选择" ;;
    esac
    if [[ "\$choice" != "4" && "\$choice" != "6" && "\$choice" != "0" ]]; then
        sleep 1
    fi
done
EOFKK

chmod +x /usr/bin/kk

echo -e "${GREEN}🎉 安装完成！请在 TG 发送 /start 开始使用。${NC}"
echo -e "${SKY}输入 'kk' 可随时呼出管理面板${NC}"
