#!/bin/bash

# مسیری که اسکریپت‌ها و سرویس‌ها باید ساخته شوند
LOG_SCRIPT_PATH="/usr/local/x-ui/tail-log.sh"
ROTATE_SCRIPT_PATH="/usr/local/x-ui/rotate_logs.sh"
TAIL_SERVICE_PATH="/etc/systemd/system/tail-log.service"
ROTATE_SERVICE_PATH="/etc/systemd/system/log-rotate.service"
ROTATE_TIMER_PATH="/etc/systemd/system/log-rotate.timer"

# اطمینان از وجود دایرکتوری مورد نظر
mkdir -p /usr/local/x-ui

# ۱. ایجاد فایل tail-log.sh
echo "ایجاد فایل $LOG_SCRIPT_PATH ..."
cat <<EOT > $LOG_SCRIPT_PATH
#!/bin/bash
/usr/bin/tail -f /usr/local/x-ui/access.log >> /usr/local/x-ui/log.txt
EOT
chmod +x $LOG_SCRIPT_PATH
echo "فایل $LOG_SCRIPT_PATH ایجاد شد."

# ۲. ایجاد سرویس tail-log.service
echo "ایجاد فایل $TAIL_SERVICE_PATH ..."
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
echo "فایل $TAIL_SERVICE_PATH ایجاد شد."

# ۳. فعال‌سازی و شروع سرویس tail-log
echo "فعال‌سازی سرویس tail-log.service ..."
systemctl daemon-reload
systemctl enable tail-log.service
systemctl start tail-log.service
echo "سرویس tail-log فعال شد."

# ۴. ایجاد فایل rotate_logs.sh
echo "ایجاد فایل $ROTATE_SCRIPT_PATH ..."
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
echo "فایل $ROTATE_SCRIPT_PATH ایجاد شد."

# ۵. ایجاد سرویس log-rotate.service
echo "ایجاد فایل $ROTATE_SERVICE_PATH ..."
cat <<EOT > $ROTATE_SERVICE_PATH
[Unit]
Description=Log Rotation Service
[Service]
ExecStart=/usr/local/x-ui/rotate_logs.sh
Type=oneshot

[Install]
WantedBy=multi-user.target
EOT
echo "فایل $ROTATE_SERVICE_PATH ایجاد شد."

# ۶. ایجاد تایمر log-rotate.timer
echo "ایجاد فایل $ROTATE_TIMER_PATH ..."
cat <<EOT > $ROTATE_TIMER_PATH
[Unit]
Description=Timer for Log Rotation Service

[Timer]
OnBootSec=5min
OnUnitActiveSec=1440min

[Install]
WantedBy=timers.target
EOT
echo "فایل $ROTATE_TIMER_PATH ایجاد شد."

# ۷. فعال‌سازی و شروع سرویس و تایمر log-rotate
echo "فعال‌سازی سرویس و تایمر log-rotate ..."
systemctl daemon-reload
systemctl enable log-rotate.service
systemctl enable log-rotate.timer
systemctl start log-rotate.timer
systemctl start log-rotate.service
echo "سرویس و تایمر log-rotate فعال شد."

echo "تمام مراحل با موفقیت انجام شد!"
