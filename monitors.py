#!/usr/bin/env python3
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

"""Looks for screens and generates the relevant sway config commands."""

import json
import subprocess
import sys

# One of these is passed as the only argument to the script. If it's omitted or
# not in this set, 'all-normal' is assumed.
MODES = frozenset({
    # External monitors, sorted by name, left to right.
    # Internal monitor rightmost.
    # All y=0 and no rotations.
    'all-normal',
    # Same as 'all-normal', but the internal monitor is disabled.
    'no-internal-normal',
    # Same as 'all-normal', but the internal monitor is rotated by 90 ccw.
    'internal-90ccw',
})

INTERNAL = 'eDP-1'


def get_screens():
  """Queries sway for the screens JSON and returns it parsed."""
  json_str, _ = subprocess.Popen(
      ['swaymsg', '--raw', '--type', 'get_outputs'],
      stdout=subprocess.PIPE).communicate()
  return json.loads(json_str)


def build_current_state(sway_outputs):
  """Constructs an internal representation of the screens info."""
  state = dict()
  for out_spec in sway_outputs:
    max_mode = max(out_spec['modes'], key=lambda mode: mode['width'] * mode['height'])
    state[out_spec['name']] = {
        'x': out_spec['rect']['x'],
        'y': out_spec['rect']['y'],
        'w': max_mode['width'],
        'h': max_mode['height'],
        'active': out_spec['active'],
        'transform': out_spec.get('transform', 'normal'),
    }
  return state


def build_sway_config(mode, curr_state):
  """Builds the screen setting sway config commands."""
  assert mode in MODES

  externals = sorted([out for out in curr_state if out != INTERNAL])
  if not externals:
    return [f'output {INTERNAL} enable pos 0 0 transform normal']

  commands = []
  x = 0
  for out in externals[::-1]:
    commands.append(f'output {out} enable pos {x} 0 transform normal')
    x += curr_state[out]['w']

  # Sanity checks and flipping.
  if mode == 'no-internal-normal' and not curr_state[INTERNAL]['active']:
    mode = 'all-normal'

  if mode == 'internal-90ccw' and curr_state[INTERNAL]['transform'] != 'normal':
    mode = 'all-normal'

  # Handle mode differences.
  if mode == 'no-internal-normal':
    commands.append(f'output {INTERNAL} disable')
  elif mode == 'internal-90ccw':
    commands.append(f'output {INTERNAL} enable pos {x} 0 transform 270')
  else:
    commands.append(f'output {INTERNAL} enable pos {x} 0 transform normal')

  return commands


def main():
  mode = sys.argv[1] if len(
      sys.argv) > 1 and sys.argv[1] in MODES else 'all-normal'
  print(f'MODE: {mode}', file=sys.stderr)

  curr_state = build_current_state(get_screens())
  print(f'CURRENT STATE: {curr_state}', file=sys.stderr)

  for cmd in build_sway_config(mode, curr_state):
    print(cmd)


if __name__ == '__main__':
  main()
