#!/usr/bin/python3

import http.client
import ssl
import json

def query_solr():

  ssl_context = ssl.create_default_context()
  ssl_context.verify_mode = ssl.CERT_REQUIRED
  ssl_context.load_verify_locations('/tmp/server.crt')

  conn = http.client.HTTPSConnection('solr.private.tst.railigent.com', context = ssl_context)
  conn.request('GET', '/solr/kolide/select?q=name:"pack/locked-shields-2020/arp"%20AND%20action:added&facet=true&facet.limit=-1&facet.field=columns.mac&facet.field=columns.address&rows=0&wt=json')

  resp = conn.getresponse()

  if resp.status == 200:
    data = json.loads(resp.read())

    with open('compare_hosts_whitelist.json') as json_file:
      whitelist = json.load(json_file)

    base_node = data['facet_counts']['facet_fields']

    toggle = True

    for mac in base_node['columns.mac']:
      if toggle:
        if mac not in whitelist['macs']:
          print ("Unknown MAC found: {}".format(mac))

      toggle = not toggle

    toggle = True

    for address in base_node['columns.address']:
      if toggle:
        if address not in whitelist['ips']:
          print ("Unknown address found: {}".format(address))

      toggle = not toggle

  conn.close()


query_solr()
