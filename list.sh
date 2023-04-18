#!/bin/sh

# Copyright (C) 2021-2022 Bibliotheca Alexandrina

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

list1=$(dirname "$(readlink -f "$0")")/list1.sh

api_base_url="https://warcs.archive-it.org"

q='.files[] | [.checksums.md5, .checksums.sha1, ."crawl-time", .filename, .locations[0], .size] | @tsv'

counter=1
counter_max=10

# E.g., 13529:/vol_e/covid-19
for x in "$@"; do
  a=${x%%:*}
  b=${x#*:}

  echo "Processing collection $x (meta)..." >&2

  page=1
  while true; do
    if sudo -u "$(stat -c %U "$b")" "$list1" "$page" "$a"|jq -r "$q" >"$b/meta/$page"; then
      echo "Listed page $page" >&2
      page=$((page+1))
      counter=1
    else
      echo "[counter=$counter]" >&2

      if [ "$counter" -eq "$counter_max" ]; then
        break
      fi

      counter=$((counter+1))
    fi
  done
done
