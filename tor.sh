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

LOG_SCRIPT_PATH="/usr/local/x-ui/tail-log.sh"
ROTATE_SCRIPT_PATH="/usr/local/x-ui/rotate_logs.sh"
TAIL_SERVICE_PATH="/etc/systemd/system/tail-log.service"
ROTATE_SERVICE_PATH="/etc/systemd/system/log-rotate.service"
ROTATE_TIMER_PATH="/etc/systemd/system/log-rotate.timer"
LOG_FILE="/usr/local/x-ui/log.txt"

install_script() {
  echo "Enter the size of the file (default is 5 GB):"
  read -r INPUT_MAX_SIZE

  if [[ -z "$INPUT_MAX_SIZE" ]]; then
    INPUT_MAX_SIZE=5
  fi

  MAX_SIZE=$((INPUT_MAX_SIZE * 1024 * 1024 * 1024))
 
 cd  /usr/local/x-ui/| exit
 wget -O https://github.com/Meysamsh1092/tor/blocker.py
 echo "file downloaded"
 chmod +x blocker.py
 
 mkdir -p /usr/local/x-ui

  echo "create file: $LOG_SCRIPT_PATH ..."
  cat <<EOT > $LOG_SCRIPT_PATH
#!/bin/bash
/usr/bin/tail -f /usr/local/x-ui/access.log >> /usr/local/x-ui/log.txt
EOT
  chmod +x $LOG_SCRIPT_PATH

  echo "create file: $TAIL_SERVICE_PATH ..."
  cat <<EOT > $TAIL_SERVICE_PATH
[Unit]
Description=Tail Access Log and Redirect to File
[Service]
ExecStart=/usr/local/x-ui/tail-log.sh
Restart=always
StandardOutput=append:/usr/local/x-ui/log.txt
StandardError=inherit
[Install]
WantedBy=multi-user.target
EOT

  echo "Activation tail-log.service ..."
  systemctl daemon-reload
  systemctl enable tail-log.service
  systemctl start tail-log.service

  echo "create file $ROTATE_SCRIPT_PATH ..."
  cat <<EOT > $ROTATE_SCRIPT_PATH
#!/bin/bash

LOG_FILE="/usr/local/x-ui/log.txt"
BACKUP_FILE="/usr/local/x-ui/log_backup.txt"
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
        echo "\$(date): Log file rotated." >> /var/log/rotate_logs.log
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

  echo "create file: $ROTATE_SERVICE_PATH ..."
  cat <<EOT > $ROTATE_SERVICE_PATH
[Unit]
Description=Log Rotation Service
[Service]
ExecStart=/usr/local/x-ui/rotate_logs.sh
Type=oneshot
[Install]
WantedBy=multi-user.target
EOT

  echo "create file: $ROTATE_TIMER_PATH ..."
  cat <<EOT > $ROTATE_TIMER_PATH
[Unit]
Description=Timer for Log Rotation Service

[Timer]
OnBootSec=5min
OnUnitActiveSec=1440min

[Install]
WantedBy=timers.target
EOT

  echo "Enabling log-rotate ..."
  systemctl daemon-reload
  systemctl enable log-rotate.service
  systemctl enable log-rotate.timer
  systemctl start log-rotate.timer
  systemctl start log-rotate.service

  echo "Installation completed successfully."
}


change_file_size() {
  echo "Please enter the new file size (in GB).:"
  read -r NEW_MAX_SIZE

  if [[ -z "$NEW_MAX_SIZE" ]]; then
    echo "Volume is not entered. The operation was canceled."
    return
  fi

  NEW_MAX_SIZE_BYTES=$((NEW_MAX_SIZE * 1024 * 1024 * 1024))
  sed -i "s/MAX_SIZE=.*/MAX_SIZE=$NEW_MAX_SIZE_BYTES/" $ROTATE_SCRIPT_PATH
  echo "The new volume has been set: $NEW_MAX_SIZE"
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
}

#Menu
while true; do
  echo "Please choose:"
  echo "1) install"
  echo "2) resize"
  echo "3) search"
  echo "4) exit"
  read -rp "Choice: " CHOICE

  case $CHOICE in
  1)
    install_script
    ;;
  2)
    change_file_size
    ;;
  3)
    search_logs
    ;;
  4)
    echo "Exit"
    break
    ;;
  *)
    echo "try again"
    ;;
  esac
done
