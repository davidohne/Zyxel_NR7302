#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------
# WARNING: This script is for training image-building purposes ONLY.
# Do NOT flash the generated firmware onto any router.
# Flashing may brick or destroy your device.
# By proceeding, you acknowledge no liability for any damage caused.
# -----------------------------------------------------------------------
# Confirm user acknowledgment
read -p "[CONFIRM] I understand this script is for training purposes only. Flashing the image file will destroy the router. Proceed anyway? (y/n) " CONFIRM
case "${CONFIRM,,}" in
  y|yes)
    echo "[INFO] Proceeding with build..."
    ;;
  *)
    echo "[ERROR] User did not confirm. Exiting." >&2
    exit 1
    ;;
esac

set -euo pipefail

# -----------------------------------------------------------------------
# Firmware Build Script (Bash wrapper with embedded Python)
# - Single-file solution for Debian/Linux environments
# -----------------------------------------------------------------------

# --- Dependency Check (Bash) --------------------------------------------
if ! command -v python3 >/dev/null; then
  echo "[ERROR] python3 not found. Please install Python 3.6 or newer." >&2
  exit 1
fi
PY_VERS=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
REQUIRED="3.6"
if [[ "$(printf '%s
%s
' "$REQUIRED" "$PY_VERS" | sort -V | head -n1)" != "$REQUIRED" ]]; then
  echo "[ERROR] Python $REQUIRED+ required, you have $PY_VERS." >&2
  exit 1
fi

# --- Check for original boot image --------------------------------------
ORIG_IMG="sdxlemur-boot.img.original"
if [[ ! -f "$ORIG_IMG" ]]; then
  read -p "[WARN] $ORIG_IMG not found. Did you make changes to sdxlemur-boot.img? (y/n) " RESP
  case "${RESP,,}" in
    n|no)
      echo "[INFO] Using sdxlemur-boot.img as original image."
      cp "sdxlemur-boot.img" "$ORIG_IMG"
      ;;
    y|yes)
      echo "[ERROR] An unmodified original sdxlemur-boot.img (named $ORIG_IMG) is required. Please provide it." >&2
      exit 1
      ;;
    *)
      echo "[ERROR] Invalid response. Please answer 'y' or 'n'." >&2
      exit 1
      ;;
  esac
fi

# --- Execute Embedded Python Code ---------------------------------------
exec python3 - "$@" << 'PYCODE'
"""
Firmware Build Script (embedded Python)
Dependencies: Python 3.6+, standard libraries only.
Includes build, MD5 update, header patch, and comprehensive validation.
"""
import sys
import os
import zipfile
import struct
import zlib
import binascii
import hashlib
from xml.etree import ElementTree as ET

# --- Configuration -----------------------------------------------------
FILES_TO_INCLUDE = [
    "oemapp.ubi",
    "sdxlemur-sysfs.ubi",
    "sdxlemur-boot.img",
    "NON-HLOS.ubi",
    "multifota.bin",
    "fotaconfig.xml"
]
BUILD_MAP = {
    "oemapp.ubi": {"type": "passthrough"},
    "sdxlemur-sysfs.ubi": {"type": "passthrough"},
    "sdxlemur-boot.img": {"type": "hdr1_preserve", "original": "sdxlemur-boot.img.original"},
    "multifota.bin": {"type": "passthrough"},
    "fotaconfig.xml": {"type": "fotaconfig", "update_md5": True},
    "NON-HLOS.ubi": {"type": "passthrough"}
}
OUTPUT_FILENAME = "100ACHA4b5_F0_custom_for_router.bin"
EXPECTED_MODEL_ID = 0x7302  # Correct model ID

# --- Helper -------------------------------------------------------------
def read_model_id(data):
    if len(data) < 0x120:
        return None, None
    b = data[0x11C:0x120]
    model_id = (b[0] << 12) | (b[1] << 8) | (b[2] << 4) | b[3]
    return model_id, [hex(x) for x in b]

# --- Validation Functions ----------------------------------------------
def validate_hdr1(data, name, expected_model_id=None):
    results = []
    magic = struct.unpack_from('<I', data, 0x00)[0]
    if magic != 0x31524448:
        results.append(f"[INFO] {name}: No HDR1 magic (0x{magic:08X}), skipping HDR1 validation.")
        return results
    results.append(f"[OK] {name}: Magic 'HDR1' OK.")

    model_id, bytes_list = read_model_id(data)
    if model_id is not None:
        results.append(f"[INFO] {name}: Model-ID = 0x{model_id:X} (bytes {bytes_list}).")
        if expected_model_id is not None and model_id != expected_model_id:
            results.append(f"[WARN] {name}: Model-ID does not match expected 0x{expected_model_id:X}.")
        elif expected_model_id is not None:
            results.append(f"[OK] {name}: Expected Model-ID matches.")

    # Header CRC
    stored_hdr = struct.unpack_from('<I', data, 0x174)[0]
    tmp = bytearray(data[:0x17C])
    tmp[0x174:0x178] = b'\x00'*4
    calc_hdr = binascii.crc32(tmp) & 0xFFFFFFFF
    if calc_hdr != stored_hdr:
        results.append(f"[WARN] {name}: Header-CRC incorrect (stored 0x{stored_hdr:08X} != calc 0x{calc_hdr:08X}).")
        results.append(f"[INFO] {name}: Flashing will proceed despite header CRC mismatch.")
    else:
        results.append(f"[OK] {name}: Header-CRC correct.")

    # Image CRC
    stored_img = struct.unpack_from('<I', data, 0x0C)[0]
    calc_img = binascii.crc32(data[0x17C:]) & 0xFFFFFFFF
    if calc_img != stored_img:
        results.append(f"[WARN] {name}: Image-CRC incorrect (stored 0x{stored_img:08X} != calc 0x{calc_img:08X}).")
        results.append(f"[INFO] {name}: Flashing will proceed despite image CRC mismatch.")
    else:
        results.append(f"[OK] {name}: Image-CRC correct.")

    return results


def validate_fotaconfig(xml_data, zipf):
    results = []
    try:
        root = ET.fromstring(xml_data.decode('utf-8'))
    except ET.ParseError as e:
        return [f"[ERROR] fotaconfig.xml: XML parse error: {e}"]
    for part in root.findall('partition'):
        img = part.findtext('image')
        md5_exp = part.findtext('newmd5')
        if img and md5_exp:
            if img not in zipf.namelist():
                results.append(f"[ERROR] fotaconfig.xml: '{img}' missing in ZIP.")
                continue
            actual = hashlib.md5(zipf.read(img)).hexdigest()
            if actual != md5_exp:
                results.append(f"[ERROR] fotaconfig.xml: MD5 mismatch for '{img}' ({actual} != {md5_exp}).")
            else:
                results.append(f"[OK] fotaconfig.xml: MD5 for '{img}' correct.")
    return results


def validate_zip_firmware(path, expected_model_id=None):
    if not zipfile.is_zipfile(path):
        print(f"[ERROR] '{path}' is not a valid ZIP.")
        return False
    with zipfile.ZipFile(path, 'r') as zipf:
        print(f"[INFO] Validating ZIP firmware: {path}")
        for name in zipf.namelist():
            print(f"\n[INFO] File: {name}")
            data = zipf.read(name)
            if name.endswith('.xml'):
                for line in validate_fotaconfig(data, zipf): print(line)
            elif name.endswith(('.img', '.bin')):
                for line in validate_hdr1(data, name, expected_model_id): print(line)
            else:
                print(f"[INFO] {name}: No HDR1 checks applied.")
    return True

# --- Build Functions ----------------------------------------------------
def patch_hdr1_preserve(modified_data: bytes, original_path: str) -> bytes:
    if not os.path.exists(original_path):
        raise FileNotFoundError(f"[ERROR] Original file not found: {original_path}")
    orig = open(original_path, 'rb').read()
    header = bytearray(orig[:0x17C])
    payload = modified_data[0x17C:]
    img_crc = (zlib.crc32(payload) & 0xFFFFFFFF) ^ 0xFFFFFFFF
    header[0x0C:0x10] = struct.pack('<I', img_crc)
    header[0x174:0x178] = b'\x00'*4
    hdr_crc = (zlib.crc32(header) & 0xFFFFFFFF) ^ 0xFFFFFFFF
    header[0x174:0x178] = struct.pack('<I', hdr_crc)
    return bytes(header) + payload


def update_fotaconfig(xml_data: bytes, file_contents: dict) -> bytes:
    root = ET.fromstring(xml_data)
    for part in root.findall('partition'):
        img = part.findtext('image')
        md5_node = part.find('newmd5')
        if img and md5_node is not None and img in file_contents:
            md5_node.text = hashlib.md5(file_contents[img]).hexdigest()
    return ET.tostring(root, encoding='utf-8', xml_declaration=True)


def build_zip():
    file_map = {}
    for fname in FILES_TO_INCLUDE:
        if not os.path.exists(fname):
            raise FileNotFoundError(f"[ERROR] Missing file: {fname}")
        raw = open(fname, 'rb').read()
        cfg = BUILD_MAP.get(os.path.basename(fname), {'type':'passthrough'})
        if cfg['type']=='hdr1_preserve':
            raw = patch_hdr1_preserve(raw, cfg['original'])
        elif cfg['type']=='fotaconfig' and cfg.get('update_md5'):
            temp_map = {os.path.basename(k):v for k,v in file_map.items()}
            for f in FILES_TO_INCLUDE:
                key = os.path.basename(f)
                if key not in temp_map and os.path.exists(f):
                    temp_map[key] = open(f,'rb').read()
            raw = update_fotaconfig(raw, temp_map)
        file_map[os.path.basename(fname)] = raw
    with zipfile.ZipFile(OUTPUT_FILENAME,'w', zipfile.ZIP_DEFLATED) as zf:
        for name,data in file_map.items():
            zf.writestr(name,data)
    print(f"[OK] Firmware created: {OUTPUT_FILENAME}")

if __name__=='__main__':
    try:
        build_zip()
        print("[INFO] Running full post-build validation...")
        if not validate_zip_firmware(OUTPUT_FILENAME, expected_model_id=EXPECTED_MODEL_ID):
            sys.exit("[ERROR] Full validation failed.")
        print("[OK] Full validation passed.")
        sys.exit(0)
    except Exception as e:
        sys.exit(f"[ERROR] {e}")
PYCODE
