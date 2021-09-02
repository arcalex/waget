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

cd warcs
ls -v ../url.list.d/*|xargs cat|llx_sh -n 66 -d 2 -v -c 'wget -q --accept txt,gz -c --backups=0 $1' >../llx.log 2>&1
