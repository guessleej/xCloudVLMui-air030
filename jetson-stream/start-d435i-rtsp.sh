#!/usr/bin/env bash
set -uo pipefail

VIDEO_DEVICE="${VIDEO_DEVICE:-/dev/d435i-rgb}"
VIDEO_DEVICE_CANDIDATES="${VIDEO_DEVICE_CANDIDATES:-}"
VIDEO_DEVICE_FALLBACK_ANY="${VIDEO_DEVICE_FALLBACK_ANY:-false}"
D435I_MATCH_PATTERN="${D435I_MATCH_PATTERN:-realsense|d435|depth camera}"
RTSP_URL="${RTSP_URL:-rtsp://mediamtx:8554/d435i}"
STREAM_WIDTH="${STREAM_WIDTH:-1280}"
STREAM_HEIGHT="${STREAM_HEIGHT:-720}"
STREAM_FRAMERATE="${STREAM_FRAMERATE:-30}"
STREAM_BITRATE_KBPS="${STREAM_BITRATE_KBPS:-4000}"
STREAM_PIXEL_FORMAT="${STREAM_PIXEL_FORMAT:-YUY2}"
STREAM_V4L2_FORMAT_PATTERN="${STREAM_V4L2_FORMAT_PATTERN:-YUYV|YUY2|UYVY|MJPG|RGB3}"
MAX_RETRIES="${MAX_RETRIES:-999}"

list_video_devices() {
  if command -v v4l2-ctl >/dev/null 2>&1; then
    v4l2-ctl --list-devices 2>/dev/null || true
  else
    ls -la /dev/video* 2>/dev/null || true
  fi
}

device_ready() {
  local dev="$1"
  [[ -e "${dev}" ]] || return 1
  if command -v v4l2-ctl >/dev/null 2>&1; then
    v4l2-ctl --device="${dev}" --all >/dev/null 2>&1 || return 1
    v4l2-ctl --device="${dev}" --all 2>/dev/null | grep -Eiq "Video Capture|Video Capture Multiplanar" || return 1
  fi
  return 0
}

device_supports_stream_format() {
  local dev="$1"
  device_ready "${dev}" || return 1
  if command -v v4l2-ctl >/dev/null 2>&1; then
    v4l2-ctl --device="${dev}" --list-formats-ext 2>/dev/null \
      | grep -Eq "'(${STREAM_V4L2_FORMAT_PATTERN})'"
  fi
}

append_candidate() {
  local dev="$1"
  [[ -n "${dev}" ]] || return 0
  [[ "${dev}" == /dev/video* || "${dev}" == /dev/d435i-* ]] || return 0
  for existing in "${candidates[@]:-}"; do
    [[ "${existing}" == "${dev}" ]] && return 0
  done
  candidates+=("${dev}")
}

collect_candidates() {
  candidates=()

  append_candidate "${VIDEO_DEVICE}"

  local raw_candidate
  for raw_candidate in ${VIDEO_DEVICE_CANDIDATES//,/ }; do
    append_candidate "${raw_candidate}"
  done

  if command -v v4l2-ctl >/dev/null 2>&1; then
    while read -r raw_candidate; do
      append_candidate "${raw_candidate}"
    done < <(
      v4l2-ctl --list-devices 2>/dev/null \
        | awk -v pat="${D435I_MATCH_PATTERN}" '
            BEGIN { pat = tolower(pat); in_match = 0 }
            /^[^[:space:]].*:$/ { in_match = (tolower($0) ~ pat); next }
            in_match && /\/dev\/video[0-9]+/ { print $1 }
          '
    )
  fi

  if [[ "${VIDEO_DEVICE_FALLBACK_ANY}" == "true" ]]; then
    local globbed
    for globbed in /dev/video*; do
      [[ -e "${globbed}" ]] && append_candidate "${globbed}"
    done
  fi
}

auto_detect_d435i() {
  local detected="" candidate

  collect_candidates

  for candidate in "${candidates[@]}"; do
    if device_supports_stream_format "${candidate}"; then
      detected="${candidate}"
      break
    fi
    echo "[d435i] skip unsupported color candidate: ${candidate}"
  done

  if [[ -z "${detected}" ]]; then
    for candidate in "${candidates[@]}"; do
      if device_ready "${candidate}"; then
        detected="${candidate}"
        break
      fi
      echo "[d435i] skip unavailable candidate: ${candidate}"
    done
  fi

  if [[ -z "${detected}" ]]; then
    echo "[d435i] no D435i device detected"
    list_video_devices
    return 1
  fi

  VIDEO_DEVICE="${detected}"
  echo "[d435i] selected device: ${VIDEO_DEVICE}"
  return 0
}

retry_count=0
while true; do
  retry_count=$((retry_count + 1))
  echo "[d435i] stream loop attempt #${retry_count}"

  if auto_detect_d435i; then
    sleep 2
    if device_ready "${VIDEO_DEVICE}"; then
      echo "[d435i] start stream ${VIDEO_DEVICE} -> ${RTSP_URL}"
      gst-launch-1.0 -e \
        v4l2src device="${VIDEO_DEVICE}" do-timestamp=true ! \
        video/x-raw,format="${STREAM_PIXEL_FORMAT}",width="${STREAM_WIDTH}",height="${STREAM_HEIGHT}",framerate="${STREAM_FRAMERATE}"/1 ! \
        videoconvert ! \
        x264enc tune=zerolatency speed-preset=ultrafast bitrate="${STREAM_BITRATE_KBPS}" key-int-max="${STREAM_FRAMERATE}" ! \
        h264parse config-interval=1 ! \
        rtspclientsink location="${RTSP_URL}" protocols=tcp
      rc=$?

      if [[ "${rc}" -ne 0 ]]; then
        echo "[d435i] strict format failed, trying fallback auto-negotiate pipeline"
        gst-launch-1.0 -e \
          v4l2src device="${VIDEO_DEVICE}" do-timestamp=true ! \
          videoconvert ! \
          videoscale ! \
          videorate ! \
          x264enc tune=zerolatency speed-preset=ultrafast bitrate="${STREAM_BITRATE_KBPS}" key-int-max="${STREAM_FRAMERATE}" ! \
          h264parse config-interval=1 ! \
          rtspclientsink location="${RTSP_URL}" protocols=tcp
        rc=$?
      fi
      echo "[d435i] stream ended with code ${rc}, retrying"
    else
      echo "[d435i] device not ready: ${VIDEO_DEVICE}"
    fi
  fi

  if [[ "${MAX_RETRIES}" != "999" ]] && [[ "${retry_count}" -ge "${MAX_RETRIES}" ]]; then
    echo "[d435i] reached retry limit: ${MAX_RETRIES}"
    exit 1
  fi

  sleep 10
done
