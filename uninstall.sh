#!/bin/bash

# Скрипт для удаления SSH Password Interceptor (локальная версия)

echo "Удаление SSH Password Interceptor..."

# Очистка переменной LD_PRELOAD
echo "- Сброс LD_PRELOAD (только для текущей сессии)"
unset LD_PRELOAD
export LD_PRELOAD=

# Удаление лог-файла
if [ -f /tmp/ssh_inj.dbg ]; then
    rm -f /tmp/ssh_inj.dbg
    echo "- Лог-файл удален"
else
    echo "- Лог-файл не найден"
fi

# Очистка скомпилированных файлов
echo "- Удаление скомпилированных файлов"
make clean

echo ""
echo "Удаление SSH Password Interceptor завершено!" 