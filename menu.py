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

import os
import subprocess
import sys

_USAGE = '''
Usage: menu (RUN|POWER|WIFI)

This script merges multiple menu implementations in one place for running
simplicity, code sharing and coherent styling.

Copyright (c) 2024 Viktor Slavkovic
Licensed under the Apache License, Version 2.0
'''

_BEMENU_COMMON_ARGS = [
    '--ignorecase',
    '--no-cursor',
    '--prompt', '',
    '--fn', 'Inconsolata SemiExpanded SemiBold 16',
    '--center', '--list', '20 down', '-H', '30',
    '--scrollbar', 'hide',
    '--border', '3',
    '--border-radius', '0',
    # Palette: https://coolors.co/fffcf2-ccc5b9-403d39-252422-eb5e28
    '--bdr', '#252422R',
    '--nb', '#403d39', '--nf', '#fffcf2',
    '--ab', '#403d39', '--af', '#fffcf2',
    '--fb', '#fffcf2', '--ff', '#252422',
    '--cb', '#eb5e28', '--cf', '#eeebe1',
    '--hb', '#eb5e28', '--hf', '#403d39',
]

_POWER_PATH = os.path.join(os.path.dirname(
    os.path.abspath(__file__)), 'power.sh')


def _launch_noexec_bemenu(options: list[str], w: float = 0.1) -> str:
  args = list(_BEMENU_COMMON_ARGS)
  args.extend([
      '--no-exec',
      '-W', str(w),
  ])
  picked, _ = subprocess.Popen(
      ['bemenu'] + args,
      stdin=subprocess.PIPE,
      stdout=subprocess.PIPE,
  ).communicate(input='\n'.join(options + ['']).encode())
  return picked.decode().strip()


def power_menu():
  '''Handles the POWER mode.'''
  pick = _launch_noexec_bemenu(
      ['POWEROFF', 'HIBERNATE', 'SLEEP', 'RESTART', 'LOGOUT', 'LOCK'])
  if not pick:
    return
  cmd = [_POWER_PATH, pick]
  os.execvp(cmd[0], cmd)


def run_menu():
  '''Handles the RUN mode.'''
  cmd = ['bemenu-run']
  cmd.extend(_BEMENU_COMMON_ARGS)
  cmd.extend(['-W', '0.3'])
  os.execvp(cmd[0], cmd)


def _list_wifi():
  out, _ = subprocess.Popen(
      ['nmcli', '-t', 'd', 'wifi', 'list', '--rescan', 'auto'],
      stdout=subprocess.PIPE,
  ).communicate()
  lines = [l.strip() for l in out.decode().splitlines()]
  split = [l.replace('\:', '').split(':') for l in lines]
  return sorted([{
      'connected': s[0] == '*',
      'mac': s[1],
      'ssid': s[2],
      'chan': int(s[4]),
      'rssi': int(s[6]),
      'bars': s[7],
      'sec': s[8],
  } for s in split], key=lambda x: x['rssi'], reverse=True)


def _human_wifi(net: dict[str, any], idx: int) -> str:
  con = {True: '>', False: ' '}[net['connected']]
  ssid = net['ssid'][:20].ljust(20)
  chan = str(net['chan']).rjust(4)
  chan = f'C {chan}'
  bars = net['bars'].rjust(4)
  sec = net['sec'].strip().ljust(20)
  if sec:
    sec = f'S {sec}'
  return f'{con} {bars} {ssid} {chan} {sec} [{idx}]'


def wifi_menu():
  '''Handles the WiFi mode.'''
  # First make sure WiFi is enabled. Well, increase chances.
  # TODO: Notify on errors.
  subprocess.Popen(['nmcli', 'radio', 'wifi', 'on']).communicate()

  # Scan and display the menu.
  networks = _list_wifi()
  options = [_human_wifi(n, i) for i, n in enumerate(networks)]
  pick = _launch_noexec_bemenu(options, 0.3)
  if not pick:
    return
  ssid = networks[int(
      pick.split()[-1].removeprefix('[').removesuffix(']'))]['ssid']
  cmd = ['nmcli', 'd', 'wifi', 'connect', ssid]
  os.execvp(cmd[0], cmd)


def main():
  if len(sys.argv) != 2:
    print(_USAGE, file=sys.stderr)
    sys.exit(1)

  match sys.argv[1]:
    case 'POWER':
      power_menu()
      return
    case 'RUN':
      run_menu()
      return
    case 'WIFI':
      wifi_menu()
      return
    case _:
      print(_USAGE, file=sys.stderr)
      sys.exit(1)


if __name__ == '__main__':
  main()
