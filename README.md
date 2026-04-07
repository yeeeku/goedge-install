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

### 1. 安装 aaPanel (国际版宝塔)

如果还没装 aaPanel，先安装：

```bash
# Ubuntu/Debian
wget -O install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh && bash install.sh aapanel

# CentOS
yum install -y wget && wget -O install.sh http://www.aapanel.com/script/install_6.0_en.sh && bash install.sh aapanel
```

安装完成后，浏览器访问面板地址登录。

### 2. aaPanel 中安装必要软件

登录 aaPanel 后，在 **App Store** 中安装以下软件（选择 Quick install）：

| 软件 | 版本 | 必要性 | 说明 |
|------|------|--------|------|
| **Nginx** | 1.24+ | 必装 | 反向代理管理平台/用户平台 |
| **MySQL** | 5.7 / 8.0 / MariaDB 10.11 | 必装 | GoEdge 数据库 |
| **phpMyAdmin** | 5.2 | 推荐 | 方便管理数据库 |
| PHP | 8.3 | 可选 | GoEdge 本身不需要，但 phpMyAdmin 需要 |
| Pure-Ftpd | 1.0.49 | 可选 | 文件传输，按需安装 |

> **注意**: GoEdge 本身是 Go 编写的独立程序，不需要 PHP/Apache 运行。Nginx 主要用于反向代理和 SSL。

### 3. aaPanel 中创建数据库

1. 进入 aaPanel → **Databases**
2. 点击 **Add Database**
3. 填写：
   - Database name: `goedge`
   - Username: `goedge`
   - Password: 设置一个强密码（记住，后面要用）
   - Access: `Local server`
4. 点击 Submit

### 4. 运行安装脚本

```bash
bash <(curl -sL https://raw.githubusercontent.com/yeeeku/goedge-install/main/install.sh)
```

选择 **1) 完整安装**，按提示操作：
1. 选择下载源（默认 GitHub 自有源）
2. MySQL 选择 **跳过**（因为已经在 aaPanel 中装好了）
3. 等待管理平台启动

### 5. 完成安装向导

1. 浏览器访问 `http://服务器IP:7788`
2. 进入安装向导，填写数据库信息：
   - 数据库地址: `127.0.0.1`
   - 端口: `3306`
   - 数据库名: `goedge`
   - 用户名: `goedge`
   - 密码: 上面设置的密码
3. 设置管理员账号密码
4. 完成安装

### 6. 替换边缘节点包 & 激活

1. 回到 SSH，再次运行脚本，选择 **4) 替换边缘节点部署包**
2. 在管理平台中：**系统设置** → **商业版本** → **激活**，粘贴脚本中提供的注册码

### 7. aaPanel 配置反向代理 (推荐)

通过域名 + SSL 访问管理平台：

1. 在 aaPanel 中 **Website** → **Add Site**，绑定你的域名（如 `cdn.yourdomain.com`）
2. 点击域名 → **SSL** → 申请 Let's Encrypt 免费证书，开启强制 HTTPS
3. 点击 **Reverse Proxy** → **Add Reverse Proxy**：
   - Proxy name: `goedge`
   - Target URL: `http://127.0.0.1:7788`
   - 勾选 Send Domain
4. 之后通过 `https://cdn.yourdomain.com` 访问管理平台

如果还装了用户平台，同样操作，Target URL 改为用户平台的端口。

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
