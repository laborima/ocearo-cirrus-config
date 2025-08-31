#!/bin/bash
set -e

# Check if bluetooth is active
if ! systemctl is-active --quiet bluetooth; then
  echo "Bluetooth service not running, starting..."
  sudo systemctl start bluetooth
fi

# Enable Bluetooth controller
bluetoothctl power on

# Make the Pi visible and pairable
bluetoothctl agent on
bluetoothctl default-agent
bluetoothctl discoverable on
bluetoothctl pairable on

echo ">>> Press PS + Share on the PS5 controller to enter pairing mode."
echo ">>> The Raspberry Pi should detect it automatically."

# Configuration udev for the PS5 controller
cat > /etc/udev/rules.d/99-ps5-controller.rules << 'EOL'
# DualSense Wireless Controller - Bluetooth
KERNEL=="js*", ATTRS{name}=="Wireless Controller", SYMLINK+="input/dualsense"
# DualSense Wireless Controller - USB
KERNEL=="js*", ATTRS{name}=="PS5 Controller", SYMLINK+="input/dualsense"
EOL

# Reload udev rules
udevadm control --reload-rules
udevadm trigger

echo "PS5 controller configuration completed. Restart to apply changes."
