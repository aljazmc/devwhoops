#! /bin/bash

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
  docker compose stop
  docker system prune -af --volumes
  rm -rf GOG\ Games/ \
    utils/ \
    docker-compose.yml \
    Dockerfile
}

start() {

################################################################################
# 1.) Assign variables and create directory structure
################################################################################

  PROJECT_UID=`id -u`
  PROJECT_GID=`id -g`
  PROJECT_LANG=`echo $LANG`

  if [ ! -d GOG\ Games ]; then
    mkdir -p GOG\ Games
  fi

  if [ ! -d utils ]; then
    mkdir -p utils
  fi

  find . -name "*.sh" -execdir chmod u+x {} +

################################################################################
# 2.) Create a dockerfile
################################################################################

  if [[ ! -f Dockerfile ]]; then
    touch Dockerfile && \
    cat <<EOF> Dockerfile
    FROM debian:bullseye

    ENV DEBIAN_FRONTEND=noninteractive
    ENV USER=gog

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

    RUN groupadd -g $PROJECT_GID -r gog
    RUN useradd -u $PROJECT_UID -g $PROJECT_GID --create-home -r gog

    #Change password
    RUN echo "gog:gog" | chpasswd
    #Make sudo passwordless
    RUN echo "gog ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-gog
    RUN usermod -aG sudo gog
    RUN usermod -aG plugdev gog

    USER gog

    WORKDIR /home/gog
EOF
  fi

  if [[ ! -f docker-compose.yml ]]; then
    touch docker-compose.yml
    cat <<EOF> docker-compose.yml
    version: "3.8"

    services:
      goginstall:
        build: .
        image: gog-linux
        user: $PROJECT_UID:$PROJECT_GID
        environment:
          DISPLAY: $DISPLAY
        volumes:
          - /tmp/.X11-unix:/tmp/.X11-unix
          - .:/home/gog/source
          - "./GOG\ Games:/home/gog/GOG\ Games"
        network_mode: host
        privileged: true

      gogplay:
        build: .
        image: gog-linux
        user: $PROJECT_UID:$PROJECT_GID
        environment:
          DISPLAY: $DISPLAY
        working_dir: "/home/gog/GOG\ Games"
        volumes:
          - /tmp/.X11-unix:/tmp/.X11-unix
          - .:/home/gog/source
          - "./GOG\ Games:/home/gog/GOG\ Games"
        devices:
          - /dev/snd:/dev/snd
          - /dev/dri:/dev/dri
        network_mode: host
        privileged: true
EOF
  fi

################################################################################
# 3.) Search game installers with extension .sh && install
################################################################################

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
      echo "docker compose run goginstall sh -c 'cd /home/gog/source && ./$line'" >> utils/gameinstaller.sh;
    done < utils/gamelist.txt

    source utils/gameinstaller.sh

################################################################################
# 4.)  Search for "start.sh" and run it!
################################################################################

    touch utils/gamestarter.txt
    cd GOG\ Games && find . -name start.sh > ../utils/gamestarter.txt
    cd ..

    echo "docker compose run gogplay bash -c \"'`cat utils/gamestarter.txt`'\"" >> utils/gamestarter.sh
  fi

  source utils/gamestarter.sh
}

"$1"
