#!/usr/bin/env bash

set -eEuo pipefail

# Kill previously symlinked Nginx configs
find /etc/nginx/custom-sites -name 'vvv-auto-*.conf' -delete
