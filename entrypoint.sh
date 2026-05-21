#!/bin/sh

cd /var/www/html

if [ -n "$DATABASE_URL" ]; then
    echo "Waiting for database..."
    i=0
    while [ "$i" -lt 30 ]; do
        if php -r '
            $url = getenv("DATABASE_URL");
            if (!$url) { exit(0); }
            $parts = parse_url($url);
            if (!$parts || !isset($parts["host"])) { exit(1); }
            $dsn = sprintf(
                "mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4",
                $parts["host"],
                $parts["port"] ?? 3306,
                ltrim($parts["path"] ?? "", "/")
            );
            try {
                new PDO($dsn, $parts["user"] ?? "", $parts["pass"] ?? "");
                exit(0);
            } catch (Throwable $e) {
                exit(1);
            }
        ' 2>/dev/null; then
            echo "Database is ready."
            break
        fi
        i=$((i + 1))
        sleep 2
    done
fi

php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration || true
php bin/console cache:clear --no-warmup || true
php bin/console cache:warmup || true
php bin/console assets:install public --no-interaction || true
php bin/console asset-mapper:compile --no-interaction || true
php bin/console importmap:install --no-interaction || true

mkdir -p var/cache var/log
chown -R www-data:www-data var 2>/dev/null || true

echo "Starting PHP server..."
exec php -S 0.0.0.0:8080 -t public/