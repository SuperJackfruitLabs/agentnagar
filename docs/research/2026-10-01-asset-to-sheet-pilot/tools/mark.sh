#!/usr/bin/env bash
# mark.sh LABEL: one line in the working folder's timeline (seconds since the epoch, label), for timing the
# steps of a run: "<step>: start" and "<step>: end". Writes to $TIMELINE, or timeline.tsv beside this script.
printf '%s\t%s\n' "$(date +%s)" "$*" >> "${TIMELINE:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/timeline.tsv}"
