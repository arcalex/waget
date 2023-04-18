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

get1=$(dirname "$(readlink -f "$0")")/get1.sh

# E.g., 13529:/vol_e/covid-19
for x in "$@"; do
  a=${x%%:*}
  b=${x#*:}

  echo "Processing collection $x (data)..." >&2

  # meta: md5 sha1 crawl-time filename url size
  #       1   2    3          4        5   6

  cd "$b/data" && find "$b/meta" -mindepth 1 -maxdepth 1 -exec cut -f5 {} \;|xargs -n1 -P40 sudo -u "$(stat -c %U "$b")" "$get1" 2>"$b/logs/get.retry"
done
