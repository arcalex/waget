#!/bin/bash

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

shopt -s nullglob

usage() {
  cat >&2 <<_E
Usage: $0 [-b api_base_url] [-l] dir"

-l:
  Use file length to validate instead of checksum
dir:
  Directory to validate
_E
  exit 0
}

api_base_url="https://warcs.archive-it.org"
use_length=false

while getopts b:l opt; do
  case "$opt" in
    b) api_base_url="$OPTARG"
      ;;
    l) use_length=true
      ;;
    *) usage
      ;;
  esac
done

shift $((OPTIND-1))  # options come first

[ $# != 1 ] && usage

if "$use_length"; then
  echo "checking file length instead of checksum (fast mode)..."
fi

cd "$1" || exit 1  # collection directory

export sudo_user="$(stat -c %U "$1")"

declare -A ids_stops  # id:page to search next
declare -A names_jsons  # filename:json

load_name() {
  name="$1" id="$2"

  page=${ids_stops[$id]} page=${page:-1}

  while json="$(sudo -u "$sudo_user" /opt/waget/list1.sh "$page" "$id" "$api_base_url" 2>/dev/null | grep -Eo '\{.+\}$')"; do
    echo -n "listed page $page" >&2

    if ! c="$(jq -r '.count' <<< "$json" 2>/dev/null)"; then
      echo -n "; no count in page, json " >&2
      echo "$json" >&2
      break
    fi

    c="$(jq -r '.count' <<< "$json")"
    [ -z "$c" ] || [ "$c" -lt 1 ] && break  # empty page

    echo "looking at id $id, page $page..."

    # caching names...
    # principle of locality applies here...
    if "$use_length"; then  # to check once
      for filename in $(jq -r '.files[].filename' <<< "$json"); do
        names_jsons["$filename"]="$(jq -r ".files[] | select(.filename==\"$filename\") | .size" <<< "$json")"
      done
    else
      for filename in $(jq -r '.files[].filename' <<< "$json"); do
        names_jsons["$filename"]="$(jq -c ".files[] | select(.filename==\"$filename\") | .checksums" <<< "$json")"
      done
    fi

    # do not cache this page again
    ((page++))
    ids_stops[$id]="$page"

    # was $1 cached?
    [ -z "${names_jsons[$name]}" ] || break  # found it!
  done
}

valid=0
total=0

for f in *.warc.gz; do
  # extract id from filename
  id="$(grep -Po '(?<=^ARCHIVEIT-)[0-9]+(?=(-([A-Z]|[0-9]|_)+)+(-[0-9]+){2}-([a-z]|[0-9])+.warc.gz$)' <<< "$f")"

  # invalid
  if [ -z "$id" ]; then
    echo "$f is not valid"
    continue
  fi

  # valid
  ((total++))

  # load name if we do not have it
  echo "loading $f..."
  [ -n "${names_jsons[$f]}" ] || load_name "$f" "$id"

  sums="${names_jsons[$f]}"  # checksum (or size)

  if [ -z "$sums" ]; then
    # still not found... hmmm... maybe it was deleted on the remote end?
    echo "file $f is not found"
    continue
  fi

  echo "loaded $f"

  if ( "$use_length" && ! [ "$(du -b "$f" | awk '{print $1}')" = "$sums" ] ) ||
    ( sha1="$(sha1sum "$f" | cut -d ' ' -f 1)" md5="$(md5sum "$f" | cut -d ' ' -f 1)"  # local checksum
    ! ( "$use_length" || ([ "$sha1" = "$(jq -r '.sha1' <<< "$sums")" ] || [ "$md5" = "$(jq -r '.md5' <<< "$sums")" ]) )); then

    # local and remote checksum (or size) do not match
    echo "file $f is not valid"
    echo "$f $sums" >&2  # NOTE: this is the most important echo in the script
    # capture stderr to a text file, and you have all you need to schedule re-downloads...
  else
    echo "file $f is valid"
    ((valid++))
  fi
done

echo "$valid valid files / $total files"
echo "# of ids detected: ${#ids_stops[@]}"
echo "# of loaded $($use_length && echo size || echo checksum) records: ${#names_jsons[@]}"

# ${#names_jsons[@]} should be close to $total
# if not, then there is disparity among the ids and pages, and the principle of locality is weakened
# better performance expected when ids are mostly adjacent

[ "$valid" = "$total" ]  # exit status
