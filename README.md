# OneAPI One-Click Installation Scripts

[English](README_EN.md) | [中文](README_CN.md)

---

## Introduction / 简介

OneAPI is a unified API management platform that supports multiple AI model providers. This repository provides one-click installation scripts for various environments.

OneAPI 是一个统一的 API 管理平台，支持多种 AI 模型提供商。本仓库提供适用于不同环境的一键安装脚本。

## Quick Install / 快速安装

### Standard VPS (Linux with root) / 普通 VPS

```bash
bash <(curl -sL https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_install.sh)
```

### NAT VPS (Linux with port mapping) / NAT 机

```bash
bash <(curl -sL https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_nat_install.sh)
```

### Hostuno/Serv00 FreeBSD (No root) / 无 root 环境

```bash
sh -c "$(curl -sL https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_hostuno_install.sh)"
```

### With Proxy (China) / 国内加速

```bash
# Standard VPS
bash <(curl -sL https://ghfast.top/https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_install.sh)

# NAT VPS
bash <(curl -sL https://ghfast.top/https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_nat_install.sh)

# FreeBSD
sh -c "$(curl -sL https://ghfast.top/https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_hostuno_install.sh)"
```

## Documentation / 文档

- [English Documentation](README_EN.md)
- [中文文档](README_CN.md)

## License

MIT License
