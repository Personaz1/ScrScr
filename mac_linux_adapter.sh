#!/bin/bash

# Скрипт-адаптер для определения ОС и правильной настройки библиотеки

OS=$(uname -s)
VERSION=$(uname -r)

echo "Определение операционной системы..."
echo "Обнаружена ОС: $OS $VERSION"

case "$OS" in
  Linux)
    echo "Обнаружена Linux-система. Настраиваю для Linux..."
    
    # Создаем временный файл для Linux-версии state.hpp
    cat > state.hpp.tmp << 'EOF'
// Linux-версия state.hpp - не требует изменений
EOF
    cat state.hpp >> state.hpp.tmp
    
    # Создаем временный файл для Linux-версии ssh_inject.cpp
    cat > ssh_inject.cpp.tmp << 'EOF'
// Linux-версия ssh_inject.cpp - заменяем dlopen аргументы
EOF
    sed 's/libc\.dylib/libc.so.6/g' ssh_inject.cpp >> ssh_inject.cpp.tmp
    
    # Заменяем оригинальные файлы
    mv state.hpp.tmp state.hpp
    mv ssh_inject.cpp.tmp ssh_inject.cpp
    
    echo "Файлы настроены для Linux."
    echo "Для компиляции используйте: g++ -shared -fPIC -o libssh_inject.so ssh_inject.cpp -ldl"
    ;;
    
  Darwin)
    echo "Обнаружена macOS-система. Настраиваю для macOS..."
    
    # Создаем временный файл для macOS-версии state.hpp
    cat > state.hpp.tmp << 'EOF'
// macOS-версия state.hpp - не требует изменений
EOF
    cat state.hpp >> state.hpp.tmp
    
    # Создаем временный файл для macOS-версии ssh_inject.cpp
    cat > ssh_inject.cpp.tmp << 'EOF'
// macOS-версия ssh_inject.cpp - заменяем dlopen аргументы
EOF
    sed 's/libc\.so\.6/libc.dylib/g' ssh_inject.cpp >> ssh_inject.cpp.tmp
    
    # Заменяем оригинальные файлы
    mv state.hpp.tmp state.hpp
    mv ssh_inject.cpp.tmp ssh_inject.cpp
    
    echo "Файлы настроены для macOS."
    echo "Для компиляции используйте: clang++ -shared -fPIC -o libssh_inject.dylib ssh_inject.cpp -ldl"
    echo ""
    echo "ВНИМАНИЕ: На macOS вместо LD_PRELOAD используйте DYLD_INSERT_LIBRARIES:"
    echo "DYLD_INSERT_LIBRARIES=./libssh_inject.dylib ssh user@server"
    ;;
    
  *)
    echo "Неизвестная операционная система: $OS"
    echo "Поддерживаются только Linux и macOS."
    exit 1
    ;;
esac

echo ""
echo "Настройка завершена. Теперь вы можете скомпилировать библиотеку." 