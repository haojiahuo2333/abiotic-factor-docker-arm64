#!/bin/bash
set -eux

echo "Check game port availability (UDP)"
nc -nzuv "127.0.0.1" "${AF_GAME_PORT:-7777}"

echo "Check query port availability (UDP)"
nc -nzuv "127.0.0.1" "${AF_QUERY_PORT:-27015}"

echo "Check for latest save time"

world="${AF_WORLD_NAME:-Cascade}"
data="/abiotic/server/AbioticFactor/Saved/SaveGames/Server/Worlds/${world}"

# 如果还没生成世界存档，先不把它当成失败
if [ ! -d "$data" ]; then
  echo "Save directory $data not found yet, skipping save freshness check"
  exit 0
fi

# 检查是否有文件
if ! find "$data" -type f | head -n 1 | grep -q .; then
  echo "No save files yet in $data, skipping save freshness check"
  exit 0
fi

# 找最近修改时间（秒）
last_modified=$(find "$data" -type f -printf '%T@\n' | sort -rn | head -n 1)
last_modified_int=$(printf "%.0f" "$last_modified")

# AF_SAVE_INTERVAL：你认为服务器正常情况下多少秒自动保存一次（默认 300）
base_interval="${AF_SAVE_INTERVAL:-3000}"
# 加上 180 秒缓冲
checkup_interval=$((base_interval + 180))

threshold_time=$((last_modified_int + checkup_interval))
now_ts=$(date +%s)

if [ "$threshold_time" -lt "$now_ts" ]; then
  echo "No save files updated in the last ${checkup_interval} seconds" >&2
  exit 1
else
  echo "Save files updated within the last ${checkup_interval} seconds"
fi

