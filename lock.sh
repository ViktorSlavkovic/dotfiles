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

# This script grabs a screenshot for each screen, blurs those and invokes
# swaylock using them as backgrounds for the corresponding screens.
# In addition to that, if an argument is passed, it's used as a systemctl verb.
# This is intended for power operations, e.g. lock followed by hibernation.

function swaylock_spec() {
  local spec=""
  for out in $(swaymsg -t get_outputs | jq -r '.[].name'); do
    local raw="/tmp/scrot-raw-${out}.png"
    local blur="/tmp/scrot-blur-${out}.png"
    grim -o "${out}" "${raw}"
    convert "${raw}" -scale 2.5% -scale 4000% "${blur}"
    rm "${raw}"
    spec="${spec} --image=${out}:${blur}"
  done
  echo "${spec}"
}

swaylock -f $(swaylock_spec) &

[[ -z "$1" ]] && exit
sleep 3s
systemctl "$1"
