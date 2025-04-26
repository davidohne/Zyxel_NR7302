#!/usr/bin/env bash
set -euo pipefail

# usage:
#   $0 --extract|-e <original.ubi>
#   $0 --repack|-r <original.ubi> <squashfs-root> <output.ubi>

show_usage() {
  cat <<EOF
Usage:
  $0 --extract|-e <original.ubi>
  $0 --repack|-r <original.ubi> <squashfs-root> <output.ubi>

Options:
  -e, --extract   Extract UBI and unpack SquashFS
  -r, --repack    Build new UBI from squashfs-root
EOF
}

if [[ $# -lt 2 ]]; then
  show_usage; exit 1
fi

MODE="$1"; shift
case "$MODE" in
  -e|--extract)
    if [[ $# -ne 1 ]]; then show_usage; exit 1; fi
    ORIG_UBI="$1"
    for cmd in ubireader_extract_images unsquashfs; do
      if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' fehlt. Installiere ubi_reader oder squashfs-tools." >&2; exit 1
      fi
    done
    echo "==> Extrahiere $ORIG_UBI"
    ubireader_extract_images "$ORIG_UBI"
    BASENAME=$(basename "$ORIG_UBI")
    SRC_DIR="ubifs-root/$BASENAME"
    [[ -d "$SRC_DIR" ]] || { echo "Error: Verzeichnis $SRC_DIR nicht gefunden" >&2; exit 1; }
    IMG_FILE=$(find "$SRC_DIR" -maxdepth 1 -type f -name "*.ubifs" | head -n1)
    [[ -n "$IMG_FILE" ]] || { echo "Error: Keine .ubifs-Datei in $SRC_DIR gefunden" >&2; exit 1; }
    echo "==> Entpacke SquashFS: $IMG_FILE"
    unsquashfs -d squashfs-root "$IMG_FILE"
    echo "✔ Extraction complete. squashfs-root/ erstellt."
    exit 0
    ;;

  -r|--repack)
    if [[ $# -ne 3 ]]; then show_usage; exit 1; fi
    ORIG_UBI="$1"; SFS_ROOT="$2"; OUT_UBI="$3"
    ;;

  *) show_usage; exit 1;;
esac

# common dependencies check!
declare -A apt_deps=( [mksquashfs]=squashfs-tools [ubinize]=mtd-utils [binwalk]=binwalk )
declare -A pip_deps=( [ubireader_display_info]="git+https://github.com/onekey-sec/ubi_reader.git" )
for cmd in "${!apt_deps[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Dependency '$cmd' fehlt. Installieren via 'sudo apt-get install ${apt_deps[$cmd]}'? [Y/n]"; read -r ans
    [[ "$ans" =~ ^([yY]|$) ]] && { sudo apt-get update; sudo apt-get install -y ${apt_deps[$cmd]}; } || { echo "Abbruch: fehlende Abhängigkeit $cmd." >&2; exit 1; }
  fi
done
for cmd in "${!pip_deps[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Dependency '$cmd' fehlt. Installieren via 'pip3 install ${pip_deps[$cmd]}'? [Y/n]"; read -r ans
    [[ "$ans" =~ ^([yY]|$) ]] && pip3 install ${pip_deps[$cmd]} || { echo "Abbruch: fehlende Abhängigkeit $cmd." >&2; exit 1; }
  fi
done
for cmd in mksquashfs ubinize ubireader_display_info binwalk; do
  command -v "$cmd" &>/dev/null || { echo "Error: '$cmd' fehlt." >&2; exit 1; }
done

# Validate squashfs-root structure
required=(bin data dev etc lib mnt proc root sbin sys tmp usr var)
for d in "${required[@]}"; do
  [[ -d "$SFS_ROOT/$d" ]] || { echo "Error: Verzeichnis '$d' fehlt in '$SFS_ROOT'." >&2; exit 1; }
done

# read parameters
UBI_INFO=$(ubireader_display_info "$ORIG_UBI")
MIN_IO=$(echo "$UBI_INFO" | sed -n 's/^[[:space:]]*Min I\/O: *\([0-9]\+\).*/\1/p')
LEB_SIZE=$(echo "$UBI_INFO" | sed -n 's/^[[:space:]]*LEB Size: *\([0-9]\+\).*/\1/p')
PEB_SIZE=$(echo "$UBI_INFO" | sed -n 's/^[[:space:]]*PEB Size: *\([0-9]\+\).*/\1/p')
DATA_LEBS=$(echo "$UBI_INFO" | sed -n 's/^[[:space:]]*Data Block Count: *\([0-9]\+\).*/\1/p')
DATA_OFF=$MIN_IO
SEQ_NUM=$(echo "$UBI_INFO" | sed -n 's/^[[:space:]]*Image Sequence Num: *\([0-9]\+\).*/\1/p')
VOL_NAME=$(echo "$UBI_INFO" | sed -n 's/^[[:space:]]*Volume Name: *//p' | head -1 | xargs)
VOL_SIZE=$(( DATA_LEBS * PEB_SIZE ))

# build new SquashFS
SFS_IMG="img-${SEQ_NUM}_vol-${VOL_NAME}.ubifs"
echo "Erzeuge SquashFS-Image: $SFS_IMG"
mksquashfs "$SFS_ROOT" "$SFS_IMG" -comp gzip -b 131072 -no-progress

# ubinize config embedded from manufacturer
UBI_CFG="ubinize_oemapp_squashfs.cfg"
cat > "$UBI_CFG" <<EOF
[ubifs]
mode=ubi
image=${SFS_IMG}
vol_id=0
vol_type=dynamic
vol_name=${VOL_NAME}
vol_flags=autoresize
EOF

# pack UBI
echo "Packe neues UBI: $OUT_UBI"
ubinize -o "$OUT_UBI" -m "$MIN_IO" -p "$PEB_SIZE" -O "$DATA_OFF" -s "$MIN_IO" "$UBI_CFG"

# binwalk validation
echo "Validiere per binwalk gegen Original"
binwalk "$ORIG_UBI" > orig_bw.txt
binwalk "$OUT_UBI" > new_bw.txt
if diff -u orig_bw.txt new_bw.txt >/dev/null; then
  echo "Binwalk-Validierung bestanden."
else
  echo "Fehler: Binwalk-Output weicht ab!" >&2; diff -u orig_bw.txt new_bw.txt; exit 1
fi

# cleanup
rm -f "$SFS_IMG" "$UBI_CFG" orig_bw.txt new_bw.txt

echo "✔ Fertig: $OUT_UBI"
