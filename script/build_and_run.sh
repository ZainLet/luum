#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="luum"
APP_DISPLAY_NAME="Luum"
BUNDLE_ID="com.luum.apple"
APP_VERSION="0.0.4"
APP_BUILD="1"
APP_CATEGORY="public.app-category.productivity"
MIN_SYSTEM_VERSION="26.0"
PKG_ID="${BUNDLE_ID}.installer"
CODESIGN_IDENTITY="${APPLE_CODESIGN_IDENTITY:--}"
RELEASE_CHANNEL="${LUUM_RELEASE_CHANNEL:-alpha}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/src/LUUM.Mac"
DIST_DIR="$ROOT_DIR/dist"
SWIFT_BUILD_DIR="${SWIFT_BUILD_DIR:-$DIST_DIR/swift-build}"
ICON_SOURCE="$ROOT_DIR/src/LUUM.Client/wwwroot/favicon.png"
APP_BUNDLE="$DIST_DIR/build/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build --package-path "$PACKAGE_DIR" --build-path "$SWIFT_BUILD_DIR"
BUILD_BINARY="$(swift build --package-path "$PACKAGE_DIR" --build-path "$SWIFT_BUILD_DIR" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
mkdir -p "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

create_placeholder_icon() {
  if [[ ! -f "$ICON_SOURCE" ]] || ! command -v iconutil >/dev/null 2>&1; then
    return
  fi

  local iconset_dir="$DIST_DIR/AppIcon.iconset"
  rm -rf "$iconset_dir"
  mkdir -p "$iconset_dir"

  sips -z 16 16 "$ICON_SOURCE" --out "$iconset_dir/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE" --out "$iconset_dir/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE" --out "$iconset_dir/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_SOURCE" --out "$iconset_dir/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_SOURCE" --out "$iconset_dir/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE" --out "$iconset_dir/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE" --out "$iconset_dir/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE" --out "$iconset_dir/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE" --out "$iconset_dir/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_SOURCE" --out "$iconset_dir/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$iconset_dir" -o "$APP_RESOURCES/AppIcon.icns"
  rm -rf "$iconset_dir"
}

create_placeholder_icon

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>LuumReleaseChannel</key>
  <string>$RELEASE_CHANNEL</string>
  <key>LSApplicationCategoryType</key>
  <string>$APP_CATEGORY</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>O luum precisa conversar com navegadores suportados para ler a URL da aba ativa e classificar melhor o seu tempo entre trabalho e entretenimento.</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>$BUNDLE_ID.auth</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>luum</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

codesign --force --deep --sign "$CODESIGN_IDENTITY" --timestamp=none "$APP_BUNDLE"
xattr -cr "$APP_BUNDLE" >/dev/null 2>&1 || true

verify_bundle() {
  plutil -lint "$INFO_PLIST" >/dev/null

  local registered_scheme
  registered_scheme="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes:0:CFBundleURLSchemes:0' "$INFO_PLIST")"
  if [[ "$registered_scheme" != "luum" ]]; then
    echo "Info.plist não registra o callback luum://auth." >&2
    exit 1
  fi

  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" >/dev/null
  test -x "$APP_BINARY"
}

package_app() {
  verify_bundle

  local release_dir="$DIST_DIR/releases"
  local git_sha="unknown"
  local timestamp
  timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
  if command -v git >/dev/null 2>&1; then
    git_sha="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  fi

  mkdir -p "$release_dir"
  local archive_name="Luum-${APP_VERSION}-${RELEASE_CHANNEL}-${git_sha}-${timestamp}.zip"
  local archive_path="$release_dir/$archive_name"
  local pkg_name="Luum-${APP_VERSION}-${RELEASE_CHANNEL}-${git_sha}-${timestamp}.pkg"
  local pkg_path="$release_dir/$pkg_name"
  local pkg_stage
  rm -f "$archive_path" "$archive_path.sha256" "$archive_path.txt" "$pkg_path" "$pkg_path.sha256" "$pkg_path.txt"

  COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --norsrc --noextattr --noacl --noqtn --keepParent "$APP_BUNDLE" "$archive_path"
  if ! /usr/bin/zipinfo -1 "$archive_path" | grep -Eqx "(\./)?luum.app/Contents/Info.plist"; then
    echo "Pacote invalido: o zip precisa conter luum.app/Contents/Info.plist." >&2
    exit 1
  fi
  shasum -a 256 "$archive_path" >"$archive_path.sha256"

  pkg_stage="$(mktemp -d "$DIST_DIR/pkg-stage.XXXXXX")"
  COPYFILE_DISABLE=1 /usr/bin/ditto --norsrc --noextattr --noacl --noqtn "$APP_BUNDLE" "$pkg_stage/$APP_NAME.app"
  /usr/bin/xattr -cr "$pkg_stage" >/dev/null 2>&1 || true
  find "$pkg_stage" -name '._*' -delete
  COPYFILE_DISABLE=1 /usr/bin/pkgbuild \
    --identifier "$PKG_ID" \
    --version "${APP_VERSION}.${APP_BUILD}" \
    --install-location "/Applications" \
    --root "$pkg_stage" \
    "$pkg_path"
  rm -rf "$pkg_stage"
  if ! /usr/sbin/pkgutil --payload-files "$pkg_path" | grep -Eqx "(\./)?luum.app/Contents/Info.plist"; then
    echo "Instalador invalido: o pkg precisa instalar luum.app/Contents/Info.plist." >&2
    exit 1
  fi
  shasum -a 256 "$pkg_path" >"$pkg_path.sha256"

  cat >"$archive_path.txt" <<NOTES
Luum ${APP_VERSION} (${APP_BUILD}) ${RELEASE_CHANNEL}
Git: ${git_sha}
Generated: ${timestamp}
Bundle ID: ${BUNDLE_ID}
Minimum macOS: ${MIN_SYSTEM_VERSION}
Signature: ${CODESIGN_IDENTITY}

Alpha de teste para instalação manual em outros Macs.
Este zip contem o app bundle completo: luum.app.
Instalação:
1. Abra o zip.
2. Arraste luum.app para Aplicativos.
3. No primeiro launch, use Control-click > Abrir se o Gatekeeper bloquear.

Se um Mac de teste interno continuar bloqueando por quarentena:
  xattr -dr com.apple.quarantine /Applications/luum.app

Se aparecer prompt das Chaves do macOS por build antigo:
  security delete-generic-password -s com.zainlet.luum -a login 2>/dev/null || true

Validação esperada:
  codesign --verify --deep --strict --verbose=2 /Applications/luum.app

Sem Apple Developer ID, spctl/Gatekeeper pode rejeitar por falta de notarização.
Guia completo: docs/MACOS_ALPHA_INSTALL.md
NOTES

  cat >"$pkg_path.txt" <<NOTES
Luum ${APP_VERSION} (${APP_BUILD}) ${RELEASE_CHANNEL}
Git: ${git_sha}
Generated: ${timestamp}
Bundle ID: ${BUNDLE_ID}
Package ID: ${PKG_ID}
Minimum macOS: ${MIN_SYSTEM_VERSION}
Signature: unsigned pkg, ad-hoc app

Instalador simples para teste da alpha.
Uso:
1. Baixe o arquivo .pkg.
2. Abra com duplo clique.
3. Siga o instalador para colocar luum.app em /Applications.
4. No primeiro launch, use Control-click > Abrir se o Gatekeeper bloquear.

Se aparecer prompt das Chaves do macOS por build antigo:
  security delete-generic-password -s com.zainlet.luum -a login 2>/dev/null || true

Sem Apple Developer ID, o instalador ainda nao e notarizado.
Guia completo: docs/MACOS_ALPHA_INSTALL.md
NOTES

  echo "$pkg_path"
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --package|package)
    package_app
    ;;
  --verify-bundle|verify-bundle)
    verify_bundle
    ;;
  --verify|verify)
    verify_bundle
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--package|--verify-bundle|--verify]" >&2
    exit 2
    ;;
esac
