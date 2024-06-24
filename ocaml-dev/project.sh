#!/bin/bash

## Variables

PROJECT_NAME=`printf '%s\n' "${PWD##*/}" | tr -cd '[:alnum:]_'`
# PROJECT_NAME is parent directory in alphanumerical
PROJECT_UID=`id -u`
PROJECT_GID=`id -g`
  
## Checks if OS is linux and docker compose is installed

if ! (( "$OSTYPE" == "gnu-linux" )); then
  echo "Script runs only on GNU/Linux OS. Exiting..."
  exit
fi

if [[ ! -x "$(command -v compose version)" ]]; then
  echo "Compose plugin is not installed. Exiting..."
  exit
fi

## Functions

clean() {

  docker compose down -v --rmi all --remove-orphans
  rm -rf \
    docker-compose.yml \
    Dockerfile \
    hello.ml \
    helloworld \
    .opam

}

start() {

if [[ ! -f docker-compose.yml ]]; then
  cat <<-EOF > docker-compose.yml
  services:
  ocamlopam:
    image: ocaml/opam:debian
    user: ${PROJECT_UID}:${PROJECT_GID}
    working_dir: /home/$USER
    environment:
    DISPLAY: $DISPLAY
##    OPAMROOT: "/home/$USER/.opam"
    XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
    volumes:
    - .:/home/$USER
    - /tmp/.X11-unix:/tmp/.X11-unix
    - /run/user/${PROJECT_UID}:/run/user/${PROJECT_UID}
    - ~/.Xauthority:/root/.Xauthority
    devices:
    - /dev/dri:/dev/dri
    - /dev/snd:/dev/snd
    network_mode: host
EOF
fi

  docker compose run ocamlopam opam config list
if [ ! -d .opam ]; then
  docker compose run ocamlopam opam init --root=/home/`echo $USER`/.opam
fi

if grep -q \# docker-compose.yml ; then
  ## TODO: make OPAMROOT variable available after opam init with some tiny bit of elegance
  sed 's/\#\#//g' < docker-compose.yml > cleaned
  rm docker-compose.yml
  mv cleaned docker-compose.yml
fi

  docker compose run ocamlopam opam install core
  docker compose run ocamlopam dune init proj helloworld
  docker compose run ocamlopam sh -c "cd helloworld && dune build"
  docker compose run ocamlopam sh -c "cd helloworld && dune exec helloworld"

}

$1
