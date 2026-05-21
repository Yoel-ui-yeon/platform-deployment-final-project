FROM composer:2 AS vendor

WORKDIR /app

COPY composer.json composer.lock symfony.lock ./

RUN composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --prefer-dist \
    --no-progress

COPY . .

RUN composer dump-autoload --optimize --classmap-authoritative

FROM php:8.3-fpm-alpine

ENV APP_ENV=prod
ENV APP_DEBUG=0

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN apk add --no-cache \
        icu-dev \
        libzip-dev \
    && docker-php-ext-configure intl \
    && docker-php-ext-install -j"$(nproc)" \
        intl \
        opcache \
        pdo_mysql \
        zip

WORKDIR /var/www/html

COPY --from=vendor /app ./

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p var/cache var/log \
    && chown -R www-data:www-data var

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# No CMD: Railway runs built-in server on $PORT.
# Local docker-compose sets: command: ["php-fpm"]
