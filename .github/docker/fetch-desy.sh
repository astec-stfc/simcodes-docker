#!/bin/bash
# Put a file of DESY's website in the current directory, falling back to the known-good copy in vendor/desy.
#
#   fetch-desy REL URL
#
# REL is the file's path under vendor/desy (and the name of its line in vendor/desy/SHA256SUMS).  The download is
# accepted only if its sha256 is the one in SHA256SUMS.  If DESY cannot be reached (its user pages are down at times) or
# sends anything else, the vendored copy is used and a warning says so.  Either way the file in the current directory is
# checked against SHA256SUMS before this script returns, so a corrupt vendored copy fails the build.
#
#   FETCH_DESY_VENDOR  where vendor/desy is           default: /vendor/desy
#   FETCH_DESY_SKIP=1  do not try DESY at all        (builds that should be the same everywhere, or offline)
set -u
rel=$1
url=$2
name=$(basename "$url")
vendor=${FETCH_DESY_VENDOR:-/vendor/desy}
want=$(awk -v f="$rel" '$2 == f {print $1}' "$vendor/SHA256SUMS")
[ -n "$want" ] || { echo "fetch-desy: no checksum for $rel in $vendor/SHA256SUMS" >&2; exit 1; }

got=""
if [ "${FETCH_DESY_SKIP:-0}" != 1 ]; then
    rm -f "$name.download"
    if timeout 120 wget --quiet --tries=1 --timeout=30 -O "$name.download" "$url"; then
        got=$(sha256sum "$name.download" | cut -d' ' -f1)
    fi
fi

if [ -n "$got" ] && [ "$got" = "$want" ]; then
    mv "$name.download" "$name"
    echo "fetch-desy: $name downloaded from DESY; it is the known-good file"
else
    rm -f "$name.download"
    if [ "${FETCH_DESY_SKIP:-0}" = 1 ]; then why="skipped"
    elif [ -z "$got" ]; then why="could not be downloaded"
    else why="differs from the known-good file (sha256 $got)"; fi
    echo "fetch-desy: WARNING $url $why; using the vendored copy of $rel" >&2
    cp "$vendor/$rel" "$name"
fi
echo "$want  $name" | sha256sum -c --quiet - || { echo "fetch-desy: $name does not match vendor/desy/SHA256SUMS" >&2; exit 1; }
