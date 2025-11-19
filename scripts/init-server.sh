#!/bin/bash
set -eux

server=/abiotic/server

# 警告：不要用 root 开服
if [ "$(id -u)" -eq 0 ]; then
  echo "WARNING: Running steamcmd as root is a security risk." >&2
  echo "TIP: This image has a 'steam' user (uid=$(id steam -u), gid=$(id steam -g))." >&2
fi

# 检查 server 目录读写权限（宿主机挂卷要给对 uid/gid）
if [ ! -r "$server" ] || [ ! -w "$server" ]; then
  echo "ERROR: No read/write permissions to $server" >&2
  echo "TIP: On host: chown -R $(id -u):$(id -g) <your-host-dir-for-server>" >&2
  exit 1
fi

term_handler() {
  echo "Shutting down Abiotic Factor server..."

  # 尝试找进程
  PID=$(pgrep -of "AbioticFactorServer-Win64-Shipping.exe" || true)
  if [ -z "${PID:-}" ]; then
    echo "Server process not found, assuming already stopped."
  else
    kill -n 15 "$PID" || true
    wait "$PID" || true
  fi

  wineserver -k || true
  sleep 1
  exit 0
}

trap 'term_handler' SIGTERM SIGINT

echo ""
echo "Updating Abiotic Factor Dedicated Server files via SteamCMD..."
echo ""

# 这里只更新一次
box86 /home/steam/linux32/steamcmd \
  +@sSteamCmdForcePlatformType windows \
  +force_install_dir "$server" \
  +login anonymous \
  +app_update 2857200 validate \
  +quit

# 确保 World 存档目录存在
mkdir -p "$server/AbioticFactor/Saved/SaveGames/Server/Worlds"

echo "Server files installed under: $server"
echo "World saves under: $server/AbioticFactor/Saved/SaveGames/Server/Worlds"

# 处理 X display 锁文件
if [ -f "/tmp/.X0-lock" ]; then
  echo "Removing stale /tmp/.X0-lock"
  rm -f /tmp/.X0-lock
fi

echo ""
echo "Starting Xvfb on ${DISPLAY} (${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH})"
Xvfb "${DISPLAY}" -screen 0 "${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH}" &

echo ""
echo "Launching Abiotic Factor Dedicated Server with Wine"
echo ""

logfile="$(date +%s)-AbioticFactorServer.log"
logpath="/tmp/${logfile}"
touch "${logpath}"

# 构造启动参数（参考官方 / 社区 Linux 教程）
GAME_PORT="${AF_GAME_PORT:-7777}"
QUERY_PORT="${AF_QUERY_PORT:-27015}"
MAX_PLAYERS="${AF_MAX_PLAYERS:-6}"
WORLD_NAME="${AF_WORLD_NAME:-Cascade}"
SERVER_NAME="${AF_SERVER_NAME:-AbioticFactorDocker}"
SERVER_PASSWORD="${AF_SERVER_PASSWORD:-}"
EXTRA_ARGS="${AF_EXTRA_ARGS:-}"

cmd=(
  box64 /opt/wine-stable/bin/wine64
  "$server/AbioticFactor/Binaries/Win64/AbioticFactorServer-Win64-Shipping.exe"
  -log -newconsole -useperfthreads -NoAsyncLoadingThread
  -MaxServerPlayers="${MAX_PLAYERS}"
  -PORT="${GAME_PORT}"
  -QUERYPORT="${QUERY_PORT}"
  -tcp
  -SteamServerName="${SERVER_NAME}"
  -WorldSaveName="${WORLD_NAME}"
  -UseLocalIPs
)

# 可选密码
if [ -n "${SERVER_PASSWORD}" ]; then
  cmd+=("-ServerPassword=${SERVER_PASSWORD}")
fi

# 可选额外参数
if [ -n "${EXTRA_ARGS}" ]; then
  # shellcheck disable=SC2206
  extra=( ${EXTRA_ARGS} )
  cmd+=("${extra[@]}")
fi

# 真正启动
"${cmd[@]}" >"${logpath}" 2>&1 &
ServerPID=$!

# 把日志 tail 出去，方便 docker logs 看
tail -n 0 -f "${logpath}" &
wait "${ServerPID}"

