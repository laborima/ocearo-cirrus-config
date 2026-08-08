# Ocearo Cirrus RPI5 Docker Image

This Docker image provides a complete RPI5 environment with OpenPlotter V4 and Ocearo Cirrus configuration for marine navigation and kiosk applications.

## Features

- **OpenPlotter V4** - Complete marine navigation platform
- **Ocearo Cirrus Configuration** - Dual-screen kiosk with touch support
- **PS5 Controller Support** - Bluetooth autopilot control
- **SSL Certificate Management** - Automatic certificate generation
- **Signal K Integration** - Marine data server
- **ARM64 Architecture** - Optimized for Raspberry Pi 5

## Quick Start

### Prerequisites

- Docker with BuildKit support
- Docker Compose
- ARM64 platform support (for cross-compilation)

### Build and Run

```bash
# Make build script executable
chmod +x build-docker.sh

# Build and run the container
./build-docker.sh run

# Or build only
./build-docker.sh build
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `START_KIOSK` | `false` | Start in kiosk mode |
| `CIRRUS_HOSTNAME` | `cirrus.local` | Hostname for certificates |
| `OCEARO_UI_URL` | `https://cirrus.local/ocearo-ui` | UI application URL |
| `DISPLAY` | `:0` | X11 display for GUI applications |

## Usage Examples

### Standard Mode
```bash
# Start with OpenPlotter interface
./build-docker.sh run
```

### Kiosk Mode
```bash
# Start in kiosk mode for production
START_KIOSK=true ./build-docker.sh run
```

### Development Mode
```bash
# Start with shell access
docker run -it --rm ocearo/cirrus-rpi5:latest bash
```

## Services and Ports

| Service | Port | Description |
|---------|------|-------------|
| OpenPlotter | 3000 | Main navigation interface |
| Signal K | 3001 | Marine data server |
| HTTP | 80 | Web server |
| HTTPS | 443 | Secure web server |
| Ocearo UI | 4200 | Application interface |

## Hardware Support

### Devices
- `/dev/dri` - GPU acceleration
- `/dev/input` - Touch screens and controllers
- `/dev/ttyUSB*` - USB serial devices
- `/dev/ttyACM*` - ACM serial devices

### Bluetooth
- PS5 controller auto-pairing
- Marine device connectivity
- Automatic device configuration

### Display
- Dual-screen support (DSI + HDMI)
- Touch screen mapping
- Automatic screen configuration

## Volume Mounts

| Volume | Purpose |
|--------|---------|
| `cirrus-certs` | SSL certificates |
| `signalk-data` | Signal K configuration |
| `openplotter-data` | OpenPlotter settings |

## Management Commands

```bash
# View logs
./build-docker.sh logs

# Open shell in running container
./build-docker.sh shell

# Stop services
./build-docker.sh stop

# Restart services
./build-docker.sh restart

# Clean up
./build-docker.sh clean
```

## Configuration

### SSL Certificates
Certificates are automatically generated on first run:
- Root CA: `/etc/cirrus/certs/rootCA.pem`
- Domain cert: `/etc/cirrus/certs/cirrus.local.pem`
- Signal K certs: `/home/pi/.signalk/ssl/`

### PS5 Controller
1. Put controller in pairing mode (PS + Share for 5 seconds)
2. Controller will auto-connect via Bluetooth
3. Test with: `docker exec ocearo-cirrus-rpi5 test-ps5-controller.sh`

### Application URLs
Edit URLs in the container or via environment variables:
```bash
OCEARO_UI_URL="https://your-domain.com/app" ./build-docker.sh run
```

## Troubleshooting

### Container Won't Start
```bash
# Check Docker daemon
sudo systemctl status docker

# Check image build
docker images | grep ocearo/cirrus-rpi5

# View build logs
./build-docker.sh build
```

### Display Issues
```bash
# Check X11 forwarding
echo $DISPLAY
xhost +local:docker

# Verify GPU access
docker exec ocearo-cirrus-rpi5 ls -la /dev/dri
```

### Bluetooth Problems
```bash
# Check Bluetooth in container
docker exec ocearo-cirrus-rpi5 bluetoothctl devices

# Restart Bluetooth service
docker exec ocearo-cirrus-rpi5 sudo systemctl restart bluetooth
```

### Network Connectivity
```bash
# Check port bindings
docker port ocearo-cirrus-rpi5

# Test services
curl http://localhost:3000
curl http://localhost:3001
```

## Development

### Building from Source
```bash
# Clone the repository
git clone <repository-url>
cd ocearo-cirrus-config

# Build Docker image (cirrusconfig package is automatically installed from repository)
./build-docker.sh build
```

### Package Installation
The `cirrusconfig` Debian package is automatically installed from the GitHub repository:
- Repository: `https://laborima.github.io/ocearo-cirrus-config/`
- Package: `cirrusconfig`
- No local build required - package is fetched during Docker build

### Customization
1. Modify `Dockerfile.rpi5` for system changes
2. Update `docker/entrypoint.sh` for startup behavior
3. Edit `docker-compose.rpi5.yml` for service configuration

### Adding Services
Add new services to `docker-compose.rpi5.yml`:
```yaml
services:
  your-service:
    image: your-image:latest
    depends_on:
      - ocearo-cirrus-rpi5
```

## Security Considerations

- Container runs in privileged mode for hardware access
- SSL certificates are auto-generated
- Bluetooth requires host network access
- Device access is limited to necessary hardware

## Support

For issues and support:
1. Check container logs: `./build-docker.sh logs`
2. Verify hardware compatibility
3. Review configuration files
4. Test on actual RPI5 hardware

## License

Apache 2.0 - See main project LICENSE for details.
