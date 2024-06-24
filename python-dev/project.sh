#!/bin/bash

## Variables

PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=`id -u`
PROJECT_GID=`id -g`

## Check for linux and docker compose or quit
if ! (( "$OSTYPE" == "gnu-linux" )); then
  echo "script runs only on GNU/Linux OS. Exiting..."
  exit
fi

if [[ ! -x "$(command -v compose version)" ]]; then
  echo "Compose plugin is not installed. Exiting..."
  exit
fi

## Configuration files

# docker-compose.yml
if [ ! -f docker-compose.yml ]; then
  cat << EOF > docker-compose.yml
  services:
    python:
      image: python:latest
      user: $PROJECT_UID:$PROJECT_GID
      working_dir: /usr/src/app
      volumes:
        - .:/usr/src/app
EOF
fi

clean() {

  docker compose down -v --rmi all --remove-orphans
  rm -rf \
    __pycache__ \
    docker-compose.yml \
    hello.py

}

doc() {

  ## Generate basic commit rules
  if [ ! -f doc/commitrules.txt ]; then
    mkdir -p doc
    cat << EOF > doc/commitrules.txt
## URL: https://gist.github.com/joshbuchea/6f47e86d2510bce28f8e7f42ae84c716

Semantic Commit Messages

See how a minor change to your commit message style can make you a better programmer.

Format: <type>(<scope>): <subject>

<scope> is optional
Example

feat: add hat wobble
^--^  ^------------^
|   |
|   +-> Summary in present tense.
|
+-------> Type: chore, docs, feat, fix, refactor, style, or test.

More Examples:

  feat: (new feature for the user, not a new feature for build script)
  fix: (bug fix for the user, not a fix to a build script)
  docs: (changes to the documentation)
  style: (formatting, missing semi colons, etc; no production code change)
  refactor: (refactoring production code, eg. renaming a variable)
  test: (adding missing tests, refactoring tests; no production code change)
  chore: (updating grunt tasks etc; no production code change)

EOF
  fi

}

python() {

  if [ ! -f hello.py ]; then
    cat<<EOF > hello.py
print('Hello, world!')
EOF
  fi

  docker compose run python sh -c "python -m py_compile hello.py"
  docker compose run python sh -c "python __pycache__/hello.cpython-312.pyc"
}

start() {

  python
  
}

"$1"
