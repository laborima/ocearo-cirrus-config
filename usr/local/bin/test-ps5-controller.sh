#!/bin/bash

echo "=== Test PS5 controller ==="

# Check if jstest is installed
if ! command -v jstest &> /dev/null; then
    echo "Installing jstest..."
    sudo apt-get update && sudo apt-get install -y joystick
fi

# Find the controller device
CONTROLLER_DEV="/dev/input/js0"
if [ ! -e "$CONTROLLER_DEV" ]; then
    echo "Controller not detected on $CONTROLLER_DEV"
    echo "Input devices available :"
    ls -l /dev/input/js* 2>/dev/null || echo "No js device found"
    echo "\nCheck that the controller is connected via Bluetooth :"
    bluetoothctl devices
    exit 1
fi

echo "Controller detected on $CONTROLLER_DEV"
echo "Press controller buttons to test (CTRL+C to quit)"

# Test the controller
jstest --normal "$CONTROLLER_DEV"
