import requests
import sqlite3
import socket
import time
import re
import os

def get_machine_ip():
    try:
        # Connect to a public server to determine the IP
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            # Use Google's public DNS server IP and a random port
            s.connect(("8.8.8.8", 80))
            ip_address = s.getsockname()[0]
        return ip_address
    except socket.error as e:
        return f"Error: {e}"

def get_hostname_and_ip():
    hostname = socket.gethostname()    
    try:
        # Connect to a public server to determine the IP
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            # Use Google's public DNS server IP and a random port
            s.connect(("8.8.8.8", 80))
            ip_address = s.getsockname()[0]
        return hostname, ip_address
    except socket.error as e:
        print(f"Error: {e}")
        return "err", "err"
    

def detect_torrent_email(line):
    pattern = r"\[.*?BLOCK-TORRENT.*?\].*?email:\s(\S+)"
    match = re.search(pattern, line)
    if match:
        return match.group(1)
    return None


def disable_user(email):
    conn = sqlite3.connect(db_address)
    c = conn.cursor()

    # Check if the enable field is already 0
    c.execute(f"SELECT enable FROM client_traffics WHERE email=?", (email,))
    result = c.fetchone()

    if result and result[0] == 0:
        print("User is already disabled. No action needed.")
        rres = False
    else:
        # Update the enable field to 0
        c.execute(f"UPDATE client_traffics SET enable=0 WHERE email=?", (email,))
        conn.commit()
        print("User disabled. Restarting x-ui service.")
        os.popen("x-ui restart")
        rres = True

    conn.close()
    return rres


def send_to_telegram(bot_token, channel_id, message):
    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    payload = {"chat_id": channel_id, "text": message}
    response = requests.post(url, json=payload)

    if response.status_code != 200:
        print(
            f"Failed to send message: {message}. Status code: {response.status_code}, Response: {response.text}"
        )


def process_log_file(file_path, sleep_time, channel_id, bot_token):
    while True:
        with open(file_path, "r+") as log_file:
            lines = log_file.readlines()
            log_file.seek(0)
            log_file.truncate()

            for line in lines:
                email = detect_torrent_email(line)
                if email:
                    print(f"Found: {email}")
                    system_host, system_ip = get_hostname_and_ip()
                    mes = f"host: {system_host}\nip: {system_ip}\nuser: {email}"
                    if disable_user(email):
                        send_to_telegram(bot_token, channel_id, mes)

        time.sleep(sleep_time)


if __name__ == "__main__":
    log_file_path = "/usr/local/x-ui/access.log"
    sleep_time = 5
    bot_token = "6825002470:AAG4hKqDFB9jXhFxLQHuAfxOvU3s-HI"
    channel_id = "-1002461488"
    db_address = "/etc/x-ui/x-ui.db"

    process_log_file(log_file_path, sleep_time, channel_id, bot_token)

