#!/bin/bash
# OneAPI 一键安装脚本 (普通 VPS Linux 版)
# 适用于拥有 root 权限的 Linux 服务器
# 支持 Debian/Ubuntu 和 CentOS/RHEL 系统
# 使用 systemd 进行服务管理

Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Blue="\033[34m"
Cyan="\033[36m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
BlueBG="\033[44;37m"
Font="\033[0m"

ONEAPI_NAME=one-api
ONEAPI_PATH="/opt/oneapi"
DATA_PATH="/opt/oneapi/data"
LOG_PATH="/opt/oneapi/logs"
PROXY_URL="https://ghfast.top/"
GITHUB_REPO="songquanpeng/one-api"

clear
echo -e "${BlueBG}          OneAPI 一键安装脚本 (普通 VPS Linux 版)             ${Font}"
echo ""

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${Red}错误: 此脚本需要 root 权限运行${Font}"
    exit 1
fi

# 检查系统
if [[ -f /etc/redhat-release ]]; then
    PKG_MANAGER="yum"
elif cat /etc/issue 2>/dev/null | grep -q -E -i "debian|ubuntu"; then
    PKG_MANAGER="apt"
else
    PKG_MANAGER="apt"
fi

# 安装依赖
echo -e "${Green}安装必要依赖...${Font}"
if [[ "$PKG_MANAGER" == "apt" ]]; then
    apt update -y && apt install -y curl wget tar
else
    yum install -y curl wget tar
fi

# 检查是否已安装
if [[ -f "${ONEAPI_PATH}/${ONEAPI_NAME}" ]]; then
    echo -e "${Yellow}检测到已安装 OneAPI，是否重新安装？${Font}"
    read -p "输入 y 继续: " confirm
    [[ "$confirm" != "y" ]] && exit 0
    systemctl stop oneapi 2>/dev/null
    rm -f ${ONEAPI_PATH}/${ONEAPI_NAME}
fi

# 配置
echo -e "${Cyan}==================== 配置 OneAPI ====================${Font}"
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "")
[[ -z "$PUBLIC_IP" ]] && read -p "请输入公网 IP: " PUBLIC_IP
echo -e "${Green}公网 IP: ${PUBLIC_IP}${Font}"

read -p "监听端口 [默认 3000]: " PORT
PORT=${PORT:-3000}

echo -e "${Yellow}数据库类型: 1.SQLite 2.MySQL 3.PostgreSQL${Font}"
read -p "选择 [1-3，默认 1]: " DB_CHOICE
DB_CHOICE=${DB_CHOICE:-1}

SQL_DSN=""
case "$DB_CHOICE" in
    2)
        read -p "MySQL 主机: " MYSQL_HOST
        read -p "MySQL 端口 [3306]: " MYSQL_PORT; MYSQL_PORT=${MYSQL_PORT:-3306}
        read -p "数据库名: " MYSQL_DB
        read -p "用户名: " MYSQL_USER
        read -sp "密码: " MYSQL_PASS; echo ""
        SQL_DSN="${MYSQL_USER}:${MYSQL_PASS}@tcp(${MYSQL_HOST}:${MYSQL_PORT})/${MYSQL_DB}"
        ;;
    3)
        read -p "PostgreSQL 主机: " PG_HOST
        read -p "PostgreSQL 端口 [5432]: " PG_PORT; PG_PORT=${PG_PORT:-5432}
        read -p "数据库名: " PG_DB
        read -p "用户名: " PG_USER
        read -sp "密码: " PG_PASS; echo ""
        SQL_DSN="postgres://${PG_USER}:${PG_PASS}@${PG_HOST}:${PG_PORT}/${PG_DB}"
        ;;
esac

# 下载
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64) PLATFORM=amd64 ;;
    aarch64|arm64) PLATFORM=arm64 ;;
    *) echo -e "${Red}不支持的架构: ${ARCH}${Font}"; exit 1 ;;
esac

mkdir -p ${ONEAPI_PATH} ${DATA_PATH} ${LOG_PATH}
cd ${ONEAPI_PATH}

LATEST_TAG=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
LATEST_TAG=${LATEST_TAG:-v0.6.10}
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${LATEST_TAG}/one-api_linux_${PLATFORM}.tar.gz"

echo -e "${Green}下载 OneAPI ${LATEST_TAG}...${Font}"
if curl -o /dev/null --connect-timeout 5 -s --head "https://www.google.com"; then
    curl -L -o oneapi.tar.gz ${DOWNLOAD_URL}
else
    curl -L -o oneapi.tar.gz ${PROXY_URL}${DOWNLOAD_URL}
fi

tar -xzf oneapi.tar.gz && rm -f oneapi.tar.gz
chmod +x ${ONEAPI_PATH}/${ONEAPI_NAME}

# 配置文件
cat > ${ONEAPI_PATH}/.env <<EOF
PORT=${PORT}
PUBLIC_IP=${PUBLIC_IP}
ONEAPI_WORKING_DIR=${ONEAPI_PATH}
LOG_DIR=${LOG_PATH}
EOF
[[ -n "$SQL_DSN" ]] && echo "SQL_DSN=${SQL_DSN}" >> ${ONEAPI_PATH}/.env

# systemd 服务
ENV_LINE=""
[[ -n "$SQL_DSN" ]] && ENV_LINE="Environment=\"SQL_DSN=${SQL_DSN}\""

cat > /etc/systemd/system/oneapi.service <<EOF
[Unit]
Description=OneAPI
After=network.target
[Service]
Type=simple
WorkingDirectory=${ONEAPI_PATH}
ExecStart=${ONEAPI_PATH}/${ONEAPI_NAME} --port ${PORT} --log-dir ${LOG_PATH}
Restart=always
${ENV_LINE}
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable oneapi
systemctl start oneapi

# 创建管理脚本
cat > ${ONEAPI_PATH}/oneapi <<'EOF'
#!/bin/bash
case "$1" in
    start) systemctl start oneapi ;;
    stop) systemctl stop oneapi ;;
    restart) systemctl restart oneapi ;;
    status) systemctl status oneapi ;;
    log) journalctl -u oneapi -f ;;
    *) echo "用法: oneapi {start|stop|restart|status|log}" ;;
esac
EOF
chmod +x ${ONEAPI_PATH}/oneapi
ln -sf ${ONEAPI_PATH}/oneapi /usr/local/bin/oneapi

# 完成
echo ""
echo -e "${GreenBG}          OneAPI 安装成功!          ${Font}"
echo -e "${Green}访问地址: http://${PUBLIC_IP}:${PORT}${Font}"
echo -e "${Green}默认账号: root / 123456${Font}"
echo -e "${Red}请立即修改密码！${Font}"
echo -e "${Green}管理命令: oneapi {start|stop|restart|status|log}${Font}"
