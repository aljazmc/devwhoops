#!/bin/bash

## Variables

PROJECT_NAME=`printf '%s\n' "${PWD##*/}" | tr -cd '[:alnum:]_'`
# PROJECT_NAME is parent directory in alphanumerical
PROJECT_UID=`id -u`
PROJECT_GID=`id -g`
NODE_MAJOR=20

## Check if OS is linux, docker compose is installed and kvm device is in the mood

if ! (( "$OSTYPE" == "gnu-linux" )); then
  echo "script runs only on GNU/Linux OS. Exiting..."
  exit
fi

if [ ! -x "$(command -v compose version)" ]; then
  echo "Compose plugin is not installed. Exiting..."
  exit
fi

if [ `ls -ld /dev/kvm | awk '{print $3}'` != `echo $USER` ]; then
  echo "We need to make /dev/kvm owned by the current user"
  sudo chown `echo $USER` /dev/kvm
fi

## Configuration files

if [ ! -f Dockerfile ]; then
  cat <<-EOF > Dockerfile
FROM debian:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV ANDROID_EMULATOR_USE_SYSTEM_LIBS=1
ENV ANDROID_SDK_ROOT="/home/$USER/Android/Sdk"
ENV ANDROID_HOME="/home/$USER/Android/Sdk"
ENV JAVA_HOME="/usr/lib/jvm/java-1.17.0-openjdk-amd64"
ENV GRADLE_HOME="/home/$USER/.gradle"
ENV KOTLIN_HOME="/home/$USER/.kotlinc"
ENV PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/home/$USER/Android/Sdk/cmdline-tools/tools/bin:/home/$USER/Android/Sdk/platform-tools:/home/$USER/Android/Sdk/emulator:/usr/lib/jvm/java-1.17.0-openjdk-amd64/bin"

RUN dpkg --add-architecture i386
RUN apt-get update && apt-get install -y \
  bash \
  bridge-utils \
  build-essential \
  ca-certificates \
  curl \
  git \
  gnupg \
  lib32z1 \
  libbz2-1.0:i386 \
  libc6:i386 \
  libfreetype6 \
  libgl1-mesa-dri \
  libglu1 \
  libncurses5:i386 \
  libnotify4 \
  libqt5widgets5 \
  libstdc++6:i386 \
  libvirt-daemon-system \
  libxft2 \
  libxi6 \
  libxrender1 \
  libxtst6 \
  openjdk-17-jdk \
  qemu-system-arm \
  qemu-system-misc \
  qemu-system-x86 \
  sudo \
  unzip \
  wget \
  xvfb \
  && apt-get clean

RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | \
  sudo tee /etc/apt/sources.list.d/nodesource.list \
  && sudo apt-get update && sudo apt-get install --no-install-recommends nodejs -y \
  && apt-get clean

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - \
  && echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list \
  && sudo apt update && sudo apt install --no-install-recommends yarn \
  && apt-get clean

RUN groupadd -g $PROJECT_GID -r $USER
RUN useradd -u $PROJECT_UID -g $PROJECT_GID --create-home -r $USER
RUN adduser $USER libvirt
RUN adduser $USER kvm
#Change password
RUN echo "$USER:$USER" | chpasswd
#Make sudo passwordless
RUN echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$USER
RUN usermod -aG sudo $USER
RUN usermod -aG plugdev $USER

USER $USER
WORKDIR /home/$USER

CMD [  "sdkmanager" ]
EOF
fi

if [ ! -f docker-compose.yml ]; then
  cat <<- EOF > docker-compose.yml
services:
  android-sdk:
    build: .
    image: android-sdk
    user: $PROJECT_UID:$PROJECT_GID
    working_dir: /home/$USER
    environment:
      DISPLAY: $DISPLAY
      XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
    volumes:
      - .:/home/$USER
      - /run/user/${PROJECT_UID}:/run/user/${PROJECT_UID}
      - /tmp/.X11-unix:/tmp/.X11-unix
      - ~/.Xauthority:/root/.Xauthority
    devices:
      - /dev/bus/usb:/dev/bus/usb
      - /dev/dri:/dev/dri
      - /dev/kvm:/dev/kvm
      - /dev/snd:/dev/snd
    network_mode: host
EOF
fi

## Functions

clean() {

  docker compose down -v --rmi all --remove-orphans
  rm -rf Android \
    node_modules \
    $PROJECT_NAME \
    .android \
    .cache \
    .config \
    .gradle \
    .kotlin \
    .local \
    .npm \
    .pki \
    .yarn \
    docker-compose.yml \
    Dockerfile \
    .emulator_console_auth_token \
    .yarnrc

}

start() {
  [ ! -d Android ] && \
    mkdir -p Android/Sdk/cmdline-tools && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip && \
    unzip *tools*linux*.zip -d Android/Sdk/cmdline-tools && \
    mv Android/Sdk/cmdline-tools/cmdline-tools Android/Sdk/cmdline-tools/tools && \
    rm *tools*linux*.zip

  [ ! -d .android/avd ]       && mkdir -p .android/avd
  [ ! -d .android/cache ]     && mkdir -p .android/cache
  [ ! -d .cache/yarn ]      && mkdir -p .cache/yarn
  [ ! -d .config/yarn ]       && mkdir -p .config/yarn
  [ ! -d .gradle ]        && mkdir -p .gradle
  [ ! -d .kotlin ]        && mkdir -p .kotlin
  [ ! -d node_modules ]       && mkdir -p node_modules
  [ ! -d .yarn/bin ]        && mkdir -p .yarn/bin

  if [ ! -d $PROJECT_NAME ]; then
    docker compose run android-sdk yarn global add ynpx react-native cli && \
    docker compose run android-sdk yarn exec react-native init $PROJECT_NAME --template react-native-template-typescript
  else
    docker compose run android-sdk bash -c "cd $PROJECT_NAME && yarn install"
  fi

  docker compose run android-sdk bash -c "yes | sdkmanager --verbose --licenses && sdkmanager --list"

  docker compose run android-sdk bash -c "sdkmanager 'build-tools;33.0.0';
    sdkmanager 'platforms;android-33';
    sdkmanager 'platform-tools';
    sdkmanager 'system-images;android-33;google_apis;x86_64';
    adb devices;
    avdmanager list;
    avdmanager list avd;"

  docker compose run android-sdk bash -c "echo no | avdmanager create avd --force --name  'TestAPI33' --abi google_apis/x86_64 --package 'system-images;android-33;google_apis;x86_64'"
  sleep 15
  `ls /usr/bin | grep terminal` -e "docker compose run android-sdk bash -c 'adb start-server && emulator @TestAPI33 -dns-server 8.8.8.8'"
  sleep 15
  `ls /usr/bin | grep terminal` -e "docker compose run android-sdk bash -c 'cd $PROJECT_NAME && yarn exec react-native start'"
  sleep 15
  `ls /usr/bin | grep terminal` -e "docker compose run android-sdk bash -c 'cd $PROJECT_NAME && yarn android'"

}

"$1"
