# -*- coding: utf-8 -*-
import json
import os

# 配置文件路径 - 请根据实际部署环境修改
CONFIG_FILE = "/path/to/your/sentinel_config.json"  # 主配置文件路径
SSH_FILE = "/path/to/your/.ssh/authorized_keys"  # SSH公钥文件路径
AUDIT_FILE = "/path/to/your/bot.log"  # 审计日志文件路径

# 默认配置模板
DEFAULT_CONFIG = {
    "bot_token": "",  # Telegram Bot Token
    "admin_id": 0,    # 管理员 Telegram User ID
    "server_remark": "VPS_bot-X",
    "traffic_limit_gb": 1024,
    "backup_paths": [],
    "daily_report_times": ["08:00", "20:00"],
    "command_prefix": "kk"  # 命令前缀，默认为"kk"
}

def load_config():
    """加载配置文件"""
    if not os.path.exists(CONFIG_FILE):
        return DEFAULT_CONFIG
    try:
        with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except:
        return DEFAULT_CONFIG

def save_config(config):
    """保存配置文件"""
    try:
        with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
    except Exception as e:
        print(f"Error saving config: {e}")

# 加载配置供 main.py 使用
_conf = load_config()

# 映射 main.py 需要的变量名
TOKEN = _conf.get("bot_token", "")
ALLOWED_USER_ID = _conf.get("admin_id", 0)
ALLOWED_USER_IDS = [ALLOWED_USER_ID] if ALLOWED_USER_ID else []

# 配置加载函数
def load_ports():
    """从配置中加载端口信息"""
    config = load_config()
    return config.get('ports', {})

def save_ports(data):
    """保存端口信息到配置"""
    config = load_config()
    config['ports'] = data
    save_config(config)