#!/bin/bash

# 颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查是否以 root 权限运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}请使用 root 权限运行此脚本${NC}"
        exit 1
    fi
}

# 安装必要的软件
install_requirements() {
    echo -e "${BLUE}正在安装必要的软件...${NC}"
    apt update
    apt install -y python3-pip certbot curl
}

# 安装 Nginx
install_nginx() {
    echo -e "${BLUE}开始安装 Nginx...${NC}"
    curl -sS -O https://raw.githubusercontent.com/woniu336/cf-cdn/main/install_nginx.sh
    chmod +x install_nginx.sh
    ./install_nginx.sh
}

# 下载基础配置文件
download_config_files() {
    echo -e "${BLUE}下载配置文件模板...${NC}"
    
    # 创建配置目录
    mkdir -p /etc/nginx/conf.d/
    
    # 下载配置文件
    curl -sS -o /etc/nginx/conf.d/111.com.conf https://raw.githubusercontent.com/woniu336/cf-cdn/main/111.com.conf
    curl -sS -o /etc/nginx/conf.d/proxy_common.conf https://raw.githubusercontent.com/woniu336/cf-cdn/main/proxy_common.conf
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}配置文件下载成功${NC}"
        # 设置适当的权限
        chmod 644 /etc/nginx/conf.d/111.com.conf
        chmod 644 /etc/nginx/conf.d/proxy_common.conf
    else
        echo -e "${RED}配置文件下载失败${NC}"
        exit 1
    fi
}

# 申请证书
apply_cert() {
    local domain_type=$1
    local domain=$2
    
    echo -e "${BLUE}开始申请 $domain_type 证书...${NC}"
    
    if [ "$domain_type" = "线路域名" ]; then
        certbot certonly -d "*.$domain" --manual --preferred-challenges dns-01 --server https://acme-v02.api.letsencrypt.org/directory
    else
        certbot certonly -d "$domain" --manual --preferred-challenges dns-01 --server https://acme-v02.api.letsencrypt.org/directory
    fi
}

# 复制证书
copy_certs() {
    local prefix=$1
    local domain=$2
    
    echo -e "${BLUE}复制证书到 Nginx 目录...${NC}"
    
    # 创建证书目录
    mkdir -p /etc/nginx/certs/
    
    # 复制证书
    cp "/etc/letsencrypt/live/$domain/fullchain.pem" "/etc/nginx/certs/${prefix}.${domain}_cert.pem"
    cp "/etc/letsencrypt/live/$domain/privkey.pem" "/etc/nginx/certs/${prefix}.${domain}_key.pem"
    
    # 设置权限
    chown -R root:root /etc/nginx/certs/
    chmod 600 /etc/nginx/certs/*.pem
    
    echo -e "${GREEN}证书已复制并设置权限${NC}"
}

# 配置新站点
configure_site() {
    local main_domain=$1
    local line_domain=$2
    local backend_domain=$3
    
    echo -e "${BLUE}配置新站点...${NC}"
    
    # 创建站点专用的 proxy_common 配置
    cp /etc/nginx/conf.d/proxy_common.conf "/etc/nginx/conf.d/proxy_common_${main_domain}.conf"
    
    # 修改站点专用的 proxy_common 配置
    sed -i "s/333.com/$backend_domain/g" "/etc/nginx/conf.d/proxy_common_${main_domain}.conf"
    
    # 复制并修改主配置文件
    cp /etc/nginx/conf.d/111.com.conf "/etc/nginx/conf.d/${main_domain}.conf"
    
    # 替换域名
    sed -i "s/111.com/$main_domain/g" "/etc/nginx/conf.d/${main_domain}.conf"
    sed -i "s/222.com/$line_domain/g" "/etc/nginx/conf.d/${main_domain}.conf"
    sed -i "s/333.com/$backend_domain/g" "/etc/nginx/conf.d/${main_domain}.conf"
    
    # 修改 include 语句，使用站点专用的 proxy_common 配置
    sed -i "s/proxy_common.conf/proxy_common_${main_domain}.conf/g" "/etc/nginx/conf.d/${main_domain}.conf"
    
    echo -e "${GREEN}站点配置完成${NC}"
    echo -e "${BLUE}已创建以下配置文件：${NC}"
    echo -e "1. /etc/nginx/conf.d/${main_domain}.conf"
    echo -e "2. /etc/nginx/conf.d/proxy_common_${main_domain}.conf"
}

# 重启 Nginx
restart_nginx() {
    echo -e "${BLUE}清理缓存并重启 Nginx...${NC}"
    rm -rf /usr/local/nginx/cache/proxy/*
    systemctl restart nginx
    nginx -t
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Nginx 重启成功${NC}"
    else
        echo -e "${RED}Nginx 重启失败，请检查配置${NC}"
    fi
}

# 主菜单
show_menu() {
    clear
    echo -e "${YELLOW}=== CF-CDN 配置工具 ===${NC}"
    echo -e "${BLUE}1. 安装 certbot${NC}"
    echo -e "${BLUE}2. 安装 Nginx${NC}"
    echo -e "${BLUE}3. 下载配置文件${NC}"
    echo -e "${BLUE}4. 申请证书${NC}"
    echo -e "${BLUE}5. 配置新站点${NC}"
    echo -e "${BLUE}6. 重启 Nginx${NC}"
    echo -e "${BLUE}0. 退出${NC}"
    echo
    read -p "请选择操作 [0-6]: " choice
    
    case $choice in
        1)
            install_requirements
            ;;
        2)
            install_nginx
            ;;
        3)
            download_config_files
            ;;
        4)
            echo -e "${YELLOW}证书申请向导${NC}"
            echo "1. 申请线路域名证书"
            echo "2. 申请主域名证书"
            read -p "请选择 [1-2]: " cert_choice
            
            case $cert_choice in
                1)
                    read -p "请输入线路域名 (例如: 222.com): " line_domain
                    read -p "请输入前缀 (例如: xx): " prefix
                    apply_cert "线路域名" "$line_domain"
                    copy_certs "$prefix" "$line_domain"
                    ;;
                2)
                    read -p "请输入主域名: " main_domain
                    apply_cert "主域名" "$main_domain"
                    copy_certs "" "$main_domain"
                    ;;
                *)
                    echo -e "${RED}无效的选择${NC}"
                    ;;
            esac
            ;;
        5)
            read -p "请输入主域名: " main_domain
            read -p "请输入线路域名: " line_domain
            read -p "请输入后端域名: " backend_domain
            configure_site "$main_domain" "$line_domain" "$backend_domain"
            ;;
        6)
            restart_nginx
            ;;
        0)
            echo -e "${GREEN}感谢使用！${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选择${NC}"
            ;;
    esac
    
    echo
    read -p "按回车键返回主菜单..."
    show_menu
}

# 主程序入口
check_root
show_menu 