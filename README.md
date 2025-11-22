# Ocearo configuration for cirrus RPI5 and multiple screens

This project provides a Debian package to easily configure a dual-screen kiosk with touch support on Raspberry Pi, including automatic certificate management and PS5 controller support for autopilot control

## Features

- Automatic DSI and HDMI screen configuration
- Touch screen mapping
- Automatic kiosk mode startup
- Systemd service management
- PS5 controller support via Bluetooth
- Automatic input device configuration
- SSL/TLS certificate generation and management
- Signal K server integration
- Automatic certificate trust for Chromium and system

## Installation via APT Repository

1. Add the APT repository:
   ```bash
   echo "deb [trusted=yes] https://laborima.github.io/ocearo-cirrus-config/ ./" | sudo tee /etc/apt/sources.list.d/cirrusconfig.list
   ```

2. Update package list:
   ```bash
   sudo apt update
   ```

3. Install the package:
   ```bash
   sudo apt install cirrusconfig
   ```

4. Enable and start services:
   ```bash
   sudo systemctl enable kiosk
   sudo systemctl enable ps5-controller
   sudo systemctl enable cirrus-certs
   sudo systemctl start kiosk
   sudo systemctl start ps5-controller
   sudo systemctl start cirrus-certs
   ```

## PS5 Controller Setup

1. Put your controller in pairing mode by holding PS + Share buttons for 5 seconds
2. The controller should be automatically detected
3. Verify the connection:
   ```bash
   sudo test-ps5-controller.sh
   ```

### Troubleshooting

If the controller doesn't connect:
1. Check Bluetooth status:
   ```bash
   bluetoothctl devices
   bluetoothctl info [MAC_ADDRESS]
   ```
2. Restart Bluetooth service:
   ```bash
   sudo systemctl restart bluetooth
   ```
3. Retry pairing:
   ```bash
   sudo setup-ps5.sh
   ```

## Configuration

### Application URLs
Edit the URLs in `/usr/local/bin/kiosk-start.sh`:
```bash
URL_DSI="https://cirrus.local/ocearo-ui"
URL_HDMI="https://cirrus.local/ocearo-ui"
```

### Screen Configuration
Adjust settings in `/usr/local/bin/setup-screens.sh` as needed:
- Video output names
- Touch screen mapping
- Screen orientation

### PS5 Controller Configuration
Modify `/etc/udev/rules.d/99-ps5-controller.rules` if needed:
- Udev rules for auto-detection
- Button mapping

### SSL Certificates
Certificates are automatically generated and configured. The following files are created:
- `/etc/cirrus/certs/rootCA.pem` - Root Certificate Authority
- `/etc/cirrus/certs/cirrus.local.pem` - Domain certificate and key
- `/home/pi/.signalk/ssl/ca.pem` - Root CA for Signal K
- `/home/pi/.signalk/ssl/key-cert.pem` - Certificate and key for Signal K

## Development

### Local Build

1. Install build dependencies:
   ```bash
   sudo apt install build-essential devscripts debhelper
   ```

2. Build the package:
   ```bash
   dpkg-buildpackage -us -uc
   ```

### New Release

1. Update changelog:
   ```bash
   dch -i
   ```

2. Create a tag:
   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

## System Services

This package installs and manages the following services:
- `kiosk.service` - Handles the Chromium kiosk mode
- `ps5-controller.service` - Manages PS5 controller connection
- `cirrus-certs.service` - Handles SSL certificate generation and installation

## License

Apache 2.0 - See `debian/copyright` for details.


pi@cirrus:~ $ nmcli con show
NAME                          UUID                                  TYPE       DEVICE 
Tel@Matthieu                  ab43e5be-e55d-4f44-ac7d-02841f5c1fed  wifi       wlan0  
lo                            0c971d30-172a-40fe-87cc-080ecd26e0cb  loopback   lo     
Administratif                 f1e88c30-1d8e-44b9-8a97-72fbdeef419e  wifi       --     
Ifupdown (can0)               dbf5ce05-099b-faa3-71a7-59f5a9714731  ethernet   --     
Port_Plaisance_La_Rochelle    7a25aba1-3069-480f-af04-a002e4b599c7  wifi       --     
Port_Plaisance_La_Rochelle 1  0ed0dee6-fe25-4d32-a9df-6307e24f6604  wifi       --     
Tel@Matthieu 1                b9bffeb7-67aa-400f-b7c1-630a6e3fe83f  wifi       --     
Tel@Matthieu 2                0ab5ad72-d209-4045-9faa-e5ada3d28c3d  wifi       --     
Tel@Matthieu Network          d512bf7c-0246-44c9-8c0f-e1fb7280df97  bluetooth  --     
Wired connection 1            2eb6f5f0-c922-3640-827d-8a78b1da97e9  ethernet   --     
nausicaa                      f633f289-44ef-4ec6-bbc3-68277b4b4811  wifi       --     
pi@cirrus:~ $ 

i@cirrus:~ $ sudo cat  /etc/NetworkManager/system-connections/nausicaa.nmconnection 
[connection]
id=nausicaa
uuid=f633f289-44ef-4ec6-bbc3-68277b4b4811
type=wifi
interface-name=wlan0_ap
timestamp=1751190105

[wifi]
band=bg
channel=6
mac-address=2E:CF:67:BD:E9:14
mode=ap
ssid=nausicaa

[wifi-security]
key-mgmt=wpa-psk
psk=wifi4cirrus

[ipv4]
address1=10.42.0.1/24
method=shared

[ipv6]
addr-gen-mode=stable-privacy
method=shared

[proxy]



[connection]
id=Tel@Matthieu 1
uuid=b9bffeb7-67aa-400f-b7c1-630a6e3fe83f
type=wifi
interface-name=wlan9

[wifi]
mode=infrastructure
ssid=Tel@Matthieu

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk=wifi4matthieu

[ipv4]
method=auto

[ipv6]
addr-gen-mode=default
method=auto

[proxy]


ARCHER TX2 OU Plus
