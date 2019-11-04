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

#Emulate that app starts up for 5 seconds
sleep 5;

exec nginx -g 'daemon off;'

exit 0