# OneAPI One-Click Installation Scripts

[中文](README_CN.md) | [Back to Main](README.md)

---

## Introduction

OneAPI is a unified API management platform that supports multiple AI model providers. This repository provides one-click installation scripts for various environments:

- **Standard VPS (Linux)**: For servers with root access running Debian/Ubuntu or CentOS/RHEL
- **NAT VPS (Linux)**: For NAT VPS with shared IP and port mapping
- **Hostuno/Serv00 FreeBSD**: For FreeBSD environments without root access

## Features

- ✅ Automatic system detection and architecture support (amd64/arm64)
- ✅ Interactive configuration wizard
- ✅ Support for SQLite, MySQL, PostgreSQL databases
- ✅ Systemd service management (Standard VPS)
- ✅ Cron-based process keepalive (NAT and FreeBSD environments)
- ✅ Auto-restart on crash
- ✅ Auto-start on boot
- ✅ Easy management commands

## Quick Install

### Standard VPS (Linux with root)

```bash
# Direct installation
bash <(curl -sL https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_install.sh)

# Or with acceleration proxy (for China mainland)
bash <(curl -sL https://ghfast.top/https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_install.sh)
```

### NAT VPS (Linux with port mapping)

```bash
# Direct installation
bash <(curl -sL https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_nat_install.sh)

# Or with acceleration proxy (for China mainland)
bash <(curl -sL https://ghfast.top/https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_nat_install.sh)
```

### Hostuno/Serv00 FreeBSD (No root)

```bash
# Direct installation
sh -c "$(curl -sL https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_hostuno_install.sh)"

# Or with acceleration proxy (for China mainland)
sh -c "$(curl -sL https://ghfast.top/https://raw.githubusercontent.com/hxzlplp7/one-click-oneapi/main/oneapi_hostuno_install.sh)"
```

## System Requirements

| Environment | OS | Architecture | Root Required | Port Requirement |
|-------------|------|--------------|---------------|------------------|
| Standard VPS | Linux (Debian/Ubuntu/CentOS) | amd64/arm64 | Yes | Any port |
| NAT VPS | Linux (Debian/Ubuntu/CentOS) | amd64/arm64 | Yes | External port mapping required |
| Hostuno/Serv00 | FreeBSD | amd64 | No | Port > 1024 |

## Management Commands

### Standard VPS (systemctl)

```bash
# Start service
systemctl start oneapi

# Stop service
systemctl stop oneapi

# Restart service
systemctl restart oneapi

# Check status
systemctl status oneapi

# View logs
journalctl -u oneapi -f

# Management shortcut
oneapi start|stop|restart|status|log
```

### NAT VPS & FreeBSD

```bash
# Management commands
oneapi start    # Start service
oneapi stop     # Stop service
oneapi restart  # Restart service
oneapi status   # Check status
oneapi log      # View realtime logs
oneapi info     # Show access information
```

## Default Credentials

- **Username**: `root`
- **Password**: `123456`

⚠️ **Please change the password immediately after first login!**

## Configuration

Configuration is stored in:
- Standard VPS: `/opt/oneapi/.env`
- NAT VPS: `/opt/oneapi/.env`
- FreeBSD: `~/oneapi/.env`

## Uninstallation

Run the management script and select the uninstall option, or manually:

```bash
# Standard VPS
systemctl stop oneapi
systemctl disable oneapi
rm -rf /opt/oneapi
rm -f /etc/systemd/system/oneapi.service
rm -f /usr/local/bin/oneapi

# NAT VPS / FreeBSD
oneapi stop
crontab -l | grep -v oneapi | crontab -
rm -rf /opt/oneapi  # or ~/oneapi for FreeBSD
rm -f /usr/local/bin/oneapi
```

## Troubleshooting

1. **Port already in use**: Change the listening port during installation
2. **Cannot access web panel**: Check firewall rules and NAT port mapping
3. **Process keeps stopping**: Check logs for error messages
4. **Download failed**: Try using the proxy URL for installation

## License

MIT License

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.
