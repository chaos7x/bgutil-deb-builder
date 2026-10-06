#!/bin/sh
# Baut in einer FreeBSD-Umgebung ein pkg des BgUtils POT Providers.
# Aufruf: build-pkg.sh <version> <upstream-quelltext> <builder-repo> <ausgabeordner>
set -eu

VERSION="$1"
SRC="$(realpath "$2")"
BUILDER="$(realpath "$3")"
OUT="$4"
mkdir -p "$OUT"
OUT="$(realpath "$OUT")"

PKG_NAME=bgutil-ytdlp-pot-provider
APP_DIR=/usr/local/lib/$PKG_NAME
PLUGIN_DIR=/etc/yt-dlp/plugins
RC_NAME=bgutil_ytdlp_pot_provider
WORK="$(mktemp -d)"
STAGE="$WORK/stage"

# libbz2 gehört auf FreeBSD zum Basissystem und hat keine bzip2.pc, die
# freetype2.pc aber verlangt; ohne sie scheitert der canvas-Build an
# "pkg-config cairo --libs".
if ! pkg-config --exists bzip2; then
  mkdir -p "$WORK/pkgconfig"
  cat > "$WORK/pkgconfig/bzip2.pc" <<PC
prefix=/usr
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: bzip2
Description: bzip2 aus dem FreeBSD-Basissystem
Version: 1.0.8
Libs: -L\${libdir} -lbz2
Cflags: -I\${includedir}
PC
  export PKG_CONFIG_PATH="$WORK/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
fi

# Server bauen; danach Entwicklungsabhängigkeiten (tsc, eslint, ...) entfernen.
cd "$SRC/server"
npm ci
npx tsc
npm prune --omit=dev

mkdir -p "$STAGE$APP_DIR" "$STAGE$PLUGIN_DIR" "$STAGE/usr/local/etc/rc.d"
cp -R build node_modules package.json "$STAGE$APP_DIR/"
install -m 555 "$BUILDER/init/freebsd/$RC_NAME" "$STAGE/usr/local/etc/rc.d/$RC_NAME"

# yt-dlp-Plugin wie upstream release.yml bündeln.
mkdir -p "$WORK/plugin"
cp -R "$SRC/plugin/yt_dlp_plugins" "$WORK/plugin/"
find "$WORK/plugin" -name '*.py[co]' -delete
find "$WORK/plugin" -type d -name __pycache__ -exec rm -rf {} +
(cd "$WORK/plugin" && zip -q -9 -r "$STAGE$PLUGIN_DIR/$PKG_NAME.zip" yt_dlp_plugins)

# Laufzeitabhängigkeiten aus den gelinkten Bibliotheken der nativen
# Node-Module (canvas) ermitteln.
DEPS=""
for lib in $(find "$STAGE$APP_DIR/node_modules" -name '*.node' -type f -exec ldd {} + 2>/dev/null \
    | awk '$2 == "=>" && $3 ~ /^\/usr\/local\// {print $3}' | sort -u); do
  pkg which -q "$lib" 2>/dev/null || true
done | sort -u > "$WORK/deps.txt"
while read -r pkgver; do
  [ -n "$pkgver" ] || continue
  name="${pkgver%-*}"
  origin="$(pkg query '%o' "$name")"
  version="$(pkg query '%v' "$name")"
  DEPS="$DEPS  \"$name\": { origin: \"$origin\", version: \"$version\" }
"
done < "$WORK/deps.txt"
echo "Ermittelte Abhängigkeiten:"
cat "$WORK/deps.txt"

ABI="$(pkg config abi)"
PKG_VERSION="$(echo "${VERSION#v}" | tr '-' '.')"

cat > "$WORK/+MANIFEST" <<MANIFEST
name: "$PKG_NAME"
version: "$PKG_VERSION"
origin: "www/$PKG_NAME"
comment: "Proof-of-origin token provider for yt-dlp"
desc: "HTTP server that generates YouTube proof-of-origin tokens for yt-dlp, with rc.d service and yt-dlp plugin."
maintainer: "chaos7x@users.noreply.github.com"
www: "https://github.com/Brainicism/bgutil-ytdlp-pot-provider"
abi: "$ABI"
arch: "$ABI"
prefix: "/usr/local"
licenselogic: "single"
licenses: [ "GPLv3+" ]
categories: [ "www" ]
deps: {
$DEPS}
scripts: {
  post-install: <<EOD
if ! pw usershow bgutil >/dev/null 2>&1; then
  pw useradd bgutil -d /nonexistent -s /usr/sbin/nologin -c "BgUtils POT Provider"
fi
chown -R bgutil:bgutil $APP_DIR
EOD
  pre-deinstall: <<EOD
service $RC_NAME onestop >/dev/null 2>&1 || true
EOD
}
messages: [
  { message: <<EOD
Node.js 22 oder neuer wird benötigt, z. B.:
  pkg install node22
Dienst aktivieren und starten:
  sysrc ${RC_NAME}_enable=YES
  service $RC_NAME start
EOD
  }
]
MANIFEST

(cd "$STAGE" && find . \( -type f -o -type l \) | sed 's#^\.##' | sort) > "$WORK/plist"
pkg create -M "$WORK/+MANIFEST" -r "$STAGE" -p "$WORK/plist" -o "$OUT"
ls -l "$OUT"
