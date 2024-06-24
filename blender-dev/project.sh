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

if [ ! -f Dockerfile ]; then
  cat <<-EOF > Dockerfile
FROM debian:latest

ENV DEBIAN_FRONTEND noninteractive

ENV LANG=$PROJECT_LANG
ENV LC_ALL=$PROJECT_LANG

RUN apt-get update && apt-get install -y \
  autoconf \
  automake \
  bison \
  build-essential \
  clang \
  clang-format \
  cmake \
  cmake-curses-gui \
  cmake-gui \
  curl \
  cython3 \
  ffmpeg \
  git \
  git-lfs \
  libavdevice-dev \
  libblosc-dev \
  libboost-atomic-dev \
  libboost-date-time-dev \
  libboost-dev \
  libboost-filesystem-dev \
  libboost-iostreams-dev \
  libboost-locale-dev \
  libboost-numpy-dev \
  libboost-program-options-dev \
  libboost-python-dev \
  libboost-regex-dev \
  libboost-serialization-dev \
  libboost-system-dev \
  libboost-thread-dev \
  libboost-wave-dev \
  libbz2-dev \
  libclang-dev \
  libdbus-1-dev \
  libdecor-0-dev \
  libegl-dev \
  libembree-dev \
  libepoxy-dev \
  libfftw3-dev \
  libfontconfig-dev \
  libfreetype6-dev \
  libgl-dev \
  libgmp-dev \
  libhpdf-dev \
  libimath-dev \
  libjack-jackd2-dev \
  libjemalloc-dev \
  libjpeg-dev \
  liblzma-dev \
  libnanovdb-dev \
  libopenal-dev \
  libopencolorio-dev \
  libopenexr-dev \
  libopenimageio-dev \
  libopenjp2-7-dev \
  libopenvdb-dev \
  libopenxr-dev \
  libosd-dev \
  libpng-dev \
  libpotrace-dev \
  libpugixml-dev \
  libpulse-dev \
  libpystring-dev \
  libsdl2-dev \
  libshaderc-dev \
  libsndfile1-dev \
  libtbb-dev \
  libtiff-dev \
  libtool \
  libvulkan-dev \
  libwayland-dev \
  libx11-dev \
  libxcursor-dev \
  libxi-dev \
  libxinerama-dev \
  libxkbcommon-dev \
  libxml2-dev \
  libxrandr-dev \
  libxxf86vm-dev \
  libyaml-cpp-dev \
  libzstd-dev \
  linux-libc-dev \
  llvm-dev \
  locales \
  locales-all \
  meson \
  ninja-build \
  opencollada-dev \
  openimageio-tools \
  patch \
  patchelf \
  python3-certifi \
  python3-charset-normalizer \
  python3-dev \
  python3-idna \
  python3-mako \
  python3-numpy \
  python3-requests \
  python3-urllib3 \
  python3-zstandard \
  sudo \
  subversion \
  tcl \
  wayland-protocols \
  wget \
  yasm && \
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
      image: compile-blender
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
      working_dir: /git/blender
      volumes:
        - ./blender:/git/blender

EOF
fi

## Functions

clean() {

  docker compose down -v --rmi all --remove-orphans
  rm -rf \
    blender \
    build_linux \
    lib \
    .cache \
    .config \
    .gitconfig \
    .subversion \
    docker-compose.yml \
    Dockerfile \
    .wget-hsts

}

compile() {

  docker compose run compiler sh -c "cd blender && \
    make update && \
    make"


}

download() {

  [ ! -d blender ] && \
  docker compose run downloader clone --recurse-submodules https://projects.blender.org/blender/blender.git
  
}

getlibraries() {

  [ ! -d lib ] && \
  docker compose run compiler sh -c "mkdir -p lib && \
    cd lib && \
    svn checkout https://svn.blender.org/svnroot/bf-blender/trunk/lib/linux_x86_64_glibc_228
    svn checkout https://svn.blender.org/svnroot/bf-blender/trunk/lib/tests"

}

run() {

  docker compose run compiler sh -c "./build_linux/bin/blender"

}

update() {

  docker compose run updater pull --recurse-submodules
  docker compose run updater submodule update --init --recursive

  ## add necessary libraries


}

################################################################################
# Start it!
################################################################################

start() {

  download
  getlibraries
  update
  compile
  run

}

"$1"
