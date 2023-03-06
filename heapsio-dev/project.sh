#!/bin/bash

## Checks if OS is linux and docker compose is installed

if ! (( "$OSTYPE" == "gnu-linux" )); then
  echo "Script runs only on GNU/Linux OS. Exiting..."
  exit
fi

if [[ ! -x "$(command -v compose version)" ]]; then
  echo "Compose plugin is not installed. Exiting..."
  exit
fi

################################################################################
# 1.) Assign variable
################################################################################

  PROJECT_NAME=`printf '%s\n' "${PWD##*/}" | tr -cd '[:alnum:]_'`
  # PROJECT_NAME is parent directory in alphanumerical
  PROJECT_UID=`id -u`
  PROJECT_GID=`id -g`
    
  PROJECT_AUTHOR=`git config user.name`
  PROJECT_EMAIL=`git config user.email`

############################# CLEAN SUBROUTINE #################################

clean() {

  if [[ `ls -ld lib/heaps | awk '{print $3}'` = root ]]; then
    sudo chmod -R 777 *
  fi

  docker compose down -v --rmi all --remove-orphans

  rm -rf compile.hxml \
  docker-compose.yml \
  Dockerfile \
  hello.hl \
  lib
}

############################# START SUBROUTINE #################################

start() {

  mkdir -p src lib doc
  
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

  if [[ ! -f compile.hxml ]]; then
    cat <<-EOF > compile.hxml
-cp src
-lib heaps
-lib hlsdl
-hl hello.hl
-main Main
EOF
  fi

  if [[ ! -f Dockerfile ]]; then
    cat <<EOF > Dockerfile
FROM haxe:4.2.5-bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
    g++ \
    libmbedtls-dev \
    libopenal-dev \
    libpng-dev \
    libsdl2-dev \
    libsqlite3-dev \
    libturbojpeg-dev \
    libuv1-dev \
    libvorbis-dev \
    make && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /usr/src/hashlink && \
    cd /usr/src && \
    git clone https://github.com/HaxeFoundation/hashlink && \
    cd hashlink && \
    make && \
    make install

RUN export PATH="$PATH:/usr/local/bin"; echo $PATH

EOF
  fi

  if [[ ! -f docker-compose.yml ]]; then
    cat <<-EOF > docker-compose.yml
  version: "3.9"

  services:
    haxe-sdk:
      build: .
      image: haxe-sdk
##      user: $PROJECT_UID:$PROJECT_GID
      working_dir: /usr/src/app
      environment:
        DISPLAY: $DISPLAY
        XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
      volumes:
        - .:/usr/src/app
        - ./lib:/haxelib
        - /tmp/.X11-unix:/tmp/.X11-unix
        - ~/.Xauthority:/root/.Xauthority
      devices:
        - /dev/dri:/dev/dri
        - /dev/snd:/dev/snd
      network_mode: host
EOF
  fi

  if [[ ! -f src/Main.hx ]]; then
    cat <<-EOF > src/Main.hx
class Main extends hxd.App {
    override function init() {
        var tf = new h2d.Text(hxd.res.DefaultFont.get(), s2d);
        tf.text = "Hello Hashlink !";
    }
    static function main() {
        new Main();
    }
}
EOF
  fi

  docker compose run haxe-sdk haxelib setup
  docker compose run haxe-sdk haxelib install heaps
  docker compose run haxe-sdk haxelib install hlopenal
  docker compose run haxe-sdk haxelib install hlsdl
  docker compose run haxe-sdk haxelib install hldx

}

$1
