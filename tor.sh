#!/bin/bash

# مسیری که اسکریپت‌ها و سرویس‌ها باید ساخته شوند
LOG_SCRIPT_PATH="/usr/local/x-ui/tail-log.sh"
ROTATE_SCRIPT_PATH="/usr/local/x-ui/rotate_logs.sh"
TAIL_SERVICE_PATH="/etc/systemd/system/tail-log.service"
ROTATE_SERVICE_PATH="/etc/systemd/system/log-rotate.service"
ROTATE_TIMER_PATH="/etc/systemd/system/log-rotate.timer"

mkdir -p /usr/local/x-ui

# 1. create file tail-log.sh
echo "create file: $LOG_SCRIPT_PATH ..."
cat <<EOT > $LOG_SCRIPT_PATH
#!/bin/bash
/usr/bin/tail -f /usr/local/x-ui/access.log >> /usr/local/x-ui/log.txt
EOT
chmod +x $LOG_SCRIPT_PATH
echo " $LOG_SCRIPT_PATH was created."

# ۲. create services tail-log.service
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
echo " $TAIL_SERVICE_PATH was created."

# ۳. Activation tail-log
echo "Activation tail-log.service ..."
systemctl daemon-reload
systemctl enable tail-log.service
systemctl start tail-log.service
echo " tail-log was activated ."

# 4. Create file rotate_logs.sh
echo "create file $ROTATE_SCRIPT_PATH ..."
cat <<EOT > $ROTATE_SCRIPT_PATH
#!/bin/bash

LOG_FILE="/usr/local/x-ui/log.txt"
BACKUP_FILE="/usr/local/x-ui/log_backup.txt"
ACCESS_LOG_FILE="/usr/local/x-ui/access.log"

MAX_SIZE=\$((5 * 1024 * 1024 * 1024))

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
echo " $ROTATE_SCRIPT_PATH was created."

# 5. Create log-rotate.service
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
echo " $ROTATE_SERVICE_PATH was created."

# 6. Create timer log-rotate.timer
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
echo " $ROTATE_TIMER_PATH was created."

# 7. Activation and start of service and timer log-rotate
echo "Enabling log-rotate ..."
systemctl daemon-reload
systemctl enable log-rotate.service
systemctl enable log-rotate.timer
systemctl start log-rotate.timer
systemctl start log-rotate.service
echo "log-rotate was activated "

echo "All done"
