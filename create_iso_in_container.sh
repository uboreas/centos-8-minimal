#!/bin/bash

./bootstrap.sh clean
./bootstrap.sh step isomount
./bootstrap.sh step createtemplate
./bootstrap.sh step scandeps
./bootstrap.sh step createrepo
./bootstrap.sh step createiso
./bootstrap.sh step isounmount
cp ./CentOS-8.1.1911-x86_64-minimal.iso /mnt/
