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

if [ ! -f Dockerfile ]; then
  cat <<-EOF > Dockerfile
FROM debian:latest

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -y \
  build-essential \
  cmake \
  gettext \
  gettext-base \
  git \
  glib-networking \
  glib-networking-common \
  glib-networking-services \
  glib-networking-tests \
  libaa1-dev \
  libappstream-glib-dev \
  libatk1.0-dev \
  libasprintf-dev \
  libbabl-dev \
  libcairo2-dev \
  libegl-dev \
  libgegl-dev \
  libgettextpo-dev \
  libgexiv2-dev \
  libgirepository1.0-dev \
  libglib2.0-dev \
  libgtk-3-dev \
  libjpeg-dev \
  liblcms2-dev \
  libmng-dev \
  libmypaint-dev \
  libmypaint-dev \
  libpango1.0-dev \
  libpng-dev \
  libpoppler-glib-dev \
  librsvg2-dev \
  librust-bzip2-dev \
  libtiff-dev \
  libwmf-dev \
  libxmu-dev \
  linux-libc-dev \
  meson \
  mypaint-brushes \
  python3-cairo-dev \
  subversion \
  sudo \
  xsltproc && \
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
      image: compile-gimp
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
      working_dir: /git/gimp
      volumes:
        - ./gimp:/git/gimp        
EOF
fi

## Functions 

clean() {

  docker compose down -v --rmi all --remove-orphans
  rm -rf \
    build \
    babl \
    .cache \
    .config \
    docker-compose.yml \
    Dockerfile \
    gegl \
    gimp \
    gimp_prefix \
    .local

}

compile() {

  docker compose run compiler sh -c 'export GIMP_PREFIX=${HOME}/gimp_prefix && \
                      export PATH="${GIMP_PREFIX}/bin:$PATH" && \
                      export PKG_CONFIG_PATH="${GIMP_PREFIX}/share/pkgconfig:${GIMP_PREFIX}/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" && \
                      export PKG_CONFIG_PATH="${GIMP_PREFIX}/lib64/pkgconfig:$PKG_CONFIG_PATH" && \
                      export XDG_DATA_DIRS="${XDG_DATA_DIRS:+$XDG_DATA_DIRS:}${GIMP_PREFIX}/share:/usr/local/share:/usr/share" && \
                      export LD_LIBRARY_PATH="${GIMP_PREFIX}/lib:${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" && \
                      export ACLOCAL_FLAGS="-I $INSTALL_PREFIX/share/aclocal $ACLOCAL_FLAGS" && \
                      GI_TYPELIB_PATH="${GIMP_PREFIX}/lib/girepository-1.0:${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}" && \
                      arch="$(dpkg-architecture -q DEB_HOST_MULTIARCH 2> /dev/null)" && \
                      export PKG_CONFIG_PATH="${GIMP_PREFIX}/lib/${arch}/pkgconfig:$PKG_CONFIG_PATH" && \
                      export LD_LIBRARY_PATH="${GIMP_PREFIX}/lib/${arch}:${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" && \
                      export GI_TYPELIB_PATH="${GIMP_PREFIX}/lib/${arch}/girepository-1.0:${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}" && \
                      cd babl && \
                      meson _build \
                      --prefix=${GIMP_PREFIX} \
                      --buildtype=release \
                      -Db_lto=true && \
                      cd _build && \
                      ninja && \
                      ninja install && \
                      cd ../.. && \
                      cd gegl && \
                      meson _build \
                      --prefix=${GIMP_PREFIX} \
                      --buildtype=release \
                      -Db_lto=true && \
                      cd _build && \
                      ninja && \
                      ninja install && \
                      cd ../.. && \
                      cd gimp && \
                      meson _build \
                      --prefix=${GIMP_PREFIX} \
                      --buildtype=release \
                      -Dpython=enabled && \
                      cd _build && \
                      ninja && \
                      ninja install'

}

download() {

  [ ! -d babl ] && \
  docker compose run downloader clone https://gitlab.gnome.org/GNOME/babl.git

  [ ! -d gegl ] && \
  docker compose run downloader clone https://gitlab.gnome.org/GNOME/gegl.git
  
  [ ! -d gimp ] && \
  docker compose run downloader clone https://gitlab.gnome.org/GNOME/gimp.git

}

run() {

  docker compose run compiler bash -c 'export LD_LIBRARY_PATH="`echo $PWD`/gimp_prefix/lib/x86_64-linux-gnu/:$LD_LIBRARY_PATH" && \
                        ./gimp_prefix/bin/gimp-2.99'

}

update() {

  docker compose run compiler sh -c "cd babl && \
                      git pull --recurse-submodules && \
                      git submodule update --init --recursive && \
                      cd .. && \
                      cd gegl && \
                      git pull --recurse-submodules && \
                      git submodule update --init --recursive && \
                      cd .. && \
                      cd gimp && \
                      git pull --recurse-submodules && \
                      git submodule update --init --recursive"

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
