#!/bin/bash
# OneAPI 一键安装脚本 (NAT VPS Linux 版)
# 适用于共享 IP 需要端口映射的 NAT 服务器
# 使用 cron 保活，支持内外端口分离

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
echo -e "${BlueBG}          OneAPI 一键安装脚本 (NAT VPS Linux 版)             ${Font}"
echo ""

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${Red}错误: 此脚本需要 root 权限运行${Font}"
    exit 1
fi

# 安装依赖
if command -v apt &>/dev/null; then
    apt update -y && apt install -y curl wget tar cron
elif command -v yum &>/dev/null; then
    yum install -y curl wget tar cronie
fi

# 检查是否已安装
if [[ -f "${ONEAPI_PATH}/${ONEAPI_NAME}" ]]; then
    echo -e "${Yellow}检测到已安装 OneAPI，是否重新安装？${Font}"
    read -p "输入 y 继续: " confirm
    [[ "$confirm" != "y" ]] && exit 0
    pkill -f "one-api" 2>/dev/null
    rm -f ${ONEAPI_PATH}/${ONEAPI_NAME}
fi

# 配置
echo -e "${Cyan}==================== 配置 OneAPI (NAT VPS) ====================${Font}"
echo -e "${Yellow}【NAT 环境说明】需要配置内部端口和外部映射端口${Font}"
echo ""

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "")
[[ -z "$PUBLIC_IP" ]] && read -p "请输入 NAT 分配的公网 IP: " PUBLIC_IP
echo -e "${Green}公网 IP: ${PUBLIC_IP}${Font}"

read -p "内部监听端口 [默认 3000]: " PORT
PORT=${PORT:-3000}

echo -e "${Yellow}请输入 NAT 分配的外部端口 (供外部访问)${Font}"
read -p "外部端口 [默认与内部相同]: " EXTERNAL_PORT
EXTERNAL_PORT=${EXTERNAL_PORT:-$PORT}

echo -e "${Yellow}数据库: 1.SQLite 2.MySQL 3.PostgreSQL${Font}"
read -p "选择 [默认 1]: " DB_CHOICE
DB_CHOICE=${DB_CHOICE:-1}

SQL_DSN=""
case "$DB_CHOICE" in
    2)
        read -p "MySQL 主机: " MYSQL_HOST
        read -p "端口 [3306]: " MYSQL_PORT; MYSQL_PORT=${MYSQL_PORT:-3306}
        read -p "数据库名: " MYSQL_DB
        read -p "用户名: " MYSQL_USER
        read -sp "密码: " MYSQL_PASS; echo ""
        SQL_DSN="${MYSQL_USER}:${MYSQL_PASS}@tcp(${MYSQL_HOST}:${MYSQL_PORT})/${MYSQL_DB}"
        ;;
    3)
        read -p "PostgreSQL 主机: " PG_HOST
        read -p "端口 [5432]: " PG_PORT; PG_PORT=${PG_PORT:-5432}
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
EXTERNAL_PORT=${EXTERNAL_PORT}
PUBLIC_IP=${PUBLIC_IP}
ONEAPI_WORKING_DIR=${ONEAPI_PATH}
LOG_DIR=${LOG_PATH}
EOF
[[ -n "$SQL_DSN" ]] && echo "SQL_DSN=${SQL_DSN}" >> ${ONEAPI_PATH}/.env

# 启动脚本
cat > ${ONEAPI_PATH}/start.sh <<EOF
#!/bin/bash
cd ${ONEAPI_PATH}
if pgrep -f "one-api" >/dev/null; then exit 0; fi
export \$(cat .env | grep -v '^#' | xargs)
nohup ${ONEAPI_PATH}/${ONEAPI_NAME} --port ${PORT} --log-dir ${LOG_PATH} > ${LOG_PATH}/oneapi.out 2>&1 &
echo \$! > ${ONEAPI_PATH}/oneapi.pid
EOF
chmod +x ${ONEAPI_PATH}/start.sh

cat > ${ONEAPI_PATH}/stop.sh <<EOF
#!/bin/bash
pkill -f "one-api" 2>/dev/null
rm -f ${ONEAPI_PATH}/oneapi.pid
EOF
chmod +x ${ONEAPI_PATH}/stop.sh

# 保活脚本
cat > ${ONEAPI_PATH}/keepalive.sh <<EOF
#!/bin/bash
if ! pgrep -f "one-api" >/dev/null; then
    ${ONEAPI_PATH}/start.sh
fi
EOF
chmod +x ${ONEAPI_PATH}/keepalive.sh

# 添加 cron 任务
(crontab -l 2>/dev/null | grep -v "oneapi"; \
 echo "*/5 * * * * ${ONEAPI_PATH}/keepalive.sh"; \
 echo "@reboot ${ONEAPI_PATH}/start.sh") | crontab -

# 管理脚本
cat > ${ONEAPI_PATH}/oneapi <<'EOF'
#!/bin/bash
ONEAPI_PATH="/opt/oneapi"
case "$1" in
    start) ${ONEAPI_PATH}/start.sh ;;
    stop) ${ONEAPI_PATH}/stop.sh ;;
    restart) ${ONEAPI_PATH}/stop.sh; sleep 2; ${ONEAPI_PATH}/start.sh ;;
    status) pgrep -f "one-api" && echo "运行中" || echo "已停止" ;;
    log) tail -f ${ONEAPI_PATH}/logs/oneapi.out ;;
    info)
        IP=$(grep "^PUBLIC_IP=" ${ONEAPI_PATH}/.env | cut -d'=' -f2)
        EP=$(grep "^EXTERNAL_PORT=" ${ONEAPI_PATH}/.env | cut -d'=' -f2)
        echo "访问地址: http://${IP}:${EP}"
        echo "默认账号: root / 123456"
        ;;
    *) echo "用法: oneapi {start|stop|restart|status|log|info}" ;;
esac
EOF
chmod +x ${ONEAPI_PATH}/oneapi
ln -sf ${ONEAPI_PATH}/oneapi /usr/local/bin/oneapi

# 启动
${ONEAPI_PATH}/start.sh
sleep 3

# 完成
echo ""
echo -e "${GreenBG}          OneAPI 安装成功! (NAT VPS)          ${Font}"
echo -e "${Green}公网 IP: ${PUBLIC_IP}${Font}"
echo -e "${Green}内部端口: ${PORT} | 外部端口: ${EXTERNAL_PORT}${Font}"
echo -e "${Green}访问地址: http://${PUBLIC_IP}:${EXTERNAL_PORT}${Font}"
echo -e "${Green}默认账号: root / 123456${Font}"
echo -e "${Red}请立即修改密码！${Font}"
echo ""
echo -e "${Yellow}特性: cron 每5分钟保活 + 开机自启${Font}"
echo -e "${Green}管理命令: oneapi {start|stop|restart|status|log|info}${Font}"
