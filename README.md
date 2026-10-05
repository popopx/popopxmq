# POPOPXMQ

[![GitHub build](https://github.com/popopx/popopxmq/actions/workflows/build.yml/badge.svg)](https://github.com/popopx/popopxmq/actions/workflows/build.yml)
[![GitHub release](https://img.shields.io/github/v/release/popopx/popopxmq)](https://github.com/popopx/popopxmq/releases)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

POPOPXMQ 是一个用于管理单向消息队列的消息代理服务器，提供安全、隐私的公共网络消息传输。

> 本项目是 [simplexmq](https://github.com/simplex-chat/simplexmq) 的 fork 版本，由 [POPOPX](https://popopx.xyz) 团队维护和开发。

## 核心特性

- **单向队列管理** - 基于单向（simplex）队列的消息代理
- **端到端安全** - TLS 传输加密，离线证书保护
- **轻量级部署** - 支持低功率/低内存设备
- **高并发** - 基于 Haskell STM 的健壮并发模型
- **协议简单** - 仅 10 个客户端命令和 8 个服务器响应
- **持久化存储** - 内存持久化 + 可选追加日志

## 组件

### SMP Server（消息服务器）

SMP 服务器是 POPOPXMQ 的核心组件，负责管理消息队列和处理客户端连接。

**主要功能：**
- 消息队列创建、管理和删除
- TLS 加密传输
- 可选的消息持久化
- 队列日志压缩
- 未交付消息保存和恢复

**系统要求：**
- Linux 系统（支持 Ubuntu 20.04/22.04/24.04）
- OpenSSL 库
- x86_64 架构

**快速开始：**

```bash
# 初始化服务器
sudo smp-server init -n your.domain.com

# 启动服务器
sudo smp-server start

# 查看帮助
smp-server --help
```

**服务器地址格式：**
```
smp://<fingerprint>@<hostname>[:5223]
```

### XFTP Server（文件传输服务器）

XFTP 服务器提供安全的文件传输服务，支持大文件分块传输。

```bash
# 初始化 XFTP 服务器
sudo xftp-server init -n your.domain.com

# 启动服务器
sudo xftp-server start
```

### XFTP Client（文件传输客户端）

XFTP 客户端用于与 XFTP 服务器交互，上传和下载文件。

```bash
# 查看版本
xftp --version

# 查看帮助
xftp --help
```

## 安装

### 方式一：使用安装脚本（推荐）

```bash
curl -sSf https://raw.githubusercontent.com/popopx/popopxmq/stable/install.sh | sudo sh
```

安装脚本将：
1. 从 GitHub releases 下载最新二进制文件
2. 创建服务器目录和配置
3. 设置系统用户
4. 创建 systemd 服务
5. 安装更新和卸载脚本

### 方式二：从源码编译

**环境要求：**
- GHC 9.6.6
- Cabal 3.16+
- libgmp-dev
- libssl-dev

**编译步骤：**

```bash
# 安装 GHC 和 Cabal
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
export PATH="$HOME/.ghcup/bin:$PATH"
ghcup install ghc 9.6.6
ghcup set ghc 9.6.6

# 安装系统依赖
sudo apt-get install -y libgmp-dev libssl-dev

# 克隆仓库
git clone https://github.com/popopx/popopxmq.git
cd popopxmq

# 更新依赖并编译
cabal update
cabal build all

# 可执行文件位置
ls dist-newstyle/build/x86_64-linux/ghc-9.6.6/popopxmq-7.0.1.0/x/
```

## 配置

### SMP 服务器配置

配置文件位置：`/etc/opt/popopx/smp-server.ini`

**主要配置项：**

```ini
[main]
host: *                    # 监听地址
port: 5223                 # 监听端口
log_file: /var/opt/popopx/smp-server.log

[STORE_LOG]
enable = on               # 启用存储日志
log_stats = off           # 统计日志
restore_messages = on     # 恢复未交付消息

[CREDENTIALS]
ca_certificate_file: /etc/opt/popopx/ca.crt
private_key_file: /etc/opt/popopx/server.key
certificate_file: /etc/opt/popopx/server.crt
```

### 安全建议

1. **保护 CA 私钥** - CA 私钥（`/etc/opt/popopx/ca.key`）应安全存储并从服务器删除
2. **使用强密码** - 为系统用户设置强密码
3. **防火墙配置** - 仅开放必要端口（默认 5223）
4. **定期更新** - 使用 `popopx-servers-update` 脚本定期更新

## 协议文档

- [SMP 协议规范](./protocol/popopx-messaging.md)
- [Agent 协议规范](./protocol/agent-protocol.md)

SMP 协议灵感来自 [Redis 序列化协议](https://redis.io/topics/protocol)，但更加简化。

## 管理脚本

安装后提供以下管理脚本：

```bash
# 更新服务器
sudo popopx-servers-update

# 卸载服务器（完全清理）
sudo popopx-servers-uninstall

# 停止服务器
sudo popopx-servers-stopscript
```

## 技术架构

POPOPXMQ 使用 Haskell 实现，充分利用了 Haskell 的软件事务内存（STM）和并发原语：

- **并发模型** - 基于 STM 的健壮并发控制
- **内存管理** - 高效的内存持久化和恢复机制
- **加密实现** - OpenSSL 集成，支持现代加密算法
- **协议设计** - 简单高效的二进制协议

## 版本信息

- **当前版本**: 7.0.1.0
- **协议版本**: SMP v1
- **Haskell 版本**: GHC 9.6.6
- **许可证**: AGPL-3.0

## 上游项目

本项目基于 [simplexmq](https://github.com/simplex-chat/simplexmq) (v7.0.1.0) 开发。

**原始作者**: simplex.chat  
**版权**: Copyright 2020-2022 simplex.chat  
**维护者**: POPOPX Team (chat@popopx.xyz)

## 链接

- **官方网站**: https://popopx.xyz
- **文档**: https://popopx.xyz/docs
- **GitHub**: https://github.com/popopx/popopxmq
- **问题反馈**: https://github.com/popopx/popopxmq/issues

## 许可证

本项目采用 [AGPL-3.0](./LICENSE) 许可证。

---

**POPOPXMQ** - 安全、隐私、高效的单向消息队列代理
