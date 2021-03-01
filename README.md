# Minecraft Multi Server

This project defines a template systemd service unit file for hosting several minecraft servers via docker.
This repo was forked from the version by [nathanielc](https://github.com/nathanielc/minecraft-multi-server)

# Install

This system runs the minecraft server in a docker container, so you must first install docker.

Run `make install` as root and the systemd units files and `minecraftctl` script will be copied to the appropriate locations.

You should also create a minecraft user and group to own the server files.

The minecraft user and group should be a system user/group

You should also create `/srv/minecraft` directory and change ownership to the minecraft user and group

NOTE: The script pulls a default server icon from `/srv/minecraft/default/server-icon.png`. A default icon is not supplied and will be ignored if it doesn't exist.

NOTE: `grep` and `sed` are also required in order to watch the minecraft logs for various events.

NOTE: You may need to add your user to the minecraft group to modify files within `/srv/minecraft/` without the need to use super user.

# AUR Package

AUR package potentially soon to come

# Usage

Run `minecraftctl` to view usage message.

Running `systemctl start minecraftd@<NAME>.service` will start the server and allow you to see limited log output with `systemctl status minecraftd@<NAME>.service`

Running `minecraftctl start <NAME>` will start the server without the systemd service, leaving the logs to be viewable either through `docker logs <NAME>` or with `minecraftctl log <NAME>`

Each is given a name and can be configured in an `/etc/minecraft/<NAME>` file.
A template configuration file is supplied as `/etc/minecraft/default` with most available options

## EULA

Minecraft requires that you accept the EULA in order to run a server.
Either add `EULA=true` to all your `/etc/minecraft/<NAME>` files, or edit the `minecraftctl.sh` script to set `EULA=true` for all worlds.

## Running a server

To start a new server run:

```
sudo systemctl start minecraftd@<NAME>.service
```
Or:
```
minecraftctl start <NAME>
```

To enable the server on boot run:

```
sudo systemctl enable minecraftd@<NAME>.service
```

## Custom Config

You can customize the configuration of a server by setting environment vars in `/etc/minecraft/<NAME>`

For example, to run a server on a specific port and version, you can use

```
PORT="25565"
VERSION="1.12.2"
```

in the `/etc/minecraft/<NAME>` file

An example configuration file is supplied as `/etc/minecraft/default` with most available properties.

All properties in `server.properties` are available to be set.

## Ephemeral server

If you want to host a specific puzzle or adventure world you can use both the `EPHEMERAL` and `WORLD` vars.

```
EPHEMERAL=true
WORLD=http://minecraft.example.com/myworld.zip
```

Now every time the server is started, it will download a fresh copy of the world and launch it.
Without the `EPHEMERAL` var the world will only be downloaded the first time.

## Backups

Along with the service and auto-save systemd.timer templates, a systemd.timer is provided to run backups of a server.

For example:

```
sudo systemctl enable minecraftd-backup@<NAME>.timer
sudo systemctl start minecraftd-backup@<NAME>.timer
```

This will enable weekly backups of a server.
Backups are stored in `$DATA_DIR/$BACKUP_DIR` which is `/srv/minecraft/<NAME>/backups` by default.
If you want to copy them off-site you will need to manage that yourself.


## Further customization

Not everything that is possible to customize has been mentioned here.
Take a look at the `minecraftctl.sh` script as it is written to be extensible.

# Portability

These scripts have only been tested on my Arch Linux system.
If you run into an issue (especially any that you believe to be a bug), please file an issue here on github.

# Thanks

This project is based on nathianielc's minecraft-multi-server [here](https://github.com/nathanielc/minecraft-multi-server) and as such, is leveraging the work of the https://hub.docker.com/r/itzg/minecraft-server/ docker container for minecraft.
Many thanks to both projects for making this one possible.

