## Running Multiple Instances

It's simple. Just run both individually.

couchdb -a etc/couchdb/local-1.ini -p var/run/couchdb-1.pid
couchdb -a etc/couchdb/local-2.ini -p var/run/couchdb-2.pid
