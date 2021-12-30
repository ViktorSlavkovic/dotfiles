#!/bin/bash
#
# Copyright 2021 Viktor Slavkovic
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

# Sets up Arch Linux (https://archlinux.org/) in a semi-generic way.
# It's supposed to be run from the Arch live image. It will then do an initial
# setup, go to chroot, call itself from there for a second phase and finally,
# call itself once again on the first login as non-root.

################################################################################
# Flag parsing
################################################################################

FLAGS_HOST="_UNSET_"
FLAGS_DOMAIN="_UNSET_"
FLAGS_USER="_UNSET_"
FLAGS_DRIVE="_UNSET_"
FLAGS_MODE="LIVE_IMAGE" # Values: LIVE_IMAGE, CHROOT, POST_SETUP

function print_usage_and_die() {
  echo "Usage: arch_setup --host=alpha --domain=example.com --user=alice \\"
  echo "                  --drive=/dev/sdX                               \\"
  echo "                  --mode=(LIVE_IMAGE|CHROOT|POST_SETUP)"
  exit 2
}

function print_flags() {
  echo "--host=${FLAGS_HOST}"
  echo "--domain=${FLAGS_DOMAIN}"
  echo "--user=${FLAGS_USER}"
  echo "--drive=${FLAGS_DRIVE}"
  echo "--mode=${FLAGS_MODE}"
}

function parse_flags() {
  local parsed="$(getopt -a -n arch_setup \
                    -l host:,domain:,user:,drive:,eth:,wifi:,mode: -- "$@")"
  if [ "$?" != "0" ]; then
    echo "getopt failed"
    print_usage_and_die
  fi
  eval set -- "${parsed}"
  while :; do
    case "$1" in
      --host)      FLAGS_HOST="$2"   ; shift 2 ;;
      --domain)    FLAGS_DOMAIN="$2" ; shift 2 ;;
      --user)      FLAGS_USER="$2"   ; shift 2 ;;
      --drive)     FLAGS_DRIVE="$2"  ; shift 2 ;;
      --env)       FLAGS_MODE="$2"   ; shift 2 ;;
      # End of flags.
      --)       shift; break ;;
      # Invalid argument.
      *) echo "invalid argument $1"; print_usage_and_die; ;;
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
    echo "mandatory not set"
    print_usage_and_die
  fi
}

ALL_FLAGS="$@"
SCRIPT_PATH="$0"
parse_flags ${SCRIPT_PATH} ${ALL_FLAGS}

################################################################################
# Utilities
################################################################################

echo_spaced() {
  local num_spaces="$1"
  shift
  echo "$(printf %${num_spaces}s)$@"
}

echo_err_spaced() {
  echo_spaced $@ 1>&2
}

################################################################################
# In live arch image's root
################################################################################

function in_live_image() {
  force_flags

  echo "Hello from live image!"
  print_flags

  echo "Check if booted as UEFI"
  if ls /sys/firmware/efi/efivars > /dev/null 2>&1; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Not booted as UEFI"
    exit 1 
  fi

  echo "Check if booted as x86_64 UEFI"
  if [[ "$(cat /sys/firmware/efi/fw_platform_size)" == "64" ]]; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Not booted as x86_64 UEFI"
    exit 1
  fi

  echo "Check IP connectivity and DNS"
  # By scanning port 443 on google.com"
  if nc -zw1 google.com 443; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Network is down"
    exit 1 
  fi

  echo "Enabling NTP"
  cat > /etc/ntp.conf << EOM
server time1.google.com iburst
server time2.google.com iburst
server time3.google.com iburst
server time4.google.com iburst
EOM
  # Note that timedatectl != ntpd.
  if systemctl enable ntpd.service; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed to enable NTP"
    exit 1 
  fi

  echo "Partition ${FLAGS_DRIVE}"
  # TODO: Add encryption option
  # TODO: Get RAM size via free -gt | tail -n1 | awk ‘{print $2}’ and use it to
  #       compute swap size.
  parted --script "${FLAGS_DRIVE}"                                               \
    mklabel gpt                                                                  \
    mkpart "efi" fat32 1MiB 513MiB                                               \
    set 1 esp on                                                                 \
    mkpart "swap" linux-swap 513MiB 16384MiB                                     \
    mkpart "root" ext4 16384MiB 100%                                             \
    quit && partprobe "${FLAGS_DRIVE}"
  if [ "$?" == "0" ]; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed to partition ${FLAGS_DRIVE}"
    exit 1
  fi

  echo "Run mkfs.ext4 on the root partition"
  root_path=$(lsblk -ln -o PATH,PARTLABEL | grep ${FLAGS_DRIVE} | grep "root" | awk '{print $1}')
  echo_spaced 2 "root is ${root_path}"
  mkfs.ext4 -F "${root_path}"
  if [ "$?" == "0" ]; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed to format root"
    exit 1
  fi

  echo "Mount root"
  mount "${root_path}" /mnt
  if [ "$?" == "0" ]; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed to mount root"
    exit 1
  fi

  echo "Run mkfs.fat on the efi partition"
  efi_path=$(lsblk -ln -o PATH,PARTLABEL | grep ${FLAGS_DRIVE} | grep "efi" | awk '{print $1}')
  echo_spaced 2 "efi is ${efi_path}"
  mkfs.fat -F 32 "${efi_path}"
  if [ "$?" == "0" ]; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed to format efi"
    exit 1
  fi

  echo "Mount efi"
  mkdir /mnt/efi
  efi_path=$(lsblk -ln -o PATH,PARTLABEL | grep ${FLAGS_DRIVE} | grep "efi" | awk '{print $1}')
  echo_spaced 2 "efi is ${efi_path}"
  mount "${efi_path}" /mnt/efi
  if [ "$?" == "0" ]; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed to mount efi"
    exit 1
  fi

  echo "Run mkswap on the swap partition"
  swap_path=$(lsblk -ln -o PATH,PARTLABEL | grep ${FLAGS_DRIVE} | grep "swap" | awk '{print $1}')
  echo_spaced 2 "swap is ${swap_path}"
  mkswap "${swap_path}"
  if [ "$?" == "0" ]; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed to mkswap"
    exit 1
  fi

  echo "Activate swap"
  swapon "${swap_path}"
  if [ "$?" == "0" ]; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed activate swap"
    exit 1
  fi

  echo "Installing essential packages"
  # jq needed for the lock script
  # imagemagick for convert
  # mako for wayland notifications
  # TODO: Transition to pipewire
  yes | pacstrap /mnt base dmenu grub efibootmgr gnu-free-fonts gdm linux      \
                      linux-firmware terminator network-manager-applet         \
                      networkmanager noto-fonts-emoji pavucontrol pulseaudio   \
                      ranger sudo sway swaybg swayidle swaylock ttf-droid      \
                      ttf-font-awesome unzip vim waybar xorg-xwayland          \
                      grim imagemagick pulseaudio-alsa pulseaudio-bluetooth    \
                      blueman light python bluez bluez-utils mesa vulkan-intel \
                      vulkan-icd-loader vulkan-tools acpi_call git base-devel  \
		                  man-db jq udevil ntfs-3g encfs libva-utils               \
                      intel-media-driver openssh gimp firefox tmux gthumb vlc  \
                      imagemagick mako
  if [ "$?" == "0" ]; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed to install essential packages"
    exit 1
  fi

  echo "Generating fstab"
  genfstab -U /mnt >> /mnt/etc/fstab
  if [ "$?" == "0" ]; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed to generate fstab"
    exit 1
  fi

  echo "Copy this script and its whole dir to /mnt/setup"
  local this_dir="$(dirname "${SCRIPT_PATH}")"
  local this_script_basename="$(basename "${SCRIPT_PATH}")"
  local alien_path="/setup/${this_script_basename}"
  cp -R "${this_dir}" "/mnt/setup"
  if [ "$?" == "0" ]; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed to copy myself to /mnt/setup"
    exit 1
  fi

  echo "Entering chroot"
  arch-chroot /mnt /bin/bash ${alien_path} ${ALL_FLAGS} --mode=CHROOT
  if [ "$?" == "0" ]; then
    echo_spaced 2 "Exited chroot with success"
  else
    echo_err_spaced 2 "Exited chroot with failure"
    exit 1
  fi

  echo "Cleanup"
  umount -R /mnt
  swapoff "${swap_path}"

  echo "Press a key to reboot ..."
  reboot
}

################################################################################
# In chroot
################################################################################

function in_chroot() {
  force_flags

  echo "Hello from chroot!"
  print_flags

  echo "Setting up time"
  # Use Google's NTP servers
  cat > /etc/ntp.conf << EOM
server time1.google.com iburst
server time2.google.com iburst
server time3.google.com iburst
server time4.google.com iburst
EOM
  if systemctl enable ntpd.service; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed to enable NTP"
    exit 1 
  fi

  # TODO: Get the timezone online and use it instead.
  ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
  if [ "$?" != "0" ]; then
    echo_err_spaced 2 "Failed to link /etc/localtime"
    exit 1
  fi
  hwclock --systohc
  if [ "$?" != "0" ]; then
    echo_err_spaced 2 "Failed to set HW clock"
    exit 1
  fi
  echo_spaced 2 "OK"

  echo "Locale"
  if localectl set-locale LANG=en_US.UTF-8; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed to set locale"
    exit 1 
  fi

  echo "Set hostname to ${FLAGS_HOST}"
  echo "${FLAGS_HOST}" > /etc/hostname
  cat > /etc/hosts << EOM
127.0.0.1     localhost
::1           localhost
EOM
  echo "127.0.1.1     ${FLAGS_HOST}.${FLAGS_DOMAIN}     ${FLAGS_HOST}" >> /etc/hosts
  echo_spaced 2 "OK"

  echo "Configure network"
  if systemctl enable NetworkManager.service; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed to enable NetworkManager service"
    exit 1
  fi

  echo "Configure bluetooth"
  if systemctl enable bluetooth.service; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed to enable bluetooth service"
    exit 1
  fi

  echo "Enable login manager"
  if systemctl enable gdm.service; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed to enable gdm service"
    exit 1
  fi

  echo "Create initramfs"
  if mkinitcpio -P; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed to create initiramfs"
    exit 1 
  fi

  echo "Install GRUB"
  if  grub-install --target=x86_64-efi --efi-directory=efi --bootloader-id=GRUB; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Bootloader setup failed"
    exit 1 
  fi

  echo "Generate GRUB config"
  if grub-mkconfig -o /boot/grub/grub.cfg; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Generating GRUB config failed"
    exit 1 
  fi

  echo "Enter root password"
  # TODO: Pass on command line, ideally as a file.
  passwd

  echo "Create user: ${FLAGS_USER}"
  if useradd --create-home --user-group --shell /bin/bash "${FLAGS_USER}"; then
    echo_spaced 2 "OK"
  else
    echo_err_spaced 2 "Failed to create ${FLAGS_USER} user"
    exit 1 
  fi

  echo "Enter ${FLAGS_USER}'s password"
  # TODO: Pass on command line, ideally as a file.
  passwd "${FLAGS_USER}"

  echo "Setup sudo for ${FLAGS_USER}"
  echo "${FLAGS_USER} ALL=(ALL:ALL) ALL" | sudo EDITOR='tee -a' visudo

  echo "Add ${FLAGS_USER} to the relevant groups"
  gpasswd -a "${FLAGS_USER}" video # for brightness

  echo "Fix birghtness control permissions"
  cat >> /etc/udev/rules.d/backlight.rules << EOM
RUN+="/bin/chgrp video /sys/class/backlight/intel_backlight/brightness"
RUN+="/bin/chmod g+w /sys/class/backlight/intel_backlight/brightness"
EOM

  echo "Fetch and deploy config files."
  cd "/home/${FLAGS_USER}/"
  echo_spaced 2 "PWD: $PWD"

  echo_spaced 2 "Cloning the git repo"
  git clone https://github.com/ViktorSlavkovic/dotfiles.git ./configs/

  echo_spaced 2 "Running distribute.sh"
  chmod u+x ./configs/distribute.sh
  ./configs/distribute.sh

  touch "configs/arch_setup_uninitialized"

  chown -R "${FLAGS_USER}:${FLAGS_USER}" *
  chown -R "${FLAGS_USER}:${FLAGS_USER}" .*

  echo "Press any key to exit chroot ..."
  read
  exit
}

################################################################################
# Post setup
################################################################################

function post_setup() {
  if [[ ! -f ~/configs/arch_setup_uninitialized ]]; then
    echo "Already initialized, nothing to do here."
    exit 0
  fi

  if [[ "$1" != "show" ]]; then
    terminator -x "$0" show
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

  echo "Setup bashrc_implant"
  local bashrc_implant_grep="$(cat "${HOME}/.bashrc" | grep "bashrc_implant.sh")"
  if [[ -z "${bashrc_implant_grep}" ]]; then
    echo >> "${HOME}/.bashrc"
    echo "source ~/configs/bashrc_implant.sh" >> "${HOME}/.bashrc"
    echo >> "${HOME}/.bashrc"
  fi

  echo "Remove /setup"
  sudo rm -rf /setup

  echo "Install yay"
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  cd -
  rm -rf yay

  echo "Install stuff with yay"
  yay -S --noconfirm brave-bin visual-studio-code-bin

  echo "Done, press any key to exit ..."
  read

  rm ~/configs/arch_setup_uninitialized
}

################################################################################
# Assemble
################################################################################

case "${FLAGS_MODE}" in
  LIVE_IMAGE)
    in_live_image
    ;;
  CHROOT)
    in_chroot
    ;;
  POST_SETUP)
    post_setup
    ;;
  *)
    echo_err_spaced 0 "Unrecognized mode!"
    print_usage_and_die
esac
