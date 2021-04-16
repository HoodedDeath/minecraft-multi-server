#!/bin/bash
# Names of variables that should have a non-null default value
name_arr=("DOCKER" "PORT" "RCON_PORT" "RCON_PASSWORD" "MINHEAP" "MAXHEAP" "EULA" "TYPE" "VERSION" "DIFFICULTY" "MAX_PLAYERS" "MAX_WORLD_SIZE" "ALLOW_NETHER" "ANNOUNCE_PLAYER_ACHIEVEMENTS" "ENABLE_COMMAND_BLOCK" "FORCE_GAMEMODE" "GENERATE_STRUCTURES" "HARDCORE" "MAX_BUILD_HEIGHT" "MAX_TICK_TIME" "SPAWN_MONSTERS" "SPAWN_NPCS" "VIEW_DISTANCE" "MODE" "MOTD" "PVP" "LEVEL_TYPE" "LEVEL" "AUTOPAUSE" "TIMEOUT" "EPHEMERAL" "DATA_DIR" "BACKUP_DIR" "SPAWN_PROTECTION" "MINECRAFT_UID" "MINECRAFT_GID")
# Default values for variables in above array
vals_arr=("$(which docker)" "25565" "25575" "minecraft" "512" "2048" "false" "vanilla" "LATEST" "normal" "10" "29999984" "true" "true" "false" "false" "true" "false" "256" "60000" "true" "true" "10" "survival" "A minecraft server" "true" "default" "world" "true" "0" "false" "/srv/minecraft" "./backups" "64" "$(id -u minecraft)" "$(id -g minecraft)")
# Setup flag variables for script
seteula=false
debug=false
followlog=false
verbose=false
# Usage message
function usage {
    echo "Usage: $0 <ACTION> <OPTIONS> <NAME>"
    echo
    echo "Options:"
    echo "  -c <PATH> | --config <PATH>: Use the file at the given path for environment variables instead of a file in the default location"
    echo "  -d | --debug: Enable debug messages about what values are being set and what is being called. Debug also enables verbosity messages"
    echo "  -e <TRUE|FALSE> | --eula <TRUE|FALSE>: Set Eula to a desired value, regardless of environment file. Useful for starting a default environment server that doesn't need an environment file just for the EULA option."
    echo "  -f | --follow: Follows the log of the docker container when used with the 'log' command"
    echo "  -v | --verbose: Enables verbosity messages about what is happening"
    echo
    echo "Actions:"
    echo "  help | usage"
    echo "    Displays this message"
    echo "  start   <NAME>"
    echo "    Starts a server with the given name"
    echo "  stop    <NAME>"
    echo "    Stops the server with the given name"
    echo "  restart <NAME>"
    echo "    Restarts the server with the given name"
    echo "  status  <NAME>"
    echo "    Displays if the server with the given name is running"
    echo "    Name can be given as all to show status of all running servers"
    echo "  save    <NAME>"
    echo "    Saves the server with the given name"
    echo "  backup  <NAME>"
    echo "    Creates a backup of the server with the given name"
    echo "  command <NAME> <COMMAND>"
    echo "    Sends the given command to the server with the given name"
    echo "  console <NAME>"
    echo "    Opens an interactive console for the server with the given name"
    echo "  log     <NAME>"
    echo "    Displays the log for the server with the given name"
    echo
    echo "Name is a name for the server and the data dir"
    echo "Name cannot be 'default'"
    echo "Name can only be 'all' when using status command"
    echo
    echo "If your user account is not part of the 'docker' group, you will need to invoke this script with sudo in order to use the commands: start, stop, restart, status, save, backup, log, and follow-log"
    if [[ $debug == true ]]; then
        echo
        echo "Command 'print-environment <NAME>' can be used to print environment variables for given server"
        echo "Command 'print-var <NAME> <VAR>' can be used to print a specific variable for the given server"
    fi

    exit 1
}
# Print environment variables
function printvars {
    for i in ${!name_arr[@]}; do
        echo "${name_arr[$i]} - Default: ${vals_arr[$i]} - Currently: ${!name_arr[$i]}"
    done
}
# Print a specific environment variable
function printvar {
    echo "$1 is set to ${!1}"
}
# Print debug messages if debug flag enabled
function dmsg {
    if [[ $debug == true ]]; then echo $@; fi
}
# Print verbosity messages if verbose flag enabled
function vmsg {
    if [[ $verbose == true ]]; then echo $@; fi
}
# Print verbosity messages if verbose flag enabled and debug flag disabled
function vndmsg {
    if [[ $verbose == true ]] && [[ ! $debug == true ]]; then echo $@; fi
}
# Check if container is running
function running {
    if [[ -z "$1" ]]; then
        dmsg "Checking docker container ${name}.State.Status ..."
        stat="$($DOCKER inspect -f '{{.State.Status}}' "$name" 2>/dev/null)"
    else
        dmsg "Checking docker container ${1}.State.Status ..."
        stat="$($DOCKER inspect -f '{{.State.Status}}' "$1" 2>/dev/null)"
    fi
    test running = "$stat"
    return $?
}
function status {
    if [[ "x$name" == "xall" ]]; then
        vmsg "Finding docker containers ..."
        servers=($(docker ps --filter ancestor=itzg/minecraft-server:java8 --format "{{.Names}}"))
        dmsg "Containers found: [ ${servers[@]} ]"
        for i in ${!servers[@]}; do
            vmsg "Testing container '${servers[$i]}'"
            if running "${servers[$i]}"; then
                echo "Server '${servers[$i]}' is running. $(minecraftctl command ${servers[$i]} list)"
            else
                echo "Server '${servers[$i]}' is stopped"
            fi
        done
    else
        vmsg "Testing container '$name' for running status ..."
    	if running; then
    		echo "Server '$name' is running. $(game_command list)"
    		exit 0
    	else
    		echo "Server '$name' is stopped"
    		exit 2
    	fi
    fi
}
# Start the minecraft docker container
function start {
    vmsg "Checking if container '$name' is already running ..."
    if running; then
        echo "Server already running..."
        exit 0
    fi
    vmsg "Calling stop_container to remove potential of conflicting container"
    stop_container
    # # Was a workaround for ICON variable for container not working, but requires you to have write access within the server directory
    # Copy requested server icon if it exists
#    if [[ -f "${ICON}" ]] && [[ ! -f "${DATA_DIR}/${name}/server-icon.png" ]]; then
#        vmsg "Copying icon from '${ICON}' to '${DATA_DIR}/${name}/server-icon.png' ..."
#        mkdir -p "${DATA_DIR}/${name}"
#        cp "${ICON}" "${DATA_DIR}/${name}/server-icon.png"
#    fi
    # Set volume flag for docker, will be changed to empty if ephemeral option is set to true
    vol_mount="--volume=$DATA_DIR/${name}:/data"
    dmsg "Setting volume flag for docker to '$vol_mount'"
    if $EPHEMERAL; then
        vmsg "Ephemeral is true, discarding volume flag."
        vol_mount=""
        echo "Ephemeral server, a restart will lose all world data."
    fi
    vmsg "Calling '$DOCKER' to start server container '$name' ..."
    $DOCKER run -d -i \
        --name "$name" \
        $vol_mount \
        -p $PORT:25565 \
        -p $RCON_PORT:25575 \
        -e "RCON_PASSWORD=${RCON_PASSWORD}" \
        -e "JVM_OPTS=-D${name}" \
        -e "INIT_MEMORY=${MINHEAP}M" \
        -e "MAX_MEMORY=${MAXHEAP}M" \
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
        -e "SPAWN_PROTECTION=$SPAWN_PROTECTION" \
        itzg/minecraft-server:java8
    echo "Started minecraft container '$name'"
}
# Send a command to the game server
function game_command {
    dmsg "Sending command '$@' to server rcon on port $RCON_PORT ..."
    # Issue command
    $RCON_CMD "$@"
}
# Do a world save
function save {
    vmsg "Saving world ..."
    game_command "save-all flush"
    game_command "say Saved the world"
}
# Do a world backup
function backup {
    filename="$name-$(date +%Y_%m_%d_%H.%M.%S).tar.gz"
    vmsg "Creating backup as $filename ..."
    if running; then
        game_command "say Starting backup..."
        # Make sure we always turn saves back on
        set +e
        ret=0
        dmsg "Disabling autosave ..."
        game_command "save-off"
        ret=$(($ret + $?))
        dmsg "Return value currently at '$ret'"
        dmsg "Saving world ..."
        game_command "save-all flush"
        ret=$(($ret + $?))
        dmsg "Return value currently at '$ret'"
        dmsg "Synchronizing cached files to storage ..."
        sync
        ret=$(($ret + $?))
        dmsg "Return value currently at '$ret'"
        dmsg "Creating directory for backup if it doesn't already exist ..."
        $DOCKER exec -u minecraft "$name" mkdir -p "/data/$BACKUP_DIR"
        ret=$(($ret + $?))
        dmsg "Return value currently at '$ret'"
        dmsg "Creating backup archive ..."
        $DOCKER exec -u minecraft "$name" tar -C /data -czf "$BACKUP_DIR/$filename" "$LEVEL" server.properties
        ret=$(($ret + $?))
        dmsg "Return value currently at '$ret'"
        dmsg "Re-enabling autosave ..."
        game_command "save-on"
        ret=$(($ret + $?))
        dmsg "Backup finished with return value at '$ret'"
        game_command "say Backup finished"
    else
        read -n 1 -p "The server is not running, sudo will need to be used to run commands as the minecraft user. This will prompt you for your password. Continue? [Y/N]: " continue_yn
        case $continue_yn in
            [Yy] ) ret=0; dmsg "Creating directory for backup if it doesn't already exist ..."; sudo -u minecraft mkdir -p "${DATA_DIR}/${name}/${BACKUP_DIR}"; ret=$((ret + $?)); dmsg "Return value currently at '$ret'"; dmsg "Creating backup archive ..."; sudo -u minecraft tar -C "${DATA_DIR}/${name}" -czf "$BACKUP_DIR/$filename" "$LEVEL" server.properties; ret=$((ret + $?)); dmsg "Backup finished with return value at '$ret'"; if [[ ! $debug == true ]]; then echo "Backup finished."; fi;;
            * ) echo "Cancelling backup."; exit 1;;
        esac
    fi
    exit $ret
}
# Stop the server
function stop {
    vmsg "Testing container '$name' for running status ..."
    if running; then
        echo "Stopping server '$name' with 10 second warning ..."
        for i in {10..1}; do
            vmsg "Server shutting down in ${i}s ..."
            game_command "say Server saving and shutting down in ${i}s ..."
            sleep 1
        done
        vndmsg "Saving and shutting down server ..."
        game_command "say Saving ..."
        dmsg "Saving world ..."
        game_command "save-all"
        game_command "say Shutting down ..."
        dmsg "Shutting down server ..."
        game_command "stop"
        # Wait for container to stop on its own
        dmsg "Waiting for docker container to exit ..."
        $DOCKER wait "$name"
    else
        vmsg "Server '$name' is not running"
    fi
    stop_container
}
# Stop and remove the container
function stop_container {
	$DOCKER stop "$name" > /dev/null 2>&1 || true
    $DOCKER rm "$name" > /dev/null 2>&1 || true
}
# Can't use 'default' as server name
function unuseable_name {
    case $1 in
        a) echo "Cannot use given command on all containers.";;
        d|*) echo "Cannot use name '$name' for server.";;
    esac
    exit 3
}
# Open an interactive console with the server
function game_console {
    echo "Connecting to server console ..."
    $RCON_CMD
}
# Show log
function show_log {
    if [[ $followlog == true ]]; then
        $DOCKER logs -ft "$name"
    else
        $DOCKER logs -t "$name"
    fi
    exit 0
}
# Check variables and set default values if needed
function check_vars {
    vmsg "Checking variables for empty values ..."
    # Loop through each variable
    for i in ${!name_arr[@]}; do
        # Check if it is empty
        if [[ -z ${!name_arr[$i]} ]]; then
            # Set variable with matching default value
            declare -g "${name_arr[$i]}=${vals_arr[$i]}"
            dmsg "'${name_arr[$i]}' is empty, setting to default value of '${vals_arr[$i]}'"
        fi
    done
    # Set the rcon command now that password and port are set either to user-defined or default values
    RCON_CMD="mcrcon -P ${RCON_PORT} -p ${RCON_PASSWORD}"
    dmsg "Setting RCON_CMD to '$RCON_CMD'"
}

# Exit immediately if a command exits with non-zero status
set -e

# Check valid command before other steps
case $1 in
    status|start|stop|restart|backup|save|command|console|log|help|usage|print-environment|print-var) if [[ "$@" == *"-d"* ]] || [[ "$@" == *"--debug"* ]]; then echo "Command recognized as $1"; fi; cmd=$1; shift;;
    *) usage;;
esac
# Command line options
while true; do
    case $1 in
        -e|--eula) shift; eulaset=$1; seteula=true; shift;;
        -c|--config) shift; cfg_file=$1; shift;;
        -f|--follow) shift; followlog=true;;
        -d|--debug) shift; debug=true; verbose=true; echo "Debug messages enabled."; echo "Verbosity messages enabled.";;
        -v|--verbose) shift; verbose=true; echo "Verbosity messages enabled.";;
        -*) echo "Unknown option: $1"; exit 1;;
        *) break;;
    esac
done
# Option based debug messages
if [[ $seteula == true ]]; then vndmsg "Eula flag found."; dmsg "Eula flag found, eula will be set to $eulaset"; fi
if [[ -n $cfg_file ]]; then vndmsg "Config file flag found."; dmsg "Config file will attempt to load from '$cfg_file'"; fi

# Check given name
if [[ -z "$1" ]]; then
    usage
elif [[ "x$1" == "xdefault" ]]; then
    unuseable_name d
elif [[ "x$1" == "xall" ]]; then
    case $cmd in
        status) name=$1;;
        *) unuseable_name a;;
    esac
else
    name=$1
fi
# Source config file from either command line option or from /etc/minecraft
if [[ -n $cfg_file ]] && [[ -r $cfg_file ]]; then
    source "$cfg_file"
elif [[ -r "/etc/minecraft/$name" ]]; then
    source "/etc/minecraft/$name"
fi
# Set default values for variables where needed
check_vars
# Set eula if eula flag present
if [[ $seteula == true ]]; then
    EULA=$eulaset
fi
# Handle command issued to script
case "$cmd" in
	status)     status;;
	start)      start;;
	stop)       stop;;
	restart)    stop; start;;
	backup)     backup;;
	save)       save;;
    help)       usage;;
    usage)      usage;;
    command)    shift; game_command "$@";;
    console)    game_console;;
    log)        show_log;;
    print-environment) printvars;;
    print-var) shift; printvar "$1";;
	*)          usage;;
esac
