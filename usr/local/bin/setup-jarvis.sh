#!/bin/bash
# ocearo-core installation script for Raspberry Pi 5 (OpenPlotter)
# Author: Matthieu
# Description: Installs dependencies for Ollama, Piper TTS, SignalK with audio setup

set -e

# Display system information
echo "📋 System Information:"
echo "   - Architecture: $(uname -m)"
echo "   - Kernel: $(uname -r)"
echo "   - Distribution: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
echo "   - Memory: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2}')"
echo "   - Storage: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')"
echo ""

echo "🚀 Installing ocearo-core dependencies for Raspberry Pi 5"
echo "=========================================================="

# Update system and clean repositories
echo "🔄 Updating system packages..."
echo "🧹 Cleaning up obsolete repositories..."
# Remove all Node.js repositories and configuration
sudo rm -f /etc/apt/sources.list.d/nodesource.list*
sudo rm -f /etc/apt/sources.list.d/nodesource.list.save*
sudo rm -rf /etc/apt/sources.list.d/nodesource*
sudo rm -f /usr/share/keyrings/nodesource.gpg
sudo rm -f /usr/share/keyrings/nodesource-repo.gpg
# Remove Node.js repository from main sources files
sudo sed -i '/nodesource/d' /etc/apt/sources.list 2>/dev/null || true
sudo sed -i '/node_20\.x/d' /etc/apt/sources.list 2>/dev/null || true
sudo sed -i '/node_20\.x/d' /etc/apt/sources.list.d/* 2>/dev/null || true
# Clean apt cache and update
sudo apt-get clean
sudo apt-get autoremove -y
sudo apt-get update --allow-releaseinfo-change
sudo apt-get upgrade -y

# Install base dependencies
echo "📦 Installing system dependencies..."
sudo apt-get install -y \
    pulseaudio-utils \
    pulseaudio \
    alsa-utils \
    sox \
    espeak-ng \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    curl \
    wget \
    lsb-release \
    git \
    htop \
    iotop 

# Add current user to audio group
echo "👤 Adding $(whoami) to audio group..."
sudo usermod -aG audio $(whoami)

# Add current user to pulse group for PulseAudio access
sudo usermod -aG pulse,pulse-access $(whoami) 2>/dev/null || true

# Setup audio configuration
echo "🔊 Setting up audio system..."

# Create PulseAudio client configuration
mkdir -p "$HOME/.config/pulse"
cat > "$HOME/.config/pulse/client.conf" << 'EOL'
# PulseAudio client configuration for Raspberry Pi
default-server = unix:/run/user/$(id -u)/pulse/native
autospawn = no
daemon-binary = /bin/true
disable-shm = yes
EOL
echo "✅ PulseAudio client configuration created"

# Test audio system
echo "🎵 Testing audio system..."
if command -v pulseaudio >/dev/null 2>&1; then
    if ! pactl info >/dev/null 2>&1; then
        echo "⚠️  Warning: Cannot connect to PulseAudio server"
        echo "   Audio features may be limited - you may need to restart or log out/in"
    else
        echo "✅ PulseAudio connection successful"
        pactl info | grep "Server Version" || true
    fi
else
    echo "⚠️  Warning: PulseAudio not available"
fi

# Test ALSA
if command -v aplay >/dev/null 2>&1; then
    if aplay -l >/dev/null 2>&1; then
        echo "✅ ALSA devices available"
        aplay -l | head -5
    else
        echo "⚠️  Warning: No ALSA devices found"
    fi
fi

# Setup Piper in virtual environment
PIPER_DIR="/opt/piper"
VENV_DIR="$PIPER_DIR/venv"

echo "🎤 Installing Piper TTS in virtual environment..."
sudo mkdir -p $PIPER_DIR
sudo chown $(whoami):$(whoami) $PIPER_DIR
chmod 755 $PIPER_DIR

if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv $VENV_DIR
fi

$VENV_DIR/bin/pip install --upgrade pip
$VENV_DIR/bin/pip install piper-tts

sudo tee /usr/local/bin/piper > /dev/null <<EOF
#!/bin/bash
$VENV_DIR/bin/piper "\$@"
EOF
sudo chmod +x /usr/local/bin/piper

# Setup Kokoro in virtual environment
KOKORO_DIR="/opt/kokoro"
KOKORO_VENV="$KOKORO_DIR/venv"

echo "🗣️  Installing Kokoro TTS in virtual environment..."
sudo mkdir -p $KOKORO_DIR
sudo chown $(whoami):$(whoami) $KOKORO_DIR
chmod 755 $KOKORO_DIR

if [ ! -d "$KOKORO_VENV" ]; then
    python3 -m venv $KOKORO_VENV
fi

$KOKORO_VENV/bin/pip install --upgrade pip
$KOKORO_VENV/bin/pip install kokoro-onnx soundfile

if [ -f "/home/matthieu/becpg-workspace/ocearo/ocearo-core/scripts/ocearo-tts.py" ]; then
    cp /home/matthieu/becpg-workspace/ocearo/ocearo-core/scripts/ocearo-tts.py $KOKORO_DIR/ocearo-tts.py
fi

echo "   Place kokoro-v1.0.int8.onnx and voices-v1.0.bin in $KOKORO_DIR"

# Function to download Piper model with retry logic
download_piper_model() {
    local model_name="$1"
    local base_url="$2"
    local max_retries=3
    local retry_count=0
    
    echo "   📥 Downloading $model_name voice model..."
    
    # Download .onnx file
    while [ $retry_count -lt $max_retries ]; do
        if wget --timeout=30 --tries=1 -q --show-progress -O "$PIPER_DIR/${model_name}.onnx" \
            "${base_url}/${model_name}.onnx"; then
            echo "   ✅ Downloaded ${model_name}.onnx"
            break
        else
            retry_count=$((retry_count + 1))
            echo "   ⚠️  Attempt $retry_count failed for ${model_name}.onnx"
            if [ $retry_count -eq $max_retries ]; then
                echo "   ❌ Failed to download ${model_name}.onnx after $max_retries attempts"
                return 1
            fi
            sleep 2
        fi
    done
    
    # Download .json file
    retry_count=0
    while [ $retry_count -lt $max_retries ]; do
        if wget --timeout=30 --tries=1 -q --show-progress -O "$PIPER_DIR/${model_name}.onnx.json" \
            "${base_url}/${model_name}.onnx.json"; then
            echo "   ✅ Downloaded ${model_name}.onnx.json"
            return 0
        else
            retry_count=$((retry_count + 1))
            echo "   ⚠️  Attempt $retry_count failed for ${model_name}.onnx.json"
            if [ $retry_count -eq $max_retries ]; then
                echo "   ❌ Failed to download ${model_name}.onnx.json after $max_retries attempts"
                return 1
            fi
            sleep 2
        fi
    done
}

# French voice (Tom - medium quality)
if [ ! -f "$PIPER_DIR/fr_FR-tom-medium.onnx" ]; then
    download_piper_model "fr_FR-tom-medium" \
        "https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR/tom/medium" || {
        echo "❌ Failed to download French voice model"
        exit 1
    }
fi

# English voice (Joe - medium quality)
if [ ! -f "$PIPER_DIR/en_US-joe-medium.onnx" ]; then
    download_piper_model "en_US-joe-medium" \
        "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/joe/medium" || {
        echo "❌ Failed to download English voice model"
        exit 1
    }
fi

echo "✅ Piper installed with voices in $PIPER_DIR"
echo "   To run: piper --help"

# Test Piper installation
if command -v piper >/dev/null 2>&1; then
    echo "✅ Piper TTS available in PATH"
else
    echo "❌ Error: Piper TTS not found in PATH"
    echo "   Installation may have failed"
    exit 1
fi

# Install Ollama
echo "🤖 Installing Ollama..."
if ! curl -fsSL https://ollama.com/install.sh | sh; then
    echo "❌ Failed to install Ollama"
    exit 1
fi

# Enable and start Ollama service
echo "⚙️  Enabling Ollama systemd service..."
if ! sudo systemctl enable ollama; then
    echo "⚠️  Warning: Failed to enable Ollama service"
fi

if ! sudo systemctl start ollama; then
    echo "⚠️  Warning: Failed to start Ollama service"
    echo "   You may need to start it manually with: sudo systemctl start ollama"
fi

# Wait for Ollama to be ready
echo "   Waiting for Ollama service to start..."
for i in {1..30}; do
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        echo "✅ Ollama service ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "⚠️  Warning: Ollama service not responding after 60 seconds"
        echo "   Check service status with: sudo systemctl status ollama"
        break
    fi
    sleep 2
done

# Final checks
echo "🔍 Performing final installation checks..."
echo "   - System memory: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2}')"
echo "   - Disk usage: $(df -h / | tail -1 | awk '{print $5 " used"}')"
echo "   - Piper voices: $(ls -1 $PIPER_DIR/*.onnx 2>/dev/null | wc -l) models"
echo "   - Piper wrapper: $([ -f /usr/local/bin/piper ] && echo "✅ Installed" || echo "❌ Missing")"
echo "   - Ollama status: $(systemctl is-active ollama 2>/dev/null || echo "❌ Not running")"
echo "   - Ollama API: $(curl -s http://localhost:11434/api/tags >/dev/null 2>&1 && echo "✅ Responding" || echo "❌ Not responding")"
echo "   - Audio system: $(pactl info >/dev/null 2>&1 && echo "✅ Connected" || echo "⚠️  Limited")"
echo "   - User groups: $(groups $(whoami) | grep -o audio || echo "❌ Not in audio group")"

echo ""
echo "🎉 ocearo-core environment ready!"
echo "   Ollama API: http://localhost:11434"
echo "   Piper TTS: piper --help"
echo ""
echo "📝 Next steps:"
echo "   1. Log out and log back in for audio group changes to take effect"
echo "   2. Test audio with: speaker-test -c 2 -t wav"
echo "   3. Pull Ollama models: ollama pull llama3.2:3b"
echo "   4. Start SignalK server when ready"
