#!/usr/bin/env python3
"""
Offline decryption of the "_encrypt_..." password blobs in a Zyxel NR7302
zcfg_config.json (Quectel RG520F / SDX65 firmware).

No device/WebUI oracle needed: key + IV are derived from firmware-embedded
constants that are identical across devices with this firmware.

Scheme (reverse-engineered from encryptPassword/aesEncryptCbc256 in /bin/zcmd):
  AES-256-CBC, PKCS#7, key/iv = OpenSSL EVP_BytesToKey(md=SHA1, count=5)
  passphrase = "ThiSISEncryptioNKeY"  (assembled byte-by-byte by zcmdInit1..6)
  salt       = 39 30 00 00 31 d4 00 00   (ints 12345 / 54321, little-endian)

Usage:
  pip install pycryptodome
  python3 decrypt_zcfg_config.py zcfg_config.json       # dump all password-like fields
  python3 decrypt_zcfg_config.py --blob _encrypt_uX9B4FiFkf67Bzx33piCEQ==
"""
import sys, json, base64, hashlib, argparse
from Crypto.Cipher import AES

PASSPHRASE = b"ThiSISEncryptioNKeY"
SALT       = bytes.fromhex("3930000031d40000")

def evp_bytestokey(pw, salt, klen=32, ivlen=16, count=5, md=hashlib.sha1):
    d, out = b"", b""
    while len(out) < klen + ivlen:
        d = md(d + pw + salt).digest()
        for _ in range(count - 1):
            d = md(d).digest()
        out += d
    return out[:klen], out[klen:klen + ivlen]

KEY, IV = evp_bytestokey(PASSPHRASE, SALT)

def decrypt(value):
    if not isinstance(value, str) or not value.startswith("_encrypt_"):
        return None
    ct = base64.b64decode(value[len("_encrypt_"):])
    pt = AES.new(KEY, AES.MODE_CBC, IV).decrypt(ct)
    pad = pt[-1]
    if 1 <= pad <= 16 and pt[-pad:] == bytes([pad]) * pad:
        pt = pt[:-pad]
    return pt.rstrip(b"\x00").decode("utf-8", "replace")

def walk(obj, path=""):
    if isinstance(obj, dict):
        for k, v in obj.items():
            yield from walk(v, f"{path}/{k}")
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            yield from walk(v, f"{path}[{i}]")
    else:
        yield path, obj

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("config", nargs="?", help="path to zcfg_config.json")
    ap.add_argument("--blob", help="decrypt a single _encrypt_... value")
    a = ap.parse_args()
    if a.blob:
        print(decrypt(a.blob)); return
    if not a.config:
        ap.error("give a zcfg_config.json or --blob")
    data = json.load(open(a.config))
    for path, val in walk(data):
        if isinstance(val, str) and val.startswith("_encrypt_"):
            print(f"{path} = {decrypt(val)!r}")

if __name__ == "__main__":
    main()
