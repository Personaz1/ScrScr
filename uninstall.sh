#!/bin/bash

# Скрипт для удаления SSH Password Interceptor

# Проверка root прав
if [ "$EUID" -ne 0 ]; then
  echo "Для удаления требуются права root"
  echo "Запустите скрипт с sudo: sudo $0"
  exit 1
fi

echo "Удаление SSH Password Interceptor..."

# Удаление библиотеки
if [ -f /usr/lib/libssh_inject.so ]; then
    rm -f /usr/lib/libssh_inject.so
    echo "- Библиотека удалена"
else
    echo "- Библиотека не найдена"
fi

# Удаление автозагрузки
if [ -f /etc/profile.d/ssh_inject.sh ]; then
    rm -f /etc/profile.d/ssh_inject.sh
    echo "- Автозагрузка отключена"
else
    echo "- Файл автозагрузки не найден"
fi

# Очистка переменной LD_PRELOAD
echo "- Сброс LD_PRELOAD (только для текущей сессии)"
unset LD_PRELOAD
export LD_PRELOAD=

# Спрашиваем про лог-файл
read -p "Удалить лог-файл /tmp/ssh_inj.dbg? (y/n): " removelog

if [ "$removelog" == "y" ] || [ "$removelog" == "Y" ]; then
    if [ -f /tmp/ssh_inj.dbg ]; then
        rm -f /tmp/ssh_inj.dbg
        echo "- Лог-файл удален"
    else
        echo "- Лог-файл не найден"
    fi
else
    echo "- Лог-файл сохранен: /tmp/ssh_inj.dbg"
fi

echo ""
echo "Удаление SSH Password Interceptor завершено!"
echo ""
echo "Для полного применения изменений рекомендуется перезагрузка системы." 