#!/bin/bash
#
# Copyright 2022 Viktor Slavkovic
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

# Bypasses the Wayland + Chrome fullscreen limitation described in
# https://tinyurl.com/chrome-ozone-wayland-full
# by looking for the focused floating window running Chrome (called after
# floating toggle) and if found, stretches it to 100% of the parent. 
app_id="$(swaymsg --type get_tree --raw | jq '.nodes[].nodes[].floating_nodes[] | select(.focused==true) | .app_id')"
if [[ "${app_id}" =~ ^.*(chrome|brave).*$ ]]; then
  swaymsg "resize set width 100 ppt height 100 ppt"
fi
