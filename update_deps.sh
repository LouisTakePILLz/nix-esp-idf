#!/usr/bin/env bash

sp="$(nix-build --builders "" -Q --no-out-link fetch_deps.nix)"
cat "$sp" > deps.nix
