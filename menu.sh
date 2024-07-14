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
  echo "Usage: menu (RUN|POWER)                                                         "
  echo "                                                                                "
  echo "This script merges multiple menu implementations in one place for running       "
  echo "simplicity, code sharing and coherent styling.                                  "
  echo "                                                                                "
  echo "Copyright (c) 2024 Viktor Slavkovic                                             "
  echo "Licensed under the Apache License, Version 2.0                                  "
  echo "                                                                                "
  exit 1
}

# Palette: https://coolors.co/fffcf2-ccc5b9-403d39-252422-eb5e28
BEMENU_STYLE=()
BEMENU_STYLE+=( --ignorecase --no-cursor --prompt "" )
BEMENU_STYLE+=( --fn 'Roboto Mono-16' )
BEMENU_STYLE+=( --center --list 20 down -W 0.1 -H 30 --scrollbar hide )
BEMENU_STYLE+=( --border 3 --border-radius 0 )
BEMENU_STYLE+=( --border-radius 0 --bdr "#252422R" )
BEMENU_STYLE+=( --nb "#403d39" --nf "#fffcf2" )
BEMENU_STYLE+=( --ab "#403d39" --af "#fffcf2" )
BEMENU_STYLE+=( --fb "#fffcf2" --ff "#252422" )
BEMENU_STYLE+=( --cb "#eb5e28" --cf "#eeebe1" )
BEMENU_STYLE+=( --hb "#eb5e28" --hf "#403d39" )

function power_menu() {
  local options="POWEROFF\nHIBERNATE\nSLEEP\nRESTART\nLOGOUT"
  local cmd="$(echo -e "${options}" | bemenu --no-exec "${BEMENU_STYLE[@]}")"
  [[ ! -z "${cmd}" ]] && ~/configs/power.sh "${cmd}"
}

function run_menu() {
  bemenu-run "${BEMENU_STYLE[@]}" -W 0.3
}

function main() {
  if [[ "$#" != 1 ]]; then
    print_usage_and_die
  fi

  case "$1" in
    POWER)
      power_menu
      ;;
    RUN)
      run_menu
      ;;
    *)
      print_usage_and_die
  esac
}

main $@
