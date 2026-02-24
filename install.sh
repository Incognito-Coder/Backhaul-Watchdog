#!/usr/bin/env bash

set -e
echo "Script by @Incognito_Coder - Alireza Ahmand && Arash Ariaye"
echo "Installing Backhaul Watchdog..."

INSTALL_PATH="/usr/local/bin/backhaul-watchdog.sh"
SERVICE_PATH="/etc/systemd/system/backhaul-watchdog.service"

# Create watchdog script
cat > "$INSTALL_PATH" << 'EOF'
#!/usr/bin/env bash

CONFIG_DIR="/root/backhaul-core"
COOLDOWN=30
CHECK_INTERVAL=5

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

    log "[$SERVICE] Monitoring (last line check every ${CHECK_INTERVAL}s)..."

    while true; do
        
        LAST_LINE=$(journalctl -u "$SERVICE" -n 1 -o cat 2>/dev/null)

        if [[ -z "$LAST_LINE" ]]; then
            sleep "$CHECK_INTERVAL"
            continue
        fi

        if [[ "$LAST_LINE" == *"Heartbeat timeout — Status: 🔴 Disconnected"* || \
              "$LAST_LINE" == *"invalid packet received: not IPv4 packet"* ]]; then

            log "[$SERVICE] Problem detected in LAST LINE → $LAST_LINE"

            CURRENT_PROFILE=$(grep -E '^profile\s*=' "$TOML_FILE" | awk -F'"' '{print $2}')

            if [[ "$CURRENT_PROFILE" == "tcp" ]]; then
                NEW_PROFILE="bip"
            elif [[ "$CURRENT_PROFILE" == "bip" ]]; then
                NEW_PROFILE="tcp"
            else
                log "[$SERVICE] Unknown profile: $CURRENT_PROFILE → skipping"
                sleep "$CHECK_INTERVAL"
                continue
            fi

            log "[$SERVICE] Switching profile: $CURRENT_PROFILE → $NEW_PROFILE"

            sed -i "s/^profile\s*=\s*\"$CURRENT_PROFILE\"/profile = \"$NEW_PROFILE\"/" "$TOML_FILE"

            systemctl restart "$SERVICE"
            log "[$SERVICE] Restarted"

            sleep "$COOLDOWN"
        fi

        sleep "$CHECK_INTERVAL"
    done
}

while true; do
    SERVICES=$(systemctl list-units --type=service --no-legend \
        | awk '{print $1}' \
        | grep '^backhaul-' \
        | grep -v '^backhaul-watchdog\.service$')

    for FULL_SERVICE in $SERVICES; do
        
        if ! pgrep -f "monitor_service $FULL_SERVICE" > /dev/null; then
            monitor_service "$FULL_SERVICE" &
        fi
    done

    sleep 10 
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
