#!/bin/bash

# SSH Password Interceptor - Скрипт деинсталляции
# Версия 1.1.0

echo "====================================="
echo "   SSH Password Interceptor v1.1.0"
echo "         Деинсталляция"
echo "====================================="
echo ""

# Проверка привилегий root
if [ "$(id -u)" != "0" ]; then
    echo "Ошибка: для деинсталляции требуются привилегии администратора."
    echo "Запустите скрипт с sudo: sudo ./uninstall.sh"
    exit 1
fi

# Проверка операционной системы
OS=$(uname -s)
if [ "$OS" != "Linux" ]; then
    echo "Ошибка: автоматическая деинсталляция поддерживается только для Linux."
    exit 1
fi

# Определение имени библиотеки
LIB_NAME="libssh_inject.so"
LIB_PATH="/usr/lib/$LIB_NAME"

# Проверка наличия библиотеки
if [ -f "$LIB_PATH" ]; then
    echo "Удаление библиотеки $LIB_PATH..."
    rm -f "$LIB_PATH"
    echo "Библиотека удалена."
else
    echo "Библиотека $LIB_PATH не найдена."
fi

# Обработка файла /etc/ld.so.preload
if [ -f "/etc/ld.so.preload" ]; then
    echo "Проверка настроек автозагрузки..."
    
    # Создаем резервную копию
    cp /etc/ld.so.preload /etc/ld.so.preload.uninstall.bak
    echo "Создана резервная копия: /etc/ld.so.preload.uninstall.bak"
    
    # Удаляем ссылку на нашу библиотеку
    if grep -q "/usr/lib/$LIB_NAME" /etc/ld.so.preload; then
        grep -v "/usr/lib/$LIB_NAME" /etc/ld.so.preload > /etc/ld.so.preload.new
        mv /etc/ld.so.preload.new /etc/ld.so.preload
        echo "Ссылка на библиотеку удалена из /etc/ld.so.preload"
        
        # Если файл пустой, можно его удалить
        if [ ! -s /etc/ld.so.preload ]; then
            rm -f /etc/ld.so.preload
            echo "Файл /etc/ld.so.preload пуст и был удален."
        fi
    else
        echo "Библиотека не была настроена для автозагрузки."
    fi
else
    echo "Файл /etc/ld.so.preload не найден."
fi

# Предлагаем удалить лог-файл
echo ""
read -p "Удалить файл логов (/tmp/ssh_inj.dbg)? (y/n): " choice

if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
    if [ -f "/tmp/ssh_inj.dbg" ]; then
        rm -f /tmp/ssh_inj.dbg
        echo "Файл логов удален."
    else
        echo "Файл логов не найден."
    fi
else
    echo "Файл логов сохранен."
fi

echo ""
echo "Деинсталляция завершена успешно!"
echo "" 