#!/bin/bash
# ocearo-core installation script for Raspberry Pi 5 (OpenPlotter)
# Author: Matthieu
# Description: Installs dependencies for Ollama, Piper TTS, SignalK with audio setup

set -e

echo "🚀 Installing ocearo-core dependencies for Raspberry Pi 5"
echo "=========================================================="

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install base dependencies
echo "📦 Installing system dependencies..."
sudo apt-get install -y \
    pulseaudio-utils \
    sox \
    espeak-ng \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    curl \
    wget 

# Add current user to audio group
echo "👤 Adding $(whoami) to audio group..."
sudo usermod -aG audio $(whoami)

# Setup Piper in virtual environment
PIPER_DIR="/opt/piper"
VENV_DIR="$PIPER_DIR/venv"

echo "🎤 Installing Piper TTS in virtual environment..."
sudo mkdir -p $PIPER_DIR
sudo chown $(whoami):$(whoami) $PIPER_DIR
chmod 755 $PIPER_DIR

# Create virtual environment if not exists
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv $VENV_DIR
fi

# Upgrade pip inside venv
$VENV_DIR/bin/pip install --upgrade pip

# Install Piper TTS in venv
$VENV_DIR/bin/pip install piper-tts

# Create wrapper so 'piper' works globally
sudo tee /usr/local/bin/piper > /dev/null <<EOF
#!/bin/bash
$VENV_DIR/bin/piper "\$@"
EOF
sudo chmod +x /usr/local/bin/piper

# Function to download Piper models
download_piper_model() {
    local model_name="$1"
    local base_url="$2"
    echo "   📥 Downloading $model_name..."
    wget -q -O "$PIPER_DIR/${model_name}.onnx" "${base_url}/${model_name}.onnx"
    wget -q -O "$PIPER_DIR/${model_name}.onnx.json" "${base_url}/${model_name}.onnx.json"
}

# French voice (Tom)
if [ ! -f "$PIPER_DIR/fr_FR-tom-medium.onnx" ]; then
    download_piper_model "fr_FR-tom-medium" \
        "https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR/tom/medium"
fi

# English voice (Joe)
if [ ! -f "$PIPER_DIR/en_US-joe-medium.onnx" ]; then
    download_piper_model "en_US-joe-medium" \
        "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/joe/medium"
fi

echo "✅ Piper installed with voices in $PIPER_DIR"
echo "   To run: piper --help"

# Install Ollama
echo "🤖 Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

# Enable and start Ollama service (system-wide one installed by Ollama script)
echo "⚙️  Enabling Ollama systemd service..."
sudo systemctl enable ollama
sudo systemctl start ollama

# Final checks
echo "🔍 Installation complete!"
echo "   - Piper voices: $(ls -1 $PIPER_DIR | wc -l) files"
echo "   - Ollama status: $(systemctl is-active ollama)"
echo ""
echo "🎉 ocearo-core environment ready!"
echo "   Ollama API: http://localhost:11434"
