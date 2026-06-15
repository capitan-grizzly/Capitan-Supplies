#!/bin/bash

# Read this before running the script; here's what you need to know:
# --- PROBLEM 1: Loss of connectivity (DNS Resolution) ---
# --- PROBLEM 2: Rogue network interface ---
# --- PROBLEM 3: Suspicious open port ---
# --- PROBLEM 4: Anomalous storage consumption (Hidden space) ---
# --- PROBLEM 5: Ephemeral mount point ---

# Run script: 
# 1. nano Linux_network_lab.sh
# 2. chmod +x Linux_network_lab.sh
# 3. sudo ./Linux_network_lab.sh -s

# Capitan note: Just read the challenges before you can't solve anything

# ==========================================
# Catch Ctrl+C for clean exit
# ==========================================
trap ctrl_c INT

function ctrl_c(){
    echo -e "\n${redColour}[!] Exiting execution...${endColour}\n"
    exit 1
}

# Privilege check
if [ "$EUID" -ne 0 ]; then
    echo -e "${redColour}[!] Please run this script as root (sudo).${endColour}"
    exit 1
fi

# ==========================================
# Function: Setup the Laboratory
# ==========================================
function setup_lab() {
    echo -e "\n${blueColour}[*] Starting Network & Storage lab setup...${endColour}"

    # 1. Break DNS resolution (/etc/resolv.conf)
    echo -e "${yellowColour}[+] Altering DNS resolution...${endColour}"
    cp /etc/resolv.conf /etc/resolv.conf.backup
    echo "nameserver 127.0.0.99" > /etc/resolv.conf
    
    # 2. Create a fake network interface with a strange IP (ip a)
    echo -e "${yellowColour}[+] Configuring hidden network interface...${endColour}"
    ip link add dummy_lab type dummy 2>/dev/null
    ip addr add 10.99.99.99/24 dev dummy_lab 2>/dev/null
    ip link set dummy_lab up 2>/dev/null

    # 3. Start a "suspicious" port in the background (ss -tulpn)
    echo -e "${yellowColour}[+] Opening background ports...${endColour}"
    nohup python3 -m http.server 1337 > /dev/null 2>&1 &
    echo $! > /tmp/lab_port_pid

    # 4. Create a hidden heavy file (df -h / du -sh)
    echo -e "${yellowColour}[+] Generating temporary storage anomalies...${endColour}"
    mkdir -p /opt/.hidden_space
    # Creates a 500MB file
    dd if=/dev/zero of=/opt/.hidden_space/payload.data bs=1M count=500 2>/dev/null

    # 5. Mount a temporary filesystem in an unusual location (mount)
    echo -e "${yellowColour}[+] Creating ephemeral mount points...${endColour}"
    mkdir -p /mnt/lab_secret
    mount -t tmpfs -o size=100M tmpfs /mnt/lab_secret

    echo -e "\n${greenColour}[✔] Lab configured. Let the hunt begin!${endColour}"
    echo -e "Your objectives:"
    echo -e "  1. Identify why you have no internet (Check /etc/resolv.conf)"
    echo -e "  2. Find the rogue network interface and its IP (Use ip a)"
    echo -e "  3. Discover what service is running on port 1337 (Use ss -tulpn)"
    echo -e "  4. Locate a hidden directory in /opt consuming 500MB (Use du -sh)"
    echo -e "  5. Find a strange 100MB temporary mount (Use mount and df -h)"
}

# ==========================================
# Function: Restore the Laboratory
# ==========================================
function restore_lab() {
    echo -e "\n${blueColour}[*] Restoring the virtual machine to its original state...${endColour}"

    # 1. Restore DNS
    if [ -f /etc/resolv.conf.backup ]; then
        mv /etc/resolv.conf.backup /etc/resolv.conf
        echo -e "${greenColour}[+] DNS restored.${endColour}"
    fi

    # 2. Remove fake interface
    ip link del dummy_lab 2>/dev/null
    echo -e "${greenColour}[+] Network interface removed.${endColour}"

    # 3. Kill the open port process
    if [ -f /tmp/lab_port_pid ]; then
        kill -9 $(cat /tmp/lab_port_pid) 2>/dev/null
        rm /tmp/lab_port_pid
        echo -e "${greenColour}[+] Background processes terminated.${endColour}"
    fi

    # 4. Remove heavy file
    rm -rf /opt/.hidden_space 2>/dev/null
    echo -e "${greenColour}[+] Storage freed.${endColour}"

    # 5. Unmount and clean
    umount /mnt/lab_secret 2>/dev/null
    rm -rf /mnt/lab_secret 2>/dev/null
    echo -e "${greenColour}[+] Mount points removed.${endColour}"

    echo -e "\n${greenColour}[✔] Environment fully cleaned.${endColour}"
}

# ==========================================
# Execution menu
# ==========================================
if [ "$1" == "-s" ] || [ "$1" == "--setup" ]; then
    setup_lab
elif [ "$1" == "-r" ] || [ "$1" == "--restore" ]; then
    restore_lab
else
    echo -e "\n${yellowColour}Script usage:${endColour}"
    echo -e "  sudo $0 -s  | --setup    -> Sets up the broken environment for practice"
    echo -e "  sudo $0 -r  | --restore  -> Cleans the environment and restores normalcy\n"
fi