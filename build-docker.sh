#!/bin/bash
set -e

# Colors for messages
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
IMAGE_NAME="ocearo/cirrus-rpi5"
IMAGE_TAG="latest"
DOCKERFILE="Dockerfile.rpi5"
COMPOSE_FILE="docker-compose.rpi5.yml"
PLATFORM="linux/arm64"

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    if [ ! -f "$DOCKERFILE" ]; then
        error "Dockerfile not found: $DOCKERFILE"
        exit 1
    fi
    
    # Check if buildx is available
    if ! docker buildx version &> /dev/null; then
        error "Docker buildx is not available. Please update Docker to a newer version."
        exit 1
    fi
    
    info "Prerequisites check passed"
}

# Setup buildx for cross-platform building
setup_buildx() {
    info "Setting up Docker buildx for cross-platform building..."
    
    # Create a new builder instance if it doesn't exist
    if ! docker buildx ls | grep -q "ocearo-builder"; then
        docker buildx create --name ocearo-builder --driver docker-container --bootstrap
    fi
    
    # Use the builder
    docker buildx use ocearo-builder
    
    # Install QEMU for ARM64 emulation if not available
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
    
    info "Buildx setup completed"
}

# Build Docker image
build_image() {
    info "Building Docker image: $IMAGE_NAME:$IMAGE_TAG for $PLATFORM"
    
    # Setup buildx
    setup_buildx
    
    # Build with buildx for ARM64
    docker buildx build \
        --platform "$PLATFORM" \
        -f "$DOCKERFILE" \
        -t "$IMAGE_NAME:$IMAGE_TAG" \
        --load \
        .
    
    info "Docker image built successfully"
}

# Build with docker-compose
build_compose() {
    info "Building with docker-compose..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$COMPOSE_FILE" build
    else
        docker compose -f "$COMPOSE_FILE" build
    fi
    
    info "Docker compose build completed"
}

# Run the container
run_container() {
    info "Starting container with docker-compose..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$COMPOSE_FILE" up -d
    else
        docker compose -f "$COMPOSE_FILE" up -d
    fi
    
    info "Container started successfully"
    info "You can access the services at:"
    info "  - OpenPlotter: http://localhost:3000"
    info "  - Signal K: http://localhost:3001"
    info "  - Ocearo UI: https://localhost/ocearo-ui"
}

# Stop the container
stop_container() {
    info "Stopping container..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$COMPOSE_FILE" down
    else
        docker compose -f "$COMPOSE_FILE" down
    fi
    
    info "Container stopped"
}

# Clean up images and containers
cleanup() {
    info "Cleaning up..."
    
    # Stop and remove containers
    stop_container || true
    
    # Remove image
    docker rmi "$IMAGE_NAME:$IMAGE_TAG" 2>/dev/null || true
    
    # Clean up build cache
    docker builder prune -f
    
    info "Cleanup completed"
}

# Show usage
usage() {
    echo "Build script for Ocearo Cirrus RPI5 Docker image"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  build       Build the Docker image only"
    echo "  compose     Build with docker-compose"
    echo "  run         Build and run the container"
    echo "  stop        Stop the running container"
    echo "  restart     Stop and restart the container"
    echo "  clean       Clean up images and containers"
    echo "  logs        Show container logs"
    echo "  shell       Open shell in running container"
    echo "  help        Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  START_KIOSK=true     Start in kiosk mode"
    echo "  CIRRUS_HOSTNAME      Set hostname (default: cirrus.local)"
    echo "  OCEARO_UI_URL        Set UI URL (default: https://cirrus.local/ocearo-ui)"
}

# Show logs
show_logs() {
    info "Showing container logs..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$COMPOSE_FILE" logs -f
    else
        docker compose -f "$COMPOSE_FILE" logs -f
    fi
}

# Open shell in container
open_shell() {
    info "Opening shell in container..."
    
    docker exec -it ocearo-cirrus-rpi5 /bin/bash
}

# Main function
main() {
    cd "$(dirname "$0")"
    
    case "${1:-build}" in
        build)
            check_prerequisites
            build_image
            ;;
        compose)
            check_prerequisites
            setup_buildx
            build_compose
            ;;
        run)
            check_prerequisites
            setup_buildx
            build_compose
            run_container
            ;;
        stop)
            stop_container
            ;;
        restart)
            stop_container
            sleep 2
            run_container
            ;;
        clean)
            cleanup
            ;;
        logs)
            show_logs
            ;;
        shell)
            open_shell
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            error "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
