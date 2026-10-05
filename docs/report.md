# Лабораторная работа №1. Управление многоконтейнерными системами

**Дисциплина:** «Непрерывное интегрирование и сборка программного обеспечения»

**Выполнил(а):** Чжао Аофэй, группа 13

**Вариант:** — (задания 1–4, группа 13)

---

## 1. Цель работы

Изучение современных технологий контейнеризации: установка и применение Docker,
создание многоконтейнерных инфраструктур, структура Dockerfile, утилита Docker Compose.

---

## 2. Задание 1. Основы управления контейнерами и образами контейнеров Docker

### 2.1. Установка Docker Engine

Установлен Docker Desktop для Windows (Docker Engine 29.8.0).

```text
$ docker --version
Docker version 29.8.0, build 88096ef
```

### 2.2. Запуск контейнеров nginx с пробросом портов

```bash
docker run -d --name mynginxlast   -p 8080:80 nginx:latest
docker run -d --name mynginxalpine -p 8081:80 nginx:alpine
docker run -d --name mynginx1-28   -p 8082:80 nginx:1.28
```

Список активных контейнеров:

```text
$ docker ps
NAMES           IMAGE          PORTS                                     STATUS
mynginx1-28     nginx:1.28     0.0.0.0:8082->80/tcp, [::]:8082->80/tcp   Up
mynginxalpine   nginx:alpine   0.0.0.0:8081->80/tcp, [::]:8081->80/tcp   Up
mynginxlast     nginx:latest   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   Up
```

Проверка доступа к контейнерам из хостовой системы (curl):

```bash
curl http://localhost:8080   # Welcome to nginx! (nginx:latest)
curl http://localhost:8081   # Welcome to nginx! (nginx:alpine)
curl http://localhost:8082   # Welcome to nginx! (nginx:1.28)
```

<!-- Место для скриншотов из браузера: http://localhost:8080, :8081, :8082 -->

Список образов:

```text
$ docker images
IMAGE          ID
nginx:1.28     146adea4768b
nginx:alpine   df221db836e1
nginx:latest   abe47724e466
```

### 2.3. Подключение к контейнеру (exec)

Неинтерактивный запуск команды внутри работающего контейнера:

```bash
$ docker exec mynginxlast sh -c "hostname && id"
34b41825edaa
uid=0(root) gid=0(root) groups=0(root)
```

Интерактивное подключение (выполняется в терминале вручную):

```bash
docker exec -it mynginxlast sh   # вход; выход — команда exit
docker run -it --name mynginx-interactive nginx:alpine sh   # интерактивный запуск; выход — exit
```

### 2.4. Монтирование каталога task1 как тома

В каталоге `task1` создан html-документ (`index.html`) с тегами `html, head, title, body, h1, p`,
содержащий название задания, ФИО и номер группы.

```bash
docker stop mynginxalpine && docker rm mynginxalpine
docker run -d --name mynginxalpine -p 8081:80 \
    -v "$PWD/task1:/usr/share/nginx/html:ro" nginx:alpine
curl http://localhost:8081
```

Результат — страница из `task1/index.html`:

```html
<h1>Задание 1. Основы управления контейнерами и образами контейнеров Docker</h1>
<p>Выполнил(а): Чжао Аофэй</p>
<p>Группа: 13</p>
```

<!-- Место для скриншота страницы из браузера -->

---

## 3. Задание 2. Создание и публикация образа контейнера в репозиторий

На основе пункта 3 задания 1 (html-страница как корень сайта) создан образ,
включающий страницу внутрь себя (без монтирования тома).

`task2/Dockerfile`:

```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

Сборка и проверка:

```bash
docker build -t mynginx-task1:v1 task2/
docker run -d --name mynginx-task1 -p 8083:80 mynginx-task1:v1
curl http://localhost:8083   # страница из задания 1
```

Публикация в Docker Hub (требуется `docker login`):

```bash
docker tag mynginx-task1:v1 <dockerhub-логин>/mynginx-task1:v1
docker push <dockerhub-логин>/mynginx-task1:v1
```

<!-- Место для скриншота репозитория на Docker Hub -->

---

## 4. Задание 3. Настройка конфигурации многоконтейнерных систем в консоли и с помощью Dockerfile

### 4.1. Приложение simple_python_app

В каталоге `task3/simple_python_app` создано приложение на FastAPI,
подключающееся к PostgreSQL (файлы `app.py`, `requirements.txt`,
`requirements.dev.txt` — см. репозиторий).

Запуск БД:

```bash
docker run --name postgres-db \
    -e POSTGRES_PASSWORD=apipass \
    -e POSTGRES_DB=api \
    -e POSTGRES_USER=apiuser \
    -p 5432:5432 -d postgres:16.2-alpine
```

Локальный запуск приложения (через virtual env) и в контейнере — по методическим
указаниям; ответ API на `http://localhost:8001`:

```json
{
  "message": "Hello World",
  "postgres_version": "PostgreSQL 16.2 on x86_64-pc-linux-musl, ..."
}
```

### 4.2. Оптимизация Dockerfile

В каталоге `task3/simple_python_app` подготовлены Dockerfile версий v1–v6
(`Dockerfile.v1` … `Dockerfile.v6`), нарастающие оптимизация:

| Версия | Техника | Размер образа (content size) |
|--------|---------|------------------------------|
| v1 | Базовая сборка: `FROM python:3.12.1`, копирование всего каталога | 427 MB |
| v2 | Сортировка слоёв: сначала редко изменяемые операции | 427 MB |
| v3 | В образ копируется только `app.py`, зависимости — через bind mount | 427 MB |
| v4 | Удаление кеша apt (`rm -rf /var/lib/apt/lists/*`) и pip (`--no-cache-dir`) | 386 MB |
| v5 | Multi-stage сборка на основе `python:3.12.1-slim` | 64.4 MB |
| v6 | v5 + непривилегированный пользователь `app` (USER app) | 64.4 MB |

> **Примечание.** В методических указаниях v1–v4 используется `FROM python`
> (тег latest). На момент выполнения `python:latest` — это Python 3.14,
> с которым `psycopg2==2.9.9` не собирается (ошибка компиляции C-расширения),
> поэтому версия базового образа зафиксирована: `python:3.12.1`
> (комментарий в Dockerfile). Инструкции `RUN --mount=...` (v3–v6) требуют
> BuildKit; установлен плагин buildx v0.37.2.

Фактический вывод `docker image ls simple_python_app` после каждого этапа
зафиксирован скриптом `task3/build-all.sh` в файле `task3/image-sizes.txt`:

```text
IMAGE                  ID             DISK USAGE   CONTENT SIZE
simple_python_app:v1   88b8e3580cb7       1.61GB          427MB
simple_python_app:v2   3fb18025650d       1.61GB          427MB
simple_python_app:v3   1fdfa7e8fa7f       1.61GB          427MB
simple_python_app:v4   2cad9cfed998        1.5GB          386MB
simple_python_app:v5   0d34c62cd328        264MB          64.4MB
simple_python_app:v6   d92215ad154d        264MB          64.4MB
```

Итог: multi-stage сборка на slim-образе уменьшила образ примерно в 6,6 раза.

### 4.3. Локальный запуск приложения и запуск в контейнере

Создано виртуальное окружение (Windows, Python 3.12.8), установлены
зависимости из `requirements.dev.txt`:

```bash
python -m venv venv312
./venv312/Scripts/pip install -r requirements.dev.txt
./venv312/Scripts/python -m uvicorn app:app --host 0.0.0.0 --port 8000
```

Ответ на `http://localhost:8000`:

```json
{"message": "Hello World", "postgres_version": "PostgreSQL 16.2 on x86_64-pc-linux-musl, ..."}
```

Запуск контейнера с приложением (v1) поверх локальной БД
(на Windows Docker Desktop контейнер обращается к хосту по `host.docker.internal`):

```bash
docker run -d --name simple_python_app_local \
    -e API_DB_HOST=host.docker.internal \
    -p 8001:8000 simple_python_app:v1
curl http://localhost:8001
```

Ответ идентичен локальному запуску. После проверки контейнеры остановлены
(`docker stop simple_python_app_local postgres-db`).

Проверка пользователя в контейнерах v6 и v5:

```bash
$ docker run --rm --entrypoint id simple_python_app:v6
uid=100(app) gid=101(app) groups=101(app)
$ docker run --rm --entrypoint id simple_python_app:v5
uid=0(root) gid=0(root) groups=0(root)
```

---

## 5. Задание 4. Применение Docker Compose

В каталоге `task4/compose` описана инфраструктура из трёх сервисов
(файлы `compose.yaml`, `simple_python_app/Dockerfile`, `simple_python_app/app.py`,
`simple_python_app/requirements.txt`, `nginx/app.conf`):

- **web** — nginx:alpine (обратный прокси, порт 80);
- **simple_python_app** — FastAPI-приложение (сборка из `./simple_python_app`);
- **db** — postgres:16.2-alpine (healthcheck, том `dbdata`).

Сети: `frontend-net` (web ↔ app) и `backend-net` (app ↔ db).

Запуск и проверка:

```bash
cd task4/compose
docker compose up -d          # или docker-compose up -d
curl http://localhost         # ответ API с postgres_version
curl http://localhost/hello/Имя
```

Состояние стека после запуска:

```text
$ docker compose ps
NAME                                    IMAGE                      STATUS                    PORTS
simple-python-app-db-1                  postgres:16.2-alpine       Up (healthy)              5432/tcp
simple-python-app-simple_python_app-1   simple_python_app:latest   Up
simple-python-app-web-1                 nginx:alpine               Up                        0.0.0.0:80->80/tcp
```

Ответ через nginx-прокси:

```json
$ curl http://localhost
{"message":"Hello World","postgres_version":"PostgreSQL 16.2 on x86_64-pc-linux-musl, ..."}
$ curl http://localhost/hello/BSU
{"message":"Hello BSU"}
```

> **Примечание 1.** В методических указаниях используется `restart: true`;
> актуальная схема Compose требует строковое значение, в `compose.yaml`
> используется `restart: "always"` (тот же смысл).
>
> **Примечание 2.** На машине с Windows используется самостоятельная
> утилита `docker-compose` (v5.5.1); синтаксис команд идентичен плагину
> `docker compose`.

Остановка:

```bash
docker compose down -v
```

<!-- Место для скриншотов: вывод docker compose ps, ответ API в браузере -->

---

## 6. Ответы на контрольные вопросы

### 1. Что такое Docker и зачем он нужен? Ключевые преимущества? Альтернативы?

Docker — платформа контейнеризации: упаковывает приложение вместе со всеми
зависимостями в изолированный контейнер, который одинаково работает на любой
машине. Преимущества: воспроизводимость окружения («работает у меня» →
«работает везде»), быстрый запуск (секунды, нет полноценной ОС-гостя),
лёгкость (общие слои образов), изоляция процессов и зависимостей,
плотная упаковка на одном хосте, удобство CI/CD.
Альтернативы: **Podman** (даемон-независимый, rootless — удобен в
безопасных окружениях и совместим с Kubernetes), **containerd** (низкоуровневый
рантайм, на нём построен Docker), **LXC/LXD** (системные контейнеры),
**Kubernetes** — не контейнеризатор, а оркестратор поверх рантаймов.

### 2. Что такое Docker-образ? Как его получить? Разница образ/контейнер?

Образ — неизменяемый (read-only) шаблон из слоёв: код приложения, зависимости,
конфигурация, команда запуска. Получить образ можно:
- из реестра: `docker pull nginx:1.28`;
- сборкой: `docker build -t имя .` по Dockerfile;
- из контейнера: `docker commit <container> имя:тег` (снимок файловой
  системы контейнера — обычно антипаттерн).
Разница: образ — статический шаблон, контейнер — работающий экземпляр
образа (образ из него можно запустить много; контейнер добавляет
записываемый слой и изолированные процессы).

### 3. Как запустить контейнер? Проброс портов, имя, ограничение ресурсов?

```bash
docker run -d --name myapp -p 8080:80 --cpus="1.5" --memory=512m имя_образа
```
`-p 8080:80` — проброс хост-порта 8080 на порт 80 контейнера;
`--name` — имя контейнера; `--cpus` / `--memory` — лимиты CPU и RAM
(также `--memory-swap`, `--pids-limit`).

### 4. Логи контейнера: просмотр, фильтрация, ротация?

`docker logs myapp` (`-f` — следить в реальном времени, `--tail 100` —
последние строки). По времени: `--since 2026-10-05T10:00` / `--until ...`.
По строкам/уровню — через `grep`/`jq`, например
`docker logs myapp 2>&1 | grep -i error`.
Ротация настраивается драйвером логирования в `daemon.json` (или в compose):
```json
{"log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "3"}}
```

### 5. Сохранение данных: volume vs bind mount vs tmpfs?

- **volume** — том, управляемый Docker (`docker volume create`); лучший выбор
  для баз данных (переживает пересоздание контейнера, быстрый, изолирован);
- **bind mount** — монтирование каталога хоста в контейнер; удобен для кода
  при разработке (редактируешь на хосте — меняется в контейнере);
- **tmpfs** — данные только в памяти, исчезают при остановке; подходит для
  чувствительных временных данных (сессии, кеши).
БД → volume; логи → bind mount или stdout-драйвер; временный кеш → tmpfs.

### 6. Как подключить контейнеры к одной сети? Типы сетей?

`docker network create mynet`, затем `docker run --network mynet ...` или
в Compose — секция `networks:`. Типы:
- **bridge** (по умолчанию) — частная сеть на одном хосте, контейнеры
  общаются по имени; user-defined bridge вместо default — правильный выбор;
- **host** — контейнер использует сеть хоста без изоляции (максимальная
  скорость, но нет изоляции портов);
- **overlay** — сеть между контейнерами на разных хостах (Docker Swarm);
- также: macvlan (контейнер «в физической сети»), none.
Альтернатива без сетей Docker — общение через порты хоста (неудобно) или
внешние SDN-решения.

### 7. Почему контейнеры обращаются друг к другу по имени?

В user-defined bridge-сети встроенный DNS-сервер Docker (127.0.0.11)
разрешает имена контейнеров/сервисов в их IP (service discovery). Если
контейнер перезапустился, его IP изменился, но имя продолжает резолвиться
в новый адрес — клиентам достаточно знать имя. При смене имени сервиса
старые ссылки перестают работать, пока не обновлены (поэтому имена выносят
в переменные окружения).

### 8. Метки (docker tag)? Семантика, latest, удаление тегов?

Тег — `имя:тег` указывает на образ (манифест). Best practices: семантические
версии `1.4.2`, явные теги вместо `latest`, не перезаписывать опубликованные
теги, подписывать образы. `latest` — просто тег по умолчанию, он НЕ означает
«последняя версия». Удалить тег: `docker rmi имя:тег` — удаляется только
ссылка; сам образ удалится, когда будут сняты все его теги и он не нужен
ни одному контейнеру.

### 9. Как удалить образы и контейнеры? Автоматизация очистки?

```bash
docker rm $(docker ps -aq)         # все остановленные контейнеры
docker rmi $(docker images -q)     # все образы
docker system prune -a --volumes   # всё неиспользуемое
```
Автоматизация: `docker system prune` по cron, политики retention в CI,
`--filter "until=24h"`. Чтобы не удалить работающее: `docker rm` не удаляет
running-контейнеры без `-f`; избегать `prune -a` на проде, использовать
фильтры по меткам и дате.

### 10. docker exec vs docker attach?

`docker exec -it container cmd` — запускает **новый** процесс внутри
контейнера (отладка, shell). `docker attach` — подключается к **основному**
процессе контейнера (его stdout/stdin, Ctrl+C убьёт контейнер).
`docker exec` безопаснее для отладки. Для постоянных фоновых задач вместо
exec используются ENTRYPOINT/CMD или sidecar-контейнеры.

### 11. Как узнать, какие файлы изменяет программа в контейнере? Сравнение слоёв?

`docker diff container` — список изменённых файлов относительно образа
(A — добавлены, C — изменены, D — удалены). Состав слоёв образа:
`docker history имя` и `docker image inspect`; наглядно — утилита `dive`.

### 12. Когда завершается контейнер? Graceful shutdown?

Контейнер живёт, пока работает его основной процесс (PID 1); при его выходе
(код 0 — успех, !=0 — ошибка) контейнер останавливается. Корректная остановка:
`docker stop` шлёт SIGTERM, ждёт 10 с (grace period), затем SIGKILL.
Настройка: `--stop-grace-period 30s` в Compose, `docker stop -t`.
Приложение должно обрабатывать SIGTERM (закрывать соединения, завершать
транзакции); PID 1 должен корректно пересылать сигналы дочерним процессам
(иначе использовать `--init` / tini).

### 13. Кеширование слоёв при сборке?

Каждая инструкция Dockerfile создаёт слой; при пересборке используются
кешированные слои, пока инструкция и её входные данные не изменились —
с этого места кеш инвалидируется. Поэтому: редко меняющиеся операции
(установка зависимостей) — в начале, копирование кода — в конце;
`--mount=type=bind` для requirements позволяет не инвалидировать кеш при
изменении файла зависимостей. Multi-stage и `.dockerignore` уменьшают
контекст и финальный образ. Время сборки видно в выводе buildx по шагам;
по `docker history` видно, какой слой занимает место.

### 14. Сколько слоёв стремиться иметь? Оптимизация?

Чем меньше, тем лучше, но важнее суммарный размер и повторное использование
кеша. Правила: объединять связанные `RUN` (обновление кеша + установка +
очистка в одну команду), ставить `--no-install-recommends`, удалять
`/var/lib/apt/lists/*` и pip-кеш, копировать только нужные файлы, использовать
slim/alpine базовые образы и multi-stage. Оценка: `docker images`,
`docker history`, `dive`.

### 15. Базовые инструкции Dockerfile?

- **FROM** — базовый образ (обязательна, кроме scratch);
- **RUN** — выполнить команду при сборке (создаёт слой);
- **COPY** — скопировать файлы из контекста; **ADD** — то же + URL/архивы;
- **WORKDIR** — рабочий каталог (создаётся, если нет);
- **ENV** — переменные окружения, доступны при сборке и запуске;
- **EXPOSE** — документирует порт (не публикует);
- **CMD** — аргументы по умолчанию; **ENTRYPOINT** — основная команда.
Антипаттерны: `latest` без контроля, несколько RUN apt-get update,
хранение секретов в ENV, запуск от root. Проверка: **hadolint**
(`hadolint Dockerfile`), официальная документация docs.docker.com.

### 16. Что такое контекст сборки?

Набор файлов, передаваемых клиентом демону при `docker build` (путь/URL
последним аргументом). COPY/ADD работают **только** внутри контекста.
Оптимизация: копировать Dockerfile-рядом только нужное, исключить лишнее
через `.dockerignore` (venv, .git, логи) — меньше трафик и быстрее сборка.

### 17. COPY vs ADD?

`COPY` — простое копирование из контекста. `ADD` дополнительно умеет
распаковывать локальные tar-архивы и скачивать по URL (но без распаковки
для URL). Правило: использовать `COPY` по умолчанию; `ADD` — только для
архивов/URL, чему нет альтернативы.

### 18. CMD vs ENTRYPOINT?

`ENTRYPOINT` — неизменяемая команда контейнера, `CMD` — аргументы по
умолчанию, которые можно переопределить при `docker run`.
Итоговая команда = ENTRYPOINT + CMD. Пример:
`ENTRYPOINT ["uvicorn"]`, `CMD ["app:app", "--host", "0.0.0.0"]` —
при `docker run img --port 9000` порт заменится. Если ENTRYPOINT нет,
CMD исполняется через `/bin/sh -c`. Обе инструкции имеют формы exec (JSON,
рекомендуется) и shell.

### 19. ARG vs ENV?

`ARG` — переменные времени сборки (`--build-arg`), в контейнере во время
выполнения недоступны (кроме переопределяемых http_proxy и т.п.).
`ENV` — задаётся при сборке, доступна и при сборке, и в рантайме.
Канонический приём: `ARG APP_VERSION` → `ENV APP_VERSION=$APP_VERSION`.

### 20. Multi-stage builds?

Сборка в несколько этапов: промежуточные стадии содержат инструменты
сборки (компиляторы), финальный образ копирует только артеффакты.
Пример: Go-приложение — stage 1 `FROM golang:1.22 AS builder`
(`go build`), stage 2 `FROM alpine` + `COPY --from=builder /app/bin /bin/app`
— вместо образа с Go-тулчейном (сотни МБ) получаем образ в десятки МБ.
Аналогично для React (node-сборка → nginx с dist) и Python (wheels в
builder, slim-образ для запуска — см. задание 3, версия v5).

### 21. Из каких компонентов состоит Docker Engine?

- **docker CLI** — клиент (команды пользователя);
- **dockerd** — демон, принимает API-запросы, управляет объектами;
- **containerd** — управление жизненным циклом контейнеров и образами;
- **runc** — низкоуровневый рантайм, создаёт контейнеры через namespace/cgroups.

### 22. Подробная информация о контейнере?

`docker inspect <container>` — JSON со всем: IP-адрес
(`.NetworkSettings.Networks.*.IPAddress`), смонтированные тома (`Mounts`),
переменные окружения (`Config.Env`), портами, состоянием. Удобно с jq:
```bash
docker inspect myapp | jq '.[0].NetworkSettings.IPAddress'
```

### 23. Потребление ресурсов в реальном времени?

`docker stats` — CPU, память, сеть, диск по всем контейнерам с обновлением
в реальном времени; `docker stats myapp` — по конкретному.

### 24. Возможности Docker Compose? docker-compose vs docker compose?

Сервисы, тома, сети, секреты, профили (`profiles:`), зависимости
(`depends_on`), healthcheck, переменные окружения, override-файлы.
`docker-compose` — устаревший самостоятельный бинарник v1 (Python);
`docker compose` — плагин v2 (Go), встроен в Docker CLI. В v2: profiles,
GPU, `watch`, `include`, секреты, лучшая производительность.

### 25. Порядок запуска сервисов с учётом готовности?

`depends_on` с условиями: `service_started` (контейнер запущен),
`service_healthy` (healthcheck зелёный), `service_completed_successfully`.
Пример из задания 4: приложение стартует только после
`db: condition: service_healthy`. Дополнительно — скрипты ожидания
(wait-for-it) в entrypoint.

### 26. Что такое Healthcheck?

Механизм проверки, что сервис реально готов к работе (а не просто запущен).
Описывается в Dockerfile (`HEALTHCHECK CMD curl -f http://localhost/`) или
в compose (`healthcheck: test: ["CMD-SHELL", "pg_isready"]` с интервалом,
таймаутом, retries). Нужен для `depends_on: condition: service_healthy`
и для оркестраторов, которые перезапускают нездоровые контейнеры.

### 27. Переопределение compose-файла для разных окружений?

Иерархия файлов: `docker compose -f compose.yaml -f compose.prod.yaml up`
(последний файл переопределяет первый); автоматически подхватывается
`compose.override.yml`. Плюс: переменные `${VAR}` с `--env-file`,
профили сервисов, шаблонизация через envsubst. Так отделяют dev/prod
(логи, ресурсы, реплики, секреты).

### 28. Почему root в контейнере — плохая практика? Как запустить от non-root?

Если процесс в контейнере скомпрометирован, root внутри контейнера легко
эскалировать привилегии на хосте (особенно с `--privileged` или mounted
docker.sock). Non-root: создать пользователя (`addgroup/adduser`,
`USER app` — версия v6 в задании 3, uid=100), или запускать
`docker run --user 1000:1000`. Для bind mount-ов потребуется выравнивание
uid/gid.

### 29. Read-only файловая система контейнера?

`docker run --read-only` или в compose `read_only: true`. Все слои образа
монтируются read-only; для временных файлов добавляют
`--tmpfs /tmp` (tmpfs в памяти) или отдельные тома для каталогов,
которые приложение обязано писать (кеш, pid-файлы).

### 30. Как безопасно передавать секреты?

- **не** через `ENV` в Dockerfile и не коммитить в образ (слои читаются
  через `docker history`);
- BuildKit: `RUN --mount=type=secret,id=mysecret ...` +
  `--secret id=mysecret,src=файл` — секрет не попадает в слои;
- Compose: секция `secrets:` (файлы или environment);
- Docker Swarm/Kubernetes secrets с шифрованием и ротацией;
- минимально: переменные окружения при запуске (`-e`) — видны через
  `docker inspect`, поэтому лучше файлы с правами 0400.

### 31. Ограничения Docker Compose в Production?

Compose управляет мультиконтейнерным приложением на **одном хосте**:
нет распределённого хранилища состояния, самовосстановления (self-healing),
горизонтального масштабирования по кластеру, rolling-update с откатом,
сервис-дискавери между хостами, секретов/конфигов на уровне кластера.
Для кластеров используют оркестраторы: **Kubernetes** (de-facto стандарт)
и **Docker Swarm** (проще, встроен в Docker).

### 32. Что такое Docker Swarm? Отличие от Kubernetes?

Docker Swarm — встроенный оркестратор Docker: кластер из manager/worker
нод, декларативные сервисы (`docker service create`), встроенные overlay-сети,
распределённые секреты/конфиги, самовосстановление. Проще в настройке,
но беднее: меньше экосистемы, нет гибких контроллеров, политик размещения,
hpa и стандартизации. Kubernetes — открытая платформа с богатой
экосистемой, автоскейлингом, service mesh, стал отраслевым стандартом.

