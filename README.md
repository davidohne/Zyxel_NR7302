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

Devices from Telenor and A1 have eSIM support enabled by default. However, DTAG (Deutsche Telekom) devices are not equipped with this feature by default.
This is not a firmware problem; it is a modem configuration issue. Even cross-flashed DTAG devices can be affected (TAKE CARE: cross-flashing without proper preparation can soft-brick your device).

If you have a valid eID added to the zcfg_config.json file, the eSIM functionality will work even with DTAG firmware. However, at the time of writing, I could not find a way to locate the eID. The eID is empty by default in DTAG configurations, so the eSIM menu is missing in the WebUI. The app does not receive the flag "esim_supported:true" and does not allow you to add an eSIM profile. Adding a fake eID brings up the menu, but you won't be able to add the eSIM or connect.

At the time of writing, my findings are leading me towards the EFS/nv_item file uim_hw_config, which is responsible for activating and deactivating SIM slots. I cannot validate my hypothesis until I receive a uim_hw_config from an eSIM-activated modem.

Telenor users can easily extract this file using EFS Explorer. In contrast, A1 users would need to solder the USB port.

I've extracted all the valid AT commands for the modem firmware, which showed that writing NVRAM values is only possible up to index 7300, and that EFS files cannot be opened. Therefore, without Qualcomm access, I don't see an option to edit the modem's EFS files. I was also unsuccessful in mirroring the DIAG port to the router OS.


## Telenor Devices

They have their own section... The devices are practically unmanageable by the user. In the delivery state and after resetting the devices, a configuration is imported that leaves the 'BootFromFactoryDefault' option set to true. This deletes any configuration changes when booting. However, as the devices have a USB port, the configuration can easily be changed via ADB Shell. Telenor has come up with even more gifts for its customers which you can edit to gain permanent access. You have to change several setting in /xdata/zcfg_config.json. 
**First of course you have to change the BootFromFactoryDefault setting to false!**
- The DHCP server is deactivated. To activate, set Enable to true:
    ```"DHCPv4":{
            "Server":{
                "Enable":true,```

- Remote management only works on the WAN interfaces, i.e. no Web UI and no SSH etc. To be able to access via the LAn interface, change the mode to LAN_ONLY and DisableSshPasswordLogin to false:
```{
        "Name":"HTTPS",
        "Enable":true,
        "Protocol":6,
        "Port":443,
        "Mode":"LAN_ONLY",
        "TrustAll":true
      },
```
```
      {
        "Name":"SSH",
        "Enable":true,
        "Protocol":6,
        "Port":22022,
        "Mode":"LAN_ONLY",
        "TrustAll":true,
        "DisableSshPasswordLogin":false
      },
```

The Telenor devices receive updates via a special Telenor server. Updates are only made available if the router is logged into the Telenor network. If you are running a Telenor NR7302 device without a telenor IP, you could consider cross-flashing the device to a more customer-friendly version. 