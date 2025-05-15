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