# @copyright Chungbuk National University, Autonomous Vehicle Laboratory, 2026. All rights reserved.
#            Subject to limited distribution and restricted disclosure only.
#
# @file      Dockerfile
# @brief     vehicle_ws dev image: Ubuntu 20.04, ROS 1 noetic desktop-full, scripts/install_deps.sh
#
# @date      2026-11-10 created by Junhyeok Seo (jun2342@chungbuk.ac.kr)
#
# Build and run with compose (docker/compose.yaml):
#   docker compose -f docker/compose.yaml up -d --build
#   docker compose -f docker/compose.yaml exec dev bash
#
# Only the base OS and ROS are set up here. Everything the workspace needs on top of ROS is in
# scripts/install_deps.sh, which the vehicle PC (no docker) runs as well.
FROM ubuntu:20.04

ARG ROS_DISTRO=noetic
ARG ROS_APT_SOURCE_VERSION=1.3.0
ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=1000
# Parallel compile jobs while building the image (dbcppp); keeps RAM use low.
ARG BUILD_JOBS=4

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    ROS_DISTRO=${ROS_DISTRO}

SHELL ["/bin/bash", "-c"]

# What a fresh Ubuntu install already has, plus sudo and locale.
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash-completion \
      ca-certificates \
      curl \
      git \
      gnupg2 \
      less \
      locales \
      lsb-release \
      nano \
      sudo \
      tzdata \
      wget \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ROS 1 noetic desktop-full (ros-apt-source installs the repo and its signing key)
RUN curl -fsSL -o /tmp/ros-apt-source.deb \
      "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${VERSION_CODENAME})_all.deb" \
    && apt-get install -y /tmp/ros-apt-source.deb \
    && rm /tmp/ros-apt-source.deb \
    && apt-get update && apt-get install -y --no-install-recommends \
      ros-${ROS_DISTRO}-desktop-full \
    && rm -rf /var/lib/apt/lists/*

# Workspace dependencies (same script as the vehicle PC)
COPY scripts/install_deps.sh /tmp/vehicle_ws_deps/scripts/install_deps.sh
COPY requirements.txt /tmp/vehicle_ws_deps/requirements.txt
RUN BUILD_JOBS=${BUILD_JOBS} bash /tmp/vehicle_ws_deps/scripts/install_deps.sh \
    && rm -rf /tmp/vehicle_ws_deps /var/lib/apt/lists/*

# Non-root user with passwordless sudo. UID/GID match the host user so files in the mounted
# workspace keep the host owner.
RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /bin/bash ${USERNAME} \
    && usermod -aG sudo,dialout,video,plugdev ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

USER ${USERNAME}
WORKDIR /home/${USERNAME}/vehicle_ws

RUN rosdep update --rosdistro ${ROS_DISTRO} \
    && { echo "source /opt/ros/${ROS_DISTRO}/setup.bash"; \
         echo "[ -f ~/vehicle_ws/devel/setup.bash ] && source ~/vehicle_ws/devel/setup.bash"; } \
       >> /home/${USERNAME}/.bashrc

CMD ["bash"]
