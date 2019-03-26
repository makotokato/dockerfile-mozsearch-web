#!/bin/sh

if [ $# != 2 ]
then
    echo "usage: $0 <config-repo-path> <index-path>"
    exit 1
fi

/vagrant/infrastructure/web-server-setup.sh $1 config.json $2 /work/www
/vagrant/infrastructure/web-server-run.sh $1 $2 /work/www
/etc/init.d/nginx start
tail -f /dev/null

