#!/usr/bin/python2

import hashlib
import httplib
import pickle
import random
import string
import sys
import time

def send(ip, port, msg):
  conn = httplib.HTTPConnection(ip, port)
  conn.request("POST", "/session/send", msg, {"Accept": "text/plain"})
  return conn.getresponse()

def main():
  if len(sys.argv) < 5:
    sys.stderr.write("Usage: %s port count my_idx dataset\n" % sys.argv[0])
    return

  port = int(sys.argv[1])
  count = int(sys.argv[2])
  my_idx = int(sys.argv[3])

  duration = -1
  if sys.argv == 6:
    duration = int(sys.argv[5])

  f = open(sys.argv[4])
  s = f.read()
  dataset = pickle.loads(s)
  f.close()

  data_count = len(dataset)
  rand = random.Random(s)
  selected = {}
  idx = 0
  bound = min(.5, 1.0 - (data_count * 1.0) / (count * 1.0))

  while idx <= my_idx:
    if rand.random() < bound:
      sel_idx = data_count + idx
    else:
      sel_idx = int(data_count * rand.random())

    while sel_idx in selected:
      if rand.random() < bound:
        sel_idx = data_count + idx
      else:
        sel_idx = int(data_count * rand.random())

    selected[sel_idx] = idx
    idx += 1

  if data_count <= sel_idx:
    print "Passive member"
    return 0

  dataset = dataset[sel_idx]
  print "Active member:"
  print dataset

  ctime = 0
  for entry in dataset:
    if duration != -1 and entry[0] > duration:
      break
    time.sleep(entry[0] - ctime)
#    Debug
#    time.sleep(1)
    ctime = entry[0]

    msg = ''.join(random.choice(string.ascii_letters + string.digits) \
        for x in range(entry[1]))
    resp = send("127.0.0.1", port, msg)

    if resp.status != 200:
      print "Failed! %d %s" % (resp.status, resp.reason)

if __name__ == "__main__":
  main()
