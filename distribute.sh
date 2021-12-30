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

# Distributes the configs in its directory to their rightful places.

# Go to the script's directory, since everything should be there.
script_dir="$(realpath ${BASH_SOURCE[0]})"
script_dir="$(dirname ${script_dir})"
want_script_dir="$(realpath ~/configs/foo)"
want_script_dir="$(dirname ${want_script_dir})"
if [[ "${script_dir}" != "${want_script_dir}" ]]; then
  echo "The config directory has to be: ${want_script_dir}, but is ${script_dir}" 1>&2
  exit 1
fi
cd "${script_dir}"

ln -sf "${script_dir}/sway_config" ~/.config/sway/config
ln -sf "${script_dir}/terminator_config" ~/.config/terminator/config
ln -sf "${script_dir}/waybar_config.json" ~/.config/waybar/config
ln -sf "${script_dir}/waybar_style.css" ~/.config/waybar/style.css
ln -sf "${script_dir}/tmux_config" ~/.tmux.conf

chmod u+x lock.sh
chmod u+x monitors.py
chmod u+x sway_shell.sh

sudo cp -rf sway_shell.sh /usr/bin/sway_shell.sh
sudo chmod o+x /usr/bin/sway_shell.sh
sudo cp -rf sway_shell.desktop /usr/share/wayland-sessions/sway_shell.desktop
