#!/usr/bin/env bash
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${LUA:-lua}" "$dir/smoke/shared.lua"
"${LUA:-lua}" "$dir/smoke/client.lua"
"${LUA:-lua}" "$dir/smoke/blips.lua"
"${LUA:-lua}" "$dir/smoke/server.lua"
