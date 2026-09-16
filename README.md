# AWCM – Autoware Container Manager

`awcm` (Autoware Container Manager) startet und verwaltet einen lokalen Autoware-Docker-Container.

## Installation

Das Repository klonen und das Skript einmal direkt ausführen:

```bash
git clone https://github.com/dpolz/awcm.git ~/awcm
~/awcm/awcm.bash help
```

Beim ersten Aufruf legt das Skript den symbolischen Link `~/.local/bin/awcm` an. Die einzige Skriptdatei bleibt `~/awcm/awcm.bash`; Änderungen aus dem Git-Repository sind deshalb sofort über den globalen Befehl verfügbar. `~/.local/bin` muss in `PATH` enthalten sein.

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
sim         Planning Simulator und Vehicle Interface starten
build-interface
            Vehicle Interface im Container kompilieren
rqt         rqt_graph im aktuellen Terminal starten
exec ...    Beliebigen Befehl im Container ausführen
status      Containerstatus anzeigen
stop        Container stoppen
help        Hilfe anzeigen
```

Ohne Befehl führt `awcm` den Befehl `start` aus.

## Vehicle Interface im Entwicklungsmodus

`awcm sim` erwartet das Repository unter `~/autoware_data/vehicle_interface`. Vor jedem Simulationsstart prüft AWCM die Protobuf-Buildabhängigkeiten im Container und kompiliert `thorsten_vehicle_interface` inkrementell. Anschließend wird das lokale ROS-Overlay geladen und der Planning Simulator zusammen mit dem Vehicle Interface gestartet.

```bash
awcm start
awcm sim
```

Das Vehicle Interface läuft in der Simulation im Shadow Mode. Es liest die regulären Autoware-Steuerbefehle, während seine Statusausgänge und sein Control-Mode-Service unter `/thorsten/...` isoliert werden. Damit konkurriert es nicht mit dem `simple_planning_simulator`.

Der Build kann auch unabhängig von der Simulation ausgeführt werden:

```bash
awcm build-interface
```

Da der Container mit `--rm` läuft, installiert AWCM die Protobuf-Buildabhängigkeiten nach einem vollständigen Container-Neustart bei Bedarf erneut. Die Build-Ausgaben bleiben im gemounteten Verzeichnis `~/autoware_data/vehicle_interface/autoware_ws` erhalten.

## Konfiguration

Die Standardwerte können über Umgebungsvariablen überschrieben werden:

```text
AWCM_CONTAINER_NAME   Containername, Standard: autoware
AWCM_CONTAINER_USER   Benutzer für Befehle im Container, Standard: aw
AWCM_IMAGE            Autoware-Image
AWCM_DATA_DIR         Host-Verzeichnis für Karten, Modelle und Logs
AWCM_INSTALL_DIR      Verzeichnis für den symbolischen Link
```

Die bisherigen Variablen `AUTOWARE_CONTAINER_NAME`, `AUTOWARE_IMAGE` und `AUTOWARE_DATA_DIR` werden aus Kompatibilitätsgründen weiterhin unterstützt.
