# AWCM – Autoware Container Manager

`awcm` (Autoware Container Manager) startet und verwaltet einen lokalen Autoware-Docker-Container.

## Installation

Das Repository klonen und das Skript einmal direkt ausführen:

```bash
git clone https://github.com/dpolz/awcm.git ~/awcm
~/awcm/awcm help
```

Beim ersten Aufruf legt das Skript den symbolischen Link `~/.local/bin/awcm` an. Die einzige Skriptdatei bleibt `~/awcm/awcm`; Änderungen aus dem Git-Repository sind deshalb sofort über den globalen Befehl verfügbar. `~/.local/bin` muss in `PATH` enthalten sein.

Danach kann der Manager ohne Pfadangabe verwendet werden:

```bash
awcm start
awcm sim
awcm shell
awcm stop
```

## Befehle

```text
start       Container im Hintergrund starten
shell       Interaktive Shell im Container öffnen
sim         Planning Simulator im aktuellen Terminal starten
rqt         rqt_graph im aktuellen Terminal starten
exec ...    Beliebigen Befehl im Container ausführen
status      Containerstatus anzeigen
stop        Container stoppen
help        Hilfe anzeigen
```

Ohne Befehl führt `awcm` den Befehl `start` aus.

## Konfiguration

Die Standardwerte können über Umgebungsvariablen überschrieben werden:

```text
AWCM_CONTAINER_NAME   Containername, Standard: autoware
AWCM_IMAGE            Autoware-Image
AWCM_DATA_DIR         Host-Verzeichnis für Karten, Modelle und Logs
AWCM_INSTALL_DIR      Verzeichnis für den symbolischen Link
```

Die bisherigen Variablen `AUTOWARE_CONTAINER_NAME`, `AUTOWARE_IMAGE` und `AUTOWARE_DATA_DIR` werden aus Kompatibilitätsgründen weiterhin unterstützt.
