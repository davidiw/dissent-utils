#!/usr/bin/python

from datetime import datetime
import httplib
import json
import sys
import time

def request(ip, port, offset):
  conn = httplib.HTTPConnection(ip, port)
  conn.request("GET", "/session/messages?offset=%s&count=-1&wait=1" % offset)
  return conn.getresponse()
  
def main():
  if len(sys.argv) != 3:
    sys.stderr.write("Usage: %s port output\n" % sys.argv[0])
    return 0

  port = int(sys.argv[1])
  fname = sys.argv[2]

  offset = 0
  start = datetime.now()

  while True:
    resp = request("127.0.0.1", port, offset)
    if resp.status != 200:
      print "Failed! %d %s" %s (resp.status, resp.reason)
      return 0
    output = resp.read()
    try:
      msg = json.loads(output)
      count = len(msg["output"]["messages"])
      offset += count

      f = open(fname, "a")
      for idx in range(count):
        f.write("%f\n" % (datetime.now() - start).total_seconds())
      f.close()
    except:
      offset += 1
      print output

if __name__ == "__main__":
  main()
  
