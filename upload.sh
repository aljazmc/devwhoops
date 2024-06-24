#!/bin/bash

rm -rf .git
git init
git add .
git commit -m "chore: initial commit"
git remote add origin https://github.com/aljazmc/devwhoops.git
git push -f origin main
