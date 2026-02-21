# Backhaul Watchdog

## Overview
Backhaul Watchdog is a tool designed to monitor and manage backhaul network connections, ensuring reliability and quick detection of outages or issues.

## Features
- Monitors backhaul network status
- Provides alerts on connection failures
- Easy installation and configuration

## Installation
Run the provided installation script:

```sh
bash <(curl -Ls https://raw.githubusercontent.com/Incognito-Coder/Backhaul-Watchdog/master/install.sh)
```

## Usage

After running the installation script, the Backhaul Watchdog service will be installed and started automatically.

### Service Management

- **Check service status:**
	```sh
	systemctl status backhaul-watchdog
	```
- **View live logs:**
	```sh
	journalctl -u backhaul-watchdog -f
	```
- **Restart the service:**
	```sh
	systemctl restart backhaul-watchdog
	```
- **Enable service on boot:**
	```sh
	systemctl enable backhaul-watchdog
	```

### How It Works

The watchdog monitors all `backhaul-*` services (except itself). If a service logs a heartbeat timeout (disconnection), the watchdog automatically switches the profile in the corresponding TOML config file between `tcp` and `bip`, then restarts the affected service. This helps maintain connectivity by toggling profiles on failure.

Configuration files are expected in `/root/backhaul-core/` as `<name>.toml` for each service.

## Author
Telegram : [Alireza Ah-mand](https://t.me/incognito_coder)
