#!/bin/sh

if [ -t 1 ] && command -v fastfetch >/dev/null 2>&1; then
    fastfetch
fi

exec "${SHELL:-/bin/bash}" "$@"
