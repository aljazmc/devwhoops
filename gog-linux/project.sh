#! /bin/bash

## Variables

PROJECT_UID=`id -u`
PROJECT_GID=`id -g`
PROJECT_LANG=`echo $LANG`

## Checks if OS is linux and docker-compose is installed

if ! (( "$OSTYPE" == "gnu-linux" )); then
  echo "script runs only on GNU/Linux OS. Exiting..."
  exit
fi

if [[ ! -x "$(command -v compose)" ]]; then
  echo "Docker compose is not installed. Exiting..."
  exit
fi

clean() {

  docker compose down -v --rmi all --remove-orphans
  rm -rf GOG\ Games/ \
    utils/ \
    docker-compose.yml \
    Dockerfile

}

start() {

## Create directory structure and onfiguration files

  if [ ! -d GOG\ Games ]; then
    mkdir -p GOG\ Games
  fi

  if [ ! -d utils ]; then
    mkdir -p utils
  fi

  find . -name "*.sh" -execdir chmod u+x {} +

  if [[ ! -f Dockerfile ]]; then
    touch Dockerfile && \
    cat <<EOF> Dockerfile
  FROM debian:bullseye

  ENV DEBIAN_FRONTEND=noninteractive
  ENV USER=$USER

  RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y \
    gtk2-engines \
    gtk2-engines-pixbuf \
    gtk2-engines-murrine \
    libasound2-data \
    libasound2 \
    libasound2-plugins \
    libc6 \
    libcanberra-gtk-module \
    libcurl4 \
    libegl1-mesa \
    libgl1-mesa-dri \
    libgl1-mesa-glx \
    libglapi-mesa \
    libgles2-mesa \
    libgtk2.0-0 \
    libnss3 \
    libpng16-16 \
    libpng-dev \
    libxml2 \
    libxt6 \
    libudev-dev \
    locales \
    locales-all \
    mesa-opencl-icd \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    sudo \
    dosbox

  ENV LC_ALL $PROJECT_LANG
  ENV LANG $PROJECT_LANG
  ENV LANGUAGE $PROJECT_LANG

  RUN groupadd -g $PROJECT_GID -r $USER
  RUN useradd -u $PROJECT_UID -g $PROJECT_GID --create-home -r $USER

  #Change password
  RUN echo "$USER:$USER" | chpasswd
  #Make sudo passwordless
  RUN echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$USER
  RUN usermod -aG sudo $USER
  RUN usermod -aG plugdev $USER

  USER $USER

  WORKDIR /home/$USER
EOF
fi

if [[ ! -f docker-compose.yml ]]; then
  touch docker-compose.yml
  cat <<EOF> docker-compose.yml
  services:
    goginstall:
      build: .
      image: gog-linux
      user: $PROJECT_UID:$PROJECT_GID
      environment:
        DISPLAY: $DISPLAY
        XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
      volumes:
        - /tmp/.X11-unix:/tmp/.X11-unix
        - /run/user/${PROJECT_UID}:/run/user/${PROJECT_UID}
        - .:/home/$USER/source
        - "./GOG\ Games:/home/$USER/GOG\ Games"

    gogplay:
      build: .
      image: gog-linux
      user: $PROJECT_UID:$PROJECT_GID
      environment:
        DISPLAY: $DISPLAY
        XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
      working_dir: "/home/$USER/GOG\ Games"
      volumes:
        - /tmp/.X11-unix:/tmp/.X11-unix
        - /run/user/${PROJECT_UID}:/run/user/${PROJECT_UID}
        - .:/home/$USER/source
        - "./GOG\ Games:/home/$USER/GOG\ Games"
      devices:
        - /dev/snd:/dev/snd
        - /dev/dri:/dev/dri

EOF
fi

## Search *.sh files and install them

if [[ ! -f utils/gamestarter.sh ]]; then
  find * -maxdepth 1 -name "*.sh" |
  grep -v help.sh |
  grep -v project.sh |
  grep -v utils/gamestarter.sh |
  grep -v utils/gameinstaller.sh > utils/gamelist.txt

  echo "#!/bin/bash -u" |
  tee utils/gameinstaller.sh utils/gamestarter.sh

  while IFS= read -r line;
  do
    echo "docker compose run goginstall sh -c 'cd /home/$USER/source && ./$line'" >> utils/gameinstaller.sh;
  done < utils/gamelist.txt

  source utils/gameinstaller.sh

## Run start.sh

  touch utils/gamestarter.txt
  cd GOG\ Games && find . -name start.sh > ../utils/gamestarter.txt
  cd ..

  echo "docker compose run gogplay bash -c \"'`cat utils/gamestarter.txt`'\"" >> utils/gamestarter.sh
fi

  source utils/gamestarter.sh
}

"$1"
