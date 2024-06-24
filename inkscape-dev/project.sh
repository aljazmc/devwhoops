#!/bin/bash

## Variables

PROJECT_UID=`id -u`
PROJECT_GID=`id -g`

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
  cat <<EOF > Dockerfile
FROM debian:latest

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -y \
  libgettextpo-dev \
  libgraphicsmagick++1-dev \
  libgspell-1-dev \
  libgtk-3-dev \
  libgtksourceview-4-dev \
  libmagick++-dev \
  libpoppler-cpp-dev \
  libreadline-dev \
  libxslt-dev \
  adwaita-icon-theme-full \
  aspell \
  bc \
  build-essential \
  ccache \
  clang \
  clang-format \
  clang-tidy \
  cmake \
  cython3 \
  doxygen \
  fonts-dejavu \
  gcovr \
  git \
  google-mock \
  gtk-doc-tools \
  imagemagick \
  intltool \
  jq \
  libart-2.0-dev \
  libaspell-dev \
  libblas3 \
  libboost-all-dev \
  libboost-dev \
  libboost-filesystem-dev \
  libboost-python-dev \
  libboost-stacktrace-dev \
  libcairo-gobject2 \
  libcairo2-dev \
  libcdr-dev \
  libdouble-conversion-dev \
  libgc-dev \
  libgdl-3-dev \
  libglib2.0-dev \
  libgsl-dev \
  libgspell-1-dev \
  libgtest-dev \
  libgtk-3-dev \
  libgtkmm-3.0-dev \
  libgtksourceview-4-dev \
  libgtkspell3-3-dev \
  libhunspell-dev \
  libjemalloc-dev \
  libjpeg-dev \
  liblapack3 \
  liblcms2-dev \
  libmagick++-dev \
  libpango1.0-dev \
  libpng-dev \
  libpoppler-dev \
  libpoppler-glib-dev \
  libpoppler-private-dev \
  libpotrace-dev \
  libreadline-dev \
  librevenge-dev \
  librsvg2-dev \
  librust-pangocairo-dev \
  libsigc++-2.0-dev \
  libsoup2.4-dev \
  libtool \
  libvisio-dev \
  libwmf-bin \
  libwpg-dev \
  libxml-parser-perl \
  libxml2-dev \
  libxslt1-dev \
  perlmagick \
  pkg-config \
  poppler-utils \
  python3-cssselect \
  python3-dev \
  python3-lxml \
  python3-numpy \
  python3-packaging \
  python3-pil \
  python3-pip \
  python3-scour \
  python3-serial \
  software-properties-common \
  subversion \
  sudo \
  wget \
  zlib1g-dev && \
  apt-get clean

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
      image: compile-inkscape
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
      working_dir: /git/inkscape
      volumes:
        - ./inkscape:/git/inkscape

EOF
fi

## Functions

clean() {

  docker compose down -v --rmi all --remove-orphans
  rm -rf build \
    .cache \
    .config \
    docker-compose.yml \
    Dockerfile \
    inkscape \
    install_dependencies.sh \
    .local \
    Projects \
    .wget-hsts

}

compile() {

  docker compose run compiler sh -c "wget -v https://gitlab.com/inkscape/inkscape-ci-docker/-/raw/master/install_dependencies.sh -O install_dependencies.sh && \
    bash install_dependencies.sh --recommended && \
    mkdir -p build && \
    cd build && \
    cmake ../inkscape -DCMAKE_INSTALL_PREFIX=${PWD}/install_dir && \
    make && \
    make install"

}

download() {

  [ ! -d inkscape ] && \
  docker compose run downloader clone --recurse-submodules https://gitlab.com/inkscape/inkscape.git

}

run() {

  docker compose run compiler sh -c 'export LD_LIBRARY_PATH="`echo $PWD`/build/lib/:$LD_LIBRARY_PATH" && \
    ./build/bin/inkscape'

}

update() {

  docker compose run updater pull --recurse-submodules 
  docker compose run updater submodule update --init --recursive 

}

################################################################################
# Start it!
################################################################################

start() {

  download
  update
  compile
  run

}

"$1"
