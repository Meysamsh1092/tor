#!/bin/bash

LOG_DIR="/root/log"
LOG_SCRIPT_PATH="$LOG_DIR/tail-log.sh"
ROTATE_SCRIPT_PATH="$LOG_DIR/rotate_logs.sh"
TAIL_SERVICE_PATH="/etc/systemd/system/tail-log.service"
ROTATE_SERVICE_PATH="/etc/systemd/system/log-rotate.service"
ROTATE_TIMER_PATH="/etc/systemd/system/log-rotate.timer"
LOG_FILE="$LOG_DIR/log.txt"

# اطمینان از ایجاد مسیر /root/log
mkdir -p $LOG_DIR

# لوگو
show_logo() {
  echo -e "\e[1;31m#########################################################\e[0m"
  echo -e "\e[1;31m#                                                       #\e[0m"
  echo -e "\e[1;31m#                      ███╗   ███╗                      #\e[0m"
  echo -e "\e[1;31m#                      ████╗ ████║                      #\e[0m"
  echo -e "\e[1;31m#                      ██╔████╔██║                      #\e[0m"
  echo -e "\e[1;31m#                      ██║╚██╔╝██║                      #\e[0m"
  echo -e "\e[1;31m#                      ██║ ╚═╝ ██║                      #\e[0m"
  echo -e "\e[1;31m#                      ╚═╝     ╚═╝                      #\e[0m"
  echo -e "\e[1;31m#                                                       #\e[0m"
  echo -e "\e[1;31m#                   M E Y S A M S H 1 0 9 2             #\e[0m"
  echo -e "\e[1;31m#########################################################\e[0m"
  echo ""
}

install_script() {
  echo "Enter the size of the file (default is 5 GB):"
  read -r INPUT_MAX_SIZE
  if [[ -z "$INPUT_MAX_SIZE" ]]; then
    INPUT_MAX_SIZE=5
  fi

  MAX_SIZE=$((INPUT_MAX_SIZE * 1024 * 1024 * 1024))

  echo "Installing required packages..."
  apt update
  apt install -y python3-requests pipx python3-sqlite3 python3-pip screen
  pipx install sqlite3
  pip3 install python-telegram-bot "python-telegram-bot==13.5" telegram-send
  
  echo "Downloading and setting up blocker.py..."
  cd $LOG_DIR || exit
  wget https://raw.githubusercontent.com/meysamsh1092/tor/main/blocker.py

  echo "Creating $LOG_SCRIPT_PATH ..."
  cat <<EOT > $LOG_SCRIPT_PATH
#!/bin/bash
/usr/bin/tail -f /usr/local/x-ui/access.log >> >> $LOG_FILE
EOT
  chmod +x $LOG_SCRIPT_PATH

  echo "Creating $TAIL_SERVICE_PATH ..."
  cat <<EOT > $TAIL_SERVICE_PATH
[Unit]
Description=Tail Access Log and Redirect to File
[Service]
ExecStart=$LOG_SCRIPT_PATH
Restart=always
StandardOutput=append:$LOG_FILE
StandardError=inherit
[Install]
WantedBy=multi-user.target
EOT

  echo "Activating tail-log.service ..."
  systemctl daemon-reload
  systemctl enable tail-log.service
  systemctl start tail-log.service

  echo "Creating $ROTATE_SCRIPT_PATH ..."
  cat <<EOT > $ROTATE_SCRIPT_PATH
#!/bin/bash

LOG_FILE="$LOG_FILE"
BACKUP_FILE="$LOG_DIR/log_backup.txt"
ACCESS_LOG_FILE="/usr/local/x-ui/access.log"

MAX_SIZE=$MAX_SIZE

if [ -f "\$LOG_FILE" ]; then
    FILE_SIZE=\$(stat -c%s "\$LOG_FILE")
    if [ \$FILE_SIZE -ge \$MAX_SIZE ]; then
        if [ -f "\$BACKUP_FILE" ]; then
            rm -f "\$BACKUP_FILE"
        fi
        cp "\$LOG_FILE" "\$BACKUP_FILE"
        > "\$LOG_FILE"
        echo >> /var/log/rotate_logs.log
    fi
else
    echo "\$(date): Log file not found: \$LOG_FILE" >> /var/log/rotate_logs.log
fi

if [ -f "\$ACCESS_LOG_FILE" ]; then
    ACCESS_FILE_SIZE=\$(stat -c%s "\$ACCESS_LOG_FILE")
    if [ \$ACCESS_FILE_SIZE -ge \$MAX_SIZE ]; then
        > "\$ACCESS_LOG_FILE"
        echo "\$(date): Access log file cleared." >> /var/log/rotate_logs.log
        sleep 5
        systemctl restart x-ui.service
        echo "\$(date): Xray service restarted." >> /var/log/rotate_logs.log
    fi
else
    echo "\$(date): Access log file not found: \$ACCESS_LOG_FILE" >> /var/log/rotate_logs.log
fi
EOT
  chmod +x $ROTATE_SCRIPT_PATH

  echo "Creating $ROTATE_SERVICE_PATH ..."
  cat <<EOT > $ROTATE_SERVICE_PATH
[Unit]
Description=Log Rotation Service
[Service]
ExecStart=$ROTATE_SCRIPT_PATH
Type=oneshot
[Install]
WantedBy=multi-user.target
EOT

  echo "Creating $ROTATE_TIMER_PATH ..."
  cat <<EOT > $ROTATE_TIMER_PATH
[Unit]
Description=Timer for Log Rotation Service

[Timer]
OnBootSec=5min
OnUnitActiveSec=1440min

[Install]
WantedBy=timers.target
EOT

  echo "Enabling log-rotate services..."
  systemctl daemon-reload
  systemctl enable log-rotate.service
  systemctl enable log-rotate.timer
  systemctl start log-rotate.timer
  systemctl start log-rotate.service

  echo "Creating /etc/systemd/system/torrentblocker.service ..."
  cat <<EOT > /etc/systemd/system/torrentblocker.service
[Unit]
Description= torrent blocker Service

[Service]
Type=simple
ExecStart=/usr/bin/python3 $LOG_DIR/blocker.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOT

  echo "Starting torrentblocker.service ..."
  systemctl daemon-reload
  systemctl enable torrentblocker.service
  systemctl start torrentblocker.service

  echo "Installation completed successfully."
  echo -e "\nPress Enter to return to the menu."
  read -r
}

change_file_size() {
  echo "Please enter the new file size (in GB):"
  read -r NEW_MAX_SIZE

  if [[ -z "$NEW_MAX_SIZE" ]]; then
    echo "Volume is not entered. The operation was canceled."
    return
  fi

  NEW_MAX_SIZE_BYTES=$((NEW_MAX_SIZE * 1024 * 1024 * 1024))
  sed -i "s/MAX_SIZE=.*/MAX_SIZE=$NEW_MAX_SIZE_BYTES/" $ROTATE_SCRIPT_PATH
  echo "The new volume has been set: $NEW_MAX_SIZE GB"
  echo -e "\nPress Enter to return to the menu."
  read -r
}

restart_service() {
  systemctl restart torrentblocker.service
  systemctl restart log-rotate.service
  systemctl restart tail-log.service
  echo "All services are restarted"
  echo -e "\nPress Enter to return to the menu."
  read -r
}

search_logs() {
  echo "Please enter the word you want to search:"
  read -r SEARCH_TERM

  if [[ -z "$SEARCH_TERM" ]]; then
    echo "No words have been entered. The operation was canceled."
    return
  fi

  echo "Search results for: '$SEARCH_TERM':"
  grep "$SEARCH_TERM" $LOG_FILE
  echo -e "\nPress Enter to return to the menu."
  read -r
}

update_variables() {
  PYTHON_FILE="$LOG_DIR/blocker.py"

  if [ ! -f "$PYTHON_FILE" ]; then
    echo "The file $PYTHON_FILE does not exist."
    return
  fi

  echo "Enter new bot_token:"
  read -r NEW_BOT_TOKEN
  if [[ -z "$NEW_BOT_TOKEN" ]]; then
    echo "No bot_token entered. Operation cancelled."
    return
  fi

  echo "Enter new channel_id:"
  read -r NEW_CHANNEL_ID
  if [[ -z "$NEW_CHANNEL_ID" ]]; then
    echo "No channel_id entered. Operation cancelled."
    return
  fi

  sed -i 's/^\s*bot_token\s*=\s*".*"/    bot_token = "'"$NEW_BOT_TOKEN"'"/' "$PYTHON_FILE"
  sed -i 's/^\s*channel_id\s*=\s*".*"/    channel_id = "'"$NEW_CHANNEL_ID"'"/' "$PYTHON_FILE"

  echo "The variables have been updated in $PYTHON_FILE."
  echo -e "\nPress Enter to return to the menu."
  read -r
}

delete_script() {
  echo "Are you sure you want to delete all services and the following files? (yes/no)"
  read -r CONFIRMATION

  if [[ "$CONFIRMATION" != "yes" ]]; then
    echo "Operation cancelled."
    return
  fi

  echo "Stopping and disabling torrentblocker.service..."
  systemctl stop torrentblocker.service
  systemctl disable torrentblocker.service
  rm -f /etc/systemd/system/torrentblocker.service

  echo "Stopping and disabling log-rotate.service..."
  systemctl stop log-rotate.service
  systemctl disable log-rotate.service
  rm -f /etc/systemd/system/log-rotate.service  

  echo "Removing log-rotate.timer and service..."
  systemctl stop log-rotate.service
  systemctl disable log-rotate.timer
  rm -f $ROTATE_TIMER_PATH
  rm -f $ROTATE_SERVICE_PATH

  echo "Deleting specific files in $LOG_DIR..."
  rm -f $LOG_FILE
  rm -f $ROTATE_SCRIPT_PATH
  rm -f $LOG_SCRIPT_PATH
  rm -f "$LOG_DIR/blocker.py"

  echo "Reloading systemd daemon..."
  systemctl daemon-reload
  
  echo "All specified files and services have been successfully deleted."
  echo -e "\nPress Enter to return to the menu."
  read -r
}

# منو
while true; do
  clear
  show_logo
  echo "Please choose:"
  echo "1) Install"
  echo "2) Resize File"
  echo "3) Search Logs"
  echo "4) Update bot_token and channel_id"
  echo "5) Delete Services and Files"
  echo "6) Restart service"
  echo "7) Exit"
  read -rp "Choice: " CHOICE

  case $CHOICE in
  1) install_script ;;
  2) change_file_size ;;
  3) search_logs ;;
  4) update_variables ;;
  5) delete_script ;;
  6) restart_service ;;
  7) echo "Exit"; break ;;
  *) echo "Invalid choice. Please try again." ;;
  esac
done
