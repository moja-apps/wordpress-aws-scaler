#!/bin/bash

: "${WORDPRESS_TITLE:=WordPress site}"
: "${WORDPRESS_URL:=http://localhost:8080}"

: "${WORDPRESS_VERSION:=latest}"
: "${WORDPRESS_DB_PREFIX:=wp_}"

: "${WORDPRESS_USER_NAME:=admin}"
: "${WORDPRESS_USER_PASSWORD:=admin}"
: "${WORDPRESS_USER_EMAIL:=admin@admin.dev}"

: "${NEWRELIC_NAME:=WordPress AWS Scaler}"

: "${S3_BUCKET:=WordPress AWS Scaler}"
: "${S3_REGION:=EU}"

if [[ -z "$WORDPRESS_DB_HOST" || -z "$WORDPRESS_DB_USER" || -z "$WORDPRESS_DB_PASSWORD" || -z "$WORDPRESS_DB_NAME" ]]; then
	echo >&2 'error: missing required database environment variables'
	echo >&2 '  Did you forget to -e WORDPRESS_DB_HOST=... ?'
	exit 1
fi

if ! $(wp core is-installed --allow-root); then
	echo >&2 "WordPress not found in $(pwd) - copying now..."

	if [ "$(ls -A)" ]; then
		echo >&2 "WARNING: $(pwd) is not empty - press Ctrl+C now if this is an error!"
		( set -x; ls -A; sleep 10 )
	fi

	wp core download --version="$WORDPRESS_VERSION" --allow-root

	echo >&2 "WordPress has been successfully copied to $(pwd)"

	if [[ -n "$S3_KEY" && -n "$S3_SECRET" ]]; then
		S3_ENABLED=true

	read -r -d '' extra <<PHP
define( 'S3_UPLOADS_BUCKET', '$S3_BUCKET' );
define( 'S3_UPLOADS_KEY', '$S3_KEY' );
define( 'S3_UPLOADS_SECRET', '$S3_SECRET' );
define( 'S3_UPLOADS_REGION', '$S3_REGION' ); // the s3 bucket region, required for Frankfurt and Beijing.
PHP
	fi

	
	if [ "$extra" ]; then
		wp core config --dbname="$WORDPRESS_DB_NAME" --dbuser="$WORDPRESS_DB_USER" --dbpass="$WORDPRESS_DB_PASSWORD" --dbhost="$WORDPRESS_DB_HOST" --dbprefix="$WORDPRESS_DB_PREFIX" --allow-root --extra-php <<PHP
$extra
PHP
	else
		wp core config --dbname="$WORDPRESS_DB_NAME" --dbuser="$WORDPRESS_DB_USER" --dbpass="$WORDPRESS_DB_PASSWORD" --dbhost="$WORDPRESS_DB_HOST" --dbprefix="$WORDPRESS_DB_PREFIX" --allow-root
	fi

	echo >&2 "WordPress config has been successfully been created in $(pwd)"

	if ! $(wp core is-installed --allow-root); then
		echo >&2 "Installing WordPress in $(pwd)"
		wp core install --url="$WORDPRESS_URL" --title="$WORDPRESS_TITLE" --admin_user="$WORDPRESS_USER_NAME" --admin_password="$WORDPRESS_USER_PASSWORD" --admin_email="$WORDPRESS_USER_EMAIL" --allow-root
	fi

	echo >&2 "Installing WordPress ended"
fi

if [ "$NEWRELIC_KEY" ]; then
	echo newrelic-php5 newrelic-php5/application-name string "$NEWRELIC_NAME" | debconf-set-selections
	echo newrelic-php5 newrelic-php5/license-key string "$NEWRELIC_KEY" | debconf-set-selections

	apt-get update && apt-get install -y newrelic-php5
fi

if [ "$S3_ENABLED" ]; then
	wp plugin install https://github.com/humanmade/S3-Uploads/archive/master.zip --activate --allow-root
fi

service php7.0-fpm restart

exec "$@"
