#!/bin/bash
set -e

# Colors for messages
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Check build dependencies
check_dependencies() {
    local deps=("dpkg-buildpackage" "fakeroot" "debuild" "dh_make")

    # Detect distro
    . /etc/os-release
    DISTRO=$ID
    VERSION=$VERSION_ID
    info "Detected distro: $DISTRO $VERSION"

    # Install missing dependencies
    local missing=()
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        info "All build dependencies are installed."
        return
    fi

    warning "Missing packages: ${missing[*]}"

    if [[ "$DISTRO" == "ubuntu" ]]; then
        info "Configuring Ubuntu repositories..."
        sudo apt-get update
        sudo apt-get install -y software-properties-common
        sudo add-apt-repository -y universe
        sudo add-apt-repository -y multiverse
        sudo apt-get update
        sudo apt-get install -y "${missing[@]}" build-essential gnupg2
    elif [[ "$DISTRO" == "debian" ]]; then
        info "Installing missing packages on Debian..."
        sudo apt-get update
        sudo apt-get install -y "${missing[@]}" build-essential gnupg2
    else
        warning "Unsupported distro: $DISTRO. Please install dependencies manually: ${missing[*]}"
        exit 1
    fi
}

# Clean previous build files
clean() {
    info "Cleaning build files..."
    rm -f ../cirrusconfig_*.deb \
          ../cirrusconfig_*.build \
          ../cirrusconfig_*.changes \
          ../cirrusconfig_*.dsc \
          ../cirrusconfig_*.tar.gz \
          ../cirrusconfig_*.buildinfo
    
    rm -rf debian/.debhelper/
    rm -f debian/debhelper-build-stamp debian/files debian/*.substvars debian/*.debhelper.log
}

# Build the Debian package
build_package() {
    info "Starting package build..."
    chmod +x usr/local/bin/*.sh
    chmod +x debian/rules
    dpkg-buildpackage -us -uc -b
    info "Build finished. Package files:"
    ls -l ../cirrusconfig_*.*
}

# Main
main() {
    cd "$(dirname "$0")"
    case "$1" in
        -c|--clean) clean ;;
        -h|--help)
            echo "Build script for cirrusconfig Debian package"
            echo "Usage: $0 [option]"
            echo "Options:"
            echo "  -c, --clean    Clean build files"
            echo "  -h, --help     Show this help"
            ;;
        *)
            check_dependencies
            clean
            build_package
            ;;
    esac
}

main "$@"
