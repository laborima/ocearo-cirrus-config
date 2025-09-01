#!/bin/bash
set -e

# Colors for messages
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }


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
            clean
            build_package
            ;;
    esac
}

main "$@"
