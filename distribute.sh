#!/usr/bin/env bash
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

# Everything is in the script's directory.
script_dir="$(realpath ${BASH_SOURCE[0]})"
script_dir="$(dirname ${script_dir})"

# Force script directory to be ~/configs/.
want_script_dir="${HOME}/configs"
if [[ "${script_dir}" != "${want_script_dir}" ]]; then
  echo "The config directory has to be: ${want_script_dir}, but is ${script_dir}" 1>&2
  exit 1
fi

chmod u+x "${script_dir}"/*.{sh,py}

mkdir -p "${HOME}/.config/kitty"
mkdir -p "${HOME}/.config/mako"
mkdir -p "${HOME}/.config/sway"
mkdir -p "${HOME}/.config/terminator"
mkdir -p "${HOME}/.config/tmux"
mkdir -p "${HOME}/.config/waybar"
ln -sf "${script_dir}/kitty.conf"         "${HOME}/.config/kitty/kitty.conf"
ln -sf "${script_dir}/mako.conf"          "${HOME}/.config/mako/config"
ln -sf "${script_dir}/sway.conf"          "${HOME}/.config/sway/config"
ln -sf "${script_dir}/tmux.conf"          "${HOME}/.config/tmux/tmux.conf"
ln -sf "${script_dir}/waybar_config.json" "${HOME}/.config/waybar/config"
ln -sf "${script_dir}/waybar_style.css"   "${HOME}/.config/waybar/style.css"

if [[ -f "${HOME}/.bashrc" ]]; then
  bashrc_implant_grep="$(cat "${HOME}/.bashrc" | grep "bashrc_implant.sh")"
  if [[ -z "${bashrc_implant_grep}" ]]; then
    echo >> "${HOME}/.bashrc"
    echo "source ~/configs/bashrc_implant.sh" >> "${HOME}/.bashrc"
    echo >> "${HOME}/.bashrc"
  fi
fi

