#!/bin/bash
#
# Copyright 2024 Viktor Slavkovic
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function print_usage_and_die() {
  echo "                                                                                "
  echo "Usage: nixos_setup --host=alpha --domain=example.com --user=alice             \\"
  echo "                   --drive=/dev/sdX                                           \\"
  echo "                   --mode=(LIVE_IMAGE|CHROOT|POST_SETUP|POST_SETUP_SHOW)        "
  echo "                                                                                "
  echo "This script automates installation of NixOS (https://nixos.org) on my systems.  "
  echo "It's supposed to be run from the NixOS minimal ISO image and it will do the     "
  echo "basic setup, including disk formatting, and fetch my NixOS and other configs.   "
  echo "                                                                                "
  echo "This script is also available from nixos-setup.viktors.net.                     "
  echo "                                                                                "
  exit 1
}

################################################################################
# Utilities
################################################################################

function _log_helper() {
  # _log_helper color indent msg
  local color="$1"
  shift
  local indent="$1"
  shift

  local ts="$(date -u "+%Y-%m-%d %H:%M:%S.%N %Z")"
  local pad="$(printf %${indent}s)"
  local start="I"
  local cbefore=""
  local cafter=""
  if [[ "${color}" == "error" ]]; then
    start="E"
    cbefore="\033[0;31m"
    cafter="\033[0m"
  elif [[ "${color}" == "success" ]]; then
    start="S"
    cbefore="\033[0;32m"
    cafter="\033[0m"
  fi

  echo -e "${cbefore}${start}${cafter} [${ts}] ${pad}${cbefore}${@}${cafter}"
}

function LOG_INFO() {
  local indent=0
  if [[ $# -gt 1 ]]; then
    local indent="$1"
    shift
  fi
  _log_helper "default" "${indent}" $@
}

function LOG_ERROR() {
  local indent=0
  if [[ $# -gt 1 ]]; then
    local indent="$1"
    shift
  fi
  _log_helper "error" "${indent}" $@
}

function LOG_SUCCESS() {
  local indent=0
  if [[ $# -gt 1 ]]; then
    local indent="$1"
    shift
  fi
  _log_helper "success" "${indent}" $@
}

################################################################################
# Flag parsing
################################################################################

FLAGS_HOST="_UNSET_"
FLAGS_DOMAIN="_UNSET_"
FLAGS_USER="_UNSET_"
FLAGS_DRIVE="_UNSET_"
FLAGS_MODE="LIVE_IMAGE" # Values: LIVE_IMAGE, CHROOT, POST_SETUP, POST_SETUP_SHOW

function LOG_FLAGS() {
  LOG_INFO "--host=${FLAGS_HOST}"
  LOG_INFO "--domain=${FLAGS_DOMAIN}"
  LOG_INFO "--user=${FLAGS_USER}"
  LOG_INFO "--drive=${FLAGS_DRIVE}"
  LOG_INFO "--mode=${FLAGS_MODE}"
}

function parse_flags() {
  local parsed="$(getopt -a -n nixos_setup \
                    -l host:,domain:,user:,drive:,eth:,wifi:,mode: -- "$@")"
  if [ "$?" != "0" ]; then
    LOG_ERROR "getopt failed to parse flags"
    print_usage_and_die
  fi
  eval set -- "${parsed}"
  while :; do
    case "$1" in
      --host)      FLAGS_HOST="$2"   ; shift 2 ;;
      --domain)    FLAGS_DOMAIN="$2" ; shift 2 ;;
      --user)      FLAGS_USER="$2"   ; shift 2 ;;
      --drive)     FLAGS_DRIVE="$2"  ; shift 2 ;;
      --mode)      FLAGS_MODE="$2"   ; shift 2 ;;
      # End of flags.
      --)       shift; break ;;
      # Invalid argument.
      *) LOG_ERROR "Invalid argument $1"; print_usage_and_die; ;;
    esac
  done
}

function force_flags() {
  local mandatory_flags=""
  mandatory_flags+="${FLAGS_HOST}"
  mandatory_flags+="${FLAGS_DOMAIN}"
  mandatory_flags+="${FLAGS_USER}"
  mandatory_flags+="${FLAGS_DRIVE}"
  if [[ "${mandatory_flags}" == *"_UNSET_"* ]]; then
    LOG_ERROR "Not all mandatory flags are set!"
    print_usage_and_die
  fi
}

ALL_FLAGS="$@"
SCRIPT_PATH="$0"
parse_flags ${SCRIPT_PATH} ${ALL_FLAGS}

################################################################################
# In live image's root
################################################################################

function in_live_image() {
  force_flags

  LOG_INFO "Hello from live image!"
  LOG_FLAGS

  LOG_ERROR "Unimplemented, coming soon."
  exit 1
}

################################################################################
# In chroot
################################################################################

function in_chroot() {
  force_flags

  LOG_INFO "Hello from chroot!"
  LOG_FLAGS

  LOG_ERROR "Unimplemented, coming soon."
  exit 1
}

################################################################################
# Post setup
################################################################################

function post_setup() {
  force_flags

  LOG_INFO "Hello from post-setup!"
  LOG_FLAGS

  LOG_ERROR "Unimplemented, coming soon."
  exit 1
}

################################################################################
# Assemble
################################################################################

function main() {
  case "${FLAGS_MODE}" in
  LIVE_IMAGE)
    in_live_image
    ;;
  CHROOT)
    in_chroot
    ;;
  POST_SETUP | POST_SETUP_SHOW)
    post_setup
    ;;
  *)
    LOG_ERROR "Invalid --mode=${FLAGS_MODE}"
    print_usage_and_die
  esac
}

main
