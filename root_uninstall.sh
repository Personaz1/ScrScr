#!/bin/bash

# SSH Root Password Sniffer Uninstaller
# Удаляет системный перехватчик

# Проверка наличия прав root
if [ "$(id -u)" != "0" ]; then
    echo "Этот скрипт должен быть запущен с правами root"
    exit 1
fi

echo "Удаление SSH Root Password Sniffer..."

# Удаление из /etc/ld.so.preload
if [ -f "/etc/ld.so.preload" ]; then
    echo "[1/3] Очистка системного предзагрузчика..."
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
echo "[2/3] Удаление библиотеки..."
rm -f /usr/lib/libssh_root_inject.so

# Обработка лог-файла
echo "[3/3] Обработка логов..."
echo "Что вы хотите сделать с лог-файлом паролей (/var/log/.ssh_passwd.log)?"
echo "1) Оставить лог-файл"
echo "2) Удалить лог-файл (все записанные пароли будут удалены)"
echo -n "Выберите вариант (1/2): "
read choice

if [ "$choice" = "2" ]; then
    rm -f /var/log/.ssh_passwd.log
    echo "Лог-файл удален"
else
    echo "Лог-файл сохранен: /var/log/.ssh_passwd.log"
fi

echo "Удаление завершено!" 