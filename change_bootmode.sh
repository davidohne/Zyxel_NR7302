#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 -p <port> -c <command> -t <terminal>

  -p PORT         Serial device (e.g. /dev/ttyUSB0 or /dev/cu.usbserial)
  -c COMMAND      fastboot | recovery | PINTEST | charge
  -t TERMINAL     screen | minicom
EOF
  exit 1
}

# --- Parse arguments ---
PORT=""
CMD=""
TERM_APP=""
while getopts "p:c:t:" opt; do
  case "$opt" in
    p) PORT="$OPTARG" ;;
    c) CMD="$OPTARG" ;;
    t) TERM_APP="$OPTARG" ;;
    *) usage ;;
  esac
done
if [[ -z "$PORT" || -z "$CMD" || -z "$TERM_APP" ]]; then
  usage
fi

# --- Validate inputs ---
case "$CMD" in
  fastboot|recovery|PINTEST|charge) ;;
  *)
    echo "Invalid command: $CMD"
    usage
    ;;
esac

case "$TERM_APP" in
  screen|minicom) ;;
  *)
    echo "Invalid terminal: $TERM_APP"
    usage
    ;;
esac

# --- Detect OS for stty syntax ---
OS="$(uname)"
if [[ "$OS" == "Linux" ]]; then
  STTY_CMD="stty -F \"$PORT\" raw 115200 cs8 -cstopb -parenb"
elif [[ "$OS" == "Darwin" ]]; then
  STTY_CMD="stty \"$PORT\" raw 115200 cs8 -cstopb -parenb"
else
  echo "Unsupported OS: $OS"
  exit 1
fi

# --- Configure serial port ---
eval $STTY_CMD

# --- Open port for read/write on FD 3 ---
exec 3<> "$PORT"

# 1) Prompt user to power on
echo "Close all interfering console windows."
echo "Please power on the router."

# 2) Wait for first line from device
if read -r -u 3 first_line; then
  echo "First line received: $first_line"
else
  echo "Error: no data received from port."
  exec 3>&-  # close FD 3
  exit 1
fi

# 3) Send Ctrl‑C (0x03) for 5 seconds
END=$((SECONDS + 5))
while (( SECONDS < END )); do
  printf '\x03' >&3
  sleep 0.1
done

# brief pause to flush
sleep 0.2

# 4) Send chosen command
printf '%s\r\n' "$CMD" >&3

# close FD 3
exec 3>&-

# 5) Launch interactive terminal
if ! command -v "$TERM_APP" &>/dev/null; then
  echo "Error: '$TERM_APP' not found. Please install it."
  exit 1
fi

if [[ "$TERM_APP" == "screen" ]]; then
  exec screen "$PORT" 115200
else
  exec minicom -D "$PORT"
fi
