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
  echo "Usage: power (POWEROFF|RESTART|SLEEP|HIBERNATE|LOCK|LOGOUT)                     "
  echo "                                                                                "
  echo "This script merges lock screen and power controls under one command that's easy "
  echo "to invoke from display managers/menus.                                          "
  echo "For locking, it grabs a screenshot of each screen, blurs it and uses that as the"
  echo "lockscreen background for that screen.                                          "
  echo "                                                                                "
  echo "Copyright (c) 2024 Viktor Slavkovic                                             "
  echo "Licensed under the Apache License, Version 2.0                                  "
  echo "                                                                                "
  exit 1
}

function lock_screen() {
  local spec=""
  for out in $(swaymsg -t get_outputs | jq -r '.[].name'); do
    local raw="/tmp/scrot-raw-${out}.jpeg"
    local blur="/tmp/scrot-blur-${out}.jpeg"
    grim -t jpeg -o "${out}" "${raw}"
    convert "${raw}" -scale 2.5% -scale 4000% "${blur}"
    rm "${raw}"
    spec="${spec} --image=${out}:${blur}"
  done
  swaylock -f ${spec}
}

function main() {
  if [[ "$#" != 1 ]]; then
    print_usage_and_die
  fi

  case "$1" in
    POWEROFF)
      systemctl poweroff
      ;;
    RESTART)
      systemctl reboot
      ;;
    SLEEP)
      lock_screen &
      sleep 3s
      systemctl suspend
      ;;
    HIBERNATE)
      lock_screen &
      sleep 3s
      systemctl hibernate
      ;;
    LOCK)
      lock_screen &
      ;;
    LOGOUT)
      swaymsg exit
      ;;
    *)
      print_usage_and_die
  esac
}

main $@
