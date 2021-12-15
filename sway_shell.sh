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

# This script is a simple wrapper around the sway binary used to tweak the
# environment before entering sway.

export SSH_AUTH_SOCK="$(mktemp -d /tmp/ssh-agent-sway.XXXXXX)/agent"
export XAUTOSTART_WANT_SSH_AGENT=1

export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=sway

# Look for the connected screens and arrange them in the preferred way.
~/configs/monitors.py "all-normal" > ~/configs/sway_monitor_setup

timestamp=$(date +%s)
exec /usr/bin/sway > "/tmp/sway-stdout-${timestamp}.txt" \
                   2> "/tmp/sway-stderr-${timestamp}.txt"
