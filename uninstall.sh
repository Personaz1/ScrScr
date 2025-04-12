#!/bin/bash

# SSH Password Sniffer Uninstallation Script
# Removes all components and configuration

# Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m"

echo -e "${BLUE}SSH Sniffer Uninstaller${NC}"
echo "Removing userspace monitoring components..."

# Hidden directory path
HIDDEN_DIR="$HOME/.hidden"

# Remove from profile files
echo -e "${BLUE}[1/5]${NC} Cleaning profile hooks..."

# Clean .bashrc
if [ -f "$HOME/.bashrc" ]; then
    # Create backup first
    cp "$HOME/.bashrc" "$HOME/.bashrc.bak"
    
    # Remove our entries
    sed -i '/# Update SSH client library path/,/# End update/d' "$HOME/.bashrc"
    echo "Cleaned .bashrc"
fi

# Clean .zshrc
if [ -f "$HOME/.zshrc" ]; then
    # Create backup first
    cp "$HOME/.zshrc" "$HOME/.zshrc.bak"
    
    # Remove our entries
    sed -i '/# Update SSH client library path/,/# End update/d' "$HOME/.zshrc"
    echo "Cleaned .zshrc"
fi

# Clean SSH rc file
echo -e "${BLUE}[2/5]${NC} Cleaning SSH server hooks..."
if [ -f "$HOME/.ssh/rc" ]; then
    # Back up the file
    cp "$HOME/.ssh/rc" "$HOME/.ssh/rc.bak"
    
    # Remove our entries or the entire file if it only contains our hook
    if [ $(wc -l < "$HOME/.ssh/rc") -le 4 ] && grep -q "libsshd_sniff.so" "$HOME/.ssh/rc"; then
        rm "$HOME/.ssh/rc"
        echo "Removed SSH rc file"
    else
        sed -i '/libsshd_sniff.so/d' "$HOME/.ssh/rc"
        echo "Cleaned SSH rc file"
    fi
fi

# Clean crontab entries
echo -e "${BLUE}[3/5]${NC} Removing crontab entries..."
crontab -l 2>/dev/null | grep -v "libssh_sniff.so" | grep -v "libsshd_sniff.so" | crontab -
echo "Cleaned crontab"

# Clean bash_aliases if exists
if [ -f "$HOME/.bash_aliases" ]; then
    sed -i '/# SSH compatibility alias/d' "$HOME/.bash_aliases"
    sed -i '/alias ssh=.*libssh_sniff.so/d' "$HOME/.bash_aliases"
    echo "Cleaned bash aliases"
fi

# Handle logs
echo -e "${BLUE}[4/5]${NC} Handling log files..."
echo "Log files contain captured credentials."
echo "1) Keep logs and libraries (for review later)"
echo "2) Keep only logs, remove libraries"
echo "3) Remove everything (secure cleanup)"
echo -n "Choose an option (1-3): "
read -r choice

case $choice in
    1)
        echo "Keeping all files in $HIDDEN_DIR"
        ;;
    2)
        echo "Removing library files, keeping logs"
        rm -f "$HIDDEN_DIR/libssh_sniff.so" "$HIDDEN_DIR/libsshd_sniff.so"
        ;;
    3)
        echo "Performing complete removal"
        rm -rf "$HIDDEN_DIR"
        echo "All files removed"
        ;;
    *)
        echo "Invalid option, keeping files for safety"
        ;;
esac

# Reset LD_PRELOAD
echo -e "${BLUE}[5/5]${NC} Cleaning environment..."
LD_PRELOAD=$(echo $LD_PRELOAD | sed 's|'$HIDDEN_DIR'/libssh_sniff.so:\?||g' | sed 's|'$HIDDEN_DIR'/libsshd_sniff.so:\?||g')
export LD_PRELOAD

# Compile cleanup
if [ -f "libssh_sniff.so" ]; then
    rm -f libssh_sniff.so libsshd_sniff.so
    echo "Removed compiled libraries from current directory"
fi

# Done
echo -e "${GREEN}Uninstallation complete!${NC}"
echo "Note: You need to log out and log back in for all changes to take effect." 