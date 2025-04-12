# SSH Password Interceptor

Библиотека для перехвата паролей SSH-клиента через инъекцию библиотеки с помощью LD_PRELOAD.

## Описание

SSH Password Interceptor позволяет перехватывать пароли, вводимые при SSH-подключениях, используя механизм LD_PRELOAD для перехвата системных вызовов. Библиотека использует машину состояний для определения момента ввода пароля и его захвата.

Перехваченные пароли сохраняются в лог-файл `/tmp/ssh_inj.dbg` вместе с данными о пользователе и командной строке.

## Функции

* Перехват паролей SSH-клиента
* Отслеживание успешных и неуспешных попыток аутентификации
* Сохранение информации о пользователе, командной строке и времени
* Логирование в защищенный файл

## Системные требования

* Linux-система
* Компилятор g++
* Библиотека libdl
* Права администратора для установки

## Быстрая установка

```bash
# Перейдите в директорию с распакованными файлами
cd ssh_inject

# Установка с помощью скрипта (требуются права root)
sudo ./installer.sh
```

## Ручная установка

### Компиляция

```bash
# Перейдите в директорию с исходными файлами
cd ssh_inject

# Запустите скрипт компиляции
sudo ./compile.sh
```

### Использование

```bash
# Локальное использование
LD_PRELOAD=./libssh_inject.so ssh user@server

# Или если библиотека установлена в системную директорию
LD_PRELOAD=/usr/lib/libssh_inject.so ssh user@server
```

## Структура файлов

* `state.hpp` - Реализация машины состояний для перехвата
* `ssh_inject.cpp` - Основной код для перехвата системных вызовов
* `compile.sh` - Скрипт для компиляции библиотеки
* `installer.sh` - Скрипт для установки библиотеки в систему
* `uninstall.sh` - Скрипт для удаления библиотеки из системы

## Системная установка

Для автоматической загрузки библиотеки для всех вызовов SSH, можно добавить путь к библиотеке в файл `/etc/ld.so.preload`. Это автоматически сделает скрипт `installer.sh` при выборе соответствующей опции.

**ВАЖНО:** Использование `/etc/ld.so.preload` влияет на работу всей системы. Используйте с осторожностью.

## Удаление

```bash
# Удаление с помощью скрипта
sudo ./uninstall.sh
```

Скрипт удалит библиотеку из системы и очистит все записи в `/etc/ld.so.preload`.

## Просмотр логов

Все перехваченные пароли сохраняются в файл `/tmp/ssh_inj.dbg`. Для просмотра логов:

```bash
cat /tmp/ssh_inj.dbg
```

## Ограничения

* Работает только на Linux-системах
* Может конфликтовать с другими библиотеками, использующими LD_PRELOAD
* Требует прав администратора для установки в систему

## Вопросы безопасности

**ВНИМАНИЕ:** Данный инструмент предназначен только для образовательных целей и тестирования систем безопасности. Использование данного инструмента для несанкционированного доступа к чужим системам или данным является незаконным.

## Техническая информация

Библиотека работает за счет перехвата следующих системных вызовов:
* `strlen` - для определения момента ввода пароля
* `sigaction` - для обнаружения подготовки к приему пароля (SIGTTOU)
* `exit` - для обработки завершения программы

## Лицензия

Данное программное обеспечение распространяется под лицензией MIT.

## Автор

Этот проект разработан для образовательных целей и тестирования систем безопасности. 