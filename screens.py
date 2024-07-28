#!/usr/bin/env python3
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

import dataclasses
import enum
import json
import subprocess
import sys

_USAGE = '''
Usage: screens [MODE]

Looks for sway outputs and repositions them into one of the MODE-s.

Where MODE can be one of:

  * DEFAULT:        External screens, sorted by ID, left to right.
                    Internal screen goes after that, rightmost.
                    All top-aligned (y-0) and no rotations.
  * INTERNAL_OFF:   Same as DEFAULT, but the internal screen is disabled.
                    If invoked with this mode while already in it, toggles back
                    to DEFAULT.
  * INTERNAL_90CCW: Same as DEFAULT, but the internal screen is rotated by 90
                    deg CCW.
                    If invoked with this mode while already in it, toggles back
                    to DEFAULT.

If MODE is omitted, DEFAULT is assumed.

Copyright (c) 2024 Viktor Slavkovic
Licensed under the Apache License, Version 2.0
'''


class Mode(enum.Enum):
  DEFAULT = 1
  INTERNAL_OFF = 2
  INTERNAL_90CCW = 3


@dataclasses.dataclass
class SwayScreen:
  """Represents a single screen with sway-relevant properties."""

  id: str = ''
  enabled: bool = False
  pos_x: int = 0
  pos_y: int = 0
  res_w: int = 0
  res_h: int = 0
  # As per `man 5 sway-output`.
  transform: str = 'normal'

  def is_internal(self) -> bool:
    # This is sad, but should be a good enough estimate on modern laptops.
    return self.id.startswith('eDP-')

  def from_sway_json(self, out_spec: any):
    """Populates the current object from swaymsg get_outputs out spec."""
    self.id = out_spec['name']
    self.pos_x = out_spec['rect']['x']
    self.pos_y = out_spec['rect']['y']
    self.enabled = out_spec['active']
    self.transform = out_spec.get('transform', 'normal')

    max_mode = max(out_spec['modes'],
                   key=lambda mode: mode['width'] * mode['height'])
    self.res_w = max_mode['width']
    self.res_h = max_mode['height']

  def to_sway_command(self) -> str:
    """Generates a sway output command from the current object state."""
    if self.enabled:
      return f'output {self.id} enable pos {self.pos_x} {self.pos_y} transform {self.transform}'
    return f'output {self.id} disable'


def get_screens() -> list[SwayScreen]:
  """Queries sway for the screens JSON and returns it parsed as SwayScreen-s."""
  swaymsg_args = ['swaymsg', '--raw', '--type', 'get_outputs']
  result = subprocess.run(
      args=swaymsg_args,
      capture_output=True,
      text=True,
  )
  if result.returncode != 0:
    raise RuntimeError(
        f'Calling swaymsg with {swaymsg_args} failed with {result.returncode}.')

  # Might raise json.JSONDecodeError, but let it bubble up.
  out_specs = json.loads(result.stdout)

  screens = list()
  for out_spec in out_specs:
    screen = SwayScreen()
    screen.from_sway_json(out_spec)
    screens.append(screen)
  return sorted(screens, key=lambda s: s.id)


def set_screens(screens: list[SwayScreen]):
  """Invokes swaymsg to set the provided screen state."""
  for screen in screens:
    swaymsg_args = ['swaymsg', screen.to_sway_command()]
    result = subprocess.run(
        args=swaymsg_args,
        text=True,
    )
    if result.returncode != 0:
      raise RuntimeError(
          f'Calling swaymsg with {swaymsg_args} failed: {result.returncode}')


def reconfigure_screens(screens: dict[str, SwayScreen], mode: Mode) -> Mode:
  if not screens:
    raise RuntimeError('No screens to reconfigure!')

  internals = sorted([id for id, s in screens.items() if s.is_internal()])
  externals = sorted([id for id, s in screens.items() if not s.is_internal()])

  if len(internals) > 1:
    raise RuntimeError(
        f'Number of internal screens is greater than 1: {internals}')

  # If not docked, fall back to DEFAULT to make sure that the internal screen is
  # on and not weirdly transformed.
  if not externals:
    mode = Mode.DEFAULT

  # If the mode is INTERNAL_OFF, yet the intenral screen is disabled, we'll
  # treat that as toggle back from INTERNAL_OFF to DEFAULT.
  if mode == Mode.INTERNAL_OFF and internals and not screens[internals[0]].enabled:
    mode = Mode.DEFAULT

  # Same for toggling back from INTERNAL_90CCW.
  if mode == Mode.INTERNAL_90CCW and internals and screens[internals[0]].transform != 'normal':
    mode = Mode.DEFAULT

  # Handle externals.
  x = 0
  for e in externals:
    s = screens[e]
    s.enabled = True
    s.pos_x = x
    s.pos_y = 0
    s.transform = 'normal'
    x += s.res_w

  # Handle internal.
  if not internals:
    return mode

  internal = screens[internals[0]]
  if mode == Mode.INTERNAL_OFF:
    internal.enabled = False
  elif mode == Mode.INTERNAL_90CCW:
    internal.enabled = True
    internal.pos_x = x
    internal.pos_y = 0
    internal.transform = '270'
  else:
    internal.enabled = True
    internal.pos_x = x
    internal.pos_y = 0
    internal.transform = 'normal'

  return mode


def main(args: list[str]):
  modestr = Mode.DEFAULT.name

  if len(args) == 2:
    modestr = args[1]

  if len(args) > 2 or modestr not in Mode.__members__:
    print(_USAGE, file=sys.stderr)
    sys.exit(1)

  mode = Mode[modestr]
  print(f'Original mode: {mode.name}', file=sys.stderr)

  screens = get_screens()
  mode = reconfigure_screens({s.id: s for s in screens}, mode)

  print(f'Decided  mode: {mode.name}', file=sys.stderr)
  print(f'Sway commands:', file=sys.stderr)
  for s in screens:
    print("  " + s.to_sway_command(), file=sys.stderr)

  set_screens(screens)


if __name__ == '__main__':
  main(sys.argv)
