# WordPress migration tool [![Version](https://img.shields.io/badge/version-v1.0.1-brightgreen.svg)](https://github.com/zevilz/zwp-migrate/releases/tag/1.0.1)

Simple tool for migrate WordPress sites between servers and shared hostings with SSH access via rsync and WP-CLI (including local migrations).

## Features

- migrating from local to remote server;
- migrating from remote to local server;
- local migrations;
- using WP-CLI for right urls and paths replacements in database;
- autodownloading WP-CLI to target server if it not installed.

## Requirements

Required:

- ssh access to source and target host (if not local migrations);
- rsync (on host where does the script run);
- curl.

Recommended:

- WP-CLI (on target host);
- access to remote host via SSH key.

SSH keys with passphrase not supported. But you can temporary disable asking passphrase:

```bash
eval "$(ssh-agent)"
ssh-add ~/.ssh/id_rsa
```

After migration you can remove identity for enable passphrase:

```bash
ssh-add -d ~/.ssh/id_rsa
```

## Parameters

Common parameters:

- `-h (--help)` - shows a help message;
- `-q (--quiet)` - automatically confirm migration after checks.

Non-interactive mode only parameters:

- `--non-interactive` - enable non-interactive mode;
- `--source-host=<ip|hostname>:<ssh_port>` - source host IP/hostname with ssh port (if it not 22) separated by colon (don't set it if you run script on this host; usage: `--source-host=111.222.333.444 | --source-host=111.222.333.444:1234 | --source-host=hostname.com | --source-host=hostname.com:1234`);
- `--source-user=<username>` - system user on source host (source site owner; usage: `--source-user=username`);
- `--source-user-pass='<password>'` - system user password on source host (password of source site owner; don't set it if you run script as this user; usage: `--source-user-pass='qwerty123'`);
- `--source-path=<path>` - full path to source site root (usage: `--source-path=/home/username/site.com/public_html`);
- `--target-host=<ip|hostname>:<ssh_port>` - target host IP/hostname with ssh port (if it not 22) separated by colon (don't set it if you run script on this host; usage: `--target-host=111.222.333.444 | --target-host=111.222.333.444:1234 | --target-host=hostname.com | --target-host=hostname.com:1234`);
- `--target-user=<username>` - system user on target host (target site owner; usage: `--target-user=username`);
- `--target-user-pass='<password>'` - system user password on target host (password of target site owner; don't set it if you run script as this user; usage: `--target-user-pass='qwerty123'`);
- `--target-path=<path>` - full path to target site root (usage: `--target-path=/home/username/site.com/public_html`);
- `--target-site-url=<url>` - full url of target site with protocol (usage: `--target-site-url=https://site.com`);
- `--target-db-name=<database>` - target site database name (usage: `--target-db-name=db`);
- `--target-db-user=<username>` - target site database user with full access rights to target site database (usage: `--target-db-user=db_user`);
- `--target-db-pass=<password>` - target site database user password (usage: `--target-db-pass='qwerty123'`).

## Usage

IMPORTANT: The script creates temporary file with user password for remote SSH connections via passwords. Delete it manually if the script terminates abnormally! This file not created if using SSH keys.

### Common usage

First download the script to any directory:

```bash
curl -O https://raw.githubusercontent.com/zevilz/zwp-migrate/master/zwp_migrate.sh
```

Then run the script without parameters, answer the questions, check data and confirm:

```bash
bash zwp_migrate.sh
```

Also you can use it without downloading:

```bash
bash <(curl -sL https://raw.githubusercontent.com/zevilz/zwp-migrate/master/zwp_migrate.sh)
```

### Non-interactive mode

Non-interactive mode disable questions that spend time to read and answer questions. All data transmitted as parameters. It usefull for many migrations and automatical migrations (with `-q (--quiet)` parameter). Also it suitable for advanced users. All data will be check during migration as in normal mode.

Local migration as owner both sites:

```bash
bash zwp_migrate.sh --non-interactive \
	--source-user=user \
	--source-path=/home/user/public_html/oldsite.com \
	--target-user=user \
	--target-path=/home/user/public_html/newsite.com \
	--target-site-url=https://newsite.com \
	--target-db-name=db \
	--target-db-user=dbuser \
	--target-db-pass='querty1234'
```

Local migration as root between different users:

```bash
bash zwp_migrate.sh --non-interactive \
	--source-user=user \
	--source-path=/home/user/public_html/oldsite.com \
	--target-user=newuser \
	--target-path=/home/newuser/public_html/newsite.com \
	--target-site-url=https://newsite.com \
	--target-db-name=db \
	--target-db-user=dbuser \
	--target-db-pass='querty1234'
```

Migrate from remote to local server:

```bash
bash zwp_migrate.sh --non-interactive \
	--source-host=111.222.111.222 \
	--source-user=user \
	--source-user-pass='querty1234' \
	--source-path=/home/user/public_html/site.com \
	--target-user=anotheruser \
	--target-path=/home/anotheruser/public_html/another-site.com \
	--target-site-url=https://another-site.com \
	--target-db-name=db \
	--target-db-user=dbuser \
	--target-db-pass='querty1234'
```

Migrate from local to remote server (with custom SSH port):

```bash
bash zwp_migrate.sh --non-interactive \
	--source-user=user \
	--source-path=/home/user/public_html/site.com \
	--target-host=111.222.111.222:6666 \
	--target-user=anotheruser \
	--target-user-pass='querty1234' \
	--target-path=/home/anotheruser/public_html/another-site.com \
	--target-site-url=https://another-site.com \
	--target-db-name=db \
	--target-db-user=dbuser \
	--target-db-pass='querty1234'
```

NOTE: add a space in front of the command to avoid getting the password in the command history or disable history (`unset HISTFILE`).

## TODO

- [ ] support for sync exclude list;
- [ ] support for set WP-CLI custom path;
- [ ] support for using WP-CLI on source host;
- [ ] support for backup/restore on non localhost db servers;
- [ ] support for change db backup/restore method (direct/WP-CLI);
- [ ] support for both remote servers;
- [ ] support for different remote user and remote site owner;
- [ ] support for run the script as users with sudo;
- [ ] support for set custom SSH key path;
- [ ] support for check DB user write access to DB on target host (now checks only usage);
- [ ] support for set custom PHP version for WP-CLI (source/target);
- [ ] checking neccessary disk space on source host;
- [ ] decrease number of parameters;
- [ ] logging.

## Changelog

2023.07.12 - 1.0.1 - [Bugfixes](https://github.com/zevilz/zwp-migrate/releases/tag/1.0.1)
2023.07.07 - 1.0.0 - Released
