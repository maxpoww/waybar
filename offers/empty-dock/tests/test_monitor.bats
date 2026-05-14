#!/usr/bin/env bats
# Tests for workspace_is_empty(), dock_show(), dock_hide() in waybar-monitor.sh

SCRIPT="$BATS_TEST_DIRNAME/../waybar-monitor.sh"
MOCK_DIR="$BATS_TEST_DIRNAME/mocks"
FIXTURE_DIR="$BATS_TEST_DIRNAME/mocks/fixtures"

setup() {
  export PATH="$MOCK_DIR:$PATH"
  # Source the script in library mode (skips main loop)
  source "$SCRIPT" --source-only 2>/dev/null || true
}

@test "workspace_is_empty returns 0 when windows=0" {
  export HYPRCTL_FIXTURE="$FIXTURE_DIR/empty-workspace.json"
  run workspace_is_empty 1
  [ "$status" -eq 0 ]
}

@test "workspace_is_empty returns 1 when windows>0" {
  export HYPRCTL_FIXTURE="$FIXTURE_DIR/busy-workspace.json"
  run workspace_is_empty 1
  [ "$status" -eq 1 ]
}

@test "dock_show prints DRY_RUN message" {
  export EMPTY_DOCK_DRY_RUN=1
  run dock_show
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY_RUN: start waybar"* ]]
}

@test "dock_hide prints DRY_RUN message when pid file exists" {
  export EMPTY_DOCK_DRY_RUN=1
  echo "99999" > /tmp/empty-dock-waybar.pid
  run dock_hide
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY_RUN: kill 99999"* ]]
  rm -f /tmp/empty-dock-waybar.pid
}
