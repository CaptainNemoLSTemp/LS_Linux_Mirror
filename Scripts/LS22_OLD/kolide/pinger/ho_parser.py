#!/usr/bin/python3

import argparse
import http.client
import json
import sys
import re
from datetime import datetime

def parse_ho(args, hof):

  line = hof.readline()
  result = []
  timestamp = datetime.utcnow().strftime ('%a %b %d %H:%M:%S %Y UTC')

  while line:
    matchObj = re.match(r'^\+.*\+$', line)

    if not matchObj:
      matchObj = re.match(r'^\|(.*)\|(.*)\|(.*)\|(.*)\|$', line.strip())

      if matchObj and matchObj.group(1).strip() != 'UUID':
        temp = {}

        temp['name'] = 'host_online_state'
        temp['hostIdentifier'] = matchObj.group(1).strip()
        temp['columns.hostname'] = matchObj.group(2).strip()
        temp['columns.online'] = matchObj.group(4).strip() == 'online'
        temp['columns.timestamp'] = timestamp
        temp['calendarTime'] = timestamp

        result.append(temp)

    line = hof.readline()

  return result

def send_data_to_logstash(args, params):

  headers = {"Content-type": "application/json"}
  params = json.dumps(params)

  conn = http.client.HTTPConnection(args.logstash_url)
  conn.request("POST", "", params, headers)

  is_ok = conn.getresponse().status == 200

  conn.close()

  return is_ok


def main():

  parser = argparse.ArgumentParser()
  parser.add_argument('--source_file', help='File which should be parsed (output from fleetctl get h)', default='/tmp/host_overview.txt')
  parser.add_argument('logstash_url', help='Solr logstash url')

  args = parser.parse_args()

  with open(args.source_file, "r") as hof:
    result = parse_ho(args, hof)

    if len(result) > 0:
      return send_data_to_logstash(args, result)
    else:
      return true


res = main()

if res:
  sys.exit(0)
else:
  sys.exit(1)
