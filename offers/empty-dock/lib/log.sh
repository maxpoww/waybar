LOG_FILE="${EMPTY_DOCK_LOG:-$HOME/.local/share/empty-dock/empty-dock.log}"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
  local level="$1"; shift
  printf '[%s] %s %s\n' "$level" "$(date -u +%FT%TZ)" "$*" | tee -a "$LOG_FILE" >&2
}
log_info()  { log INFO  "$@"; }
log_warn()  { log WARN  "$@"; }
log_error() { log ERROR "$@"; }
log_debug() { [[ "${EMPTY_DOCK_DEBUG:-0}" == "1" ]] && log DEBUG "$@" || true; }
