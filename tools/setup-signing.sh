#!/bin/bash
# One-time setup: creates a personal code-signing certificate, "QuickNote Local Signing",
# in your login keychain. ./build.sh signs with it when present, so every build has the
# same identity and macOS keeps QuickNote's permissions (Input Monitoring, Microphone,
# Notes…) across rebuilds. Safe to run again; it does nothing if the certificate exists.
#
# macOS will ask for your Mac password once to trust the certificate for code signing.
set -euo pipefail

NAME="QuickNote Local Signing"
KEYCHAIN="${KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"

if security find-identity -v -p codesigning "$KEYCHAIN" | grep -q "\"$NAME\""; then
    echo "\"$NAME\" is already set up. Nothing to do."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<CNF
[req]
distinguished_name = dn
prompt = no
x509_extensions = ext
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF

# macOS's own openssl (LibreSSL) writes a .p12 that `security import` accepts.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cert.cnf" \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/id.p12" -passout pass:quicknote -name "$NAME"

# Let codesign use the key without asking each time.
security import "$TMP/id.p12" -k "$KEYCHAIN" -P quicknote -T /usr/bin/codesign >/dev/null

# Trust it for code signing (this is the step that asks for your password).
if [[ "${TRUST_AS_ADMIN:-}" == 1 ]]; then
    sudo security add-trusted-cert -d -r trustRoot -p codeSign -k /Library/Keychains/System.keychain "$TMP/cert.pem"
else
    security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem"
fi

security find-identity -v -p codesigning "$KEYCHAIN" | grep -q "\"$NAME\""
echo "Done. ./build.sh will now sign QuickNote as \"$NAME\"."
echo "Rebuild once, then grant QuickNote's permissions one last time; they'll stick from then on."
