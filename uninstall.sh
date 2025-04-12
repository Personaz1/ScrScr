#!/bin/bash

# Скрипт для удаления libssh_inject.so из системы

# Проверка root прав
if [ "$EUID" -ne 0 ]; then
  echo "Для удаления библиотеки требуются права администратора."
  echo "Запустите скрипт с sudo: sudo ./uninstall.sh"
  exit 1
fi

LIBRARY_PATH="/usr/lib/libssh_inject.so"

# Проверка наличия библиотеки
if [ ! -f "$LIBRARY_PATH" ]; then
  echo "Библиотека $LIBRARY_PATH не найдена."
  echo "Возможно, она уже была удалена или установлена в другое место."
else
  # Удаление библиотеки
  echo "Удаление библиотеки $LIBRARY_PATH..."
  rm -f "$LIBRARY_PATH"
  if [ ! -f "$LIBRARY_PATH" ]; then
    echo "Библиотека успешно удалена."
  else
    echo "Ошибка: не удалось удалить библиотеку $LIBRARY_PATH."
    exit 1
  fi
fi

# Проверка и очистка /etc/ld.so.preload
if [ -f /etc/ld.so.preload ]; then
  echo "Проверка файла /etc/ld.so.preload..."
  
  # Создаем резервную копию
  cp /etc/ld.so.preload /etc/ld.so.preload.uninstall.bak
  echo "Создана резервная копия: /etc/ld.so.preload.uninstall.bak"
  
  # Проверяем, содержит ли файл ссылку на нашу библиотеку
  if grep -q "libssh_inject.so" /etc/ld.so.preload; then
    echo "Удаление записи о библиотеке из /etc/ld.so.preload..."
    # Создаем временный файл с удаленной строкой
    grep -v "libssh_inject.so" /etc/ld.so.preload > /etc/ld.so.preload.tmp
    
    # Если временный файл пустой, удаляем ld.so.preload
    if [ ! -s /etc/ld.so.preload.tmp ]; then
      rm -f /etc/ld.so.preload
      rm -f /etc/ld.so.preload.tmp
      echo "Файл /etc/ld.so.preload был очищен и удален."
    else
      # Иначе заменяем старый файл новым
      mv /etc/ld.so.preload.tmp /etc/ld.so.preload
      echo "Запись о библиотеке удалена из /etc/ld.so.preload."
    fi
  else
    echo "Запись о библиотеке не найдена в /etc/ld.so.preload."
  fi
else
  echo "Файл /etc/ld.so.preload не найден, очистка не требуется."
fi

# Спрашиваем, нужно ли удалять лог-файл
echo ""
echo -n "Удалить файл логов /tmp/ssh_inj.dbg? [y/N]: "
read delete_logs

if [[ "$delete_logs" =~ ^[Yy]$ ]]; then
  rm -f /tmp/ssh_inj.dbg
  echo "Файл логов удален."
else
  echo "Файл логов сохранен: /tmp/ssh_inj.dbg"
fi

echo ""
echo "Удаление завершено."
echo "ВНИМАНИЕ: Если вы перезапустите систему или выполните ldconfig,"
echo "изменения вступят в силу немедленно. В противном случае,"
echo "библиотека может оставаться в памяти для текущих процессов." 