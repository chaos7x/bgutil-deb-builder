# BgUtils POT Provider auf FreeBSD

Das .deb gibt es nur für Debian/Devuan. Auf FreeBSD wird der Server aus dem
Upstream-Quelltext gebaut und mit dem rc.d-Skript aus diesem Ordner als
Dienst gestartet. Das npm-Paket `canvas` hat für FreeBSD keine fertigen
Binärdateien und wird beim Installieren kompiliert, deshalb die
Build-Abhängigkeiten.

## Installation

```sh
# Node.js, npm und Build-Abhängigkeiten für canvas
pkg install node22 npm-node22 git zip gmake pkgconf python3 \
  cairo pango jpeg-turbo giflib librsvg2

# Dienstbenutzer
pw useradd bgutil -d /nonexistent -s /usr/sbin/nologin -c "BgUtils POT Provider"

# Quelltext holen und bauen (Version anpassen)
VERSION=2.0.1
git clone --depth 1 --branch "$VERSION" \
  https://github.com/Brainicism/bgutil-ytdlp-pot-provider.git /tmp/bgutil
cd /tmp/bgutil/server
npm ci
npx tsc

# Nach /usr/local/lib installieren
mkdir -p /usr/local/lib/bgutil-ytdlp-pot-provider
cp -R build node_modules package.json /usr/local/lib/bgutil-ytdlp-pot-provider/
chown -R bgutil:bgutil /usr/local/lib/bgutil-ytdlp-pot-provider

# yt-dlp-Plugin (yt-dlp sucht auch auf FreeBSD in /etc/yt-dlp/plugins)
mkdir -p /etc/yt-dlp/plugins
cd /tmp/bgutil/plugin && zip -9 -r /etc/yt-dlp/plugins/bgutil-ytdlp-pot-provider.zip yt_dlp_plugins

# rc.d-Skript installieren, aktivieren und starten
fetch -o /usr/local/etc/rc.d/bgutil_ytdlp_pot_provider \
  https://raw.githubusercontent.com/chaos7x/bgutil-deb-builder/main/init/freebsd/bgutil_ytdlp_pot_provider
chmod 555 /usr/local/etc/rc.d/bgutil_ytdlp_pot_provider
sysrc bgutil_ytdlp_pot_provider_enable=YES
service bgutil_ytdlp_pot_provider start
```

## Prüfen

```sh
service bgutil_ytdlp_pot_provider status
fetch -qo - http://127.0.0.1:4416/ping
```

Logs landen in `/var/log/bgutil-ytdlp-pot-provider.log`.

## Einstellungen in /etc/rc.conf

| Variable | Standard |
| --- | --- |
| `bgutil_ytdlp_pot_provider_user` | `bgutil` |
| `bgutil_ytdlp_pot_provider_dir` | `/usr/local/lib/bgutil-ytdlp-pot-provider` |
| `bgutil_ytdlp_pot_provider_token_ttl` | `6` |
| `bgutil_ytdlp_pot_provider_logfile` | `/var/log/bgutil-ytdlp-pot-provider.log` |
