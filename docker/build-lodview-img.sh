#!/usr/bin/env bash

if [ -d "LodView" ]; then rm -Rf LodView; fi
git clone --branch fix-war-plugin --single-branch https://github.com/miguel76/LodView
cd LodView
mvn compile war:war
docker build -t lodview .
cd ..
