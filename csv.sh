#!/bin/sh

# Copyright (C) 2021-2023 Bibliotheca Alexandrina

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# CSV fields: ait_url,id,dir,name,active

usage () {
  echo "Usage: $0 [-a|-A] list|get [csv...]" >&2
}

if ! opts=`getopt -q -o "aA" -l "help" -- "$@"`; then
  usage
  exit 1
fi

eval set -- "$opts"

while true; do
  case "$1" in
    a)
      active=active
      ;;
    A)
      active=inactive
      ;;
    --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
  esac
  shift
done

if [ "$#" -eq 0 ] || [ "$1" != "list" ] && [ "$1" != "get" ]; then
  usage
  exit 1
fi

action="$1"
shift

grep "^https:.*,$active\$" "$@" | cut -d, -f2,3 --output-delimiter=: | xargs echo "$(dirname "$(readlink -f "$0")")/$action.sh"
