#!/usr/bin/env bash

set -eu

docker run -it \
  --rm \
  --mount src="$(pwd)",target=/package,type=bind \
  swift:5.10-jammy \
  /usr/bin/swift test --package-path /package
