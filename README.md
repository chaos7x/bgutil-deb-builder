# bgutil-deb-builder

Baut aus [Brainicism/bgutil-ytdlp-pot-provider](https://github.com/Brainicism/bgutil-ytdlp-pot-provider)
fertige Pakete für Debian/Devuan (`.deb`) und FreeBSD (`.pkg`). Jedes Paket
enthält den POT-Server, einen Systemdienst und das passende yt-dlp-Plugin aus
demselben Upstream-Release, sodass Server und Plugin immer zusammenpassen.

Die Pakete liegen unter [Releases](https://github.com/chaos7x/bgutil-deb-builder/releases).
Neue Upstream-Versionen werden automatisch gebaut.

## Was installiert wird

| | Debian / Devuan (`.deb`) | FreeBSD (`.pkg`) |
| --- | --- | --- |
| Server | `/usr/lib/bgutil-ytdlp-pot-provider` | `/usr/local/lib/bgutil-ytdlp-pot-provider` |
| Dienst (systemd) | `/lib/systemd/system/bgutil-ytdlp-pot-provider.service` | – |
| Dienst (sysvinit / rc.d) | `/etc/init.d/bgutil-ytdlp-pot-provider` | `/usr/local/etc/rc.d/bgutil_ytdlp_pot_provider` |
| yt-dlp-Plugin | `/etc/yt-dlp/plugins/bgutil-ytdlp-pot-provider.zip` | `/etc/yt-dlp/plugins/bgutil-ytdlp-pot-provider.zip` |
| Dienstbenutzer | `bgutil` | `bgutil` |
| Node.js | `nodejs (>= 22.13)` | `node22` oder neuer |

Der Server lauscht auf `http://127.0.0.1:4416`, der Standardadresse des
Plugins. yt-dlp braucht deshalb keine zusätzliche Konfiguration.

## Installation

### Debian / Devuan

Benötigt `nodejs` ab 22.13. Debian 13 (trixie) liefert nur Node.js 20, deshalb
vorher Node.js 22 aus dem Repo von
[NodeSource](https://github.com/nodesource/distributions) einrichten:

```sh
curl -fsSL https://deb.nodesource.com/setup_22.x -o nodesource_setup.sh
sudo bash nodesource_setup.sh
sudo apt install nodejs
node --version
```

Danach das Paket installieren:

```sh
wget https://github.com/chaos7x/bgutil-deb-builder/releases/download/2.0.1/bgutil-ytdlp-pot-provider_2.0.1_amd64.deb
sudo apt install ./bgutil-ytdlp-pot-provider_2.0.1_amd64.deb
```

Mit systemd wird der Dienst installiert, aber nicht automatisch aktiviert:

```sh
sudo systemctl enable --now bgutil-ytdlp-pot-provider
systemctl status bgutil-ytdlp-pot-provider
journalctl -u bgutil-ytdlp-pot-provider
```

Einstellungen wie `TOKEN_TTL` lassen sich per Drop-in ändern, ohne die
Unit selbst anzufassen:

```sh
sudo systemctl edit bgutil-ytdlp-pot-provider
```

```ini
[Service]
Environment=TOKEN_TTL=12
```

Ohne systemd (z. B. Devuan) wird der Dienst bei der Installation automatisch
registriert und gestartet:

```sh
sudo service bgutil-ytdlp-pot-provider status
tail /var/log/bgutil-ytdlp-pot-provider.log
```

Einstellungen für das init.d-Skript (z. B. `TOKEN_TTL`) lassen sich in
`/etc/default/bgutil-ytdlp-pot-provider` überschreiben.

### FreeBSD

```sh
pkg install node22
fetch https://github.com/chaos7x/bgutil-deb-builder/releases/download/2.0.1/bgutil-ytdlp-pot-provider-2.0.1.pkg
pkg add ./bgutil-ytdlp-pot-provider-2.0.1.pkg
sysrc bgutil_ytdlp_pot_provider_enable=YES
service bgutil_ytdlp_pot_provider start
```

Weitere Einstellungen und die manuelle Installation aus dem Quelltext stehen
in [init/freebsd/README.md](init/freebsd/README.md).

## Prüfen

```sh
curl http://127.0.0.1:4416/ping
yt-dlp -v --simulate "https://www.youtube.com/watch?v=dQw4w9WgXcQ" 2>&1 | grep -i pot
```

In der Ausgabe von yt-dlp sollte `bgutil:http` als PO-Token-Provider
auftauchen. Läuft der Server auf einer anderen Adresse, braucht yt-dlp:

```sh
--extractor-args "youtubepot-bgutilhttp:base_url=http://HOST:PORT"
```

## Wie die Pakete entstehen

- [`watch-upstream.yml`](.github/workflows/watch-upstream.yml) prüft stündlich
  den Release-Feed von upstream. Bei einer neuen Version merkt er sie sich in
  `.github/last-upstream-version` und stößt den Build an.
- [`build-deb.yml`](.github/workflows/build-deb.yml) klont den Upstream-Tag,
  baut den Server mit Node.js 22, packt das `.deb` mit
  [fpm](https://github.com/jordansissel/fpm) und baut in einer FreeBSD-VM das
  `.pkg` ([`freebsd/build-pkg.sh`](freebsd/build-pkg.sh)). Das FreeBSD-Paket
  wird vor dem Hochladen installiert und mit `/ping` getestet. Beide Pakete
  landen als Release mit der Upstream-Version als Tag.

Einen Build für eine bestimmte Version startet man unter *Actions → Build
bgutil-ytdlp-pot-provider .deb → Run workflow* mit dem gewünschten
Upstream-Tag; leer gelassen wird das neueste Release gebaut.

## Repo-Aufbau

```
.github/workflows/   Watcher und Build-Workflow
init/systemd/        systemd-Unit
init/sysvinit/       init.d-Skript für Systeme ohne systemd
init/freebsd/        rc.d-Skript und FreeBSD-Anleitung
debian/copyright     Lizenzangaben, die das .deb mitliefert
freebsd/             Build-Skript für das FreeBSD-pkg
```

## Lizenz

Die Pakete enthalten Software aus
[bgutil-ytdlp-pot-provider](https://github.com/Brainicism/bgutil-ytdlp-pot-provider),
die unter GPL-3.0 steht.

Dieses Repo selbst steht ebenfalls unter GPL-3.0 (siehe [LICENSE](LICENSE)),
wie upstream. Das .deb liefert die Lizenzangaben unter
`/usr/share/doc/bgutil-ytdlp-pot-provider/copyright` mit, das FreeBSD-pkg
den Lizenztext unter `/usr/local/share/doc/bgutil-ytdlp-pot-provider/LICENSE`.
