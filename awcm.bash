#!/usr/bin/env bash
set -Eeuo pipefail

COMMAND_NAME="awcm"
INSTALL_DIR="${AWCM_INSTALL_DIR:-${HOME}/.local/bin}"
INSTALL_PATH="${INSTALL_DIR}/${COMMAND_NAME}"
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"

# Feste, bei Bedarf ueber Umgebungsvariablen ueberschreibbare Einstellungen.
CONTAINER_NAME="${AWCM_CONTAINER_NAME:-${AUTOWARE_CONTAINER_NAME:-autoware}}"
CONTAINER_USER="${AWCM_CONTAINER_USER:-aw}"
IMAGE="${AWCM_IMAGE:-${AUTOWARE_IMAGE:-ghcr.io/autowarefoundation/autoware:universe-cuda-jazzy-1.9.0}}"
DATA_DIR="${AWCM_DATA_DIR:-${AUTOWARE_DATA_DIR:-${HOME}/autoware_data}}"
VEHICLE_INTERFACE_DIR="${DATA_DIR}/vehicle_interface"
CONTAINER_VEHICLE_INTERFACE_DIR="/home/aw/autoware_data/vehicle_interface"
CONTAINER_VEHICLE_INTERFACE_SETUP="${CONTAINER_VEHICLE_INTERFACE_DIR}/autoware_ws/install/setup.bash"

install_self() {
  mkdir -p "${INSTALL_DIR}"

  if [[ -e "${INSTALL_PATH}" && ! -L "${INSTALL_PATH}" ]]; then
    echo "Installation nicht moeglich: '${INSTALL_PATH}' existiert und ist kein symbolischer Link." >&2
    exit 1
  fi

  local installed_target=""
  if [[ -L "${INSTALL_PATH}" ]]; then
    installed_target="$(readlink -f "${INSTALL_PATH}" 2>/dev/null || true)"
  fi

  if [[ "${installed_target}" != "${SCRIPT_PATH}" ]]; then
    ln -sfn "${SCRIPT_PATH}" "${INSTALL_PATH}"
    echo "${COMMAND_NAME} wurde als symbolischer Link unter '${INSTALL_PATH}' installiert."
  fi

  if [[ ":${PATH}:" != *":${INSTALL_DIR}:"* ]]; then
    echo "Hinweis: '${INSTALL_DIR}' ist nicht in PATH enthalten." >&2
    echo "Fuege das Verzeichnis zu PATH hinzu, damit '${COMMAND_NAME}' ohne Pfad aufgerufen werden kann." >&2
  fi
}

container_exists() {
  docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1
}

container_running() {
  [[ "$(docker container inspect --format '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null)" == "true" ]]
}

require_running() {
  if ! container_running; then
    echo "Container '${CONTAINER_NAME}' laeuft nicht. Zuerst ausfuehren: ${COMMAND_NAME} start" >&2
    exit 1
  fi
}

require_vehicle_interface_source() {
  local package_file="${VEHICLE_INTERFACE_DIR}/autoware_ws/src/thorsten_vehicle_interface/package.xml"
  if [[ ! -f "${package_file}" ]]; then
    echo "Vehicle-Interface-Package nicht gefunden: ${package_file}" >&2
    exit 1
  fi
}

ensure_vehicle_interface_dependencies() {
  if docker exec --user root "${CONTAINER_NAME}" \
    bash -lc 'command -v protoc >/dev/null 2>&1 && dpkg-query -W libprotobuf-dev >/dev/null 2>&1'; then
    return
  fi

  echo "Protobuf-Buildabhaengigkeiten werden im Container installiert ..."
  docker exec --user root "${CONTAINER_NAME}" \
    bash -lc 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends protobuf-compiler libprotobuf-dev libprotoc-dev'
}

build_vehicle_interface() {
  require_running
  require_vehicle_interface_source
  ensure_vehicle_interface_dependencies

  echo "Vehicle Interface wird inkrementell kompiliert ..."
  docker exec --user "${CONTAINER_USER}" "${CONTAINER_NAME}" \
    bash -lc 'set -Eeo pipefail; source /opt/autoware/setup.bash; set -u; cd "$1/autoware_ws"; colcon build --packages-select thorsten_vehicle_interface --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release' \
    bash "${CONTAINER_VEHICLE_INTERFACE_DIR}"
}

simulation_running() {
  docker exec --user "${CONTAINER_USER}" "${CONTAINER_NAME}" \
    pgrep -f 'ros2 launch (autoware_launch planning_simulator\.launch\.xml|thorsten_vehicle_interface planning_simulator_with_vehicle_interface\.launch\.py)' \
    >/dev/null 2>&1
}

start_container() {
  if container_running; then
    echo "Container '${CONTAINER_NAME}' laeuft bereits."
    return
  fi

  # Ein eventuell nach einem Fehler uebrig gebliebener, gestoppter Container
  # blockiert sonst den festen Namen. Nutzdaten liegen ausserhalb im Volume.
  if container_exists; then
    docker container rm "${CONTAINER_NAME}" >/dev/null
  fi

  mkdir -p "${DATA_DIR}/maps" "${DATA_DIR}/ml_models" "${DATA_DIR}/logs"

  if [[ -n "${DISPLAY:-}" ]] && command -v xhost >/dev/null 2>&1; then
    xhost +local:docker >/dev/null
  fi

  docker_args=(
    run --detach --rm
    --name "${CONTAINER_NAME}"
    --init
    --network host
    --mount type=bind,source=/dev/input,target=/dev/input,readonly
    --mount type=bind,source=/run/udev,target=/run/udev,readonly
    --device-cgroup-rule='c 13:* r'
    --runtime nvidia
    --cap-add NET_ADMIN
    --shm-size 2g
    --ulimit memlock=-1
    --env "NVIDIA_VISIBLE_DEVICES=all"
    --env "NVIDIA_DRIVER_CAPABILITIES=all"
    --env "HOST_UID=$(id -u)"
    --env "HOST_GID=$(id -g)"
    --env "QT_X11_NO_MITSHM=1"
    --volume "${DATA_DIR}:/home/aw/autoware_data"
  )

  if [[ -n "${DISPLAY:-}" ]] && [[ -d /tmp/.X11-unix ]]; then
    docker_args+=(
      --env "DISPLAY=${DISPLAY}"
      --volume /tmp/.X11-unix:/tmp/.X11-unix:rw
    )
  fi

  docker "${docker_args[@]}" "${IMAGE}" \
    bash -lc 'source /opt/autoware/setup.bash && exec sleep infinity'

  echo "Container '${CONTAINER_NAME}' wurde gestartet."
  echo "Shell oeffnen: ${COMMAND_NAME} shell"
}

open_shell() {
  require_running
  docker exec --user "${CONTAINER_USER}" --env "AWCM_OVERLAY_SETUP=${CONTAINER_VEHICLE_INTERFACE_SETUP}" -it "${CONTAINER_NAME}" \
    bash -lc 'source /opt/autoware/setup.bash; if [[ -f "${AWCM_OVERLAY_SETUP}" ]]; then source "${AWCM_OVERLAY_SETUP}"; fi; exec bash -i'
}

run_command() {
  require_running
  if (( $# == 0 )); then
    echo "Verwendung: ${COMMAND_NAME} exec BEFEHL [ARGUMENTE ...]" >&2
    exit 2
  fi

  docker exec --user "${CONTAINER_USER}" --env "AWCM_OVERLAY_SETUP=${CONTAINER_VEHICLE_INTERFACE_SETUP}" -it "${CONTAINER_NAME}" \
    bash -lc 'source /opt/autoware/setup.bash; if [[ -f "${AWCM_OVERLAY_SETUP}" ]]; then source "${AWCM_OVERLAY_SETUP}"; fi; exec "$@"' bash "$@"
}

launch_simulator() {
  require_running
  if simulation_running; then
    echo "Im Container laeuft bereits eine Planning-Simulation." >&2
    exit 1
  fi

  build_vehicle_interface
  run_command ros2 launch thorsten_vehicle_interface planning_simulator_with_vehicle_interface.launch.py \
    map_path:=/home/aw/autoware_data/maps/sample-map-planning \
    vehicle_model:=sample_vehicle \
    sensor_model:=sample_sensor_kit
}

launch_rqt_graph() {
  require_running

  if ! docker exec --user "${CONTAINER_USER}" "${CONTAINER_NAME}" \
    bash -lc 'source /opt/autoware/setup.bash && ros2 pkg prefix rqt_graph >/dev/null 2>&1'; then
    echo "rqt_graph fehlt und wird im laufenden Container installiert ..."
    docker exec --user root "${CONTAINER_NAME}" \
      bash -lc 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ros-jazzy-rqt-graph graphviz'
  fi

  run_command ros2 run rqt_graph rqt_graph
}

show_help() {
  cat <<EOF
Verwendung: ${COMMAND_NAME} [BEFEHL]

  start       Container im Hintergrund starten (Standard)
  shell       Neue interaktive Shell im Container oeffnen
  build-interface
              Vehicle Interface im Container kompilieren
  sim         Planning Simulator und Vehicle Interface starten
  rqt         rqt_graph im aktuellen Terminal starten
  exec ...    Beliebigen Befehl mit geladener Autoware-Umgebung ausfuehren
  status      Containerstatus anzeigen
  stop        Container und darin laufende Prozesse stoppen
  help        Diese Hilfe anzeigen

Beispiele:
  ${COMMAND_NAME} start
  ${COMMAND_NAME} shell
  ${COMMAND_NAME} exec ros2 node list
  ${COMMAND_NAME} sim

Feste Einstellungen:
  Container: ${CONTAINER_NAME}
  Benutzer:  ${CONTAINER_USER}
  Image:     ${IMAGE}
  Daten:     ${DATA_DIR}
  Interface: ${VEHICLE_INTERFACE_DIR}
EOF
}

install_self

requested_command="${1:-start}"

if [[ "${requested_command}" == "help" || "${requested_command}" == "-h" || "${requested_command}" == "--help" ]]; then
  show_help
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker wurde nicht gefunden." >&2
  exit 1
fi

case "${requested_command}" in
  start)
    start_container
    ;;
  shell)
    open_shell
    ;;
  build-interface)
    build_vehicle_interface
    ;;
  sim)
    launch_simulator
    ;;
  rqt)
    launch_rqt_graph
    ;;
  exec)
    shift
    run_command "$@"
    ;;
  status)
    docker container ls --all --filter "name=^/${CONTAINER_NAME}$"
    ;;
  stop)
    if container_running; then
      docker container stop --time 10 "${CONTAINER_NAME}"
    else
      echo "Container '${CONTAINER_NAME}' laeuft nicht."
    fi
    ;;
  *)
    echo "Unbekannter Befehl: $1" >&2
    show_help >&2
    exit 2
    ;;
esac
