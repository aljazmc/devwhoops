#!/bin/bash

## Variables
PROJECT_NAME=`realpath . | sed 's@.*/@@'`
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
      MARIADB_ROOT_PASSWORD: $PROJECT_NAME
      MARIADB_DATABASE:    $PROJECT_NAME
      MARIADB_USER:      $PROJECT_NAME
      MARIADB_PASSWORD:    $PROJECT_NAME

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
      PMA_HOST:        database
      PMA_PORT:        3306
      MYSQL_ROOT_PASSWORD:  $PROJECT_NAME
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
      - ./$PROJECT_NAME:/var/www/html/wp-content/themes/$PROJECT_NAME
    links:
      - database
    ports:
      - 80:80
    environment:
      WORDPRESS_DB_HOST:   database
      WORDPRESS_DB_USER:   $PROJECT_NAME
      WORDPRESS_DB_PASSWORD: $PROJECT_NAME
      WORDPRESS_DB_NAME:   $PROJECT_NAME

  wpcli:
    image: wordpress:cli
    user: $PROJECT_UID:$PROJECT_GID
    command: /bin/sh -c 'wp core install --path="/var/www/html" --url="http://localhost" --title="Testing Site" --admin_user="$PROJECT_NAME" --admin_password="$PROJECT_NAME" --admin_email=foo@bar.com --skip-email; '
    links:
      - wordpress
    volumes_from:
      - wordpress
    environment:
      WORDPRESS_DB_HOST:   database
      WORDPRESS_DB_USER:   $PROJECT_NAME
      WORDPRESS_DB_PASSWORD: $PROJECT_NAME
      WORDPRESS_DB_NAME:   $PROJECT_NAME

volumes:
  db_data:
EOF
fi

clean() {

  docker compose down -v --rmi all --remove-orphans
  rm -rf \
    .cache \
    .npm \
    .phpdoc \
    .phpunit.cache \
    .yarn \
    .yarnrc.yml \
    license.txt \
    node_modules \
    readme.html \
    vendor \
    yarn-error.log \
    yarn.lock

}

start() {

##################### Conditional start() tasks ################################

  if [ ! -d $PROJECT_NAME ]; then

    ## Creating directory structure
    mkdir -p {$PROJECT_NAME/{assets/{ts,scss,fonts,img},parts,patterns,styles,templates},__tests__/{ts,php}}
  
    ## Setting up node related stuff
    docker compose run node yarn init
  
    ## Setting up php related stuff
    docker compose run composer init
  
    docker compose run composer config allow-plugins.dealerdirect/phpcodesniffer-composer-installer true
    docker compose run composer composer require --dev dealerdirect/phpcodesniffer-composer-installer
    docker compose run composer require --dev composer squizlabs/php_codesniffer
    docker compose run composer require --dev composer wp-coding-standards/wpcs
    docker compose run composer require --dev composer sirbrillig/phpcs-variable-analysis
    docker compose run composer require --dev phpcompatibility/phpcompatibility-wp
    docker compose run composer require --dev composer phpunit/phpunit
    docker compose run composer require --dev composer spatie/phpunit-watcher
    docker compose run phpunit --generate-configuration
    cp vendor/wp-coding-standards/wpcs/phpcs.xml.dist.sample phpcs.xml
  else
    docker compose run composer install
    docker compose run node yarn install
  fi

  if [ ! -f phpunit-watcher.yml ]; then
    cat << EOF > phpunit-watcher.yml
watch:
  directories:
    - $PROJECT_NAME
    - __tests__
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
## Docker related

/docker-compose.yml

## Node/JavaScript related

/.cache
/.eslintrc.mjs
/.npm
/.pnp.cjs
/.yarn
/.yarnrc
/.yarnrc.yml
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
EOF
  fi

############################# Regular start() tasks ###########################

  docker compose up -d && \
  sleep 30 && \
  docker compose run wpcli
  `ls /usr/bin | grep terminal` -- sh -c "docker compose run phpunit-watcher watch"

}

"$1"
