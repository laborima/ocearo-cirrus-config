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
