# devWhoops - a collection of scripts to quickly create dockerized development environments

***
The basic philosophy is fairly simple:
* with "./project.sh start" you download and setup everything necessary to begin with real work without losing too much time to configure everything.
* with "./project.sh clean" you clean everything except your project code. Use it carefully when changing configuration and remove changed configuration files from "project.sh clean()" function!

##### Trivia:
1. "Project name" (when applicable) is usually the parent folder.
2. You need to throw the linux version (with .sh extension) of GOG game in the folder before you run ./project.sh start (for gog-linux).
3. device kvm ( /dev/kvm ) should be owned by the current user (for react-native-dev).
4. kvm support must be installed on host (for react-native-dev).

##### Requirements:
* GNU/Linux operating system
* docker with docker compose plugin

---
1. **gog-linux** - for um... detailed "testing" of peripheral devices and help against coding blocks.
2. **heapsio-dev** - installs Heaps.io, mature HaXe game engine together with the freshly compiled recent version of HashLink virtual machine.
3. **react-native-dev** - installs everything necessary (Android SDK, emulators, node, countless JavaScript libs, ...) to begin development in React Native for Android. iOS not supported!
4. **wordpress-dev** - to install everything necessary (PHP and JS related) to develop themes/plugins for WordPress.

---

##### LICENSE: [MIT](https://www.mit.edu/~amini/LICENSE.md)

## HAPPY HACKING!
