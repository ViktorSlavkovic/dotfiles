#!/usr/bin/env bash
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
  echo "                   --drive=/dev/sdX [--mode=MODE]                             \\"
  echo "                                                                                "
  echo "Where MODE can be one of:                                                       "
  echo "  LIVE_IMAGE_NON_ROOT - Default. Execute in live image with or without root.    "
  echo "  LIVE_IMAGE_ROOT     - Execute in live image as root.                          "
  echo "  CHROOT              - Execute in chroot environment during setup.             "
  echo "  POST_SETUP          - Execute after the setup, on first login as --user.      "
  echo "  POST_SETUP_SHOW     - Same as above, just in a visible console.               "
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

function _log_impl() {
  local sev="$1"
  shift
  local indent="$1"
  shift

  local ts="$(date -u "+%Y-%m-%d %H:%M:%S.%N %Z")"
  local pad="$(printf %${indent}s)"
  local start="I"
  local cbefore=""
  local cafter=""
  if [[ "${sev}" == "error" ]]; then
    start="E"
    cbefore="\033[0;31m"
    cafter="\033[0m"
  elif [[ "${sev}" == "success" ]]; then
    start="S"
    cbefore="\033[0;32m"
    cafter="\033[0m"
  fi

  echo -e "${cbefore}${start}${cafter} [${ts}] ${pad}${cbefore}${@}${cafter}"
}

function _log_info() {
  local indent="$1"
  shift
  _log_impl "default" "${indent}" "$@"
}

function _log_error() {
  local indent="$1"
  shift
  _log_impl "error" "${indent}" "$@"
}

function _log_success() {
  local indent="$1"
  shift
  _log_impl "success" "${indent}" "$@"
}

function LOG() {
  local sev="$1"
  shift
  local indent=0
  if [[ $# -gt 1 ]]; then
    indent="$1"
    shift
  fi
  case "${sev}" in
    SUCCESS)
      _log_success "${indent}" $@
      ;;
    ERROR)
      _log_error "${indent}" $@
      ;;
    *)
      _log_info "${indent}" $@
  esac
}

################################################################################
# Flag parsing
################################################################################

FLAGS_HOST="_UNSET_"
FLAGS_DOMAIN="_UNSET_"
FLAGS_USER="_UNSET_"
FLAGS_DRIVE="_UNSET_"
# Values: LIVE_IMAGE_NON_ROOT, CHROOT, POST_SETUP, POST_SETUP_SHOW
FLAGS_MODE="LIVE_IMAGE_NON_ROOT"

function LOG_FLAGS() {
  local indent="$1"
  shift
  LOG INFO "${indent}" "--host=${FLAGS_HOST}"
  LOG INFO "${indent}" "--domain=${FLAGS_DOMAIN}"
  LOG INFO "${indent}" "--user=${FLAGS_USER}"
  LOG INFO "${indent}" "--drive=${FLAGS_DRIVE}"
  LOG INFO "${indent}" "--mode=${FLAGS_MODE}"
}

function parse_flags() {
  local parsed="$(getopt -a -n nixos_setup                                     \
                         -l host:,domain:,user:,drive:,eth:,wifi:,mode:        \
                         -- "$@")"
  if [ "$?" != "0" ]; then
    LOG ERROR "getopt failed to parse flags"
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
      *) LOG ERROR "Invalid argument $1"; print_usage_and_die; ;;
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
    LOG ERROR "Not all mandatory flags are set!"
    print_usage_and_die
  fi
}

ALL_FLAGS="$@"
SCRIPT_PATH="$0"
parse_flags ${SCRIPT_PATH} ${ALL_FLAGS}

################################################################################
# In live image.
################################################################################

function in_live_image_non_root() {
  force_flags

  LOG INFO "Hello from live image as ${USER}!"
  LOG_FLAGS 2

  LOG INFO "Checking if booted as UEFI..."
  if ls /sys/firmware/efi/efivars > /dev/null 2>&1; then
    LOG SUCCESS 2 "OK"
  else
    LOG ERROR 2 "Not booted as UEFI."
    exit 1
  fi

  LOG INFO "Checking if booted as x86_64 UEFI..."
  if [[ "$(cat /sys/firmware/efi/fw_platform_size)" == "64" ]]; then
    LOG SUCCESS 2 "OK"
  else
    LOG ERROR 2 "Not booted as x86_64 UEFI."
    exit 1
  fi

  LOG INFO "Checking IP connectivity and DNS..."
  # By scanning port 443 on google.com"
  if nc -zw1 google.com 443 > /dev/null 2>&1; then
    LOG SUCCESS 2 "OK"
  else
    LOG ERROR 2 "Network is down."
    exit 1 
  fi

  if [[ "${USER}" != "root" ]]; then
    LOG INFO "Handing off to root..."
    sudo ${SCRIPT_PATH} ${ALL_FLAGS} --mode=LIVE_IMAGE_ROOT
  else
    LOG INFO "Already root..."
    ${SCRIPT_PATH} ${ALL_FLAGS} --mode=LIVE_IMAGE_ROOT
  fi
}

function _ram_gib_round_pow2() {
  local gib_ram_pow2=1
  local ram_bytes="$(free -b | grep 'Mem:' | awk '{print $2}')"
  for ((;ram_bytes > gib_ram_pow2 * 1024 * 1024 * 1024;)) do
    ((gib_ram_pow2 *= 2))
  done
  echo "${gib_ram_pow2}"
}

function in_live_image_root() {
  force_flags

  LOG INFO "Hello from live image as ${USER}!"
  LOG_FLAGS 2

  # TODO: Add encryption option behind a flag.
  LOG INFO "Partitioning ${FLAGS_DRIVE}..."
  local swap_gib="$(_ram_gib_round_pow2)"
  LOG INFO 2 "RAM size in GiB rounded to the next power of 2 is ${swap_gib}GiB."
  LOG INFO 2 "Using that as swap size."
  # For some reason parted --script doesn't support using negative numbers to
  # represent offset from the end of the disk, so we're going with multiple
  # parted calls here.
  #
  # Parted doesn't generally treats GB as GiB, but it also uses GiB as a signal
  # of "user knows what they are doing", meaning that it won't perform alignment
  # at the expense of your partition size, while GB is treated as more wiggly.
  # That's why we use MB and GB here. In fact, replacing it with MiB and GiB
  # causes misalignment warnings on one of my systems.
  parted -s "${FLAGS_DRIVE}" mklabel gpt                                     &&\
  parted "${FLAGS_DRIVE}" -- mkpart "efi" fat32 1MB 512MB                    &&\
  parted "${FLAGS_DRIVE}" -- mkpart "root" ext4 512MB -"${swap_gib}"GB       &&\
  parted "${FLAGS_DRIVE}" -- mkpart "swap" linux-swap -"${swap_gib}"GB 100%  &&\
  parted "${FLAGS_DRIVE}" -- set 1 esp on                                    &&\
  partprobe "${FLAGS_DRIVE}"
  if [ "$?" == "0" ]; then
    LOG SUCCESS 2 "OK"
  else
    LOG ERROR 2 "Failed to partition ${FLAGS_DRIVE}."
    exit 1
  fi

  # Looks like there's some async flushing/propagation that needs to happen after
  # parted exits in order for udev and lsblk to know about partlabel, so let's
  # wait a bit.
  sleep 5s

  LOG INFO "Formatting the root partition as ext4..."
  local root_path="$(lsblk -ln -o PATH,PARTLABEL | grep ${FLAGS_DRIVE} | grep "root" | awk '{print $1}')"
  LOG INFO 2 "root is ${root_path}"
  mkfs.ext4 -F -L root "${root_path}" > /dev/null 2>&1
  if [ "$?" == "0" ]; then
    LOG SUCCESS 2 "OK"
  else
    LOG ERROR 2 "Failed to format root."
    exit 1
  fi

  LOG INFO "Formatting the efi partition as fat32..."
  local efi_path="$(lsblk -ln -o PATH,PARTLABEL | grep ${FLAGS_DRIVE} | grep "efi" | awk '{print $1}')"
  LOG INFO 2 "efi is ${efi_path}"
  mkfs.fat -F 32 -n efi "${efi_path}" > /dev/null 2>&1
  if [ "$?" == "0" ]; then
    LOG SUCCESS 2 "OK"
  else
    LOG ERROR 2 "Failed to format efi."
    exit 1
  fi

  LOG INFO "Formatting the swap partition with mkswap..."
  local swap_path="$(lsblk -ln -o PATH,PARTLABEL | grep ${FLAGS_DRIVE} | grep "swap" | awk '{print $1}')"
  LOG INFO 2 "swap is ${swap_path}"
  mkswap -L swap "${swap_path}" > /dev/null 2>&1
  if [ "$?" == "0" ]; then
    LOG SUCCESS 2 "OK"
  else
    LOG ERROR 2 "Failed to format swap."
    exit 1
  fi

  LOG INFO "Mount root..."
  mkdir -p /mnt
  mount /dev/disk/by-label/root /mnt
  if [ "$?" == "0" ]; then
    LOG SUCCESS 2 "OK"
  else
    LOG ERROR 2 "Failed to mount root."
    exit 1
  fi

  LOG INFO "Mount efi..."
  mkdir -p /mnt/boot
  mount -o umask=077 /dev/disk/by-label/efi /mnt/boot
  if [ "$?" == "0" ]; then
    LOG SUCCESS 2 "OK"
  else
    LOG ERROR 2 "Failed to mount efi."
    exit 1
  fi

  LOG INFO "Activating swap..."
  swapon /dev/disk/by-label/swap
  if [ "$?" == "0" ]; then
    LOG SUCCESS 2 "OK"
  else
    LOG ERROR 2 "Failed activate swap."
    exit 1
  fi

  LOG INFO "Generating nix config boilerplate..."
  nixos-generate-config --root /mnt
  if [ "$?" == "0" ]; then
    LOG SUCCESS 2 "OK"
  else
    LOG ERROR 2 "Failed to generate nix configs."
    exit 1
  fi

  LOG INFO "Fetching my nix config..."
  curl -L https://dotfiles.viktors.net/configuration.nix -o /mnt/etc/nixos/configuration.nix
  if [ "$?" == "0" ]; then
    LOG SUCCESS 2 "OK"
  else
    LOG ERROR 2 "Failed to fetch my nix config."
    exit 1
  fi

  LOG INFO "Running nixos-install..."
  nixos-install
  if [ "$?" == "0" ]; then
    LOG SUCCESS 2 "OK"
  else
    LOG ERROR 2 "nixos-install failed."
    exit 1
  fi

  LOG INFO "Copying this script and its whole dir to /mnt/setup..."
  local this_dir="$(dirname "${SCRIPT_PATH}")"
  local this_script_basename="$(basename "${SCRIPT_PATH}")"
  local alien_path="/setup/${this_script_basename}"
  cp -R "${this_dir}" "/mnt/setup"
  if [ "$?" == "0" ]; then
    LOG SUCCESS 2 "OK"
  else
    LOG ERROR 2 "Failed to copy myself to /mnt/setup."
    exit 1
  fi

  LOG INFO "Entering chroot..."
  nixos-enter --root /mnt -c bash -- ${alien_path} ${ALL_FLAGS} --mode=CHROOT
  if [ "$?" == "0" ]; then
    LOG SUCCESS 2 "OK: Successfully exited chroot."
  else
    LOG ERROR 2 "Exited chroot with failure."
    exit 1
  fi

  LOG INFO "Cleaning up..."
  umount -R /mnt
  swapoff /dev/disk/by-label/swap

  LOG SUCCESS "Press a key to reboot ..."
  read
  reboot
}

################################################################################
# In chroot
################################################################################

function in_chroot() {
  force_flags

  LOG INFO "Hello from chroot!"
  LOG_FLAGS 2

  # TODO: This is sad because aliceX would pass as alice, but also because there
  #       isn't a single SoT about where the user name comes from.
  if [[ -z "$(cat /etc/passwd | awk -F':' '{print $1}' | grep "${FLAGS_USER}")" ]]; then
    LOG ERROR 2 "User ${FLAGS_USER} doesn't exist. This is likely a mismatch between \
                 configuration.nix and --user."
    exit 1
  fi

  LOG INFO "Enter ${FLAGS_USER}'s password:"
  passwd "${FLAGS_USER}"
  if [ "$?" == "0" ]; then
    LOG SUCCESS 2 "OK"
  else
    LOG ERROR 2 "Failed to set ${FLAGS_USER}'s password."
    exit 1
  fi

  LOG INFO "Fetching and deploying dotfiles..."
  cd "/home/${FLAGS_USER}/"
  LOG INFO 2 "PWD: $PWD"

  LOG INFO 2 "Cloning the git repo..."
  git clone https://github.com/ViktorSlavkovic/dotfiles.git ./configs/
  if [ "$?" == "0" ]; then
    LOG SUCCESS 4 "OK"
  else
    LOG ERROR 4 "Failed to git clone."
    exit 1
  fi

  LOG INFO 2 "Running distribute.sh..."
  chmod u+x ./configs/distribute.sh
  HOME="/home/${FLAGS_USER}" ./configs/distribute.sh
  if [ "$?" == "0" ]; then
    LOG SUCCESS 4 "OK"
  else
    LOG ERROR 4 "distribute.sh failed"
    exit 1
  fi

  LOG INFO 2 "Misc distribute.sh follow-up."
  touch "./configs/nixos_setup_uninitialized" && \
  chown -R "${FLAGS_USER}:${FLAGS_USER}" *    && \
  chown -R "${FLAGS_USER}:${FLAGS_USER}" .*
  if [ "$?" == "0" ]; then
    LOG SUCCESS 4 "OK"
  else
    LOG ERROR 4 "Failed in one of the misc steps."
    exit 1
  fi

  LOG SUCCESS 2 "Done with juggling dotfiles."

  LOG SUCCESS "Press any key to exit chroot ..."
  read
  exit
}

################################################################################
# Post setup
################################################################################

function post_setup() {
  LOG INFO "Hello from post-setup (${FLAGS_MODE})!"

  if [[ ! -f ~/configs/nixos_setup_uninitialized ]]; then
    LOG SUCCESS "Already initialized, nothing to do here."
    exit 0
  fi

  if [[ "${FLAGS_MODE}" != "POST_SETUP_SHOW" ]]; then
    kitty --hold --start-as=fullscreen sh "$0" --mode=POST_SETUP_SHOW
    exit 0
  fi

  cat << EOM

██╗    ██╗███████╗██╗      ██████╗ ██████╗ ███╗   ███╗███████╗
██║    ██║██╔════╝██║     ██╔════╝██╔═══██╗████╗ ████║██╔════╝
██║ █╗ ██║█████╗  ██║     ██║     ██║   ██║██╔████╔██║█████╗  
██║███╗██║██╔══╝  ██║     ██║     ██║   ██║██║╚██╔╝██║██╔══╝  
╚███╔███╔╝███████╗███████╗╚██████╗╚██████╔╝██║ ╚═╝ ██║███████╗
 ╚══╝╚══╝ ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝

EOM

  LOG INFO "Setting up bashrc_implant..."
  local bashrc_implant_grep="$(cat "${HOME}/.bashrc" | grep "bashrc_implant.sh")"
  if [[ -z "${bashrc_implant_grep}" ]]; then
    echo >> "${HOME}/.bashrc"
    echo "source ~/configs/bashrc_implant.sh" >> "${HOME}/.bashrc"
    echo >> "${HOME}/.bashrc"
  fi

  LOG INFO "Removing /setup..."
  sudo rm -rf /setup
  LOG SUCCESS 2 "OK"

  LOG INFO "Removing nixos_setup_uninitialized..."
  rm -rf ~/configs/nixos_setup_uninitialized
  LOG SUCCESS 2 "OK"

  LOG SUCCESS "Done, press any key to exit ..."
  read
}

################################################################################
# Assemble
################################################################################

function main() {
  case "${FLAGS_MODE}" in
    LIVE_IMAGE_NON_ROOT)
      in_live_image_non_root
      ;;
    LIVE_IMAGE_ROOT)
      in_live_image_root
      ;;
    CHROOT)
      in_chroot
      ;;
    POST_SETUP | POST_SETUP_SHOW)
      post_setup
      ;;
    *)
      LOG ERROR "Invalid --mode=${FLAGS_MODE}"
      print_usage_and_die
  esac
}

main
