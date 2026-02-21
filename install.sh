#!/usr/bin/env bash

set -e
echo "Script by @Incognito_Coder - Alireza Ahmand"
echo "Installing Backhaul Watchdog..."

INSTALL_PATH="/usr/local/bin/backhaul-watchdog.sh"
SERVICE_PATH="/etc/systemd/system/backhaul-watchdog.service"

# Create watchdog script
cat > "$INSTALL_PATH" << 'EOF'
#!/usr/bin/env bash

CONFIG_DIR="/root/backhaul-core"
COOLDOWN=10

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

monitor_service() {
    FULL_SERVICE="$1"
    SERVICE="${FULL_SERVICE%.service}"
    NAME="${SERVICE#backhaul-}"
    TOML_FILE="${CONFIG_DIR}/${NAME}.toml"

    if [[ ! -f "$TOML_FILE" ]]; then
        log "[$SERVICE] Config not found: $TOML_FILE"
        return
    fi

    log "[$SERVICE] Monitoring..."

    journalctl -u "$SERVICE" -f -o cat | while read -r line; do
        if [[ "$line" == *"Heartbeat timeout — Status: 🔴 Disconnected"* ]]; then

            log "[$SERVICE] Disconnected detected"

            CURRENT_PROFILE=$(grep -E '^profile\s*=' "$TOML_FILE" | awk -F'"' '{print $2}')

            if [[ "$CURRENT_PROFILE" == "tcp" ]]; then
                NEW_PROFILE="bip"
            elif [[ "$CURRENT_PROFILE" == "bip" ]]; then
                NEW_PROFILE="tcp"
            else
                log "[$SERVICE] Unknown profile: $CURRENT_PROFILE"
                continue
            fi

            log "[$SERVICE] Switching $CURRENT_PROFILE → $NEW_PROFILE"

            sed -i "s/^profile\s*=\s*\"$CURRENT_PROFILE\"/profile = \"$NEW_PROFILE\"/" "$TOML_FILE"

            systemctl restart "$SERVICE"
            sleep "$COOLDOWN"
        fi
    done
}

while true; do
    SERVICES=$(systemctl list-units --type=service --no-legend \
        | awk '{print $1}' \
        | grep '^backhaul-' \
        | grep -v '^backhaul-watchdog\.service$')

    for FULL_SERVICE in $SERVICES; do
        monitor_service "$FULL_SERVICE" &
    done

    wait
    sleep 5
done
EOF

chmod +x "$INSTALL_PATH"

# Create systemd service
cat > "$SERVICE_PATH" << EOF
[Unit]
Description=Backhaul Auto Profile Watchdog
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_PATH
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

# Reload and enable
systemctl daemon-reload
systemctl enable backhaul-watchdog
systemctl restart backhaul-watchdog

clear
echo
echo "Installation completed!"
echo "The Backhaul Watchdog is now running and will automatically switch profiles if a disconnection is detected."
echo "You can check its status with: systemctl status backhaul-watchdog"
echo "To view logs: journalctl -u backhaul-watchdog -f"
echo