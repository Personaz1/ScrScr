#!/bin/bash

# Самораспаковывающийся установщик SSH Password Interceptor
# Это скрипт распаковывает все необходимые файлы и предлагает установку

echo "==================================="
echo "  SSH Password Interceptor v1.0"
echo "==================================="
echo "Самораспаковывающийся установщик"
echo ""

# Создаем временную директорию для распаковки
TMP_DIR=$(mktemp -d)
echo "Распаковка файлов во временную директорию..."

# Ищем метку начала архива в этом скрипте
ARCHIVE_START=$(awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' $0)

# Распаковываем файлы из архива
tail -n+$ARCHIVE_START $0 | tar xz -C "$TMP_DIR"

echo "Файлы успешно распакованы."
echo ""

# Переходим во временную директорию
cd "$TMP_DIR"

# Определяем операционную систему и настраиваем файлы
echo "Определение операционной системы и настройка файлов..."
./mac_linux_adapter.sh

echo ""
echo "Выберите действие:"
echo "1. Установить в систему (требуются права root)"
echo "2. Скомпилировать локально для текущего пользователя"
echo "3. Просто распаковать файлы в текущую директорию"
echo "4. Выход без установки"

read -p "Ваш выбор (1-4): " choice

case $choice in
  1)
    echo "Запуск установки в систему..."
    if [ "$EUID" -ne 0 ]; then
      echo "Для установки требуются права администратора."
      echo "Запустите скрипт с sudo: sudo $0"
      cd - > /dev/null
      rm -rf "$TMP_DIR"
      exit 1
    fi
    
    # Запускаем системный установщик
    ./installer.sh
    
    # Возвращаемся в исходную директорию и удаляем временные файлы
    cd - > /dev/null
    rm -rf "$TMP_DIR"
    ;;
    
  2)
    echo "Запуск локальной компиляции..."
    # Создаем директорию в домашнем каталоге
    INSTALL_DIR="$HOME/ssh_inject"
    mkdir -p "$INSTALL_DIR"
    
    # Копируем все файлы
    cp -r ./* "$INSTALL_DIR/"
    
    echo "Файлы скопированы в $INSTALL_DIR/"
    echo "Компиляция библиотеки..."
    
    cd "$INSTALL_DIR"
    # Компилируем без прав root
    if [[ "$(uname -s)" == "Darwin" ]]; then
      clang++ -shared -fPIC -o libssh_inject.dylib src/ssh_inject/ssh_inject.cpp -ldl
      echo ""
      echo "Библиотека скомпилирована: $INSTALL_DIR/libssh_inject.dylib"
      echo ""
      echo "Для использования выполните команду:"
      echo "DYLD_INSERT_LIBRARIES=$INSTALL_DIR/libssh_inject.dylib ssh user@server"
    else
      g++ -shared -fPIC -o libssh_inject.so src/ssh_inject/ssh_inject.cpp -ldl
      echo ""
      echo "Библиотека скомпилирована: $INSTALL_DIR/libssh_inject.so"
      echo ""
      echo "Для использования выполните команду:"
      echo "LD_PRELOAD=$INSTALL_DIR/libssh_inject.so ssh user@server"
    fi
    
    # Возвращаемся и удаляем временные файлы
    cd - > /dev/null
    rm -rf "$TMP_DIR"
    ;;
    
  3)
    echo "Распаковка файлов в текущую директорию..."
    CURRENT_DIR=$(pwd)
    TARGET_DIR="$CURRENT_DIR/ssh_inject"
    
    # Возвращаемся в исходную директорию
    cd - > /dev/null
    
    # Создаем директорию для файлов
    mkdir -p "$TARGET_DIR"
    
    # Копируем все файлы из временной директории
    cp -r "$TMP_DIR"/* "$TARGET_DIR/"
    
    echo "Файлы распакованы в $TARGET_DIR/"
    echo "Для компиляции перейдите в эту директорию и выполните:"
    echo "cd $TARGET_DIR"
    echo "./compile.sh"
    
    # Удаляем временные файлы
    rm -rf "$TMP_DIR"
    ;;
    
  4)
    echo "Выход без установки."
    cd - > /dev/null
    rm -rf "$TMP_DIR"
    ;;
    
  *)
    echo "Неверный выбор. Выход без установки."
    cd - > /dev/null
    rm -rf "$TMP_DIR"
    ;;
esac

echo ""
echo "Спасибо за использование SSH Password Interceptor!"
exit 0

# Здесь начинается архив с файлами
__ARCHIVE_BELOW__ 