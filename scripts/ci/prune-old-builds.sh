#!/bin/sh
set -eu

version=$(awk '/^version:/ {print $2}' popopxmq.cabal)
for dir in "$@"; do
  if [ -d "$dir/build" ]; then
    find "$dir/build" -mindepth 3 -maxdepth 3 -type d -name 'popopxmq-*' ! -name "popopxmq-$version" -exec rm -rf {} +
  fi
done
