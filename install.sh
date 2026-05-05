#!/usr/bin/env bash
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
#
# Thin shim: the real installer lives at bin/lfx-skills.
# Preserved as `./install.sh` because that's the documented entry point.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin/lfx-skills" install "$@"
