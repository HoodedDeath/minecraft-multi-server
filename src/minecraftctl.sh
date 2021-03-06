#!/bin/bash
function usage {
    echo "Usage: $0 <ACTION> <NAME>"
    echo
    echo
    echo "Actions:"
    echo "  help / usage"
    echo "    Displays this message"
    echo "  start   <NAME>"
    echo "    Starts a server with the given name"
    echo "  stop    <NAME>"
    echo "    Stops the server with the given name"
    echo "  restart <NAME>"
    echo "    Restarts the server with the given name"
    echo "  status  <NAME>"
    echo "    Displays if the server with the given name is running"
    echo "  save    <NAME>"
    echo "    Saves the server with the given name"
    echo "  backup  <NAME>"
    echo "    Creates a backup of the server with the given name"
    echo "  command <NAME> <COMMAND>"
    echo "    Sends the given command to the server with the given name"
    echo "  console <NAME>"
    echo "    Opens an interactive console for the server with the given name"
    echo "  log <NAME>"
    echo "    Displays the log for the server with the given name"
    echo "  follow-log <NAME>"
    echo "    Same as 'log', but it continues to follow the log output of the server"
    echo
    echo
    echo "Name is a name for the server and the data dir"
    echo "Name cannot be 'default'"
    exit 1
}
# Check if container is running
function running {
    stat="$($DOCKER inspect -f '{{.State.Status}}' "$name" 2>/dev/null)"
    test running = "$stat"
    return $?
}
function status {
	if running; then
		echo "Minecraft server $name is running"
		exit 0
	else
		echo "Minecraft server $name is stopped"
		exit 2
	fi
}
# Start the minecraft docker container
function start {
    if running; then
        echo "Server already running..."
        exit 0
    fi
    stop_container

    # Copy requested server icon if it exists
    if [[ -f "${ICON}" ]]; then
        mkdir "${DATA_DIR}/${name}"
        cp "${ICON}" "${DATA_DIR}/${name}/server-icon.png"
    fi

    vol_mount="--volume=$DATA_DIR/${name}:/data"
    if $EPHEMERAL; then
        vol_mount=""
        echo "Ephemeral server, a restart will lose all world data"
    fi

    $DOCKER run -d -i \
        --name "$name" \
        $vol_mount \
        -p $PORT:25565 \
        -p $RCON_PORT:25575 \
        -e "RCON_PASSWORD=${RCON_PASSWORD}" \
        -e "JVM_OPTS=-Xmx${MAXHEAP}M -Xms${MINHEAP}M -D${name}" \
        -e "JVM_XX_OPTS=$EXTRA_JVM_OPTS" \
        -e "EULA=$EULA" \
        -e "TYPE=$TYPE" \
        -e "VERSION=$VERSION" \
        -e "DIFFICULTY=$DIFFICULTY" \
        -e "WHITELIST=$WHITELIST" \
        -e "OPS=$OPS" \
        -e "ICON=$ICON" \
        -e "MAX_PLAYERS=$MAX_PLAYERS" \
        -e "MAX_WORLD_SIZE=$MAX_WORLD_SIZE" \
        -e "ALLOW_NETHER=$ALLOW_NETHER" \
        -e "ANNOUNCE_PLAYER_ACHIEVEMENTS=$ANNOUNCE_PLAYER_ACHIEVEMENTS" \
        -e "ENABLE_COMMAND_BLOCK=$ENABLE_COMMAND_BLOCK" \
        -e "FORCE_GAMEMODE=$FORCE_GAMEMODE" \
        -e "GENERATE_STRUCTURES=$GENERATE_STRUCTURES" \
        -e "HARDCORE=$HARDCORE" \
        -e "MAX_BUILD_HEIGHT=$MAX_BUILD_HEIGHT" \
        -e "MAX_TICK_TIME=$MAX_TICK_TIME" \
        -e "SPAWN_MONSTERS=$SPAWN_MONSTERS" \
        -e "SPAWN_NPCS=$SPAWN_NPCS" \
        -e "VIEW_DISTANCE=$VIEW_DISTANCE" \
        -e "SEED=$SEED" \
        -e "MODE=$MODE" \
        -e "MOTD=$MOTD" \
        -e "PVP=$PVP" \
        -e "LEVEL_TYPE=$LEVEL_TYPE" \
        -e "GENERATOR_SETTINGS=$GENERATOR_SETTINGS" \
        -e "LEVEL=$LEVEL" \
        -e "WORLD=$WORLD" \
        -e "UID=$MINECRAFT_UID" \
        -e "GID=$MINECRAFT_GID" \
        -e "ENABLE_AUTOPAUSE=$AUTOPAUSE" \
        -e "TIMEOUT=$TIMEOUT" \
        itzg/minecraft-server

    echo "Started minecraft container $name"
}
# Send a command to the game server
function game_command {
    # Issue command
    $RCON_CMD "$@"
}
# Do a world save
function save {
    game_command "save-all flush"
    game_command "say Saved the world"
}
# Do a world backup
function backup {
    filename="$name-$(date +%Y_%m_%d_%H.%M.%S).tar.gz"
    game_command "say Starting backup..."
    # Make sure we always turn saves back on
    set +e
    ret=0
    game_command "save-off"
    ret=$(($ret + $?))
    game_command "save-all flush"
    ret=$(($ret + $?))
    sync
    ret=$(($ret + $?))
    $DOCKER exec -u minecraft "$name" mkdir -p "/data/$BACKUP_DIR"
    ret=$(($ret + $?))
    $DOCKER exec -u minecraft "$name" tar -C /data -czf "$BACKUP_DIR/$filename" "$LEVEL" server.properties
    ret=$(($ret + $?))
    game_command "save-on"
    ret=$(($ret + $?))
    game_command "say Backup finished"
    exit $ret
}
# Stop the server
function stop {
    if running; then
        for i in {10..1}; do
            game_command "say Server saving and shutting down in ${i}s ..."
            sleep 1
        done
        game_command "say Saving ..."
        game_command "save-all"
        game_command "say Shutting down ..."
        game_command "stop"
        # Wait for container to stop on its own now
        $DOCKER wait "$name"
    fi
    stop_container
}
# Stop the container
function stop_container {
	$DOCKER stop "$name" > /dev/null 2>&1 || true
	$DOCKER rm "$name" > /dev/null 2>&1 || true
}
# Can't use 'default' as server name
function unuseable_name {
    echo "Cannot use name '$name' for server."
    exit 3
}
# Interactive console
function game_console {
    echo "Connecting to server console ..."
    $RCON_CMD
}
# Show log
function show_log {
    $DOCKER logs -t "$name"
    exit 0
}
# Follow log
function active_log {
    $DOCKER logs -ft "$name"
    exit 0
}

# Launch Minecraft docker container
set -e
# Check given name
name=$2
if [[ -z "$name" ]]; then
    usage
elif [[ "x$name" == "xdefault" ]]; then
    unuseable_name
fi
# Attempt to source the related configuration file
if [[ -f "/etc/minecraft/$name" ]]; then
    source "/etc/minecraft/$name"
fi
# Server type
if [[ -z $TYPE ]]; then
    TYPE="vanilla"
fi
# Docker autopause
if [[ -z $AUTOPAUSE ]]; then
    AUTOPAUSE=true
fi
# Level type
if [[ -z $LEVEL_TYPE ]]; then
    LEVEL_TYPE="default"
fi
# PVP
if [[ -z $PVP ]]; then
    PVP=true
fi
# Message of the day
if [[ -z $MOTD ]]; then
    MOTD="A Minecraft server"
fi
# View distance
if [[ -z $VIEW_DISTANCE ]]; then
    VIEW_DISTANCE=10
fi
# Spawn NPCs
if [[ -z $SPAWN_NPCS ]]; then
    SPAWN_NPCS=true
fi
# Spawn monsters
if [[ -z $SPAWN_MONSTERS ]]; then
    SPAWN_MONSTERS=true
fi
# Max tick time
if [[ -z $MAX_TICK_TIME ]]; then
    MAX_TICK_TIME=60000
fi
# Max build height
if [[ -z $MAX_BUILD_HEIGHT ]]; then
    MAX_BUILD_HEIGHT=256
fi
# Hardcore
if [[ -z $HARDCORE ]]; then
    HARDCORE=false
fi
# Generate structures
if [[ -z $GENERATE_STRUCTURES ]]; then
    GENERATE_STRUCTURES=true
fi
# Force gamemode
if [[ -z $FORCE_GAMEMODE ]]; then
    FORCE_GAMEMODE=false
fi
# Enable command blocks
if [[ -z $ENABLE_COMMAND_BLOCK ]]; then
    ENABLE_COMMAND_BLOCK=false
fi
# Announce player achievements
if [[ -z $ANNOUNCE_PLAYER_ACHIEVEMENTS ]]; then
    ANNOUNCE_PLAYER_ACHIEVEMENTS=true
fi
# Allow nether
if [[ -z $ALLOW_NETHER ]]; then
    ALLOW_NETHER=true
fi
# Max world size
if [[ -z $MAX_WORLD_SIZE ]]; then
    MAX_WORLD_SIZE="29999984"
fi
# Max players
if [[ -z $MAX_PLAYERS ]]; then
    MAX_PLAYERS="10"
fi
# Server icon
if [[ -z $ICON ]]; then
    ICON="/srv/minecraft/default/server-icon.png"
fi
# Game difficulty
if [[ -z $DIFFICULTY ]]; then
    DIFFICULTY="normal"
fi
# Game version
if [[ -z $VERSION ]]; then
    VERSION="LATEST"
fi
# Default listen port
# This is the published host port,
# internally the container always listens on 25565
if [[ -z $PORT ]]; then
    PORT="25565"
fi
# Default listen port for rcon
# This is the published host port,
# internally the container always listens on 25575
if [[ -z $RCON_PORT ]]; then
    RCON_PORT="25575"
fi
if [[ -z $RCON_PASSWORD ]]; then
    RCON_PASSWORD="minecraft"
fi
RCON_CMD="mcrcon -P ${RCON_PORT} -p ${RCON_PASSWORD}"
# Default max java heap size in MB
if [[ -z $MAXHEAP ]]; then
    MAXHEAP="2048"
fi
# Default min java heap size in MB
if [[ -z $MINHEAP ]]; then
    MINHEAP="512"
fi
# Path to docker executable
DOCKER=$(which docker)
# Wether to mount a persistent volume for the server
# If true a volume will not be mounted and a restart will lose all world data
if [[ -z $EPHEMERAL ]]; then
    EPHEMERAL=false
fi
# Directory for persisting minecraft data
if [[ -z $DATA_DIR ]]; then
    DATA_DIR="/srv/minecraft"
fi
# Relative directory to $DATA_DIR for saving minecraft backups
if [[ -z $BACKUP_DIR ]]; then
    BACKUP_DIR="./backups"
fi
# IDs of minecraft user and group
MINECRAFT_UID=$(id -u minecraft)
MINECRAFT_GID=$(id -g minecraft)
# Name of world dir
if [[ -z $LEVEL ]]; then
    LEVEL="world"
fi
# Game command timeout
if [[ -z $TIMEOUT ]]; then
    TIMEOUT="0"
fi
# EULA
if [[ -z $EULA ]]; then
    EULA=false
fi

if [[ -n "$DEBUG" ]]; then
    set -x
fi

case "$1" in
	status)     status;;
	start)      start;;
	stop)       stop;;
	restart)    stop; start;;
	backup)     backup;;
	save)       save;;
    help)       usage;;
    usage)      usage;;
    command)    shift 2; game_command "$@";;
    console)    game_console;;
    log)        show_log;;
    follow-log) active_log;;
	*)          usage;;
esac
