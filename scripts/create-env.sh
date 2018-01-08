#!/bin/sh
cd ..
git clone https://github.com/libremesh/lime-sdk.git env
cd env
./cooker -d ar71xx/generic

echo "src-link firstbootwizard $( cd ..; pwd )" >> feeds.conf.default
./cooker -f
