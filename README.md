# Zyxel NR7302 Findings 

This is a collection of firmware- and hardware-related findings for the Zyxel NR7302 router. Most of these findings could also be applied to the NR7301 and NR7303.


[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/ohne)

## Admin & Root Password Retrieval

If you lost or never received the admin password for the devices, there is a solution to retrieve it again by editing the firmware files and flash these files with zycast

[Firmware-Editing](firmware/README.md)

## Flash a Firmware with Zycast

If you soft-bricked your device or you don't have access to SSH/WebUI you can flash a valid firmware file via zycast multicast flash method. A detailed description is here:

[Zycasting](usb/README.md)

## Adding USB to access ADB and Qualcomm DIAG

Since you can not access the EFS system of the modem you need to access these files via QPST/EFS Explorer. Therefore you need to access and enable the DIAG mode and add an USB port to the device.

[USB-Functionality](usb/README.md)

## "Miracle" Adding eSIM Functionality

Telenor and A1 devices have enabled eSIM support by default. DTAG (German Telekom) devices are not equipped with this feature by default. 
This is not a firmware problem, it is a modem configuration problem. Even cross-flashed DTAG devices (take take -> cross-flashing without preperations before soft-bricks your device).

IF(!) you have the valid eID added to the zcfg_config.json file, the eSIM functionality works even with DTAG firmwares. Problem: At the time of writing I did not find a way to find the eID. Factory default the eID is empty in DTAG configurations and therefore the eSIM menu is missing in the WebUI and the APP does not receive the flag "esim_supported:true" and does not allow you to add a eSIM profile. Adding a fake eID brings up the menu - but you won't be able to add the eSIM or connect.

At the time of this writing, my finding are leading me to the EFS/nv_item file uim_hw_config which is responsible for the activation and deactivation of sim slots. Until I don't receive a uim_hw_config of a eSIM activated modem I can not validate my hypothesis.

Telenor users could easily extract this file with EFS Explorer. A1 users would have to solder the USB port.

I've extracted all valid AT commands for the modem firmware and it showed up that writing nv values is only possible until index 7300 and it is not possible to open EFS files. Therefore I don't see an option to edit the modem's efs files without qualcomm access. I was not successful mirroring the DIAG port to the router OS.