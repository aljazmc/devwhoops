#!/bin/bash

## Variables

PROJECT_UID=`id -u`
PROJECT_GID=`id -g`

## Checks if OS is linux and docker compose is installed

if ! (( "$OSTYPE" == "gnu-linux" )); then
  echo "script runs only on GNU/Linux OS. Exiting..."
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
    .local \
    .cache \
    docker-compose.yml
}

start() {

mkdir -p .local .cache/pip .cache/yt-dlp/youtube-nsig
if [[ ! -f docker-compose.yml ]]; then
  cat<<EOF > docker-compose.yml
services:
  yt-dlp:
    image: python:latest
    user: $PROJECT_UID:$PROJECT_GID
    working_dir: /home/$USER
    volumes:
      - .:/home/$USER
      - .local:/.local
      - .cache/pip:/.cache/pip
    environment:
      PATH:     "/.local/bin:\$PATH"
EOF
fi

docker compose run yt-dlp pip3 install --user yt-dlp
docker compose run yt-dlp python3 .local/bin/yt-dlp --version

}

"$1"
