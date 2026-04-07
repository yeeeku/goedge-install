# GoEdge CDN v1.3.9 一键安装脚本

配合 aaPanel (国际版宝塔) 使用的 GoEdge CDN v1.3.9 纯净版一键部署工具。

## 功能

- 交互式菜单，操作简单
- 自动检测系统架构 (amd64/arm64)
- 默认从 GitHub Release 下载 (自有源，安全可靠)
- 备用支持国际源 (Cloudflare) / 国内源 (阿里云CDN)
- 一键安装管理平台、用户平台、智能DNS
- 自动屏蔽官方域名通信
- 自动替换安全版边缘节点部署包
- 内置旗舰版离线激活码
- aaPanel 反向代理配置指引
- 支持卸载

## 支持系统

- CentOS 7/8/9
- Ubuntu 18/20/22/24
- Debian 10/11/12
- RockyLinux 8/9

## 快速开始

### 一键安装

```bash
bash <(curl -sL https://raw.githubusercontent.com/yeeeku/goedge-install/main/install.sh)
```

### 手动安装

```bash
git clone https://github.com/yeeeku/goedge-install.git
cd goedge-install
chmod +x install.sh
sudo ./install.sh
```

### 命令行模式

```bash
# 完整安装
sudo ./install.sh --full

# 仅安装管理平台
sudo ./install.sh --admin

# 安装用户平台
sudo ./install.sh --user

# 安装智能DNS
sudo ./install.sh --dns

# 查看状态
sudo ./install.sh --status

# 卸载
sudo ./install.sh --uninstall
```

## 安装流程

### 1. 前置准备
- 一台 Linux 服务器 (建议 2C2G 以上)
- 已安装 aaPanel (国际版宝塔)
- Root 权限

### 2. 安装步骤

1. 运行安装脚本，选择 **完整安装**
2. 选择下载源 (国际/国内)
3. 在 aaPanel 中安装 MySQL 5.7/8.0
4. 浏览器访问 `http://服务器IP:7788` 完成安装向导
5. 安装向导中填写 MySQL 数据库信息
6. 回到脚本替换边缘节点部署包
7. 在管理平台中激活旗舰版

### 3. aaPanel 反向代理 (可选)

在 aaPanel 中添加网站 → 反向代理 → 目标: `http://127.0.0.1:7788`

## 端口说明

| 服务 | 默认端口 |
|------|---------|
| 管理平台 | 7788 |
| API 服务 | 8003 |
| DNS 服务 | 53 |

## 组件说明

| 组件 | 说明 | 必要性 |
|------|------|--------|
| edge-admin | 管理平台 + API 服务 | 必要 |
| edge-node | 边缘节点 (CDN节点) | 必要 |
| edge-user | 用户平台 | 可选 (商业运营需要) |
| edge-dns | 智能DNS | 可选 |

## 安全说明

- 本脚本使用 GoEdge v1.3.9 纯净版 (原作者最后维护版本)
- 自动屏蔽官方域名，防止与官方服务器通信
- 离线激活，不依赖官方授权服务器

## 致谢

- GoEdge 存档由 [@DigitalVirt](https://github.com/DigitalVirt) 提供
- 部署教程参考 [NodeSeek 社区](https://www.nodeseek.com)
