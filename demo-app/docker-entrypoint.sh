#!/bin/sh

set -e

if [ -n "$TEST_VAR" ]
then
  sed "s/TEST_VAR=/TEST_VAR=$TEST_VAR/g" -i /usr/share/nginx/html/index.html
fi

if [ -n "$TEST_SECRET" ]
then
  sed "s/TEST_SECRET=/TEST_SECRET=$TEST_SECRET/g" -i /usr/share/nginx/html/index.html
fi

#Emulate that app starts up for 15 seconds
nc -l 80 &
sleep 15;
echo 'killing nc'
killall nc

exec nginx -g 'daemon off;'

exit 0