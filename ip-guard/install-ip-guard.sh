#!/bin/bash
#
# ip-guard 一键安装脚本
# 本地 ip2region 查询服务，配合 GoEdge 边缘脚本使用
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="/usr/local/ip-guard"

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "请使用 root 用户运行"
        exit 1
    fi
}

detect_arch() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)  echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) error "不支持的架构: $arch"; exit 1 ;;
    esac
}

install_go() {
    if command -v go &>/dev/null; then
        info "Go 已安装: $(go version)"
        return
    fi

    info "安装 Go..."
    local arch=$(detect_arch)
    local go_url="https://go.dev/dl/go1.22.5.linux-${arch}.tar.gz"
    wget -q --show-progress -O /tmp/go.tar.gz "$go_url"
    rm -rf /usr/local/go
    tar -C /usr/local -xzf /tmp/go.tar.gz
    rm -f /tmp/go.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    info "Go 安装完成: $(go version)"
}

download_ip2region() {
    info "下载最新 ip2region.xdb..."
    mkdir -p "$INSTALL_DIR"
    wget -q --show-progress -O "$INSTALL_DIR/ip2region.xdb" \
        "https://raw.githubusercontent.com/lionsoul2014/ip2region/master/data/ip2region.xdb"
    info "ip2region.xdb 下载完成"
}

build_service() {
    info "编译 ip-guard 服务..."
    mkdir -p "$INSTALL_DIR/src"

    # 写入 Go 源码
    cat > "$INSTALL_DIR/src/main.go" << 'GOEOF'
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"strings"

	"github.com/lionsoul2014/ip2region/binding/golang/xdb"
)

var searcher *xdb.Searcher

type Result struct {
	IP       string `json:"ip"`
	Country  string `json:"country"`
	Province string `json:"province"`
	City     string `json:"city"`
	ISP      string `json:"isp"`
	Raw      string `json:"raw"`
}

func queryHandler(w http.ResponseWriter, r *http.Request) {
	ip := r.URL.Query().Get("ip")
	if ip == "" {
		http.Error(w, `{"error":"missing ip parameter"}`, 400)
		return
	}
	region, err := searcher.SearchByStr(ip)
	if err != nil {
		http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), 500)
		return
	}
	parts := strings.Split(region, "|")
	result := Result{IP: ip, Raw: region}
	if len(parts) >= 5 {
		result.Country = parts[0]
		result.Province = parts[2]
		result.City = parts[3]
		result.ISP = parts[4]
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func main() {
	dbPath := flag.String("db", "/usr/local/ip-guard/ip2region.xdb", "ip2region.xdb path")
	listen := flag.String("listen", "127.0.0.1:2060", "listen address")
	flag.Parse()
	cBuff, err := xdb.LoadContentFromFile(*dbPath)
	if err != nil {
		log.Fatalf("load ip2region.xdb failed: %s", err)
	}
	searcher, err = xdb.NewWithBuffer(cBuff)
	if err != nil {
		log.Fatalf("create searcher failed: %s", err)
	}
	defer searcher.Close()
	http.HandleFunc("/ip", queryHandler)
	log.Printf("ip-guard started on %s", *listen)
	log.Fatal(http.ListenAndServe(*listen, nil))
}
GOEOF

    cat > "$INSTALL_DIR/src/go.mod" << 'MODEOF'
module ip-guard

go 1.21

require github.com/lionsoul2014/ip2region/binding/golang v0.0.0-20240510055607-89e20ab7b6c6
MODEOF

    cd "$INSTALL_DIR/src"
    /usr/local/go/bin/go mod tidy
    CGO_ENABLED=0 /usr/local/go/bin/go build -o "$INSTALL_DIR/ip-guard" main.go
    info "编译完成"
}

create_systemd_service() {
    info "创建系统服务..."
    cat > /etc/systemd/system/ip-guard.service << EOF
[Unit]
Description=IP Guard - ip2region query service
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/ip-guard -db ${INSTALL_DIR}/ip2region.xdb -listen 127.0.0.1:2060
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ip-guard
    systemctl start ip-guard
    info "ip-guard 服务已启动"
}

update_xdb() {
    info "更新 ip2region.xdb..."
    wget -q --show-progress -O "$INSTALL_DIR/ip2region.xdb.new" \
        "https://raw.githubusercontent.com/lionsoul2014/ip2region/master/data/ip2region.xdb"
    mv -f "$INSTALL_DIR/ip2region.xdb.new" "$INSTALL_DIR/ip2region.xdb"
    systemctl restart ip-guard
    info "更新完成并已重启服务"
}

uninstall() {
    set +e
    info "卸载 ip-guard..."
    systemctl stop ip-guard 2>/dev/null
    systemctl disable ip-guard 2>/dev/null
    rm -f /etc/systemd/system/ip-guard.service
    systemctl daemon-reload
    rm -rf "$INSTALL_DIR"
    info "卸载完成"
    set -e
}

show_status() {
    echo ""
    systemctl status ip-guard --no-pager 2>/dev/null || echo "服务未安装"
    echo ""
    # 测试查询
    if curl -s "http://127.0.0.1:2060/ip?ip=1.1.1.1" 2>/dev/null; then
        echo ""
        info "服务正常运行"
    else
        warn "服务未响应"
    fi
}

show_menu() {
    echo ""
    echo -e "${BOLD}===== ip-guard (ip2region 本地查询服务) =====${NC}"
    echo -e "  ${GREEN}1)${NC} 安装"
    echo -e "  ${GREEN}2)${NC} 更新 ip2region.xdb 数据库"
    echo -e "  ${GREEN}3)${NC} 查看状态"
    echo -e "  ${RED}4)${NC} 卸载"
    echo -e "  ${YELLOW}0)${NC} 退出"
    echo ""
}

main() {
    check_root

    case "${1:-}" in
        --install)
            install_go
            download_ip2region
            build_service
            create_systemd_service
            show_status
            exit 0
            ;;
        --update)
            update_xdb
            exit 0
            ;;
        --uninstall)
            uninstall
            exit 0
            ;;
    esac

    while true; do
        show_menu
        read -p "  请选择 [0-4]: " choice
        case "$choice" in
            1)
                install_go
                download_ip2region
                build_service
                create_systemd_service
                show_status
                ;;
            2) update_xdb ;;
            3) show_status ;;
            4) uninstall ;;
            0) exit 0 ;;
            *) warn "无效选项" ;;
        esac
    done
}

main "$@"
