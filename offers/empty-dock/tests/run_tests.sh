#!/usr/bin/env bash
# Minimal test runner (used when bats is not installed).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOCK_DIR="$SCRIPT_DIR/mocks"
FIXTURE_DIR="$SCRIPT_DIR/mocks/fixtures"
MONITOR="$SCRIPT_DIR/../waybar-monitor.sh"
LAUNCH="$SCRIPT_DIR/../launch-app.sh"

PASS=0; FAIL=0

run_test() {
  local name="$1"; shift
  if "$@" 2>/dev/null; then
    echo "  PASS: $name"; ((PASS++))
  else
    echo "  FAIL: $name"; ((FAIL++))
  fi
}

echo "=== test_monitor ==="

run_test "workspace_is_empty returns 0 when windows=0" bash -c '
  export PATH="'"$MOCK_DIR"':$PATH"
  source "'"$MONITOR"'"
  export HYPRCTL_FIXTURE="'"$FIXTURE_DIR"'/empty-workspace.json"
  workspace_is_empty 1
'

run_test "workspace_is_empty returns 1 when windows>0" bash -c '
  export PATH="'"$MOCK_DIR"':$PATH"
  source "'"$MONITOR"'"
  export HYPRCTL_FIXTURE="'"$FIXTURE_DIR"'/busy-workspace.json"
  workspace_is_empty 1 && exit 1 || exit 0
'

run_test "dock_show DRY_RUN prints expected message" bash -c '
  export PATH="'"$MOCK_DIR"':$PATH"
  source "'"$MONITOR"'"
  export EMPTY_DOCK_DRY_RUN=1
  out=$(dock_show 2>&1)
  [[ "$out" == *"DRY_RUN: start waybar"* ]]
'

run_test "dock_hide DRY_RUN prints expected message" bash -c '
  export PATH="'"$MOCK_DIR"':$PATH"
  source "'"$MONITOR"'"
  export EMPTY_DOCK_DRY_RUN=1
  echo "99999" > /tmp/empty-dock-waybar.pid
  out=$(dock_hide 2>&1)
  rm -f /tmp/empty-dock-waybar.pid
  [[ "$out" == *"DRY_RUN: kill 99999"* ]]
'

echo ""
echo "=== test_launch ==="

run_test "launch-app increments launch_count" bash -c '
  tmp=$(mktemp)
  cat > "$tmp" <<'"'"'EOF'"'"'
{"apps":[{"id":0,"name":"Firefox","exec":"firefox","icon":"firefox","launch_count":5,"pinned":false}]}
EOF
  EMPTY_DOCK_APPS="$tmp" EMPTY_DOCK_DRY_RUN=1 bash "'"$LAUNCH"'" firefox Firefox
  count=$(jq ".apps[0].launch_count" "$tmp")
  rm -f "$tmp"
  [ "$count" -eq 6 ]
'

run_test "launch-app --print-icon outputs valid JSON" bash -c '
  tmp=$(mktemp)
  cat > "$tmp" <<'"'"'EOF'"'"'
{"apps":[{"id":0,"name":"Firefox","exec":"firefox","icon":"firefox","launch_count":5,"pinned":false}]}
EOF
  out=$(EMPTY_DOCK_APPS="$tmp" EMPTY_DOCK_DRY_RUN=1 bash "'"$LAUNCH"'" firefox Firefox --print-icon firefox)
  rm -f "$tmp"
  echo "$out" | jq -e ".text" > /dev/null
'

echo ""
echo "=== test_update ==="

run_test "update-launchers produces valid JSON config" bash -c '
  tmp_apps=$(mktemp --suffix=.json)
  tmp_cfg=$(mktemp --suffix=.jsonc)
  cat > "$tmp_apps" <<'"'"'EOF'"'"'
{"apps":[{"id":0,"name":"Firefox","exec":"firefox","icon":"firefox","launch_count":10,"pinned":true}]}
EOF
  EMPTY_DOCK_APPS="$tmp_apps" EMPTY_DOCK_CONFIG_OUT="$tmp_cfg" bash "'"$SCRIPT_DIR/../update-launchers.sh"'"
  jq . "$tmp_cfg" > /dev/null
  rm -f "$tmp_apps" "$tmp_cfg"
'

run_test "update-launchers sets on-click for app0 to launch-app.sh" bash -c '
  tmp_apps=$(mktemp --suffix=.json)
  tmp_cfg=$(mktemp --suffix=.jsonc)
  cat > "$tmp_apps" <<'"'"'EOF'"'"'
{"apps":[{"id":0,"name":"Firefox","exec":"firefox","icon":"firefox","launch_count":10,"pinned":true}]}
EOF
  EMPTY_DOCK_APPS="$tmp_apps" EMPTY_DOCK_CONFIG_OUT="$tmp_cfg" bash "'"$SCRIPT_DIR/../update-launchers.sh"'"
  val=$(jq -r ".\"custom/app0\".\"on-click\"" "$tmp_cfg")
  rm -f "$tmp_apps" "$tmp_cfg"
  [[ "$val" == *"launch-app.sh"* ]]
'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
