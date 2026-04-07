#!/bin/bash
#
# GoEdge CDN v1.3.9 一键安装脚本 (配合 aaPanel)
# 支持: CentOS 7/8/9, Ubuntu 18/20/22, Debian 10/11/12
# 架构: amd64 / arm64
#

set -e

# ============== 颜色定义 ==============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============== 全局变量 ==============
INSTALL_DIR="/usr/local/goedge"
ARCH=""
PKG_MGR=""
SOURCE=""
SOURCE_NAME=""

# 国际源 (Cloudflare)
CF_BASE="https://static-file-global.353355.xyz/goedge"
# 国内源 (阿里云CDN)
ALI_BASE_ADMIN_AMD64="https://fj.ly93.cc/37/1809553326"
ALI_BASE_ADMIN_ARM64="https://fj.ly93.cc/37/1809551208"
ALI_BASE_NODE_AMD64="https://fj.ly93.cc/37/1809540483"
ALI_BASE_NODE_ARM64="https://fj.ly93.cc/37/1809540478"
ALI_BASE_USER_AMD64="https://fj.ly93.cc/37/1809540410"
ALI_BASE_USER_ARM64="https://fj.ly93.cc/37/1809540413"
ALI_BASE_DNS_AMD64="https://fj.ly93.cc/37/1809540514"
ALI_BASE_DNS_ARM64="https://fj.ly93.cc/37/1809540511"
ALI_MYSQL="https://static-file-global.353355.xyz/goedge/mysql/install-mysql.sh"

# 激活码
LICENSE_KEY="F4BuVYEKSDWV+I13ISd5NUyBcWOlH0af4/ow9obzYBS3XvYC9IsK86k5UDyyBv9vqJWN2/FQTDbPyuAO0zxYlkLDC0c8rrShs+7PAkqM0O8wBIGknzForgidDZahky5Lo/ZWaPZ1dVFUxmV29ykb0I0b4tv7Q3OtnTylOuzf//MYrlvyw6VJQMGnsttmeHzsNL/r0yDONOEXZoGoLZsuBKnkfXt+qt6bZF+kM1ncbh+sY42BrPTWQ12sXqJS3qHlzU0FFl9lTNzLGYYhq5vi/4sJuPVE50/uLCtslTJdb9zOGR915hnM+jHYsR+jUk0QxOqtreaHpsvNuLkexXbkmA=="

# ============== 工具函数 ==============
info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
header()  { echo -e "\n${BOLD}${CYAN}========== $1 ==========${NC}\n"; }

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "请使用 root 用户运行此脚本"
        error "请执行: sudo bash install.sh"
        exit 1
    fi
}

detect_arch() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)  ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *)
            error "不支持的架构: $arch"
            exit 1
            ;;
    esac
    info "检测到系统架构: ${BOLD}$ARCH${NC}"
}

detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then
        PKG_MGR="apt"
    elif command -v dnf &>/dev/null; then
        PKG_MGR="dnf"
    elif command -v yum &>/dev/null; then
        PKG_MGR="yum"
    else
        error "未检测到支持的包管理器 (apt/yum/dnf)"
        exit 1
    fi
    info "检测到包管理器: ${BOLD}$PKG_MGR${NC}"
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        info "检测到操作系统: ${BOLD}$PRETTY_NAME${NC}"
    fi
}

# ============== 下载源选择 ==============
select_source() {
    header "选择下载源"
    echo -e "  ${BOLD}1)${NC} 国际源 (Cloudflare) - 海外服务器推荐"
    echo -e "  ${BOLD}2)${NC} 国内源 (阿里云CDN) - 国内服务器推荐"
    echo ""
    read -p "请选择 [1/2] (默认: 1): " choice
    case "$choice" in
        2)
            SOURCE="ali"
            SOURCE_NAME="国内源 (阿里云CDN)"
            ;;
        *)
            SOURCE="cf"
            SOURCE_NAME="国际源 (Cloudflare)"
            ;;
    esac
    info "已选择: ${BOLD}$SOURCE_NAME${NC}"
}

# ============== 获取下载链接 ==============
get_admin_url() {
    if [ "$SOURCE" = "cf" ]; then
        echo "${CF_BASE}/edge-admin-linux-${ARCH}-plus-v1.3.9.zip"
    else
        if [ "$ARCH" = "amd64" ]; then
            echo "${ALI_BASE_ADMIN_AMD64}/edge-admin-linux-amd64-plus-v1.3.9.zip"
        else
            echo "${ALI_BASE_ADMIN_ARM64}/edge-admin-linux-arm64-plus-v1.3.9.zip"
        fi
    fi
}

get_node_url() {
    local target_arch=${1:-$ARCH}
    if [ "$SOURCE" = "cf" ]; then
        echo "${CF_BASE}/edge-node-linux-${target_arch}-plus-v1.3.9.zip"
    else
        if [ "$target_arch" = "amd64" ]; then
            echo "${ALI_BASE_NODE_AMD64}/edge-node-linux-amd64-plus-v1.3.9.zip"
        else
            echo "${ALI_BASE_NODE_ARM64}/edge-node-linux-arm64-plus-v1.3.9.zip"
        fi
    fi
}

get_user_url() {
    if [ "$SOURCE" = "cf" ]; then
        echo "${CF_BASE}/edge-user-linux-${ARCH}-v1.3.9.zip"
    else
        if [ "$ARCH" = "amd64" ]; then
            echo "${ALI_BASE_USER_AMD64}/edge-user-linux-amd64-v1.3.9.zip"
        else
            echo "${ALI_BASE_USER_ARM64}/edge-user-linux-arm64-v1.3.9.zip"
        fi
    fi
}

get_dns_url() {
    if [ "$SOURCE" = "cf" ]; then
        echo "${CF_BASE}/edge-dns-linux-${ARCH}-v1.3.9.zip"
    else
        if [ "$ARCH" = "amd64" ]; then
            echo "${ALI_BASE_DNS_AMD64}/edge-dns-linux-amd64-v1.3.9.zip"
        else
            echo "${ALI_BASE_DNS_ARM64}/edge-dns-linux-arm64-v1.3.9.zip"
        fi
    fi
}

# ============== 安装依赖 ==============
install_dependencies() {
    header "安装依赖"
    case "$PKG_MGR" in
        apt)
            apt-get update -qq
            apt-get install -y -qq unzip wget curl
            ;;
        dnf)
            dnf install -y -q unzip wget curl
            ;;
        yum)
            yum install -y -q unzip wget curl
            ;;
    esac
    info "依赖安装完成"
}

# ============== 屏蔽官方域名 ==============
block_official_domains() {
    header "屏蔽官方域名"

    local domains=(
        "goedge.cloud"
        "goedge.cn"
        "dl.goedge.cloud"
        "dl.goedge.cn"
        "global.dl.goedge.cloud"
        "global.dl.goedge.cn"
    )

    local modified=false
    for domain in "${domains[@]}"; do
        if ! grep -q "$domain" /etc/hosts 2>/dev/null; then
            echo "127.0.0.1 $domain" >> /etc/hosts
            modified=true
        fi
    done

    if [ "$modified" = true ]; then
        info "已屏蔽官方域名通信"
    else
        info "官方域名已被屏蔽，跳过"
    fi
}

# ============== 安装管理平台 ==============
install_admin() {
    header "安装管理平台 (edge-admin)"

    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    local url=$(get_admin_url)
    local filename="edge-admin-linux-${ARCH}-plus-v1.3.9.zip"

    info "下载管理平台程序..."
    info "URL: $url"
    wget -q --show-progress -O "$filename" "$url"

    info "解压中..."
    unzip -o "$filename" -d . > /dev/null
    rm -f "$filename"

    info "启动管理平台..."
    cd edge-admin
    chmod +x bin/edge-admin
    bin/edge-admin start

    info "注册系统服务..."
    bin/edge-admin service

    local pid=$(pgrep -f "bin/edge-admin" || true)
    if [ -n "$pid" ]; then
        info "管理平台启动成功! PID: $pid"
    else
        warn "管理平台可能未正常启动，请检查日志: ${INSTALL_DIR}/edge-admin/logs/run.log"
    fi

    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}  管理平台访问地址: http://<服务器IP>:7788${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
}

# ============== 安装 MySQL ==============
install_mysql_standalone() {
    header "安装 MySQL"

    echo -e "  ${BOLD}1)${NC} 使用 aaPanel 面板安装 MySQL (推荐)"
    echo -e "  ${BOLD}2)${NC} 使用 GoEdge 自带脚本安装 MySQL"
    echo -e "  ${BOLD}3)${NC} 跳过 (已有 MySQL)"
    echo ""
    read -p "请选择 [1/2/3] (默认: 1): " mysql_choice

    case "$mysql_choice" in
        2)
            info "使用 GoEdge 脚本安装 MySQL..."
            curl -s "${CF_BASE}/mysql/install-mysql.sh" | bash
            info "MySQL 安装完成"
            ;;
        3)
            info "跳过 MySQL 安装"
            ;;
        *)
            echo ""
            info "请在 aaPanel 面板中安装 MySQL:"
            echo -e "  1. 登录 aaPanel 面板"
            echo -e "  2. 点击 ${BOLD}App Store${NC}"
            echo -e "  3. 安装 ${BOLD}MySQL 5.7${NC} 或 ${BOLD}MySQL 8.0${NC}"
            echo -e "  4. 安装完成后，在 ${BOLD}Databases${NC} 中创建数据库和用户"
            echo -e "  5. 在 GoEdge 管理平台安装向导中填入数据库信息"
            echo ""
            read -p "按 Enter 键继续..." _
            ;;
    esac
}

# ============== 替换边缘节点包 ==============
replace_node_packages() {
    header "替换边缘节点部署包"

    local deploy_dir="${INSTALL_DIR}/edge-admin/edge-api/deploy"

    if [ ! -d "$deploy_dir" ]; then
        warn "部署目录不存在: $deploy_dir"
        warn "请先完成管理平台的安装向导(网页端)后再替换节点包"
        echo ""
        read -p "是否继续替换? [y/N]: " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            return
        fi
        mkdir -p "$deploy_dir"
    fi

    cd "$deploy_dir"
    rm -f *.zip

    info "下载 amd64 边缘节点包..."
    wget -q --show-progress -O "edge-node-linux-amd64-v1.3.9.zip" "$(get_node_url amd64)"

    info "下载 arm64 边缘节点包..."
    wget -q --show-progress -O "edge-node-linux-arm64-v1.3.9.zip" "$(get_node_url arm64)"

    info "边缘节点部署包替换完成"
}

# ============== 安装用户平台 ==============
install_user_platform() {
    header "安装用户平台 (edge-user)"

    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    local url=$(get_user_url)
    local filename="edge-user-linux-${ARCH}-v1.3.9.zip"

    info "下载用户平台程序..."
    wget -q --show-progress -O "$filename" "$url"

    info "解压中..."
    unzip -o "$filename" -d . > /dev/null
    rm -f "$filename"

    echo ""
    warn "用户平台需要配置文件才能启动"
    echo -e "  1. 在管理平台中: ${BOLD}系统设置 → 高级设置 → 用户节点 → 添加节点${NC}"
    echo -e "  2. 创建节点后点击 ${BOLD}安装节点${NC}，复制配置文件内容"
    echo -e "  3. 将内容粘贴到: ${BOLD}${INSTALL_DIR}/edge-user/configs/api_user.yaml${NC}"
    echo ""
    read -p "是否已经获取配置文件内容? [y/N]: " has_config

    if [ "$has_config" = "y" ] || [ "$has_config" = "Y" ]; then
        mkdir -p "${INSTALL_DIR}/edge-user/configs"
        echo "请粘贴配置文件内容 (粘贴完成后按 Ctrl+D):"
        cat > "${INSTALL_DIR}/edge-user/configs/api_user.yaml"

        cd edge-user
        chmod +x bin/edge-user
        info "启动用户平台..."
        bin/edge-user start

        info "注册系统服务..."
        bin/edge-user service

        info "用户平台安装完成"
    else
        info "请稍后手动配置并启动用户平台"
        echo -e "  配置文件路径: ${BOLD}${INSTALL_DIR}/edge-user/configs/api_user.yaml${NC}"
        echo -e "  启动命令: ${BOLD}cd ${INSTALL_DIR}/edge-user && bin/edge-user start${NC}"
        echo -e "  注册服务: ${BOLD}bin/edge-user service${NC}"
    fi
}

# ============== 安装智能DNS ==============
install_dns() {
    header "安装智能DNS (edge-dns)"

    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    local url=$(get_dns_url)
    local filename="edge-dns-linux-${ARCH}-v1.3.9.zip"

    # 检查53端口占用
    if netstat -tuln 2>/dev/null | grep -q ":53 " || ss -tuln 2>/dev/null | grep -q ":53 "; then
        warn "检测到53端口被占用!"
        echo ""
        read -p "是否自动释放53端口 (停止 systemd-resolved)? [y/N]: " free_port
        if [ "$free_port" = "y" ] || [ "$free_port" = "Y" ]; then
            systemctl stop systemd-resolved 2>/dev/null || true
            systemctl disable systemd-resolved 2>/dev/null || true
            rm -f /etc/resolv.conf
            echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf
            info "53端口已释放"
        fi
    fi

    info "下载智能DNS程序..."
    wget -q --show-progress -O "$filename" "$url"

    info "解压中..."
    unzip -o "$filename" -d . > /dev/null
    rm -f "$filename"

    echo ""
    warn "智能DNS需要配置文件才能启动"
    echo -e "  1. 在管理平台中: ${BOLD}智能DNS → 集群管理 → 创建集群 → 创建节点${NC}"
    echo -e "  2. 点击节点名称 → ${BOLD}安装节点${NC}，复制配置文件内容"
    echo -e "  3. 将内容粘贴到: ${BOLD}${INSTALL_DIR}/edge-dns/configs/api_dns.yaml${NC}"
    echo ""
    read -p "是否已经获取配置文件内容? [y/N]: " has_config

    if [ "$has_config" = "y" ] || [ "$has_config" = "Y" ]; then
        mkdir -p "${INSTALL_DIR}/edge-dns/configs"
        echo "请粘贴配置文件内容 (粘贴完成后按 Ctrl+D):"
        cat > "${INSTALL_DIR}/edge-dns/configs/api_dns.yaml"

        cd edge-dns
        chmod +x bin/edge-dns
        info "启动智能DNS..."
        bin/edge-dns start

        info "注册系统服务..."
        bin/edge-dns service

        info "智能DNS安装完成"
    else
        info "请稍后手动配置并启动智能DNS"
        echo -e "  配置文件路径: ${BOLD}${INSTALL_DIR}/edge-dns/configs/api_dns.yaml${NC}"
        echo -e "  启动命令: ${BOLD}cd ${INSTALL_DIR}/edge-dns && bin/edge-dns start${NC}"
        echo -e "  注册服务: ${BOLD}bin/edge-dns service${NC}"
    fi
}

# ============== aaPanel 反向代理配置提示 ==============
show_aapanel_tips() {
    header "aaPanel 反向代理配置 (可选)"
    echo -e "如果你想通过域名访问管理平台，可以在 aaPanel 中配置反向代理:"
    echo ""
    echo -e "  1. 在 aaPanel 中添加网站，绑定你的域名"
    echo -e "  2. 点击网站设置 → ${BOLD}Reverse Proxy${NC}"
    echo -e "  3. 添加反向代理:"
    echo -e "     - 管理平台: 目标 URL = ${BOLD}http://127.0.0.1:7788${NC}"
    echo -e "     - 用户平台: 目标 URL = ${BOLD}http://127.0.0.1:<用户平台端口>${NC}"
    echo -e "  4. 建议配置 SSL 证书 (Let's Encrypt)"
    echo ""
    echo -e "  ${YELLOW}提示: 配置反向代理后，记得在 GoEdge 管理平台的系统设置中${NC}"
    echo -e "  ${YELLOW}      更新访问地址为你的域名${NC}"
    echo ""
}

# ============== 显示激活码 ==============
show_license() {
    header "商业版激活"
    echo -e "在管理平台中: ${BOLD}系统设置 → 商业版本 → 激活${NC}"
    echo -e "粘贴以下旗舰版注册码即可离线激活 (终身有效):"
    echo ""
    echo -e "${CYAN}${LICENSE_KEY}${NC}"
    echo ""
}

# ============== 状态查看 ==============
show_status() {
    header "服务状态"

    echo -e "${BOLD}进程状态:${NC}"
    ps aux | grep -E "edge-(admin|node|user|dns)" | grep -v grep || echo "  无 GoEdge 进程运行"
    echo ""

    echo -e "${BOLD}端口监听:${NC}"
    (netstat -tlnp 2>/dev/null || ss -tlnp 2>/dev/null) | grep -E "(7788|8001|53)" || echo "  未检测到相关端口"
    echo ""

    echo -e "${BOLD}安装目录:${NC}"
    if [ -d "$INSTALL_DIR" ]; then
        ls -la "$INSTALL_DIR/" 2>/dev/null
    else
        echo "  未安装"
    fi
}

# ============== 卸载 ==============
uninstall() {
    header "卸载 GoEdge"
    warn "此操作将停止所有 GoEdge 服务并删除程序文件"
    warn "数据库数据不会被删除"
    echo ""
    read -p "确认卸载? [y/N]: " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        info "已取消"
        return
    fi

    info "停止服务..."
    cd "$INSTALL_DIR/edge-admin" 2>/dev/null && bin/edge-admin stop 2>/dev/null || true
    cd "$INSTALL_DIR/edge-user" 2>/dev/null && bin/edge-user stop 2>/dev/null || true
    cd "$INSTALL_DIR/edge-dns" 2>/dev/null && bin/edge-dns stop 2>/dev/null || true

    # 移除 systemd 服务
    systemctl stop edge-admin 2>/dev/null || true
    systemctl disable edge-admin 2>/dev/null || true
    systemctl stop edge-user 2>/dev/null || true
    systemctl disable edge-user 2>/dev/null || true
    systemctl stop edge-dns 2>/dev/null || true
    systemctl disable edge-dns 2>/dev/null || true
    rm -f /etc/systemd/system/edge-*.service
    systemctl daemon-reload 2>/dev/null || true

    info "删除程序文件..."
    rm -rf "$INSTALL_DIR"

    info "卸载完成"
    info "如需清理 hosts 文件，请手动编辑 /etc/hosts"
}

# ============== 主菜单 ==============
show_menu() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║      GoEdge CDN v1.3.9 一键安装管理脚本         ║"
    echo "  ║          配合 aaPanel (国际版宝塔)               ║"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  ${BOLD}---- 安装 ----${NC}"
    echo -e "  ${GREEN}1)${NC} 完整安装 (管理平台 + MySQL + 节点包替换)"
    echo -e "  ${GREEN}2)${NC} 仅安装管理平台"
    echo -e "  ${GREEN}3)${NC} 安装 MySQL"
    echo -e "  ${GREEN}4)${NC} 替换边缘节点部署包"
    echo -e "  ${GREEN}5)${NC} 安装用户平台"
    echo -e "  ${GREEN}6)${NC} 安装智能DNS"
    echo ""
    echo -e "  ${BOLD}---- 管理 ----${NC}"
    echo -e "  ${BLUE}7)${NC} 查看激活码"
    echo -e "  ${BLUE}8)${NC} 查看服务状态"
    echo -e "  ${BLUE}9)${NC} aaPanel 反向代理配置说明"
    echo ""
    echo -e "  ${BOLD}---- 其他 ----${NC}"
    echo -e "  ${RED}10)${NC} 卸载 GoEdge"
    echo -e "  ${YELLOW}0)${NC}  退出"
    echo ""
}

# ============== 完整安装 ==============
full_install() {
    select_source
    install_dependencies
    block_official_domains
    install_admin
    install_mysql_standalone
    echo ""
    warn "请先在浏览器中完成管理平台安装向导 (http://<IP>:7788)"
    warn "安装向导需要填写数据库信息，完成后再替换节点包"
    echo ""
    read -p "管理平台安装向导是否已完成? [y/N]: " wizard_done
    if [ "$wizard_done" = "y" ] || [ "$wizard_done" = "Y" ]; then
        replace_node_packages
    else
        warn "请完成安装向导后，再次运行脚本选择 '4) 替换边缘节点部署包'"
    fi
    show_license
    show_aapanel_tips
    echo -e "${GREEN}${BOLD}安装完成!${NC}"
}

# ============== 入口 ==============
main() {
    check_root
    detect_os
    detect_arch
    detect_pkg_manager

    # 支持命令行参数快速安装
    if [ -n "$1" ]; then
        select_source
        case "$1" in
            --full)
                install_dependencies
                block_official_domains
                full_install
                ;;
            --admin)
                install_dependencies
                block_official_domains
                install_admin
                ;;
            --user)
                install_user_platform
                ;;
            --dns)
                install_dns
                ;;
            --status)
                show_status
                ;;
            --uninstall)
                uninstall
                ;;
            *)
                echo "用法: $0 [--full|--admin|--user|--dns|--status|--uninstall]"
                exit 1
                ;;
        esac
        exit 0
    fi

    # 交互式菜单
    while true; do
        show_menu
        read -p "  请选择操作 [0-10]: " choice
        echo ""
        case "$choice" in
            1) full_install ;;
            2)
                select_source
                install_dependencies
                block_official_domains
                install_admin
                show_license
                ;;
            3) install_mysql_standalone ;;
            4)
                if [ -z "$SOURCE" ]; then select_source; fi
                replace_node_packages
                ;;
            5)
                if [ -z "$SOURCE" ]; then select_source; fi
                install_user_platform
                ;;
            6)
                if [ -z "$SOURCE" ]; then select_source; fi
                install_dns
                ;;
            7) show_license ;;
            8) show_status ;;
            9) show_aapanel_tips ;;
            10) uninstall ;;
            0)
                info "再见!"
                exit 0
                ;;
            *)
                warn "无效选项，请重新选择"
                ;;
        esac
        echo ""
        read -p "按 Enter 键返回主菜单..." _
    done
}

main "$@"
