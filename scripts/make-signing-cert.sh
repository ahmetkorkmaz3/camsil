#!/bin/sh
# Creates the self-signed code signing certificate once. A stable signature keeps the Screen Recording permission.
# Usage: scripts/make-signing-cert.sh [output-folder]
# The certificate goes into the login keychain. CAMSIL_KEYCHAIN names another keychain (tests only).
set -eu

NAME="Camsil Self-Signed"
OUT="${1:-$HOME/Camsil-signing}"
KEYCHAIN="${CAMSIL_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
OPENSSL=/usr/bin/openssl

fail() { printf 'Hata: %s\n' "$1" >&2; exit 1; }

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    fail "\"$NAME\" sertifikası $KEYCHAIN içinde zaten var. Betik bu sertifikanın üzerine yazmaz. Var olan sertifikayı kullanın."
fi
[ -e "$OUT" ] && fail "$OUT zaten var. Başka bir klasör verin: scripts/make-signing-cert.sh <klasör>"

mkdir -m 700 "$OUT"
PASSWORD="$("$OPENSSL" rand -base64 24)"

cat > "$OUT/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

"$OPENSSL" req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$OUT/cert.cnf" \
    -keyout "$OUT/key.pem" -out "$OUT/cert.pem" 2>/dev/null
# 3DES and SHA-1: the macOS security tool cannot import the newer PKCS#12 formats.
"$OPENSSL" pkcs12 -export -inkey "$OUT/key.pem" -in "$OUT/cert.pem" -name "$NAME" \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
    -passout "pass:$PASSWORD" -out "$OUT/Camsil-signing.p12"
rm "$OUT/key.pem" "$OUT/cert.cnf"

security import "$OUT/Camsil-signing.p12" -k "$KEYCHAIN" -P "$PASSWORD" -T /usr/bin/codesign >/dev/null
base64 -i "$OUT/Camsil-signing.p12" > "$OUT/p12.base64"
printf '%s\n' "$PASSWORD" > "$OUT/password.txt"
chmod 600 "$OUT"/*

cat <<EOF
Sertifika oluşturuldu: $NAME
Dosyalar: $OUT

1. GitHub → repo → Settings → Secrets and variables → Actions sayfasını açın.
2. SIGNING_CERT_P12_BASE64 adında bir secret ekleyin. Değer: pbcopy < "$OUT/p12.base64"
3. SIGNING_CERT_PASSWORD adında bir secret ekleyin. Değer: pbcopy < "$OUT/password.txt"
4. Camsil-signing.p12 dosyasını ve şifreyi parola yöneticinize kaydedin.
5. Sonra $OUT klasörünü silin: rm -rf "$OUT"

Yerel derleme: scripts/bundle.sh (bundle.sh finds the certificate by its name)
EOF
