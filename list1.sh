#!/bin/sh

# Copyright (C) 2021 Bibliotheca Alexandrina

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

if [ "$#" -ne 3 ] && [ "$#" -ne 2 ]; then
  echo "Usage: $0 <page> <collection> [<api_base_url>]" >&2
  exit 1
fi

if [ "$#" -ne 3 ]; then
  api_base_url="https://warcs.archive-it.org"
else
  api_base_url="$3"
fi

curl --retry 5 --retry-delay 5 --max-time 10 -n "$api_base_url/wasapi/v1/webdata?collection=$2&page=$1"
