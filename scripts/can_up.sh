#!/usr/bin/env bash
# @copyright Chungbuk National University, Autonomous Vehicle Laboratory, 2026. All rights reserved.
#            Subject to limited distribution and restricted disclosure only.
#
# @file      can_up.sh
# @brief     Bring up a SocketCAN interface (real CAN or vcan) (ROS-independent)
#
# @date      2026-10-14 created by Junhyeok Seo (jun2342@chungbuk.ac.kr)
#
# Usage:
#   can_up.sh [IFACE] [BITRATE]
#     can_up.sh               # can0 @ 500000
#     can_up.sh can1 500000
#     can_up.sh vcan0         # virtual CAN for log replay (bitrate ignored)

set -euo pipefail

IFACE="${1:-can0}"
BITRATE="${2:-500000}"

SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
  SUDO="sudo"
fi

if [[ "${IFACE}" == vcan* ]]; then
  ${SUDO} modprobe vcan 2>/dev/null || true
  if ! ip link show "${IFACE}" >/dev/null 2>&1; then
    ${SUDO} ip link add dev "${IFACE}" type vcan
  fi
  ${SUDO} ip link set "${IFACE}" up
else
  if ! ip link show "${IFACE}" >/dev/null 2>&1; then
    echo "error: ${IFACE} not found (is the CAN adapter connected?)" >&2
    exit 1
  fi
  # bitrate can only be changed while the link is down
  ${SUDO} ip link set "${IFACE}" down
  ${SUDO} ip link set "${IFACE}" type can bitrate "${BITRATE}"
  ${SUDO} ip link set "${IFACE}" up
fi

ip -details link show "${IFACE}"
