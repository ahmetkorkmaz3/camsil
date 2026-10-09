#!/bin/sh
# Installs or updates Camsil from GitHub Releases.
#   curl -fsSL https://raw.githubusercontent.com/ahmetkorkmaz3/Camsil/main/install.sh | sh
# CAMSIL_VERSION=1.0.0 installs that version.
# CAMSIL_DOWNLOAD_BASE and CAMSIL_INSTALL_DIR are for tests only.
# All code is in main(), so a download that stops partway runs nothing.
set -eu

main() {
    REPO="ahmetkorkmaz3/Camsil"
    APP_NAME="Camsil"
    BUNDLE_ID="com.ahmetkorkmaz.Camsil"
    DEST_DIR="${CAMSIL_INSTALL_DIR:-/Applications}"

    fail() { printf 'Hata: %s\n' "$1" >&2; exit 1; }

    [ "$(uname -s)" = "Darwin" ] || fail "Camsil yalnızca macOS üzerinde çalışır."
    [ "$(uname -m)" = "arm64" ] || fail "Camsil bir Apple Silicon Mac (M1 veya üstü) ister."
    MACOS="$(sw_vers -productVersion)"
    [ "${MACOS%%.*}" -ge 14 ] || fail "Camsil macOS 14 veya üstünü ister. Bu Mac: macOS $MACOS."

    if [ -n "${CAMSIL_VERSION:-}" ]; then
        VERSION="${CAMSIL_VERSION#v}"
    else
        # The redirect of /releases/latest names the tag. It has no API rate limit.
        LATEST="https://github.com/$REPO/releases/latest"
        URL="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$LATEST")" \
            || fail "Son sürüm okunamadı: $LATEST. İnternet bağlantısını kontrol edin ve komutu yeniden çalıştırın."
        case "$URL" in
            */tag/v*) VERSION="${URL##*/tag/v}" ;;
            *) fail "Henüz bir sürüm yayınlanmadı: $LATEST" ;;
        esac
    fi
    case "$VERSION" in
        "" | *[!0-9.]*) fail "Geçersiz sürüm: \"$VERSION\". Örnek: CAMSIL_VERSION=1.0.0" ;;
    esac

    ZIP="$APP_NAME-$VERSION.zip"
    BASE="${CAMSIL_DOWNLOAD_BASE:-https://github.com/$REPO/releases/download/v$VERSION}"
    WORK="$(mktemp -d)"
    trap 'rm -rf "$WORK"' EXIT

    echo "Camsil $VERSION indiriliyor..."
    for FILE in "$ZIP" "$ZIP.sha256"; do
        curl -fsSL -o "$WORK/$FILE" "$BASE/$FILE" \
            || fail "İndirme başarısız: $BASE/$FILE. İnternet bağlantısını kontrol edin ve komutu yeniden çalıştırın."
    done
    (cd "$WORK" && shasum -a 256 -c "$ZIP.sha256" >/dev/null 2>&1) \
        || fail "SHA-256 kontrolü başarısız. Dosya bozuk veya değişmiş. Hiçbir dosya değişmedi. Komutu yeniden çalıştırın."

    ditto -x -k "$WORK/$ZIP" "$WORK/unpacked" || fail "Zip dosyası açılamadı: $ZIP."
    [ -d "$WORK/unpacked/$APP_NAME.app" ] || fail "Zip dosyasında $APP_NAME.app yok."

    if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
        echo "Çalışan Camsil kapatılıyor..."
        osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || true
        i=0
        while pgrep -x "$APP_NAME" >/dev/null 2>&1 && [ "$i" -lt 5 ]; do
            sleep 1
            i=$((i + 1))
        done
        pkill -x "$APP_NAME" 2>/dev/null || true
    fi

    TARGET="$DEST_DIR/$APP_NAME.app"
    STAGE="$DEST_DIR/.$APP_NAME.app.new"
    UPDATE=""
    [ -e "$TARGET" ] && UPDATE="yes"
    SUDO=""
    # A file of another user (for example root) in the old app also needs sudo, or the removal stops halfway.
    if [ ! -w "$DEST_DIR" ] || { [ -e "$TARGET" ] && [ -n "$(find "$TARGET" ! -user "$(id -u)" -print -quit 2>/dev/null)" ]; }; then
        echo "$DEST_DIR klasörüne yazma izni yok. Kurulum yönetici şifresi ister."
        SUDO="sudo"
    fi
    # Copy next to the old app first. The old app stays until the new copy is complete.
    $SUDO rm -rf "$STAGE"
    if ! $SUDO ditto "$WORK/unpacked/$APP_NAME.app" "$STAGE"; then
        $SUDO rm -rf "$STAGE"
        fail "Kopyalama başarısız: $STAGE. Eski uygulama değişmedi. Disk alanını kontrol edin ve komutu yeniden çalıştırın."
    fi
    # curl sets no quarantine flag. A copy from a browser download can still carry one.
    # Without notarization, a quarantined app does not open.
    $SUDO xattr -dr com.apple.quarantine "$STAGE" 2>/dev/null || true
    $SUDO rm -rf "$TARGET"
    $SUDO mv "$STAGE" "$TARGET"

    # An ad-hoc signature changes with each version. The old Screen Recording entry then
    # shows as on but does not work. Remove it, so macOS asks again.
    if [ -n "$UPDATE" ] && codesign -dv "$TARGET" 2>&1 | grep -q 'Signature=adhoc'; then
        tccutil reset ScreenCapture "$BUNDLE_ID" >/dev/null 2>&1 || true
    fi

    echo "Camsil $VERSION kuruldu: $TARGET"
    echo "1. Camsil uygulamasını açın: open \"$TARGET\""
    echo "2. İlk açılışta Ekran Kaydı iznini verin. Camsil kapanır."
    echo "3. Camsil uygulamasını yeniden açın. Esc tuşu her zaman çıkış yapar."
}

main "$@"
