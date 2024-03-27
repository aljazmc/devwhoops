#!/bin/bash

## Variables
PROJECT_NAME=`realpath ../ | sed 's@.*/@@'`
PROJECT_GID=`id -g`
PROJECT_UID=`id -u`
PHP_VERSION=8.3

## Check for linux and docker compose or quit
if ! (( "$OSTYPE" == "gnu-linux" )); then
  echo "script runs only on GNU/Linux OS. Exiting..."
  exit
fi

if [[ ! -x "$(command -v compose version)" ]]; then
  echo "Compose plugin is not installed. Exiting..."
  exit
fi

if [ ! -f docker-compose.yml ]; then
  cat << EOF > docker-compose.yml
services:
  composer:
    image: composer:latest
    user: $PROJECT_UID:$PROJECT_GID
    command: [ composer, install ]
    volumes:
      - .:/app
    environment:
      - COMPOSER_CACHE_DIR=/var/cache/composer

  database:
    image: mariadb:latest
    volumes:
      - db_data:/var/lib/mysql
    environment:
      MARIADB_ROOT_PASSWORD:  $PROJECT_NAME
      MARIADB_DATABASE:       $PROJECT_NAME
      MARIADB_USER:           $PROJECT_NAME
      MARIADB_PASSWORD:       $PROJECT_NAME

  node:
    image: node:current-alpine
    user: $PROJECT_UID:$PROJECT_GID
    working_dir: /home/node
    volumes:
      - .:/home/node
    environment:
      NODE_ENV: development

  phpcbf:
    image: php:$PHP_VERSION-fpm-alpine
    user: $PROJECT_UID:$PROJECT_GID
    working_dir: /app
    volumes:
      - .:/app
    entrypoint: vendor/bin/phpcbf

  phpcs:
    image: php:$PHP_VERSION-fpm-alpine
    user: $PROJECT_UID:$PROJECT_GID
    working_dir: /app
    volumes:
      - .:/app
    entrypoint: vendor/bin/phpcs

  phpdoc:
    image: phpdoc/phpdoc
    user: $PROJECT_UID:$PROJECT_GID
    volumes:
      - .:/data

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    environment:              
      PMA_HOST:               database
      PMA_PORT:               3306
      MYSQL_ROOT_PASSWORD:    $PROJECT_NAME
    ports:
      - 8080:80

  phpunit:
    image: php:$PHP_VERSION-fpm-alpine
    user: $PROJECT_UID:$PROJECT_GID
    working_dir: /app
    volumes:
      - .:/app
    entrypoint: vendor/bin/phpunit

  phpunit-watcher:
    image: php:$PHP_VERSION-fpm-alpine
    user: $PROJECT_UID:$PROJECT_GID
    working_dir: /app
    volumes:
      - .:/app
    entrypoint: vendor/bin/phpunit-watcher

  wordpress:
    image: wordpress:latest
    user: $PROJECT_UID:$PROJECT_GID
    volumes:
      - .:/var/www/html
    links:
      - database
    ports:
      - 80:80
    environment:
      WORDPRESS_DB_HOST:      database
      WORDPRESS_DB_USER:      $PROJECT_NAME
      WORDPRESS_DB_PASSWORD:  $PROJECT_NAME
      WORDPRESS_DB_NAME:      $PROJECT_NAME

  wpcli:
    image: wordpress:cli
    user: $PROJECT_UID:$PROJECT_GID
    command: /bin/sh -c 'wp core install --path="/var/www/html"  --url="http://localhost" --title="Testing Site" --admin_user="$PROJECT_NAME" --admin_password="$PROJECT_NAME" --admin_email=foo@bar.com --skip-email; '
    links:
      - wordpress
    volumes_from:
      - wordpress
    environment:
      WORDPRESS_DB_HOST:      database
      WORDPRESS_DB_USER:      $PROJECT_NAME
      WORDPRESS_DB_PASSWORD:  $PROJECT_NAME
      WORDPRESS_DB_NAME:      $PROJECT_NAME

volumes:
  db_data:
EOF
fi

clean() {

  docker compose stop
  docker system prune -af --volumes
  rm -rf \
    $PROJECT_NAME \
    .cache \
    .eslintrc.js \
    .gitignore \
    .htaccess \
    .npm \
    .phpdoc \
    .phpunit.cache \
    .vimrc \
    .yarn \
    .yarnrc \
    composer.json \
    composer.lock \
    docker-compose.yml \
    esbuild.config.mjs \
    index.php \
    jest.config.js \
    license.txt \
    node_modules \
    package.json \
    phpcs.xml \
    phpunit-watcher.yml \
    phpunit.xml \
    readme.html \
    src \
    tsconfig.json \
    vendor \
    wp-activate.php \
    wp-admin \
    wp-blog-header.php \
    wp-comments-post.php \
    wp-config-docker.php \
    wp-config-sample.php \
    wp-config.php \
    wp-content \
    wp-cron.php \
    wp-includes \
    wp-links-opml.php \
    wp-load.php \
    wp-login.php \
    wp-mail.php \
    wp-settings.php \
    wp-signup.php \
    wp-trackback.php \
    xmlrpc.php \
    yarn-error.log \
    yarn.lock

}

start() {

##################### Conditional start() tasks ################################

  if [ ! -d $PROJECT_NAME ]; then

    ## Creating directory structure
    mkdir -p $PROJECT_NAME/{src/{ts,scss,img},tests/{ts,php}}
    touch $PROJECT_NAME/src/scss/index.scss
    touch $PROJECT_NAME/src/ts/index.ts

    ## Setting up node related stuff
    docker compose run node yarn init
    docker compose run node yarn add -D esbuild-plugin-eslint esbuild esbuild-plugin-copy eslint jest sass ts-jest typescript typescript-eslint @types/jest
    docker compose run node yarn run tsc --init
    docker compose run node yarn ts-jest config:init
    docker compose run node npm init @eslint/config

    ## Setting up php related stuff
    docker compose run composer init

    docker compose run composer config allow-plugins.dealerdirect/phpcodesniffer-composer-installer  true
    docker compose run composer composer require --dev dealerdirect/phpcodesniffer-composer-installer
    docker compose run composer require --dev composer squizlabs/php_codesniffer
    docker compose run composer require --dev composer wp-coding-standards/wpcs
    docker compose run composer require --dev composer sirbrillig/phpcs-variable-analysis
    docker compose run composer require --dev phpcompatibility/phpcompatibility-wp
    docker compose run composer require --dev gutenberg/gutenberg-coding-standards
    docker compose run composer require --dev composer phpunit/phpunit
    docker compose run composer require --dev composer spatie/phpunit-watcher
    docker compose run composer require --dev composer phpunit-polyfills
    docker compose run phpunit --generate-configuration
    cp vendor/wp-coding-standards/wpcs/phpcs.xml.dist.sample phpcs.xml
    if [ ! -f phpunit-watcher.yml ]; then
      cat << EOF > phpunit-watcher.yml
watch:
  directories:
  - $PROJECT_NAME/src
  - $PROJECT_NAME/tests
    fileMask: '*.php'
  notifications:
     passingTests: false
  phpunit:
    binaryPath: vendor/bin/phpunit
    arguments: '--stop-on-failure'
    timeout: 180
EOF
    fi
    if [ ! -f .gitignore ]; then
      cat << EOF > .gitignore
## Build folder

/$PROJECT_NAME/build

## Docker related

/docker-compose.yml

## Node/JavaScript related

/.cache
/.eslintrc.mjs
/.npm
/.yarn
/.yarnrc
/esbuild.config.js
/jest.config.js
/node_modules
/package.json
/tsconfig.json
/yarn.lock

## PHP related

/.phpdoc
/.phpunit.cache
/composer.json
/composer.lock
/phpcs.xml
/phpunit-watcher.yml
/phpunit.xml
/vendor

## WordPress

/.htaccess
/index.php
/license.txt
/readme.html
/wp-activate.php
/wp-admin
/wp-blog-header.php
/wp-comments-post.php
/wp-config-docker.php
/wp-config-sample.php
/wp-config.php
/wp-content
/wp-cron.php
/wp-includes
/wp-links-opml.php
/wp-load.php
/wp-login.php
/wp-mail.php
/wp-settings.php
/wp-signup.php
/wp-trackback.php
/xmlrpc.php
EOF
    fi
    if [ ! -f .vimrc ]; then
      cat << EOF > .vimrc
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
EOF
    fi
    if [ ! -f esbuild.config.mjs ]; then
      cat << EOF > esbuild.config.mjs
import { build } from 'esbuild';
import eslint from 'esbuild-plugin-eslint';
import { copy } from 'esbuild-plugin-copy';

(async () => {
  const res = await build({
    entryPoints: ['$PROJECT_NAME/src/ts/index.ts'],
    outdir: 'wp-content/themes/$PROJECT_NAME/js',
    plugins: [
      eslint(),
      copy({
        resolveFrom: 'cwd',
        assets: {
          from: ['./$PROJECT_NAME/src/**/*'],
          to: ['./wp-content/themes/$PROJECT_NAME'],
        },
      watch: true,
      }),
    ],
  });
})();
EOF
    fi
  else
    docker compose run composer install
    docker compose run node yarn install
  fi

############################# Regular start() tasks  ###########################

  docker compose up -d
  sleep 10
  docker compose run wpcli
  `ls /usr/bin | grep terminal` -e "docker compose run phpunit-watcher watch"
  `ls /usr/bin | grep terminal` -e "docker compose run node yarn sass --no-source-map --watch $PROJECT_NAME/src/scss/index.scss wp-content/themes/$PROJECT_NAME/style.css"
  `ls /usr/bin | grep terminal` -e "docker compose run node yarn run jest --watchAll"
  `ls /usr/bin | grep terminal` -e "docker compose run node yarn esbuild --watch $PROJECT_NAME/src/ts/index.ts --outdir=wp-content/themes/$PROJECT_NAME/js"

}

"$1"
