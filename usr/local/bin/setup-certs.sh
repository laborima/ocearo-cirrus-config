#!/bin/bash
set -e

CERTS_DIR="/etc/cirrus/certs"
ROOT_KEY="$CERTS_DIR/rootCA.key"
ROOT_CERT="$CERTS_DIR/rootCA.pem"
DOMAIN_KEY="$CERTS_DIR/cirrus.local.key"
DOMAIN_CSR="$CERTS_DIR/cirrus.local.csr"
DOMAIN_CERT="$CERTS_DIR/cirrus.local.crt"
DOMAIN_PEM="$CERTS_DIR/cirrus.local.pem"
OPENSSL_CONFIG="$CERTS_DIR/cirrus_openssl.cnf"

mkdir -p "$CERTS_DIR"

# If certs already exist, skip generation but still install the root CA
if [[ -f "$DOMAIN_PEM" && -f "$ROOT_CERT" ]]; then
  echo "✅ Certificates already exist, skipping generation."
else
  echo "🔐 Creating Root CA key..."
  openssl genrsa -out "$ROOT_KEY" 2048

  echo "📄 Creating Root CA certificate..."
  openssl req -x509 -new -nodes -key "$ROOT_KEY" -sha256 -days 3650 -out "$ROOT_CERT" \
    -subj "/C=FR/ST=NA/L=LaRochelle/O=cirrus/CN=cirrus.local Root CA"

  echo "🔑 Creating domain private key..."
  openssl genrsa -out "$DOMAIN_KEY" 2048

  cat > "$OPENSSL_CONFIG" <<EOF
[req]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = req_ext
x509_extensions    = v3_req
prompt             = no

[req_distinguished_name]
C  = FR
ST = NA
L  = LaRochelle
O  = cirrus
CN = cirrus.local

[req_ext]
subjectAltName = @alt_names

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = cirrus.local
DNS.2 = *.cirrus.local
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

  echo "📄 Creating CSR..."
  openssl req -new -key "$DOMAIN_KEY" -out "$DOMAIN_CSR" -config "$OPENSSL_CONFIG"

  echo "🔏 Signing certificate with Root CA..."
  openssl x509 -req -in "$DOMAIN_CSR" -CA "$ROOT_CERT" -CAkey "$ROOT_KEY" -CAcreateserial \
    -out "$DOMAIN_CERT" -days 825 -sha256 -extfile "$OPENSSL_CONFIG" -extensions req_ext

  cat "$DOMAIN_KEY" "$DOMAIN_CERT" > "$DOMAIN_PEM"
  
  echo "✅ Certificates generated in: $CERTS_DIR"
fi

# Install Root CA in system trust store
echo "🔒 Installing Root CA in system trust store..."
mkdir -p /usr/local/share/ca-certificates/cirrus
cp "$ROOT_CERT" /usr/local/share/ca-certificates/cirrus/cirrus-rootCA.crt
chmod 644 /usr/local/share/ca-certificates/cirrus/cirrus-rootCA.crt
update-ca-certificates

# Install Root CA in Chromium NSS database for all users
echo "🌐 Installing Root CA in Chromium trust store for all users..."
for user_home in /home/*; do
  if [ -d "$user_home" ]; then
    username=$(basename "$user_home")
    nssdb="$user_home/.pki/nssdb"
    
    # Create NSS database if it doesn't exist
    if [ ! -d "$nssdb" ]; then
      mkdir -p "$nssdb"
      chown -R "$username:$username" "$user_home/.pki"
      sudo -u "$username" certutil -d "sql:$nssdb" --empty-password -N
    fi
    
    # Add the CA certificate
    if [ -d "$nssdb" ]; then
      sudo -u "$username" certutil -d "sql:$nssdb" -A -t "C,," -n "Cirrus Root CA" -i "$ROOT_CERT" || true
      echo "  ✓ Added to $username's Chromium trust store"
    fi
  fi
done

# Also add to root's NSSDB (for cron jobs, etc.)
root_nssdb="/root/.pki/nssdb"
if [ ! -d "$root_nssdb" ]; then
  mkdir -p "$root_nssdb"
  certutil -d "sql:$root_nssdb" --empty-password -N
fi
certutil -d "sql:$root_nssdb" -A -t "C,," -n "Cirrus Root CA" -i "$ROOT_CERT" || true

# Copy certificates to Signal K directory
SIGNALK_SSL_DIR="/home/pi/.signalk/ssl"
mkdir -p "$SIGNALK_SSL_DIR"
chmod 755 "/home/pi/.signalk"
chmod 700 "$SIGNALK_SSL_DIR"

# Copy domain certificate and key
cp "$DOMAIN_PEM" "$SIGNALK_SSL_DIR/key-cert.pem"
# Copy root CA
cp "$ROOT_CERT" "$SIGNALK_SSL_DIR/ca.pem"

# Set proper permissions
chown -R pi:pi "$SIGNALK_SSL_DIR"
chmod 600 "$SIGNALK_SSL_DIR/"*

echo "✅ Certificate setup complete!"
echo "   - Certificates copied to $SIGNALK_SSL_DIR"
echo "   - You may need to restart Signal K for changes to take effect"
