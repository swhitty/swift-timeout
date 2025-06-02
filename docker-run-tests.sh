#!/usr/bin/env bash

set -eu

docker run -it \
  --rm \
  --mount src="$(pwd)",target=/package,type=bind \
  swift:6.1.2-jammy \
  /usr/bin/swift test --package-path /package
