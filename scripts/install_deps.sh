#!/usr/bin/env bash
# @copyright Chungbuk National University, Autonomous Vehicle Laboratory, 2026. All rights reserved.
#            Subject to limited distribution and restricted disclosure only.
#
# @file      install_deps.sh
# @brief     Install everything vehicle_ws needs on top of ROS 1 noetic (vehicle PC and docker image)
#
# @date      2026-11-10 created by Junhyeok Seo (jun2342@chungbuk.ac.kr)
#
# The vehicle PC builds the workspace without docker, and the dev image runs this same script,
# so both get the same packages. ROS itself (ros-noetic-desktop-full) must already be installed.
#
# Usage:
#   scripts/install_deps.sh            # apt packages, dbcppp, pip packages
#   DBCPPP_PREFIX=/opt/dbcppp DBCPPP_VERSION=v3.2.6 scripts/install_deps.sh
#   BUILD_JOBS=8 scripts/install_deps.sh   # parallel compile jobs for dbcppp (default 4)
#
# Installs:
#   apt     build and CAN tools, catkin_tools, pybind11, yaml-cpp, ROS message/bridge packages
#   dbcppp  built from source into DBCPPP_PREFIX (it has no package.xml, so catkin cannot build it)
#   pip     requirements.txt (web tool packages missing from focal apt)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_DIR="$(dirname "${SCRIPT_DIR}")"

ROS_DISTRO="${ROS_DISTRO:-noetic}"
DBCPPP_VERSION="${DBCPPP_VERSION:-v3.2.6}"
# Own prefix, not /usr/local: dbcppp also installs its bundled libxml2, which would shadow
# the system libxml2 (built with iconv/zlib) for every program on the PC.
DBCPPP_PREFIX="${DBCPPP_PREFIX:-/opt/dbcppp}"
# Few jobs on purpose: -j$(nproc) can exhaust RAM on many-core PCs and freeze the desktop.
BUILD_JOBS="${BUILD_JOBS:-4}"

SUDO=""
SUDO_H=""   # sudo -H: pip cache and config go to root's home, not the user's
if [[ "$(id -u)" -ne 0 ]]; then
  SUDO="sudo"
  SUDO_H="sudo -H"
fi

if [[ ! -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]]; then
  echo "error: /opt/ros/${ROS_DISTRO} not found. Install ros-${ROS_DISTRO}-desktop-full first." >&2
  exit 1
fi

# ---------------------------------------------------------------------------------------------
# apt
# ---------------------------------------------------------------------------------------------
echo "==> apt packages"
${SUDO} apt-get update
${SUDO} apt-get install -y --no-install-recommends \
  build-essential \
  cmake \
  git \
  python3-dev \
  python3-pip \
  python3-pytest \
  python3-yaml \
  python3-catkin-tools \
  python3-rosdep \
  python3-vcstool \
  pybind11-dev \
  libyaml-cpp-dev \
  libgtest-dev \
  can-utils \
  iproute2 \
  kmod \
  "ros-${ROS_DISTRO}-can-msgs" \
  "ros-${ROS_DISTRO}-foxglove-bridge"

# ---------------------------------------------------------------------------------------------
# dbcppp
# ---------------------------------------------------------------------------------------------
install_dbcppp() {
  local marker="${DBCPPP_PREFIX}/share/dbcppp_version"
  if [[ -f "${marker}" && "$(cat "${marker}")" == "${DBCPPP_VERSION}" ]]; then
    echo "==> dbcppp ${DBCPPP_VERSION} already in ${DBCPPP_PREFIX}"
    return
  fi

  echo "==> dbcppp ${DBCPPP_VERSION} -> ${DBCPPP_PREFIX}"
  local tmp
  tmp="$(mktemp -d)"
  git clone --depth 1 --branch "${DBCPPP_VERSION}" --recurse-submodules --shallow-submodules \
    https://github.com/xR3b0rn/dbcppp.git "${tmp}/dbcppp"
  # $ORIGIN(/../lib): libdbcppp.so and the dbcppp CLI find libxmlmm/libxml2 without ld.so.conf
  cmake -S "${tmp}/dbcppp" -B "${tmp}/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${DBCPPP_PREFIX}" \
    -DCMAKE_INSTALL_RPATH='$ORIGIN:$ORIGIN/../lib' \
    -Dbuild_tests=OFF \
    -Dbuild_examples=OFF
  cmake --build "${tmp}/build" -j "${BUILD_JOBS}"
  ${SUDO} cmake --install "${tmp}/build"

  # find_package(libdbcppp) searches /usr/local by default; point it at the real config.
  local redirect=/usr/local/lib/cmake/libdbcppp
  ${SUDO} mkdir -p "${redirect}"
  echo "include(\"${DBCPPP_PREFIX}/lib/cmake/libdbcppp/libdbcpppConfig.cmake\")" |
    ${SUDO} tee "${redirect}/libdbcpppConfig.cmake" >/dev/null
  echo "include(\"${DBCPPP_PREFIX}/lib/cmake/libdbcppp/libdbcpppConfigVersion.cmake\")" |
    ${SUDO} tee "${redirect}/libdbcpppConfigVersion.cmake" >/dev/null

  echo "${DBCPPP_VERSION}" | ${SUDO} tee "${marker}" >/dev/null
  rm -rf "${tmp}"
}
install_dbcppp

# ---------------------------------------------------------------------------------------------
# pip
# ---------------------------------------------------------------------------------------------
echo "==> pip packages (${WS_DIR}/requirements.txt)"
${SUDO_H} python3 -m pip install --no-cache-dir -r "${WS_DIR}/requirements.txt"

# ---------------------------------------------------------------------------------------------
# rosdep
# ---------------------------------------------------------------------------------------------
if [[ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]]; then
  ${SUDO} rosdep init
fi

echo "==> done"
echo "    next: rosdep update && catkin build (see README.md)"
