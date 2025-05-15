# USB 

Most NR7301/7302/7303 devices are manufactured and supplied without a USB port. The devices from Teleonor (Norway) are an exception: they have a USB-C port soldered in and integrated. This port can be used to communicate with the OS via the adbd process running on the router. This gives the host PC access to the router system with adb (not to the Quectel RG520F modem!).

## Add USB functionality and port

Even if the USB-C connection has not been soldered in, the PINs still exist on the mainboard. A USB interface or the corresponding cables can therefore be soldered on. All PINs for a USB-C interface are included, but it is also sufficient to solder only the PINs to obtain a USB-A interface. 

### PIN-OUT USB Port:
The usb header is located at J3. To access fastboot and edl you don't need to solder the VCC connection. For ADB and DIAG you also need the VCC connection.

![PCB](<imgs/usb1.png>)

![USB-C PIN OUT 1](<imgs/usb2.png>)

![USB-C PIN OUT 2](<imgs/usb3.png>)

![Soldered USB](<imgs/usb4.png>)

## USB: Range of functions

Direct modem access:
- EDL
- Qualcomm DIAG Port 

Access to the router OS/file system:
- fastboot
- adb

## ADB + DIAG Activation

Fastboot (bootloader), EDL (bootloader + PIN short circuit) and adb can be used without changing the USB composition. The Qualcomm DIAG port, on the other hand, for the use of QPST/QFIL/EFS Explorer must be activated by changing the USB composition. As delivered, devices from Deutsche Telekom (DTAG - Germany) and A1 (Austria) use the USB composition ‘Quectel’. This must be changed in order to activate the DIAG port. Root access is required for this process.

To access the DIAG port on your host machine, at least QPST 2.7.496 and the drivers it contains are required and it is necessary to change the usb_composition from Quectel to e.g. 9025 (this composition has DIAG and adb enabled). ATTENTION: Changing the usb_composition from Quectel to 9025 will stop your WAN connection. Additonaly: There are usb_compositions which can brick your modem and you'll lose connection to change it backwards. Keep this in mind!

Necessary: Wechsel der USB-Composition:
```
1. $ usb_composition
2. Insert: 9025
3. Press: n 
4. Press: y
5. Press: y
6: Press: n
````
Changing the USB composition: The USB composition has now been changed. If the DIAG port is not recognised on the host PC directly, the router has to be restarted.