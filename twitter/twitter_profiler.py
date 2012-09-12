#!/usr/bin/python2

import pickle
import random
import sys

def main():
  if len(sys.argv) < 4:
    sys.stderr.write("Usage: %s count online_count dataset\n" % sys.argv[0])
    return

  count = int(sys.argv[1])
  online_count = int(sys.argv[2])

  duration = -1
  if sys.argv == 5:
    duration = int(sys.argv[4])

  f = open(sys.argv[3])
  s = f.read()
  dataset = pickle.loads(s)
  f.close()

  times = []
  data_count = len(dataset)
  for sel in range(online_count):
    if data_count <= sel:
      continue
    for value in dataset[sel]:
      times.append(value[0])

  times.sort()
  for time in times:
    print time

if __name__ == "__main__":
  main()

'''
  rand = random.Random(s)
# Random distribution
  selected = {}
  idx = 0
  bound = min(.5, 1.0 - (data_count * 1.0) / (count * 1.0))

  while idx < online_count:
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

  print selected
  for sel in selected.keys():
'''
