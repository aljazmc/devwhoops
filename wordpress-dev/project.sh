#!/bin/bash

## Checks if OS is linux and docker compose is installed

if ! (( "$OSTYPE" == "gnu-linux" )); then
  echo "script runs only on GNU/Linux OS. Exiting..."
  exit
fi

if [[ ! -x "$(command -v compose version)" ]]; then
  echo "Compose plugin is not installed. Exiting..."
  exit
fi

## VARIABLES

PHP_VERSION="8.2"
PROJECT_NAME=`echo ${PWD##*/}` #PROJECT_NAME is parent directory
PROJECT_UID=`id -u`
PROJECT_GID=`id -g`

#################################### clean() ###################################

clean() {
  docker compose down -v --rmi all --remove-orphans
  rm -rf .cache \
  .config \
  .env \
  .eslintrc \
  .gitignore \
  .htaccess \
  .phpdoc \
  .phpunit.cache \
  .yarn \
  composer.json \
  composer.lock \
  docker compose.yml \
  index.php \
  jest.config.js \
  license.txt \
  readme.html \
  node_modules \
  package.json \
  phpcs.xml \
  phpunit.xml \
  src \
  tsconfig.json \
  yarn.lock \
  vendor \
  wp-activate.php \
  wp-admin \
  wp-blog-header.php \
  wp-comments-post.php \
  wp-config.php \
  wp-config-docker.php \
  wp-config-sample.php \
  wp-cron.php \
  wp-includes \
  wp-links-opml.php \
  wp-load.php \
  wp-login.php \
  wp-mail.php \
  wp-settings.php \
  wp-signup.php \
  wp-trackback.php \
  xmlrpc.php
}

#################################### start() ###################################

start() {

  ## Generate directory structure if it doesn't exist

  if [[ ! -d wp-content/themes/$PROJECT_NAME ]]; then
    mkdir -p wp-content/themes/$PROJECT_NAME
  fi
  if [[ ! -d wp-content/plugins/$PROJECT_NAME ]]; then
    mkdir -p wp-content/plugins/$PROJECT_NAME
  fi
  if [[ ! -d __tests__/phpunit ]]; then
    mkdir -p __tests__/phpunit
  fi
  mkdir -p .cache/yarn/v6 .config/yarn/global .yarn/bin docs

  if [[ ! -f docs/$PROJECT_NAME.txt ]]; then
    cat <<EOF > docs/$PROJECT_NAME.txt
PROJECT INITIATION DOCUMENT

1. Project Definition

1. 1. Purpose

1. 2. Objectives

1. 3. Scope

1. 4. Deliverables

1. 5. Constraints

1. 6. Assumptions

2. Project organization

3. Plan

3. 1. Activity (with criteria)

3. 2. Timetable

3. 3. Finances
EOF
  fi

## Generate a reminder to improve myself

  if [[ ! -f docs/commitrules.txt ]]; then
    cat <<-EOF > docs/commitrules.txt
## URL: https://gist.github.com/joshbuchea/6f47e86d2510bce28f8e7f42ae84c716

Semantic Commit Messages

See how a minor change to your commit message style can make you a better programmer.

Format: <type>(<scope>): <subject>

<scope> is optional
Example

feat: add hat wobble
^--^  ^------------^
|     |
|     +-> Summary in present tense.
|
+-------> Type: chore, docs, feat, fix, refactor, style, or test.

More Examples:

    feat: (new feature for the user, not a new feature for build script)
    fix: (bug fix for the user, not a fix to a build script)
    docs: (changes to the documentation)
    style: (formatting, missing semi colons, etc; no production code change)
    refactor: (refactoring production code, eg. renaming a variable)
    test: (adding missing tests, refactoring tests; no production code change)
    chore: (updating grunt tasks etc; no production code change)

EOF
  fi

  ## Generate files if necessary

  if [[ ! -f .env ]]; then
    cat <<-EOF >  .env
PHP_VERSION=$PHP_VERSION
EOF
  fi

  if [[ ! -f .gitignore ]]; then
    cat <<-EOF >  .gitignore
.cache/

.config/
.yarn/
.yarnrc

docs/

docker-compose.yml

wp-content/plugins/akismet
wp-content/plugins/hello.php
wp-content/plugins/index.php

wp-content/themes/twentytwentyone
wp-content/themes/twentytwentythree
wp-content/themes/twentytwentytwo
wp-content/themes/index.php

wp-content/uploads
wp-content/index.php

.config
.env
.eslintrc
.gitignore
.htaccess
.phpdoc
.phpunit.cache
.yarn
composer.json
composer.lock
docker-compose.yml
index.php
license.txt
readme.html
node_modules
package.json
phpcs.xml
phpunit.xml
src
tsconfig.json
yarn.lock
vendor
wp-activate.php
wp-admin
wp-blog-header.php
wp-comments-post.php
wp-config.php
wp-config-docker.php
wp-config-sample.php
wp-cron.php
wp-includes
wp-links-opml.php
wp-load.php
wp-login.php
wp-mail.php
wp-settings.php
wp-signup.php
wp-trackback.php
xmlrpc.php
EOF
  fi

  if [[ ! -f docker-compose.yml ]]; then
    cat <<-EOF > docker-compose.yml
    version: "3.9"

    services:
      database:
        image: mariadb:latest
        volumes:
          - db_data:/var/lib/mysql
        environment:
          MARIADB_ROOT_PASSWORD: $PROJECT_NAME
          MARIADB_DATABASE:      $PROJECT_NAME
          MARIADB_USER:          $PROJECT_NAME
          MARIADB_PASSWORD:      $PROJECT_NAME

      phpmyadmin:
        image: phpmyadmin/phpmyadmin
        environment:
          PMA_HOST: database
          PMA_PORT: 3306
          MYSQL_ROOT_PASSWORD: $PROJECT_NAME
        ports:
          - 8080:80

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
          WORDPRESS_DB_HOST:     database
          WORDPRESS_DB_USER:     $PROJECT_NAME
          WORDPRESS_DB_PASSWORD: $PROJECT_NAME
          WORDPRESS_DB_NAME:     $PROJECT_NAME

      wpcli:
        image: wordpress:cli
        user: $PROJECT_UID:$PROJECT_GID
        command: >
          /bin/sh -c '
          wp core install --path="/var/www/html" --url="http://localhost" --title="Testing Site" --admin_user="$PROJECT_NAME" --admin_password="$PROJECT_NAME" --admin_email=foo@bar.com --skip-email;
          '
        links:
          - wordpress
        volumes_from:
          - wordpress
        environment:
          WORDPRESS_DB_HOST:     database
          WORDPRESS_DB_USER:     $PROJECT_NAME
          WORDPRESS_DB_PASSWORD: $PROJECT_NAME
          WORDPRESS_DB_NAME:     $PROJECT_NAME

      composer:
        image: composer:latest
        user: $PROJECT_UID:$PROJECT_GID
        command: [ composer, install ]
        volumes:
          - .:/app
        environment:
          - COMPOSER_CACHE_DIR=/var/cache/composer

      jmeter:
        image: justb4/jmeter
        user: $PROJECT_UID:$PROJECT_GID

      node:
        image: node:current-alpine
        user: $PROJECT_UID:$PROJECT_GID
        working_dir: /home/$PROJECT_NAME
        volumes:
          - .:/home/$PROJECT_NAME
        environment:
          NODE_ENV: development

      phpcbf:
        image: php:\${PHP_VERSION}-fpm-alpine
        user: $PROJECT_UID:$PROJECT_GID
        working_dir: /app
        volumes:
          - .:/app
        entrypoint: vendor/bin/phpcbf

      phpcs:
        image: php:\${PHP_VERSION}-fpm-alpine
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

      phpunit:
        image: php:\${PHP_VERSION}-fpm-alpine
        user: $PROJECT_UID:$PROJECT_GID
        working_dir: /app
        volumes:
          - .:/app
        entrypoint: vendor/bin/phpunit

    volumes:
      db_data:
EOF
  fi

  if [[ ! -f phpunit.xml ]]; then
    cat <<-EOF >  phpunit.xml
<?xml version="1.0" encoding="UTF-8"?>
  <phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
           xsi:noNamespaceSchemaLocation="https://schema.phpunit.de/10.0/phpunit.xsd"
           bootstrap="./vendor/autoload.php"
           cacheResultFile=".phpunit.cache/test-results"
           executionOrder="depends,defects"
           forceCoversAnnotation="true"
           beStrictAboutCoversAnnotation="true"
           beStrictAboutOutputDuringTests="true"
           beStrictAboutTodoAnnotatedTests="true"
           convertDeprecationsToExceptions="true"
           failOnRisky="true"
           failOnWarning="true"
           verbose="true">
      <testsuites>
          <testsuite name="default">
              <directory>tests/phpunit</directory>
          </testsuite>
      </testsuites>

      <coverage cacheDirectory=".phpunit.cache/code-coverage"
                processUncoveredFiles="true">
          <include>
              <directory suffix=".php">wp-content/plugins/$PROJECT_NAME</directory>
              <directory suffix=".php">wp-content/themes/$PROJECT_NAME</directory>
          </include>
      </coverage>
  </phpunit>
EOF
  fi

  if [[ ! -f phpcs.xml ]]; then
    cat <<-EOF >  phpcs.xml
<?xml version="1.0"?>
  <ruleset xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
  name="$PROJECT_NAME" 
  xsi:noNamespaceSchemaLocation="https://raw.githubusercontent.com/squizlabs/PHP_CodeSniffer/master/phpcs.xsd">

    <file>wp-content/plugins/$PROJECT_NAME/</file>
    <file>wp-content/themes/$PROJECT_NAME/</file>
    <file>__tests__/phpunit/</file>
       
    <exclude-pattern>*\.(scss|css|js)$</exclude-pattern>    
    
    <rule ref="WordPress">
    </rule>
    
  </ruleset>
EOF
  fi

  if [[ ! -f tsconfig.json ]]; then
    cat <<-EOF > tsconfig.json
{
  "compilerOptions": {
    "alwaysStrict": true,
    "baseUrl": "./",
    "importsNotUsedAsValues": "remove",
    "jsx": "react-jsxdev",
    "jsxFactory": "h",
    "jsxFragmentFactory": "Fragment",
    "jsxImportSource": "react-jsxdev",
    "preserveValueImports": true,
    "target": "es6",
    "useDefineForClassFields": true
  },
  "exclude": [
  "/home/$PROJECT_NAME/node_modules",
  "/home/$PROJECT_NAME/vendor"
  ]
}
EOF
  fi 

  if [[ ! -f .eslintrc ]]; then
    cat <<-EOF > .eslintrc
{
  "root": true,
  "parser": "@typescript-eslint/parser",
  "plugins": [
    "@typescript-eslint"
  ],
  "extends": [
    "eslint:recommended",
    "plugin:@typescript-eslint/eslint-recommended",
    "plugin:@typescript-eslint/recommended"
  ]
}
EOF
  fi

  # Install everything that isnt already installed

  if [[ ! -f package.json ]]; then  
    docker compose run node yarn init
    docker compose run node yarn add -D esbuild \
      eslint \
      ts-jest \
      typescript \
      @typescript-eslint/parser \
      @typescript-eslint/eslint-plugin \
      @wordpress/scripts
    if [[ ! -f jest.config.js ]]; then
      docker compose run node yarn ts-jest config:init
    fi
  else
    docker compose run node yarn install
  fi
  
  docker compose run node yarn global add ynpx

  if [[ ! -f composer.json ]]; then
    docker compose run composer init
    docker compose run composer composer require --dev phpunit/phpunit
    docker compose run composer composer require --dev squizlabs/php_codesniffer
    docker compose run composer composer require --dev wp-coding-standards/wpcs
    docker compose run composer config allow-plugins.dealerdirect/phpcodesniffer-composer-installer  true
    docker compose run composer composer require --dev dealerdirect/phpcodesniffer-composer-installer
  else
    docker compose run composer install
  fi
  
  docker compose run composer -- dump-autoload

  docker compose up -d
  sleep 8
  docker compose run wpcli

}

#################################### test()  ###################################

"$1"
