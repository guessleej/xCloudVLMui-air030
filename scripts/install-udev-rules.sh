#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="99-realsense-d435i.rules"
SRC="${SCRIPT_DIR}/${RULES_FILE}"
DST="/etc/udev/rules.d/${RULES_FILE}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo ./scripts/install-udev-rules.sh"
  exit 1
fi

if [[ ! -f "${SRC}" ]]; then
  echo "Rules file not found: ${SRC}"
  exit 1
fi

if [[ -f "${DST}" ]]; then
  cp "${DST}" "${DST}.bak"
fi

cp "${SRC}" "${DST}"
chmod 0644 "${DST}"
udevadm control --reload-rules
udevadm trigger

echo "Installed ${DST}"
echo "Replug D435i, then verify:"
echo "  ls -la /dev/d435i-rgb"
