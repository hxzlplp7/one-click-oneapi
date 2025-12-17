#!/bin/sh
# OneAPI 一键安装脚本 (Hostuno FreeBSD 无 root 专用版)
# 适配 FreeBSD + 无 root 权限 + NAT 共享 IP 环境
# 所有文件安装到用户目录，使用 cron 保活

# fonts color (POSIX 兼容)
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Blue="\033[34m"
Cyan="\033[36m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
BlueBG="\033[44;37m"
Font="\033[0m"

# variable
ONEAPI_VERSION="latest"
ONEAPI_NAME=one-api
ONEAPI_PATH="$HOME/oneapi"
DATA_PATH="$HOME/oneapi/data"
LOG_PATH="$HOME/oneapi/logs"
PROXY_URL="https://ghfast.top/"
# FreeBSD 专用版本仓库
FREEBSD_REPO="k0baya/one-api-freebsd"

clear
printf "${BlueBG}                                                                    ${Font}\n"
printf "${BlueBG}      OneAPI 一键安装脚本 (Hostuno FreeBSD 无 root 专用)            ${Font}\n"
printf "${BlueBG}              用户目录安装 + cron 保活                              ${Font}\n"
printf "${BlueBG}                                                                    ${Font}\n"
echo ""

# 检查系统
check_system() {
    if [ "$(uname)" != "FreeBSD" ]; then
        printf "${Yellow}警告: 当前系统不是 FreeBSD，脚本可能无法正常工作${Font}\n"
        printf "当前系统: $(uname)\n"
        printf "是否继续? (y/n): "
        read confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            exit 1
        fi
    else
        printf "${Green}系统检测: FreeBSD $(uname -r)${Font}\n"
    fi
}

check_system

# 检查是否已安装
if [ -f "${ONEAPI_PATH}/${ONEAPI_NAME}" ]; then
    printf "${Yellow}检测到已安装 OneAPI，是否重新安装？${Font}\n"
    printf "${Red}警告: 这将删除现有程序，但保留数据库！${Font}\n"
    printf "输入 y 继续，其他键退出: "
    read confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        printf "${Green}已取消安装${Font}\n"
        exit 0
    fi
    # 停止现有进程
    pkill -f "one-api" 2>/dev/null
    rm -f ${ONEAPI_PATH}/${ONEAPI_NAME}
fi

# ==================== 交互式配置 ====================
echo ""
printf "${Cyan}==================== 配置 OneAPI (FreeBSD 无 root) ====================${Font}\n"
echo ""

# NAT VPS 提示
printf "${Yellow}【环境说明】Hostuno FreeBSD 无 root 环境${Font}\n"
printf "${Cyan}1. 程序将安装到用户目录: ${ONEAPI_PATH}${Font}\n"
printf "${Cyan}2. 使用 cron 实现进程保活和开机自启${Font}\n"
printf "${Cyan}3. 无需 root 权限即可完成全部操作${Font}\n"
echo ""

# 获取公网 IP
printf "${Yellow}获取公网 IP...${Font}\n"
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ip.sb 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "")
if [ -z "$PUBLIC_IP" ]; then
    printf "${Yellow}无法自动获取公网IP，请手动输入${Font}\n"
    printf "请输入 Hostuno 分配的公网IP: "
    read PUBLIC_IP
fi
printf "${Green}公网 IP: ${PUBLIC_IP}${Font}\n"

# 内部监听端口
echo ""
printf "${Yellow}请输入 OneAPI 监听端口${Font}\n"
printf "${Cyan}注意: 无 root 权限只能使用 1024 以上的端口${Font}\n"
printf "监听端口 [默认 3000]: "
read PORT
PORT=${PORT:-3000}

# 验证端口
if [ "$PORT" -lt 1024 ]; then
    printf "${Red}错误: 无 root 权限无法使用 1024 以下的端口${Font}\n"
    printf "${Yellow}已自动改为端口 3000${Font}\n"
    PORT=3000
fi

# 外部访问端口 (NAT)
echo ""
printf "${Yellow}请选择端口配置方式${Font}\n"
printf "${Green}1.${Font} 手动输入端口 (已在面板中添加端口)\n"
printf "${Green}2.${Font} 自动添加端口 (脚本使用 devil 命令添加)\n"
printf "选择 [1-2，默认 1]: "
read PORT_MODE
PORT_MODE=${PORT_MODE:-1}

case "$PORT_MODE" in
    2)
        # 自动添加端口模式
        echo ""
        printf "${Yellow}自动添加端口模式${Font}\n"
        printf "${Cyan}提示: 脚本将自动生成随机端口并尝试添加${Font}\n"
        
        # 生成随机端口的函数
        generate_random_port() {
            # 生成 10000-60000 范围内的随机端口
            awk 'BEGIN{srand();print int(rand()*50000)+10000}'
        }
        
        # 尝试添加端口
        MAX_ATTEMPTS=10
        ATTEMPT=1
        PORT_ADDED=0
        
        while [ $ATTEMPT -le $MAX_ATTEMPTS ] && [ $PORT_ADDED -eq 0 ]; do
            RANDOM_PORT=$(generate_random_port)
            printf "${Green}尝试 ${ATTEMPT}/${MAX_ATTEMPTS}: 添加端口 ${RANDOM_PORT}...${Font}\n"
            
            ADD_RESULT=$(devil port add tcp ${RANDOM_PORT} 2>&1)
            
            if echo "$ADD_RESULT" | grep -qi "already"; then
                printf "${Yellow}端口 ${RANDOM_PORT} 已存在，将直接使用${Font}\n"
                EXTERNAL_PORT=$RANDOM_PORT
                PORT_ADDED=1
            elif echo "$ADD_RESULT" | grep -qi "success\|added\|ok"; then
                printf "${Green}端口 ${RANDOM_PORT} 添加成功！${Font}\n"
                EXTERNAL_PORT=$RANDOM_PORT
                PORT_ADDED=1
            else
                printf "${Yellow}端口 ${RANDOM_PORT} 添加失败，尝试下一个...${Font}\n"
                ATTEMPT=$((ATTEMPT + 1))
            fi
        done
        
        if [ $PORT_ADDED -eq 0 ]; then
            printf "${Red}自动添加端口失败（已尝试 ${MAX_ATTEMPTS} 次）${Font}\n"
            printf "${Yellow}请手动输入一个端口号: ${Font}"
            read MANUAL_PORT
            if [ -n "$MANUAL_PORT" ]; then
                ADD_RESULT=$(devil port add tcp ${MANUAL_PORT} 2>&1)
                if echo "$ADD_RESULT" | grep -qi "success\|added\|ok\|already"; then
                    printf "${Green}端口 ${MANUAL_PORT} 添加成功${Font}\n"
                    EXTERNAL_PORT=$MANUAL_PORT
                else
                    printf "${Red}端口添加失败: ${ADD_RESULT}${Font}\n"
                    printf "${Yellow}将使用监听端口 ${PORT} 作为外部端口${Font}\n"
                    EXTERNAL_PORT=$PORT
                fi
            else
                printf "${Yellow}将使用监听端口 ${PORT} 作为外部端口${Font}\n"
                EXTERNAL_PORT=$PORT
            fi
        fi
        
        # 同时更新监听端口为外部端口（NAT 环境下建议一致）
        if [ "$EXTERNAL_PORT" != "$PORT" ]; then
            printf "${Cyan}是否将监听端口也改为 ${EXTERNAL_PORT}? (y/n) [默认 y]: ${Font}"
            read sync_port
            sync_port=${sync_port:-y}
            if [ "$sync_port" = "y" ] || [ "$sync_port" = "Y" ]; then
                PORT=$EXTERNAL_PORT
                printf "${Green}监听端口已同步为: ${PORT}${Font}\n"
            fi
        fi
        
        # 显示当前端口列表
        echo ""
        printf "${Cyan}当前端口列表:${Font}\n"
        devil port list 2>/dev/null || true
        ;;
    *)
        # 手动输入端口模式
        echo ""
        printf "${Yellow}请输入 Hostuno 分配的外部端口${Font}\n"
        printf "${Cyan}提示: 这是你在控制面板中设置的转发端口${Font}\n"
        printf "外部端口 [如与内部相同请直接回车]: "
        read EXTERNAL_PORT
        EXTERNAL_PORT=${EXTERNAL_PORT:-$PORT}
        ;;
esac

# 数据库类型
echo ""
printf "${Yellow}选择数据库类型${Font}\n"
printf "${Green}1.${Font} SQLite (默认，推荐无 root 环境使用)\n"
printf "${Green}2.${Font} MySQL (需要已配置好的远程数据库)\n"
printf "${Green}3.${Font} PostgreSQL (需要已配置好的远程数据库)\n"
printf "选择 [1-3，默认 1]: "
read DB_CHOICE
DB_CHOICE=${DB_CHOICE:-1}

SQL_DSN=""
case "$DB_CHOICE" in
    2)
        echo ""
        printf "${Yellow}配置 MySQL 连接${Font}\n"
        printf "MySQL 主机: "
        read MYSQL_HOST
        printf "MySQL 端口 [默认 3306]: "
        read MYSQL_PORT
        MYSQL_PORT=${MYSQL_PORT:-3306}
        printf "MySQL 数据库名: "
        read MYSQL_DB
        printf "MySQL 用户名: "
        read MYSQL_USER
        printf "MySQL 密码: "
        stty -echo 2>/dev/null
        read MYSQL_PASS
        stty echo 2>/dev/null
        echo ""
        SQL_DSN="${MYSQL_USER}:${MYSQL_PASS}@tcp(${MYSQL_HOST}:${MYSQL_PORT})/${MYSQL_DB}"
        ;;
    3)
        echo ""
        printf "${Yellow}配置 PostgreSQL 连接${Font}\n"
        printf "PostgreSQL 主机: "
        read PG_HOST
        printf "PostgreSQL 端口 [默认 5432]: "
        read PG_PORT
        PG_PORT=${PG_PORT:-5432}
        printf "PostgreSQL 数据库名: "
        read PG_DB
        printf "PostgreSQL 用户名: "
        read PG_USER
        printf "PostgreSQL 密码: "
        stty -echo 2>/dev/null
        read PG_PASS
        stty echo 2>/dev/null
        echo ""
        SQL_DSN="postgres://${PG_USER}:${PG_PASS}@${PG_HOST}:${PG_PORT}/${PG_DB}"
        ;;
esac

# ==================== 确认配置 ====================
echo ""
printf "${Cyan}==================== 配置确认 ====================${Font}\n"
printf "${Green}安装目录:         ${Font}${ONEAPI_PATH}\n"
printf "${Green}公网 IP:          ${Font}${PUBLIC_IP}\n"
printf "${Green}监听端口:         ${Font}${PORT}\n"
printf "${Green}外部端口:         ${Font}${EXTERNAL_PORT}\n"
case "$DB_CHOICE" in
    1) printf "${Green}数据库类型:       ${Font}SQLite\n" ;;
    2) printf "${Green}数据库类型:       ${Font}MySQL\n" ;;
    3) printf "${Green}数据库类型:       ${Font}PostgreSQL\n" ;;
esac
echo ""
printf "确认以上配置? (y/n) [默认 y]: "
read confirm
confirm=${confirm:-y}
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    printf "${Red}已取消安装，请重新运行脚本${Font}\n"
    exit 0
fi

# ==================== 下载安装 ====================
echo ""
printf "${Cyan}==================== 开始下载安装 ====================${Font}\n"

# check arch
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)
        PLATFORM=amd64
        ;;
    aarch64|arm64)
        PLATFORM=arm64
        ;;
    *)
        printf "${Red}不支持的系统架构: ${ARCH}${Font}\n"
        exit 1
        ;;
esac

printf "${Green}系统: FreeBSD | 架构: ${PLATFORM}${Font}\n"

# create directories
mkdir -p ${ONEAPI_PATH}
mkdir -p ${DATA_PATH}
mkdir -p ${LOG_PATH}

cd ${ONEAPI_PATH}

# download FreeBSD version
printf "${Green}正在下载 OneAPI FreeBSD 版本...${Font}\n"

# 尝试获取最新版本
LATEST_TAG=$(curl -s "https://api.github.com/repos/${FREEBSD_REPO}/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_TAG" ]; then
    LATEST_TAG="v0.6.10"
    printf "${Yellow}无法获取最新版本，使用默认版本: ${LATEST_TAG}${Font}\n"
else
    printf "${Green}最新版本: ${LATEST_TAG}${Font}\n"
fi

DOWNLOAD_URL="https://github.com/${FREEBSD_REPO}/releases/download/${LATEST_TAG}/one-api"

# 检测网络环境
GOOGLE_HTTP_CODE=$(curl -o /dev/null --connect-timeout 5 --max-time 8 -s --head -w "%{http_code}" "https://www.google.com" 2>/dev/null)

printf "${Green}下载中: ${DOWNLOAD_URL}${Font}\n"

if [ "$GOOGLE_HTTP_CODE" = "200" ]; then
    curl -L -o ${ONEAPI_NAME} ${DOWNLOAD_URL}
else
    curl -L -o ${ONEAPI_NAME} ${PROXY_URL}${DOWNLOAD_URL}
fi

if [ ! -f "${ONEAPI_PATH}/${ONEAPI_NAME}" ]; then
    printf "${Red}下载失败,请检查网络连接${Font}\n"
    exit 1
fi

# 检查文件大小
FILE_SIZE=$(ls -l ${ONEAPI_PATH}/${ONEAPI_NAME} | awk '{print $5}')
if [ "$FILE_SIZE" -lt 1000000 ]; then
    printf "${Red}下载的文件可能不完整 (大小: ${FILE_SIZE} bytes)${Font}\n"
    printf "${Yellow}请检查网络连接后重试${Font}\n"
    exit 1
fi

# set permissions
chmod +x ${ONEAPI_PATH}/${ONEAPI_NAME}

# ==================== 生成配置文件 ====================
printf "${Green}生成配置文件...${Font}\n"

cat > ${ONEAPI_PATH}/.env <<EOF
# OneAPI 环境配置文件 (Hostuno FreeBSD)
# 由安装脚本自动生成

# 监听端口
PORT=${PORT}

# 外部访问端口
EXTERNAL_PORT=${EXTERNAL_PORT}

# 公网IP
PUBLIC_IP=${PUBLIC_IP}

# 工作目录
ONEAPI_WORKING_DIR=${ONEAPI_PATH}

# 日志目录
LOG_DIR=${LOG_PATH}
EOF

# 可选: SQL DSN
if [ -n "$SQL_DSN" ]; then
    echo "" >> ${ONEAPI_PATH}/.env
    echo "# 数据库连接" >> ${ONEAPI_PATH}/.env
    echo "SQL_DSN=${SQL_DSN}" >> ${ONEAPI_PATH}/.env
fi

# ==================== 创建启动脚本 ====================
printf "${Green}创建启动脚本...${Font}\n"

cat > ${ONEAPI_PATH}/start.sh <<EOF
#!/bin/sh
cd ${ONEAPI_PATH}

# 加载环境变量
if [ -f .env ]; then
    export \$(cat .env | grep -v '^#' | xargs)
fi

# 检查是否已运行
if pgrep -f "one-api" > /dev/null 2>&1; then
    echo "OneAPI 已在运行中"
    exit 0
fi

# 启动 OneAPI
nohup ${ONEAPI_PATH}/${ONEAPI_NAME} --port ${PORT} --log-dir ${LOG_PATH} > ${LOG_PATH}/oneapi.out 2>&1 &
echo \$! > ${ONEAPI_PATH}/oneapi.pid
echo "OneAPI 已启动, PID: \$!"
EOF
chmod +x ${ONEAPI_PATH}/start.sh

cat > ${ONEAPI_PATH}/stop.sh <<EOF
#!/bin/sh
if [ -f ${ONEAPI_PATH}/oneapi.pid ]; then
    PID=\$(cat ${ONEAPI_PATH}/oneapi.pid)
    if kill -0 \$PID 2>/dev/null; then
        kill \$PID
        echo "OneAPI 已停止 (PID: \$PID)"
    fi
    rm -f ${ONEAPI_PATH}/oneapi.pid
fi
pkill -f "one-api" 2>/dev/null
EOF
chmod +x ${ONEAPI_PATH}/stop.sh

cat > ${ONEAPI_PATH}/restart.sh <<EOF
#!/bin/sh
${ONEAPI_PATH}/stop.sh
sleep 2
${ONEAPI_PATH}/start.sh
EOF
chmod +x ${ONEAPI_PATH}/restart.sh

cat > ${ONEAPI_PATH}/status.sh <<EOF
#!/bin/sh
if pgrep -f "one-api" > /dev/null 2>&1; then
    PID=\$(pgrep -f "one-api")
    echo "OneAPI 状态: 运行中 (PID: \$PID)"
else
    echo "OneAPI 状态: 已停止"
fi
EOF
chmod +x ${ONEAPI_PATH}/status.sh

# ==================== 创建保活脚本 ====================
printf "${Green}创建保活脚本...${Font}\n"

cat > ${ONEAPI_PATH}/keepalive.sh <<EOF
#!/bin/sh
# OneAPI 保活脚本 (被 cron 调用)

cd ${ONEAPI_PATH}

# 检查进程是否存活
if ! pgrep -f "one-api" > /dev/null 2>&1; then
    echo "\$(date): OneAPI 未运行，正在重启..." >> ${LOG_PATH}/keepalive.log
    
    # 加载环境变量
    if [ -f .env ]; then
        export \$(cat .env | grep -v '^#' | xargs)
    fi
    
    # 重启服务
    nohup ${ONEAPI_PATH}/${ONEAPI_NAME} --port ${PORT} --log-dir ${LOG_PATH} > ${LOG_PATH}/oneapi.out 2>&1 &
    echo \$! > ${ONEAPI_PATH}/oneapi.pid
    echo "\$(date): OneAPI 已重启, PID: \$!" >> ${LOG_PATH}/keepalive.log
fi
EOF
chmod +x ${ONEAPI_PATH}/keepalive.sh

# ==================== 创建管理脚本 ====================
printf "${Green}创建管理脚本...${Font}\n"

cat > ${ONEAPI_PATH}/oneapi <<'MANAGEREOF'
#!/bin/sh

# fonts color
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Blue="\033[34m"
Cyan="\033[36m"
BlueBG="\033[44;37m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

ONEAPI_PATH="$HOME/oneapi"
LOG_PATH="$HOME/oneapi/logs"

get_status() {
    if pgrep -f "one-api" > /dev/null 2>&1; then
        echo "running"
        return 0
    else
        echo "stopped"
        return 1
    fi
}

start_oneapi() {
    STATUS=$(get_status)
    if [ "$STATUS" = "running" ]; then
        printf "${Yellow}OneAPI 已经在运行中${Font}\n"
        return
    fi
    printf "${Green}正在启动 OneAPI...${Font}\n"
    ${ONEAPI_PATH}/start.sh
    sleep 2
    STATUS=$(get_status)
    if [ "$STATUS" = "running" ]; then
        printf "${Green}OneAPI 启动成功${Font}\n"
    else
        printf "${Red}OneAPI 启动失败，请检查日志${Font}\n"
    fi
}

stop_oneapi() {
    STATUS=$(get_status)
    if [ "$STATUS" = "stopped" ]; then
        printf "${Yellow}OneAPI 未在运行${Font}\n"
        return
    fi
    printf "${Yellow}正在停止 OneAPI...${Font}\n"
    ${ONEAPI_PATH}/stop.sh
    printf "${Green}OneAPI 已停止${Font}\n"
}

restart_oneapi() {
    printf "${Yellow}正在重启 OneAPI...${Font}\n"
    ${ONEAPI_PATH}/restart.sh
    sleep 2
    STATUS=$(get_status)
    if [ "$STATUS" = "running" ]; then
        printf "${Green}OneAPI 重启成功${Font}\n"
    else
        printf "${Red}OneAPI 重启失败${Font}\n"
    fi
}

show_status() {
    STATUS=$(get_status)
    echo ""
    if [ "$STATUS" = "running" ]; then
        PID=$(pgrep -f "one-api")
        printf "${GreenBG} OneAPI 状态: 运行中 ${Font}\n"
        printf "${Green}PID: ${PID}${Font}\n"
    else
        printf "${RedBG} OneAPI 状态: 已停止 ${Font}\n"
    fi
}

show_config() {
    echo ""
    printf "${Cyan}==================== 当前配置 ====================${Font}\n"
    cat ${ONEAPI_PATH}/.env
    printf "${Cyan}==================================================${Font}\n"
}

show_log() {
    echo ""
    printf "${Cyan}==================== 最近日志 ====================${Font}\n"
    if [ -f "${LOG_PATH}/oneapi.out" ]; then
        tail -50 ${LOG_PATH}/oneapi.out
    else
        echo "暂无日志"
    fi
    printf "${Cyan}==================================================${Font}\n"
}

edit_config() {
    if command -v nano > /dev/null 2>&1; then
        nano ${ONEAPI_PATH}/.env
    elif command -v vim > /dev/null 2>&1; then
        vim ${ONEAPI_PATH}/.env
    elif command -v vi > /dev/null 2>&1; then
        vi ${ONEAPI_PATH}/.env
    else
        printf "${Red}未找到文本编辑器${Font}\n"
        return
    fi
    printf "${Yellow}配置已修改，是否重启 OneAPI? (y/n)${Font}\n"
    read confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        restart_oneapi
    fi
}

show_info() {
    # 从配置读取
    PUBLIC_IP=$(grep "^PUBLIC_IP=" ${ONEAPI_PATH}/.env | cut -d'=' -f2)
    INTERNAL_PORT=$(grep "^PORT=" ${ONEAPI_PATH}/.env | cut -d'=' -f2)
    EXTERNAL_PORT=$(grep "^EXTERNAL_PORT=" ${ONEAPI_PATH}/.env | cut -d'=' -f2)
    
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "未知")
    fi
    
    echo ""
    printf "${Cyan}================ Hostuno FreeBSD 访问信息 ================${Font}\n"
    printf "${Green}安装目录:       ${Font}${ONEAPI_PATH}\n"
    printf "${Green}公网 IP:        ${Font}${PUBLIC_IP}\n"
    printf "${Green}监听端口:       ${Font}${INTERNAL_PORT}\n"
    printf "${Green}外部端口:       ${Font}${EXTERNAL_PORT}\n"
    echo ""
    printf "${Blue}Web 管理面板:${Font}\n"
    printf "${Green}访问地址:       ${Font}http://${PUBLIC_IP}:${EXTERNAL_PORT}\n"
    echo ""
    printf "${Blue}默认管理员账号:${Font}\n"
    printf "${Green}用户名:         ${Font}root\n"
    printf "${Green}密码:           ${Font}123456\n"
    printf "${Red}请登录后立即修改密码！${Font}\n"
    printf "${Cyan}===========================================================${Font}\n"
}

setup_cron() {
    echo ""
    printf "${Yellow}设置 cron 定时任务（保活 + 开机自启）${Font}\n"
    
    # 检查当前 crontab
    CURRENT_CRON=$(crontab -l 2>/dev/null || echo "")
    
    if echo "$CURRENT_CRON" | grep -q "oneapi/keepalive.sh"; then
        printf "${Yellow}cron 任务已存在${Font}\n"
        return
    fi
    
    # 添加 cron 任务
    # @reboot 开机自启
    # */5 每 5 分钟检查一次保活
    (
        echo "$CURRENT_CRON"
        echo "# OneAPI 保活任务 (每5分钟检查)"
        echo "*/5 * * * * ${ONEAPI_PATH}/keepalive.sh"
        echo "# OneAPI 开机自启"
        echo "@reboot ${ONEAPI_PATH}/start.sh"
    ) | crontab -
    
    printf "${Green}cron 任务已设置:${Font}\n"
    printf "${Cyan}  - 每 5 分钟自动检查并保活${Font}\n"
    printf "${Cyan}  - 开机自动启动${Font}\n"
}

remove_cron() {
    printf "${Yellow}移除 cron 定时任务...${Font}\n"
    crontab -l 2>/dev/null | grep -v "oneapi" | crontab -
    printf "${Green}cron 任务已移除${Font}\n"
}

uninstall_oneapi() {
    printf "${Red}警告: 这将完全卸载 OneAPI!${Font}\n"
    printf "${Yellow}数据库和日志文件是否也删除? (y/n) [默认 n]: ${Font}"
    read del_data
    del_data=${del_data:-n}
    
    printf "确认卸载? (输入 yes 继续): "
    read confirm
    if [ "$confirm" = "yes" ]; then
        # 停止服务
        pkill -f "one-api" 2>/dev/null
        
        # 移除 cron
        crontab -l 2>/dev/null | grep -v "oneapi" | crontab -
        
        if [ "$del_data" = "y" ] || [ "$del_data" = "Y" ]; then
            rm -rf ${ONEAPI_PATH}
            printf "${Green}OneAPI 及所有数据已完全卸载${Font}\n"
        else
            rm -f ${ONEAPI_PATH}/one-api
            rm -f ${ONEAPI_PATH}/.env
            rm -f ${ONEAPI_PATH}/*.sh
            rm -f ${ONEAPI_PATH}/oneapi
            printf "${Green}OneAPI 已卸载，数据文件保留在 ${ONEAPI_PATH}/data${Font}\n"
        fi
        exit 0
    else
        printf "${Yellow}已取消卸载${Font}\n"
    fi
}

show_menu() {
    clear
    printf "${BlueBG}                                                           ${Font}\n"
    printf "${BlueBG}       OneAPI 管理面板 (Hostuno FreeBSD 无 root)           ${Font}\n"
    printf "${BlueBG}                                                           ${Font}\n"
    show_status
    echo ""
    printf "${Cyan}==================== 管理菜单 ====================${Font}\n"
    printf "${Green}1.${Font} 启动 OneAPI\n"
    printf "${Green}2.${Font} 停止 OneAPI\n"
    printf "${Green}3.${Font} 重启 OneAPI\n"
    printf "${Green}4.${Font} 查看状态\n"
    printf "${Green}5.${Font} 查看日志\n"
    printf "${Green}6.${Font} 查看配置\n"
    printf "${Green}7.${Font} 编辑配置\n"
    printf "${Green}8.${Font} 访问信息\n"
    printf "${Green}9.${Font} 设置 cron 保活\n"
    printf "${Green}10.${Font} 移除 cron 任务\n"
    printf "${Red}11.${Font} 卸载 OneAPI\n"
    printf "${Yellow}0.${Font} 退出\n"
    printf "${Cyan}==================================================${Font}\n"
    echo ""
    printf "请输入选项 [0-11]: "
}

# 直接执行命令模式
case "$1" in
    start)
        start_oneapi
        exit 0
        ;;
    stop)
        stop_oneapi
        exit 0
        ;;
    restart)
        restart_oneapi
        exit 0
        ;;
    status)
        show_status
        exit 0
        ;;
    log)
        if [ -f "${LOG_PATH}/oneapi.out" ]; then
            tail -f ${LOG_PATH}/oneapi.out
        else
            echo "暂无日志"
        fi
        exit 0
        ;;
    info)
        show_info
        exit 0
        ;;
    cron)
        setup_cron
        exit 0
        ;;
esac

# 菜单模式
while true; do
    show_menu
    read choice
    case "$choice" in
        1) start_oneapi; sleep 2 ;;
        2) stop_oneapi; sleep 2 ;;
        3) restart_oneapi; sleep 2 ;;
        4) show_status; printf "\n按回车继续..."; read dummy ;;
        5) show_log; printf "\n按回车继续..."; read dummy ;;
        6) show_config; printf "\n按回车继续..."; read dummy ;;
        7) edit_config ;;
        8) show_info; printf "\n按回车继续..."; read dummy ;;
        9) setup_cron; printf "\n按回车继续..."; read dummy ;;
        10) remove_cron; printf "\n按回车继续..."; read dummy ;;
        11) uninstall_oneapi ;;
        0) printf "${Green}再见!${Font}\n"; exit 0 ;;
        *) printf "${Red}无效选项${Font}\n"; sleep 1 ;;
    esac
done
MANAGEREOF

chmod +x ${ONEAPI_PATH}/oneapi

# 创建快捷方式到 ~/bin
mkdir -p $HOME/bin
ln -sf ${ONEAPI_PATH}/oneapi $HOME/bin/oneapi 2>/dev/null

# ==================== 设置 cron 保活 ====================
printf "${Green}设置 cron 保活任务...${Font}\n"

# 获取当前 crontab
CURRENT_CRON=$(crontab -l 2>/dev/null || echo "")

# 检查是否已存在
if ! echo "$CURRENT_CRON" | grep -q "oneapi/keepalive.sh"; then
    (
        echo "$CURRENT_CRON"
        echo "# OneAPI 保活任务 (每5分钟检查)"
        echo "*/5 * * * * ${ONEAPI_PATH}/keepalive.sh"
        echo "# OneAPI 开机自启"
        echo "@reboot ${ONEAPI_PATH}/start.sh"
    ) | crontab -
    printf "${Green}cron 任务已设置${Font}\n"
else
    printf "${Yellow}cron 任务已存在${Font}\n"
fi

# ==================== 启动服务 ====================
printf "${Green}启动 OneAPI 服务...${Font}\n"
${ONEAPI_PATH}/start.sh
sleep 3

# ==================== 完成提示 ====================
clear
echo ""
printf "${GreenBG}                                                                    ${Font}\n"
printf "${GreenBG}          OneAPI 安装成功! (Hostuno FreeBSD 无 root)                ${Font}\n"
printf "${GreenBG}                                                                    ${Font}\n"
echo ""
printf "${Cyan}================ 安装信息 ================${Font}\n"
printf "${Green}安装目录:       ${Font}${ONEAPI_PATH}\n"
printf "${Green}公网 IP:        ${Font}${PUBLIC_IP}\n"
printf "${Green}监听端口:       ${Font}${PORT}\n"
printf "${Green}外部端口:       ${Font}${EXTERNAL_PORT}\n"
echo ""
printf "${Blue}Web 管理面板:${Font}\n"
printf "${Green}访问地址:       ${Font}http://${PUBLIC_IP}:${EXTERNAL_PORT}\n"
echo ""
printf "${Blue}默认管理员账号:${Font}\n"
printf "${Green}用户名:         ${Font}root\n"
printf "${Green}密码:           ${Font}123456\n"
printf "${Red}请登录后立即修改密码！${Font}\n"
printf "${Cyan}===========================================${Font}\n"
echo ""
printf "${Yellow}【无 root 环境说明】${Font}\n"
printf "${Cyan}程序安装在用户目录，使用 cron 保活${Font}\n"
printf "${Cyan}每 5 分钟自动检查进程，崩溃后自动重启${Font}\n"
printf "${Cyan}系统重启后自动启动服务${Font}\n"
echo ""
printf "${Yellow}管理命令:${Font}\n"
printf "${Green}进入管理面板:   ${Font}~/oneapi/oneapi\n"
printf "${Green}或者添加到 PATH 后直接执行:${Font} oneapi\n"
echo ""
printf "${Yellow}快捷命令:${Font}\n"
printf "${Green}~/oneapi/oneapi start   ${Font}- 启动服务\n"
printf "${Green}~/oneapi/oneapi stop    ${Font}- 停止服务\n"
printf "${Green}~/oneapi/oneapi restart ${Font}- 重启服务\n"
printf "${Green}~/oneapi/oneapi status  ${Font}- 查看状态\n"
printf "${Green}~/oneapi/oneapi log     ${Font}- 实时日志\n"
printf "${Green}~/oneapi/oneapi info    ${Font}- 访问信息\n"
printf "${Green}~/oneapi/oneapi cron    ${Font}- 设置保活\n"
echo ""
printf "${Yellow}添加到 PATH (可选):${Font}\n"
printf "${Cyan}echo 'export PATH=\$HOME/bin:\$PATH' >> ~/.profile${Font}\n"
printf "${Cyan}source ~/.profile${Font}\n"
printf "${Cyan}===========================================${Font}\n"
