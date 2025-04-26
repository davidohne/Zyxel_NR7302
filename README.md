# Zyxel NR7302 Findings 

This is a collection of firmware- and hardware-related findings for the Zyxel NR7302 router. Most of these findings could also be applied to the NR7301 and NR7303.

## Admin & Root Password Retrieval

ATTENTION: There is a high risk of bricking your device, either soft or hard. I absolutely do not accept any responsibility. If you follow any of these instructions, you must accept that your device may become unusable. Know what you are doing. (However, if you know how to solder, the device is almost impossible to brick.)

### Goal

- NR7302 sends its zcfg_config.json to a local web server via HTTP POST Request
- All (root, supervisor, admin) passwords are encrypted inside the config file
- Encrypted passwords can be decrypted via Zyxel Web Interfaces (DDNS function --> paste password; save; reload UI; make password visible)

### Procedure

1. Extract existing firmware upgrade file 
2. Extract ubifs image out of oemapp.ubi
3. Extract ubifs image
4. Add HTTP POST request to zcmd.sh
5. Repack oemapp.ubi
6. Repack firmware
7. Flash firmware via zycast
8. Run local webserver to receive config file


### Step by Step Guide 

0. Pre-Requirements:
      1. Create a Python virtual environment: python3 -m venv venv
      2. Activate virtual environment: source venv/bin/activate
   1. Install ubi_reader: 
      1. git clone https://github.com/jrspruitt/ubi_reader
      2. cd ubi_reader
      3. pip3 install ubi_reader
1. Download one of the existing Telekom firmwares for NR7302 (e.g. 100ACHA4b5_F0.bin)
2. Extract firmware with binwalk: ``binwalk -e 100ACHA4b5_F0.bin``
3. Change into output folder: ``cd _100ACHA4b5_F0.bin.extracted``
4. Rename oemapp.ubi to oemapp_original.ubi: ``mv oemapp.ubi oemapp_original.ubi``
5. Download ``rebuild_oemapp.sh``into folder with ``wget https://raw.githubusercontent.com/davidohne/Zyxel_NR7302/refs/heads/main/firmware/rebuild_oemapp.sh``
6. Extract oemapp.ubi: ``bash rebuild_oemapp.sh -e oemapp.ubi``
7. Change into squashfs-root folder: ``cd squashfs-root``
8. Add HTTP request paragraph to /etc/init.d/zcmd.sh:
   1. Add 90 seconds after boot post request part right before ``exit 0``(0!):
   ```
   # ----------  Background‑Upload 90 s after Boot  ----------
        (
            sleep 90
            FILE=/xdata/zcfg_config.json
            DEST=http://192.168.1.4:8080
            if [ -f "$FILE" ]; then
                echo "[zcmd] Versuche $FILE an $DEST zu senden" > /dev/console
                curl -s -X POST -H "Content-Type: application/json" --data-binary @"$FILE" "$DEST?type=zcfg_config" \
                  && echo "[zcmd] Upload erfolgreich" > /dev/console \
                  || echo "[zcmd] Upload fehlgeschlagen" > /dev/console
            else
                echo "[zcmd] WARN: $FILE nicht gefunden – kein Upload" > /dev/console
            fi
            # dmesg hochladen
            DMESG_TMP="/tmp/dmesg.txt"
            dmesg > "$DMESG_TMP"
            echo "[zcmd] Sende dmesg an $DEST" > /dev/console
            curl -s -X POST -H "Content-Type: text/plain" --data-binary @"$DMESG_TMP" "$DEST?type=dmesg" \
              && echo "[zcmd] dmesg Upload erfolgreich" > /dev/console \
              || echo "[zcmd] dmesg Upload fehlgeschlagen" > /dev/console

            # logread (Systemlog) hochladen
            SYSLOG_TMP="/tmp/syslog.txt"
            logread > "$SYSLOG_TMP"
            echo "[zcmd] Sende Systemlog an $DEST" > /dev/console
            curl -s -X POST -H "Content-Type: text/plain" --data-binary @"$SYSLOG_TMP" "$DEST?type=syslog" \
             && echo "[zcmd] Syslog Upload erfolgreich" > /dev/console \
             || echo "[zcmd] Syslog Upload fehlgeschlagen" > /dev/console
            ) &
        # ------------------------------------------------------- 
    ```

    2. OPTIONAL: De-Brick Debug Mode (Device is flashing green):
        1. Add the following line to the first line of the if-fe part of: ``if [ -f /xdata/.zdbg ]; then``:
        ``mv -f /xdata/.zdbg /xdata/zdbg.disabled``
9. Save the zcmd.sh file
10. Change directory to _100ACHA4b5_F0.bin.extracted again
11. Run rebuild_oemapp.sh extraction script again to re-pack the oemapp.ubi:
    - ``bash rebuild_oemapp.sh -r oemapp_original.ubi squashfs-root oemapp.ubi``
12. Download ``rebuild_firmware.sh`` with: ``wget https://raw.githubusercontent.com/davidohne/Zyxel_NR7302/refs/heads/main/firmware/rebuild_firmware.sh``
13. Execute script and answer all questions to rebuild the firmware with the new oemapp.ubi: ``bash rebuild_firmware.sh``
14. ATTENTION: Validation will show two WARNings, which is normal: Header-CRC incorrect and Image-CRC incorrect --> All other validations must succeed
15. Flash the router via Zycast (see instructions in zycasting folder)
16. After you've flashed the router successful, 90 seconds after boot the router will send its zcfg_config.json via HTTP POST request to 192.168.1.4:8080
17. Your host machine (PC) which is connected has to be configured with the static IP 192.168.1.4
18. To run a simple Python webserver you can execute the ``receive_zcfg_webserver.py``Python script: ``wget https://raw.githubusercontent.com/davidohne/Zyxel_NR7302/refs/heads/main/firmware/receive_zcfg_webserver.py``
    -  Execute: ``python3 receive_zcfg_webserver.py``and wait for the router to reboot. After around 110 seconds the server receives the configuration file and saves it automatically
    -  You can decrypt the password using a working Zyxel WebUI by adding dummy data to the DDNS Settings and the _encrypt_ part from the zcfg_config.json as password. Reload the WebUI and click the button to see the password in plain text.
19. IMPORTANT: You have now implemented a significant security vulnerability to your device. As soon as you've received the passwords, flash the ORIGINAL/NOT-EDITED firmware to the router via the web interface to close the vulnerability. THIS IS A MANDATORY STEP!

        
