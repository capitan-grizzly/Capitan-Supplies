#!/bin/bash

# Read this before running the script; here's what you need to know:
# --- PROBLEM 1: Password in a visible file ---
# --- PROBLEM 2: /etc/shadow readable by others ---
# --- PROBLEM 3: ghost's home directory accessible by everyone ---
# --- PROBLEM 4: Sensitive file with incorrect permissions ---
# --- PROBLEM 5: Executable script by everyone with sensitive content ---
# --- PROBLEM 6: Sudoers with a dangerous entry ---
# --- PROBLEM 7: File with unnecessary SUID bit ---
# --- PROBLEM 8: /tmp directory with sticky bit removed ---
# --- PROBLEM 9: Log file with write permissions for everyone ---
# --- PROBLEM 10: ghost user with no password ---


# Run script: 
# 1. nano Linux_firstblock.sh
# 2. chmod +x Linux_firstblock.sh
# 3. sudo ./Linux_firstblock.sh -s

# Capitan note: Just read the challenges before you can't solve anything

echo "[*] Setting up the exam environment..."

# --- USERS ---
useradd -m -s /bin/bash auditor
useradd -m -s /bin/bash developer
useradd -m -s /bin/bash ghost
echo "auditor:auditor123" | chpasswd
echo "developer:dev2024" | chpasswd
echo "ghost:ghost123" | chpasswd


echo "developer:dev2024" > /home/developer/my_credentials.txt
chmod 644 /home/developer/my_credentials.txt

chmod 644 /etc/shadow

chmod 777 /home/ghost

echo "DB_PASSWORD=supersecret123" > /etc/app.conf
chmod 646 /etc/app.conf

mkdir -p /opt/scripts
echo '#!/bin/bash
# Backup script
cp -r /home /tmp/backup_homes
echo "Backup completed by: $(whoami)"' > /opt/scripts/backup.sh
chmod 777 /opt/scripts/backup.sh

echo "developer ALL=(ALL) NOPASSWD: /bin/cp" >> /etc/sudoers

cp /bin/bash /tmp/shell_test
chmod u+s /tmp/shell_test

chmod 777 /tmp

touch /var/log/app.log
chmod 666 /var/log/app.log

passwd -d ghost

echo ""
echo "[+] Environment ready. You have 10 security issues to find."
echo "[+] Submit a report with: what you found, why it is an issue, and how to fix it."
echo ""
