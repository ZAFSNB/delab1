# Базовая сборка из примера 1 задания 3 (соответствует Dockerfile.v1)
# NB: зафиксирована базовая версия python:3.12.1 (python:latest = 3.14 несовместим с psycopg2==2.9.9)
FROM python:3.12.1
# Копирование кода приложения
COPY . /app/
# Установка системных зависимостей для сборки зависимостей python
RUN apt-get update \
    && apt-get install -y gcc
# Установка зависимостей python
RUN pip install -r /app/requirements.txt
# Установка рабочей директории
WORKDIR /app
CMD ["uvicorn", "app:app", "--host", "0.0.0.0"]
