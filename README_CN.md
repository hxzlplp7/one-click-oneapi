# OneAPI 一键安装脚本

[English](README_EN.md) | [返回主页](README.md)

---

## 简介

OneAPI 是一个统一的 API 管理平台，支持多种 AI 模型提供商。本仓库提供适用于不同环境的一键安装脚本：

- **普通 VPS (Linux)**: 适用于拥有 root 权限的 Debian/Ubuntu 或 CentOS/RHEL 服务器
- **NAT VPS (Linux)**: 适用于共享 IP 需要端口映射的 NAT 服务器
- **Hostuno/Serv00 FreeBSD**: 适用于无 root 权限的 FreeBSD 环境

## 特性

- ✅ 自动系统检测和架构支持 (amd64/arm64)
- ✅ 交互式配置向导
- ✅ 支持 SQLite、MySQL、PostgreSQL 数据库
- ✅ Systemd 服务管理 (普通 VPS)
- ✅ 基于 Cron 的进程保活 (NAT 和 FreeBSD 环境)
- ✅ 崩溃自动重启
- ✅ 开机自动启动
- ✅ 便捷的管理命令

## 快速安装

### 普通 VPS (Linux root 权限)

```bash
# 直接安装
bash <(curl -sL https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_install.sh)

# 使用加速代理 (国内推荐)
bash <(curl -sL https://ghfast.top/https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_install.sh)
```

### NAT VPS (Linux 端口映射)

```bash
# 直接安装
bash <(curl -sL https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_nat_install.sh)

# 使用加速代理 (国内推荐)
bash <(curl -sL https://ghfast.top/https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_nat_install.sh)
```

### Hostuno/Serv00 FreeBSD (无 root)

```bash
# 直接安装
sh -c "$(curl -sL https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_hostuno_install.sh)"

# 使用加速代理 (国内推荐)
sh -c "$(curl -sL https://ghfast.top/https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_hostuno_install.sh)"
```

## 系统要求

| 环境 | 操作系统 | 架构 | 需要 Root | 端口要求 |
|------|----------|------|-----------|----------|
| 普通 VPS | Linux (Debian/Ubuntu/CentOS) | amd64/arm64 | 是 | 任意端口 |
| NAT VPS | Linux (Debian/Ubuntu/CentOS) | amd64/arm64 | 是 | 需要外部端口映射 |
| Hostuno/Serv00 | FreeBSD | amd64 | 否 | 端口 > 1024 |

## 管理命令

### 普通 VPS (systemctl)

```bash
# 启动服务
systemctl start oneapi

# 停止服务
systemctl stop oneapi

# 重启服务
systemctl restart oneapi

# 查看状态
systemctl status oneapi

# 查看日志
journalctl -u oneapi -f

# 快捷命令
oneapi start|stop|restart|status|log
```

### NAT VPS 和 FreeBSD

```bash
# 管理命令
oneapi start    # 启动服务
oneapi stop     # 停止服务
oneapi restart  # 重启服务
oneapi status   # 查看状态
oneapi log      # 查看实时日志
oneapi info     # 显示访问信息
```

## 默认账号

- **用户名**: `root`
- **密码**: `123456`

⚠️ **请在首次登录后立即修改密码！**

## 配置文件

配置文件存储位置：
- 普通 VPS: `/opt/oneapi/.env`
- NAT VPS: `/opt/oneapi/.env`
- FreeBSD: `~/oneapi/.env`

## 卸载

可以运行管理脚本选择卸载，或手动卸载：

```bash
# 普通 VPS
systemctl stop oneapi
systemctl disable oneapi
rm -rf /opt/oneapi
rm -f /etc/systemd/system/oneapi.service
rm -f /usr/local/bin/oneapi

# NAT VPS / FreeBSD
oneapi stop
crontab -l | grep -v oneapi | crontab -
rm -rf /opt/oneapi  # FreeBSD 用 ~/oneapi
rm -f /usr/local/bin/oneapi
```

## 故障排除

1. **端口已被占用**: 安装时更换监听端口
2. **无法访问 Web 面板**: 检查防火墙规则和 NAT 端口映射
3. **进程不断停止**: 查看日志检查错误信息
4. **下载失败**: 尝试使用代理 URL 进行安装

## 许可证

MIT License

## 贡献

欢迎提交 Pull Request。如有重大更改，请先开 Issue 讨论。
