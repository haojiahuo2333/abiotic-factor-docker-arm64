ARG debian_version=bookworm

FROM debian:${debian_version}-slim

ENV DEBIAN_FRONTEND="noninteractive"

LABEL maintainer="Haojiahuo2333"

ARG debian_version=bookworm

# 安装基础依赖 + 多架构 + Wine + box86/box64
RUN set -eux; \
    dpkg --add-architecture armhf && dpkg --add-architecture i386 && dpkg --add-architecture amd64; \
    apt-get update && apt-get install -y --no-install-recommends --no-install-suggests \
        p7zip-full wget ca-certificates cabextract xvfb locales procps netcat-traditional winbind gpg \
        libc6:armhf libc6:arm64 libc6:i386 libc6:amd64 \
        libxi6:arm64 libxinerama1:arm64 libxcursor1:arm64 libxcomposite1:arm64 \
        mesa-vulkan-drivers:arm64; \
    locale-gen en_US.UTF-8 && dpkg-reconfigure locales; \
    \
    # 导入 box64 / box86 / winehq 的 GPG key
    wget -qO- "https://pi-apps-coders.github.io/box64-debs/KEY.gpg" | gpg --dearmor -o /usr/share/keyrings/box64-archive-keyring.gpg; \
    wget -qO- "https://pi-apps-coders.github.io/box86-debs/KEY.gpg" | gpg --dearmor -o /usr/share/keyrings/box86-archive-keyring.gpg; \
    mkdir -pm755 /etc/apt/keyrings; \
    wget -qO- "https://dl.winehq.org/wine-builds/winehq.key" | gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key; \
    wget -NP /etc/apt/sources.list.d/ "https://dl.winehq.org/wine-builds/debian/dists/${debian_version}/winehq-${debian_version}.sources"; \
    \
    # 增加 box86/box64 源
    echo "deb [signed-by=/usr/share/keyrings/box64-archive-keyring.gpg] https://Pi-Apps-Coders.github.io/box64-debs/debian ./" > /etc/apt/sources.list.d/box64.list; \
    echo "deb [signed-by=/usr/share/keyrings/box86-archive-keyring.gpg] https://Pi-Apps-Coders.github.io/box86-debs/debian ./" > /etc/apt/sources.list.d/box86.list; \
    \
    apt-get update && apt-get install -y --install-recommends --no-install-suggests \
        box64-rpi4arm64 \
        box86-rpi4arm64:armhf \
        wine-stable-amd64 wine-stable-i386:i386 wine-stable:amd64 winehq-stable; \
    \
    apt-get -y autoremove; \
    apt-get clean autoclean; \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*

ENV LANG='en_US.UTF-8'
ENV LANGUAGE='en_US:en'

# Box86/64 运行 Wine 的路径和库路径
ENV BOX86_PATH=/opt/wine-stable/bin/
ENV BOX86_LD_LIBRARY_PATH=/opt/wine-stable/lib/wine/i386-unix/:/lib/i386-linux-gnu:/lib/aarch64-linux-gnu/
ENV BOX64_PATH=/opt/wine-stable/bin/
ENV BOX64_LD_LIBRARY_PATH=/opt/wine-stable/lib/i386-unix/:/opt/wine-stable/lib64/wine/x86_64-unix/:/lib/i386-linux-gnu/:/lib/x86_64-linux-gnu:/lib/aarch64-linux-gnu/

# Wine 前缀
ENV WINEARCH=win64 WINEPREFIX=/home/steam/.wine

# X 虚拟屏幕
ENV DISPLAY=:0
ENV DISPLAY_WIDTH=1024
ENV DISPLAY_HEIGHT=768
ENV DISPLAY_DEPTH=16

# Abiotic 专用一些默认 ENV（可以在 docker-compose 里覆盖）
ENV AF_GAME_PORT=7777
ENV AF_QUERY_PORT=27015
ENV AF_MAX_PLAYERS=6
ENV AF_WORLD_NAME=Cascade
ENV AF_SAVE_INTERVAL=300

ARG UID=1001
ARG GID=1001

# 创建 steam 用户并安装 steamcmd
RUN set -eux; \
    groupadd -g ${GID} steam && useradd -u ${UID} -m steam -g steam; \
    wget -qO- "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - -C /home/steam; \
    chown -R steam:steam /home/steam

# 数据卷：
# /abiotic/server : 专用服务器文件（通过 steamcmd 安装）
VOLUME ["/abiotic/server"]

USER steam
WORKDIR /home/steam


# 拷贝启动脚本 & 健康检查脚本
ADD --chown=steam:steam scripts /home/steam/

RUN set -eux; \
    chmod +x /home/steam/init-server.sh /home/steam/healthz.sh

# 健康检查：用 healthz.sh
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=10m \
    CMD /home/steam/healthz.sh

# 默认启动命令
CMD ["/home/steam/init-server.sh"]

