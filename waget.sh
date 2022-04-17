#!/bin/bash

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

sudo_user="yid"
export sudo_user

usage() {
  cat >&2 <<_E
Usage: $0 [-b api_base_url] [-s hooks_dir] id:dir..."
_E
  exit 0
}

# defaults
api_base_url="https://warcs.archive-it.org"
hooks_dir="$(readlink -f ./hooks)"

# overrides
while getopts b:s: opt; do
  case "$opt" in
    b) api_base_url="$OPTARG"
      ;;
    s) hooks_dir="$(readlink -f "$OPTARG")"
      ;;
    *) usage
      ;;
  esac
done

shift $((OPTIND-1))  # options come first

[ $# = 0 ] && usage

hooks() {
  ret="$?" file="$1" md5="$2" sha1="$3"

  # file must be valid before feeding it to a script

  # validating hash (borrowing some lines from validate.sh)...
  if [ -n "$md5" ] && [ -n "$sha1" ]; then
    echo "$file is $( ([ "$sha1" = "$(sha1sum "$file" | cut -d ' ' -f 1)"  ] || [ "$md5" = "$(md5sum "$file" | cut -d ' ' -f 1)" ]) && 
      echo "valid" || echo "not valid")" >&2
  fi

  # invoke every hook script on new files only
  if [ "$ret" != 0 ]; then
    echo "fetch job returned $ret" >&2

    if [ $? = 8 ]; then
      echo "server error" >&2

      # TODO: re-enter waget.sh job in schedule

      exit 1  # this doesn't stop the script, it's on a seperate process
    fi
  fi

  find "$hooks_dir" -mindepth 1 -maxdepth 1 -type f -executable -exec "{}" "$1" \;

  # suggestion for a hook script: after parsing the output of
  # validate.sh with awk, check whether the warc is invalid because of
  # an incomplete download or because it's defective (hint: wget -c).
  # delete the defective files and rerun waget.sh on their ids.
}

finito() {
  url="$1" dest="$2" filename="$3" md5="$4" sha1="$5"

  echo "launching job to fetch remote $filename" >&2
  file="$dest/$filename"
  cd "$dest" && sudo -u "$sudo_user" /opt/waget/get1.sh "$url" 2>/dev/null && hooks "$filename" "$md5" "$sha1"
}

export -f finito  # for xargs
export -f hooks  # for finito
export hooks_dir  # for hooks

for id_dir in "$@"; do
  # initializing vars
  id_dir=(${id_dir//:/ })
  id="${id_dir[0]}"
  dest="$(readlink -f "${id_dir[1]}")"

  echo "processing $id:$dest..." >&2

  # what to download?
  page=1  # pagination is not immutable, always start at the beginning

  # NOTE: We might need to mktemp a buffer (for each iteration) for jq
  # to use as the input channel (instead of a pipe), and then as the
  # output channel of the loop, to be fed to xargs.  This scenario would
  # be necessary if input/output exceeds the buffer capacity of the pipe
  # (64k on most *nixes, but 16k on a Mac, though both are automatically
  # extended, usually), which is possible if filenames get longer.
  # (You'd expect a command's output to be done before it's piped,
  # however, pipe capacity may be exceeded if JSON input is large
  # enough.)  The solution then would be to use a limitless, "disked"
  # pipe, i.e., a file.  So far in test runs, $json is ~15M, but the
  # input to the pipe into the while loop is ~76k.  If things go wrong,
  # the first suspect should be the buffer size.  If so, comment out the
  # sums=... line below and see if it works.  In test runs, this reduces
  # buffer usage to ~12k but removes the validation check.

  while json="$(sudo -u "$sudo_user" /opt/waget/list1.sh "$page" "$id" "$api_base_url" 2>/dev/null | grep -Eo '\{.+\}$')"; do
    echo -n "listed page $page" >&2

    if ! c="$(jq -r '.count' <<< "$json" 2>/dev/null)"; then
      echo -n "; no count in page, json " >&2
      echo "$json" >&2
      break
    fi

    [ -z "$c" ] || [ "$c" -lt 1 ] && break  # empty page

    jq -cr '.files[] | [.filename,.locations[0],.checksums]' <<< "$json" |
      while read -r line; do
      filename="$(jq -r '.[0]' <<< "$line")" url="$(jq -r '.[1]' <<< "$line")"

      # to check if an error is related to the buffer, comment out the next line and see if it works
      sums="$(jq -cr '.[2]' <<< "$line")"

      # parameters passed to finito, extend as seen fit...
      echo -n "$url" "$dest" "$filename"
      [ -n "$sums" ] && echo -n " $(jq -r '.md5' <<< "$sums")" "$(jq -r '.sha1' <<< "$sums")"
      echo  # delimit for xargs
    done | xargs -L1 bash -c 'finito "$@"' _ &  # do NOT use -P here, will end up with several thousand processes

    # instead, let xargs download them sequentially. there will be many xargs running in parallel after all
    echo ": launched fetch jobs for page" >&2

    ((page++))
    #break  # DEBUG ONLY
  done
done

echo  # flush the output buffer, often useful after read

# exit code is always 0

