source /etc/fleet/credentials;

fleetctl login --email ${FLEET_USERNAME} --password ${FLEET_PASSWORD}

fleetctl get h > /tmp/host_overview.txt
fleetctl logout

./ho_parser.py solr.private.tst.railigent.com:12900
