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
    .cache \
    .config \
    compile.hxml \
    doc \
    docker-compose.yml \
    Dockerfile \
    hello.hl \
    .haxelib \
    haxelib \
    src

}

start() {

  mkdir -p src haxelib doc
  
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
FROM haxe:latest

ENV PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/haxelib:/usr/lib/haxe/lib"

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
  make \
  sudo && \
  rm -rf /var/lib/apt/lists/* && \
  mkdir -p /usr/src/hashlink /usr/lib/haxe/lib && \
  cd /usr/src && \
  git clone https://github.com/HaxeFoundation/hashlink && \
  cd hashlink && \
  make && \
  make install

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

if [[ ! -f docker-compose.yml ]]; then
  cat <<-EOF > docker-compose.yml
  services:
  haxe-sdk:
    build: .
    image: haxe-sdk
    user: ${PROJECT_UID}:${PROJECT_GID}
    working_dir: /home/$USER
    environment:
    DISPLAY: $DISPLAY
    XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
    volumes:
    - .:/home/$USER
    - ./haxelib:/usr/lib/haxe/lib
    - /tmp/.X11-unix:/tmp/.X11-unix
    - /run/user/${PROJECT_UID}:/run/user/${PROJECT_UID}
    - /var/lib/dbus/machine-id:/var/lib/dbus/machine-id
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

[ ! -d haxelib/heaps ]    && docker compose run haxe-sdk bash -c "haxelib setup && haxelib install heaps"
[ ! -d haxelib/hlopenal ]   && docker compose run haxe-sdk bash -c "haxelib install hlopenal"
[ ! -d haxelib/hlsdl ]    && docker compose run haxe-sdk bash -c "haxelib install hlsdl"
[ ! -d haxelib/hldx ]     && docker compose run haxe-sdk bash -c "haxelib install hldx"

docker compose run haxe-sdk haxe compile.hxml
docker compose run haxe-sdk hl hello.hl

}

$1
