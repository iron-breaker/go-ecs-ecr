# Building on top of Ubuntu 14.04. The best distro around.
FROM nginx
COPY static-html-directory /usr/share/nginx/html

EXPOSE 80
