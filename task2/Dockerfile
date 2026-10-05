# Собственный образ на основе задания 1 (пункт 3):
# html-страница из task1 встраивается в образ nginx, mount volume не нужен.
FROM nginx:alpine

# Копирование html-страницы в корневой каталог сайта nginx
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
