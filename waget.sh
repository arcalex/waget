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

sudo_user="yid"
export sudo_user

shopt -s nullglob

usage() {
  cat >&2 <<_E
$0 [-b api-base-url] [-s hooks-dir] id:dir[:start-page[:last-page]] ..."

hooks-dir:
  Directory for scripts to be run on download, each script invoked with
  two arguments: the absolute path to the downloaded file is the first,
  argument, the absolute path to the log file is the second.
_E
  exit 0
}

# defaults
api_base_url="https://warcs.archive-it.org"
hooks_dir="$(readlink -f scripts)"

# overrides
while getopts b:s: opt; do
  case "$opt" in
    b) api_base_url="$OPTARG"
      ;;
    s) hooks_dir="$(readlink -f $OPTARG)"
      ;;
  esac
done

shift $((OPTIND-1))  # options come first
log_dir="$PWD"  # where to write logs

[ $# = 0 ] && usage

hooks() {
  ret="$?" file="$1" md5="$2" sha1="$3"

	# file must be valid before feeding it to a hook script

  # validating hash (borrowing some lines from validate.sh)...
  if [ -n "$md5" ] && [ -n "$sha1" ]; then
    echo "$file is $(([ "$sha1" = "$(sha1sum "$file" | cut -d ' ' -f 1)"  ] || [ "$md5" = "$(md5sum "$file" | cut -d ' ' -f 1)" ]) && 
      echo "valid" || echo "not valid")" >> "$log_file"
  fi

  # invoke every hook script on new files only
  if [ "$ret" != 0 ]; then
    echo "wget returned $ret"

    if [ $? = 8 ]; then
      echo "server error" >> "$log_file"

      # TODO: re-enter waget.sh job in schedule

      exit 1  # this doesn't stop the script, it's on a seperate process
    fi
  fi

  for script in "$hooks_dir"/*.sh; do
    "$script" "$1" "$log_file"
  done

  # suggestion for a hook script: after parsing the output of
  # validate.sh with awk, check whether the warc is invalid because of
  # an incomplete download or because it's defective (hint: wget -c).
  # delete the defective files and rerun waget.sh on their ids.
}

finito() {
  url="$1" dest="$2" filename="$3" md5="$4" sha1="$5"

  echo "launching wget to fetch remote $filename" >> "$log_file"
  file="$dest/$filename"
  cd "$dest" && sudo -u "$sudo_user" /opt/waget/get1.sh "$url" &>/dev/null && hooks "$filename" "$md5" "$sha1"
}

export -f finito  # for xargs
export -f hooks  # for finito
export hooks_dir  # for hooks
export log_file  # for hooks and finito

for id_dir in "$@"; do
  # initializing vars
  id_dir=(${id_dir//:/ })
  id="${id_dir[0]}"
  dest="$(readlink -f ${id_dir[1]})"
  log_file="$log_dir/waget_${id}.log"

  # initializing environment
  mkdir -p "$dest"
  chmod 1777 "$dest"
  touch "$log_file"
  echo -e "#=========\ninitializing [$dest]..." >> "$log_file"

  # what to download?
  page="$(echo "${id_dir[2]}" | grep -oE '^[1-9][0-9]*$')" page="${page:-1}"
  last_page="${id_dir[3]}"

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

  while json="$(sudo -u "$sudo_user" /opt/waget/list1.sh "$page" "$id" "$api_base_url" | grep -Eo '\{.+\}$')"; do
    echo -n "fetched page $page" >> "$log_file"

    if ! c="$(jq -r '.count' <<< "$json" 2>/dev/null)"; then
      echo "; server gave up on page $page; json: " >> "$log_file"
      echo "$json" >> "$log_file"
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
    echo ", launched wget jobs for page $page" >> "$log_file"

    [ "$last_page" = "$page" ] && break
    ((page++))
    #break  # DEBUG ONLY
  done
done

echo  # flush the output buffer, often useful after read

# exit code is always 0

