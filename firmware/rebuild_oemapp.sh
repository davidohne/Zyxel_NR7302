#!/usr/bin/env bash
set -euo pipefail

# usage: ./rebuild_oemapp.sh <original.ubi> <squashfs-root> <output.ubi>

# 0) Parameteranzahl prüfen
if [[ "$#" -ne 3 ]]; then
  echo "Usage: $0 <original.ubi> <squashfs-root> <output.ubi>"
  exit 1
fi

ORIG_UBI="$1"
SFS_ROOT="$2"
OUT_UBI="$3"

###############################
# 1) Nicht-übliche Dependencies prüfen & ggf. installieren
###############################
# apt-get installable tools
declare -A apt_deps=(
  [mksquashfs]=squashfs-tools
  [ubinize]=mtd-utils
  [binwalk]=binwalk
)
# pip-installable tools
declare -A pip_deps=(
  [ubireader_display_info]="git+https://github.com/onekey-sec/ubi_reader.git"
)

for cmd in "${!apt_deps[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Dependency '$cmd' fehlt. Installieren via 'sudo apt-get install ${apt_deps[$cmd]}'? [Y/n]"
    read -r ans
    if [[ "$ans" =~ ^([yY]|$) ]]; then
      sudo apt-get update
      sudo apt-get install -y ${apt_deps[$cmd]}
    else
      echo "Abbruch: fehlende Abhängigkeit $cmd." >&2
      exit 1
    fi
  fi
done

for cmd in "${!pip_deps[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Dependency '$cmd' fehlt. Installieren via 'pip3 install ${pip_deps[$cmd]}'? [Y/n]"
    read -r ans
    if [[ "$ans" =~ ^([yY]|$) ]]; then
      pip3 install ${pip_deps[$cmd]}
    else
      echo "Abbruch: fehlende Abhängigkeit $cmd." >&2
      exit 1
    fi
  fi
done

###############################
# 2) Tool-Check (Standard)
###############################
for cmd in mksquashfs ubinize ubireader_display_info binwalk; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' fehlt. Bitte prüfe Deine Installation." >&2
    exit 1
  fi
done

###############################
# 3) Validierung des SquashFS-Root-Verzeichnisses
###############################
required=(bin data dev etc lib mnt proc root sbin sys tmp usr var)
for d in "${required[@]}"; do
  if [[ ! -d "$SFS_ROOT/$d" ]]; then
    echo "Error: Verzeichnis '$d' fehlt in '$SFS_ROOT'." >&2
    exit 1
  fi
done

###############################
# 4) Parameter auslesen
###############################
UBI_INFO=$(ubireader_display_info "$ORIG_UBI")
MIN_IO=$(  echo "$UBI_INFO" | sed -n 's/^[[:space:]]*Min I\/O: *\([0-9]\+\).*/\1/p')
LEB_SIZE=$(echo "$UBI_INFO" | sed -n 's/^[[:space:]]*LEB Size: *\([0-9]\+\).*/\1/p')
PEB_SIZE=$(echo "$UBI_INFO" | sed -n 's/^[[:space:]]*PEB Size: *\([0-9]\+\).*/\1/p')
DATA_LEBS=$(echo "$UBI_INFO" | sed -n 's/^[[:space:]]*Data Block Count: *\([0-9]\+\).*/\1/p')
DATA_OFF=$MIN_IO
SEQ_NUM=$( echo "$UBI_INFO" | sed -n 's/^[[:space:]]*Image Sequence Num: *\([0-9]\+\).*/\1/p')
VOL_NAME=$(echo "$UBI_INFO" | sed -n 's/^[[:space:]]*Volume Name: *//p' | head -1 | xargs )
VOL_SIZE=$(( DATA_LEBS * PEB_SIZE ))

###############################
# 5) Neues SquashFS bauen
###############################
SFS_IMG="img-${SEQ_NUM}_vol-${VOL_NAME}.ubifs"
echo "Erzeuge SquashFS-Image: $SFS_IMG"
mksquashfs "$SFS_ROOT" "$SFS_IMG" -comp gzip -b 131072 -no-progress

###############################
# 6) ubinize-Konfig erstellen
###############################
UBI_CFG="ubinize_${VOL_NAME}.cfg"
cat > "$UBI_CFG" <<EOF
[ubifs]
mode=ubi
image=${SFS_IMG}
vol_id=0
vol_name=${VOL_NAME}
vol_type=dynamic
vol_alignment=1
vol_flags=autoresize
vol_size=${VOL_SIZE}
EOF

###############################
# 7) UBI-Container bauen
###############################
echo "Packe neues UBI: $OUT_UBI"
ubinize -o "$OUT_UBI" -m "$MIN_IO" -p "$PEB_SIZE" -O "$DATA_OFF" "$UBI_CFG"

###############################
# 8) Binwalk-Validierung
###############################
echo "Validiere per binwalk gegen Original"
binwalk "$ORIG_UBI" > orig_bw.txt
binwalk "$OUT_UBI" > new_bw.txt
if diff -u orig_bw.txt new_bw.txt >/dev/null; then
  echo "Binwalk-Validierung bestanden."
else
  echo "Fehler: Binwalk-Output weicht ab!" >&2
  diff -u orig_bw.txt new_bw.txt
  exit 1
fi

###############################
# 9) Aufräumen
###############################
rm -f "$SFS_IMG" "$UBI_CFG" orig_bw.txt new_bw.txt

echo "✔ Fertig: $OUT_UBI"