#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

PASS=0
FAIL=0
WARN=0

D435I_TIMEOUT="${D435I_TIMEOUT:-15}"
HLS_URL="${HLS_URL:-http://localhost/streams/d435i/index.m3u8}"
JSON_OUT=""

ok()   { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
ng()   { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; WARN=$((WARN + 1)); }

usage() {
  cat <<'EOF'
Usage: ./scripts/test-d435i-integration.sh [options]

Options:
  --timeout <sec>     Wait time for HLS readiness (default: 15)
  --hls-url <url>     HLS playlist URL (default: http://localhost/streams/d435i/index.m3u8)
  --json-out <path>   Write machine-readable result JSON
  -h, --help          Show this help
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --timeout) shift; D435I_TIMEOUT="${1:-}";;
      --hls-url) shift; HLS_URL="${1:-}";;
      --json-out) shift; JSON_OUT="${1:-}";;
      -h|--help) usage; exit 0;;
      *) echo "Unknown option: $1"; usage; exit 2;;
    esac
    if [[ -z "${1:-}" ]]; then
      echo "Missing option value"
      exit 2
    fi
    shift
  done
}

http_code() {
  local url="$1"
  curl -sS -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000"
}

wait_http_ok() {
  local url="$1"
  local timeout="$2"
  local elapsed=0
  while (( elapsed < timeout )); do
    local code
    code="$(http_code "$url")"
    if [[ "$code" =~ ^2[0-9][0-9]$ ]]; then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  return 1
}

check_symlink() {
  echo -e "${YELLOW}[L1] udev symlink 檢查${NC}"
  if [[ -L /dev/d435i-rgb ]]; then
    local target
    target="$(readlink -f /dev/d435i-rgb || true)"
    ok "/dev/d435i-rgb exists -> ${target:-unknown}"
  else
    ng "/dev/d435i-rgb missing. Run sudo ./scripts/install-udev-rules.sh and replug D435i."
  fi
}

check_services() {
  echo -e "\n${YELLOW}[L2] compose 服務狀態檢查${NC}"
  if ! command -v docker >/dev/null 2>&1; then
    ng "docker command not found"
    return
  fi

  local ps_out
  if ! ps_out="$(docker compose -f docker-compose.yml ps 2>&1)"; then
    ng "docker compose ps failed: ${ps_out}"
    return
  fi

  if echo "$ps_out" | rg -q "xcloud-mediamtx.*(Up|running)"; then
    ok "xcloud-mediamtx running"
  else
    ng "xcloud-mediamtx not running"
  fi

  if echo "$ps_out" | rg -q "xcloud-d435i-streamer.*(Up|running)"; then
    ok "xcloud-d435i-streamer running"
  else
    ng "xcloud-d435i-streamer not running"
  fi
}

check_hls() {
  echo -e "\n${YELLOW}[L3] HLS playlist 檢查${NC}"

  if wait_http_ok "$HLS_URL" "$D435I_TIMEOUT"; then
    ok "HLS reachable: $HLS_URL"
  else
    ng "HLS not reachable within ${D435I_TIMEOUT}s: $HLS_URL"
    return
  fi

  local body
  body="$(curl -sS --max-time 5 "$HLS_URL" 2>/dev/null || true)"
  if echo "$body" | rg -q '#EXTM3U'; then
    ok "playlist contains #EXTM3U"
  else
    ng "invalid playlist content (missing #EXTM3U)"
  fi
}

print_debug_hints() {
  if [[ "$FAIL" -eq 0 ]]; then
    return
  fi
  echo -e "\n${YELLOW}Debug hints${NC}"
  echo "1) ls -la /dev/d435i-*"
  echo "2) docker compose -f docker-compose.yml ps"
  echo "3) docker compose -f docker-compose.yml logs --tail=80 d435i-streamer mediamtx nginx"
}

write_json_report() {
  local status="pass"
  if [[ "$FAIL" -gt 0 ]]; then
    status="fail"
  fi

  local json
  json="$(python3 - <<'PY' "$status" "$PASS" "$FAIL" "$WARN" "$D435I_TIMEOUT" "$HLS_URL"
import json, sys
status, p, f, w, timeout, hls = sys.argv[1:]
print(json.dumps({
  "status": status,
  "pass": int(p),
  "fail": int(f),
  "warn": int(w),
  "timeout_sec": int(timeout),
  "hls_url": hls,
}, ensure_ascii=False, indent=2))
PY
)"

  if [[ -n "${JSON_OUT}" ]]; then
    printf "%s\n" "$json" > "$JSON_OUT"
    ok "wrote JSON report: $JSON_OUT"
  else
    echo -e "\n${BLUE}JSON report${NC}"
    printf "%s\n" "$json"
  fi
}

parse_args "$@"

echo -e "${BLUE}══════════════════════════════════════════${NC}"
echo -e "${BLUE}  D435i Integration Test (L1-L3)${NC}"
echo -e "${BLUE}══════════════════════════════════════════${NC}"

check_symlink
check_services
check_hls

echo -e "\n${BLUE}══════════════════════════════════════════${NC}"
echo -e "Result: ${GREEN}${PASS} pass${NC} / ${RED}${FAIL} fail${NC} / ${YELLOW}${WARN} warn${NC}"
echo -e "${BLUE}══════════════════════════════════════════${NC}\n"

print_debug_hints
write_json_report

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
