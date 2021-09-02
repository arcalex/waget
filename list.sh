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

id=13529
page=1
while curl -n "https://warcs.archive-it.org/wasapi/v1/webdata?collection=$id&page=$page" | jq -r .files[].locations[0] > "url.list.d/$page"; do
	echo "Pages listed: $page" >&2
	page=$((page+1))
done
