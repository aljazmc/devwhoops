# devWhoops - devOps environments with Docker

***
The basic philosophy is:
* with "./project.sh start" you download and setup everything necessary to begin with real work without losing too much time to configure everything.
* with "./project.sh clean" you clean everything. Use it carefully when changing files and remove changed files from "project.sh clean()" function!

##### Requirements:
* GNU/Linux operating system
* docker with docker compose plugin

```
## Scripts:
blender-dev
gcc-dev
gimp-dev
go-dev
gog-linux
haskell-dev
heapsio-dev
inkscape-dev
java-dev
libreoffice-dev
node-dev
ocaml-dev
python-dev
react-native-dev
rust-dev
scala-dev
wordpress-dev
yt-dlp
```

#### Code Samples
```
## heapsio-dev
docker compose run haxe-sdk haxe compile.hxml     # compile code
docker compose run haxe-sdk hl hello.hl           # quick run with HashLink
```

##### LICENSE: [MIT](https://github.com/aljazmc/devwhoops/blob/main/LICENSE.txt)

## HAPPY HACKING!
