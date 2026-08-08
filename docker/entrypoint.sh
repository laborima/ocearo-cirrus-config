#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Initialize container
init_container() {
    info "Initializing Ocearo Cirrus RPI5 container..."
    
    # Ensure runtime directory exists
    mkdir -p /tmp/runtime-root
    chmod 700 /tmp/runtime-root
    
    # Set up display if not already set
    if [ -z "$DISPLAY" ]; then
        export DISPLAY=:0
    fi
    
    # Initialize certificates if needed
    if [ ! -f /etc/cirrus/certs/rootCA.pem ]; then
        info "Generating SSL certificates..."
        sudo /usr/local/bin/generate-certs.sh || warning "Certificate generation failed"
    fi
    
    # Set up PS5 controller if available
    if command -v setup-ps5.sh >/dev/null 2>&1; then
        info "Setting up PS5 controller support..."
        sudo setup-ps5.sh || warning "PS5 controller setup failed"
    fi
}

# Start services
start_services() {
    info "Starting Cirrus services..."
    
    # Start certificate service
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl start cirrus-certs || warning "Failed to start cirrus-certs service"
        sudo systemctl start ps5-controller || warning "Failed to start ps5-controller service"
    fi
    
    # Start kiosk mode if requested
    if [ "$START_KIOSK" = "true" ]; then
        info "Starting kiosk mode..."
        sudo systemctl start kiosk || warning "Failed to start kiosk service"
    fi
}

# Start Signal K server
start_signalk() {
    info "Starting Signal K server..."
    
    # Create Signal K configuration directory
    mkdir -p /home/pi/.signalk
    
    # Start Signal K server in background
    if command -v signalk-server >/dev/null 2>&1; then
        cd /home/pi/.signalk
        signalk-server &
        SIGNALK_PID=$!
        info "Signal K server started with PID $SIGNALK_PID"
    else
        warning "Signal K server not found"
    fi
}

# Start marine navigation services
start_marine_services() {
    info "Starting marine navigation services..."
    
    start_signalk
    
    # Start web interface
    if [ "$START_KIOSK" != "true" ]; then
        info "Marine services available at:"
        info "  - Signal K: http://localhost:3000"
        info "  - Admin UI: http://localhost:3001"
    fi
}

# Signal handlers
cleanup() {
    info "Shutting down services..."
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl stop kiosk || true
        sudo systemctl stop ps5-controller || true
        sudo systemctl stop cirrus-certs || true
    fi
    
    # Stop Signal K if running
    if [ ! -z "$SIGNALK_PID" ]; then
        kill $SIGNALK_PID || true
    fi
    
    exit 0
}

trap cleanup SIGTERM SIGINT

# Main execution
main() {
    case "$1" in
        "signalk"|"openplotter"|"")
            init_container
            start_services
            start_marine_services
            info "Marine navigation services started. Container will run indefinitely."
            while true; do sleep 30; done
            ;;
        "kiosk")
            init_container
            START_KIOSK=true start_services
            start_marine_services
            info "Kiosk mode started. Container will run indefinitely."
            while true; do sleep 30; done
            ;;
        "bash"|"shell")
            init_container
            exec /bin/bash
            ;;
        *)
            info "Running custom command: $*"
            init_container
            exec "$@"
            ;;
    esac
}

main "$@"
