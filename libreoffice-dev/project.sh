#!/bin/bash

## Variables

PROJECT_UID=`id -u`
PROJECT_GID=`id -g`
PROJECT_LANG=`echo $LANG`

## Checks for compatible OS and required software

if ! (( "$OSTYPE" == "gnu-linux" )); then
  echo "Script runs only on GNU/Linux OS. Exiting..."
  exit
fi

if [[ ! -x "$(command -v compose version)" ]]; then
  echo "Compose plugin is not installed. Exiting..."
  exit
fi

## Configuration files

if [[ ! -f Dockerfile ]]; then
  cat <<-EOF > Dockerfile
FROM debian:latest

ENV DEBIAN_FRONTEND noninteractive

ENV LANG=$PROJECT_LANG
ENV LC_ALL=$PROJECT_LANG

RUN apt-get update && apt-get install -y \
  ant \
  ant-optional \
  autoconf \
  bash \
  bison \
  build-essential \
  ccache \
  default-jdk \
  doxygen \
  flex \
  git \
  gperf \
  graphviz \
  junit4 \
  libavahi-client-dev \
  libcups2-dev \
  libfontconfig1-dev \
  libgstreamer-plugins-base1.0-dev \
  libgstreamer1.0-dev \
  libgtk-3-dev \
  libkf5config-dev \
  libkf5coreaddons-dev \
  libkf5i18n-dev \
  libkf5kio-dev \
  libkf5windowsystem-dev \
  libkrb5-dev \
  libnss3-dev \
  libx11-dev \
  libxml2-utils \
  libxrandr-dev \
  libxslt1-dev \
  libxt-dev \
  locales \
  locales-all \
  nasm \
  python3 \
  python3-dev \
  qtbase5-dev \
  sudo \
  xsltproc \
  zip && \
  apt-get clean

RUN update-locale LANG=$PROJECT_LANG

RUN groupadd -g $PROJECT_GID -r $USER
RUN useradd -u $PROJECT_UID -g $PROJECT_GID --create-home -r $USER

#Change password
RUN echo "$USER:$USER" | chpasswd
#Make sudo passwordless
RUN echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$USER
RUN usermod -aG sudo $USER

USER $USER
WORKDIR /home/$USER

CMD ["/bin/bash"]
EOF
fi

if [ ! -f docker-compose.yml ]; then
  cat <<-EOF > docker-compose.yml
  services:
    compiler:
      build: .
      image: compile-libreoffice
      user: ${PROJECT_UID}:${PROJECT_GID}
      working_dir: /home/$USER
      environment:
        DISPLAY: $DISPLAY
        XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
      volumes:
        - .:/home/$USER
        - /tmp/.X11-unix:/tmp/.X11-unix
        - ~/.Xauthority:/root/.Xauthority
        - /run/user/${PROJECT_UID}:/run/user/${PROJECT_UID}
      devices:
        - /dev/dri:/dev/dri
        - /dev/snd:/dev/snd

    downloader:
      image: alpine/git
      user: ${PROJECT_UID}:${PROJECT_GID}
      working_dir: /git
      volumes:
        - .:/git

    updater:
      image: alpine/git
      user: ${PROJECT_UID}:${PROJECT_GID}
      working_dir: /git/libreoffice
      volumes:
        - ./libreoffice:/git/libreoffice
EOF
fi

## Functions

clean() {

  docker compose down -v --rmi all --remove-orphans
  rm -rf libreoffice \
      .cache \
      .config \
      .gnupg \
      docker-compose.yml \
      Dockerfile
}

compile() {

  docker compose run compiler sh -c "cd libreoffice && \
    ./autogen.sh && \
    make && \ 
    make check"

}

download() {

  [ ! -d libreoffice ] && \
  docker compose run downloader clone --recurse-submodules https://git.libreoffice.org/core libreoffice

}

run() {

  docker compose run compiler sh -c "cd libreoffice/instdir/program && ./soffice"

}

update() {

  docker compose run updater pull --recurse-submodules && \
  docker compose run updater submodule update --init --recursive 

}

################################################################################
# Start it!
# ##############################################################################

start() {

  download
  update
  compile
  run

}

"$1"
