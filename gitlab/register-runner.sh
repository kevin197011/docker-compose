#!/bin/bash
# Register a GitLab 18+ instance runner (global, run_untagged) via Rails API.
set -euo pipefail
cd "$(dirname "$0")"
exec ./bootstrap.sh --register-runner
