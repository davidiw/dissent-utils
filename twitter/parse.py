#!/usr/bin/python2

from datetime import datetime
import pickle
import twitter

f = open("output")
statuses = pickle.load(f)
f.close()

def parse_time(twitter_time):
  return datetime.strptime(twitter_time, "%a %b %d %H:%M:%S +0000 %Y")

start = parse_time(statuses[0].created_at)
user_dict = {}
for status in statuses:
  if status.user.id not in user_dict:
    user_dict[status.user.id] = []

  from_start = (parse_time(status.created_at) - start).total_seconds()
  user_dict[status.user.id].append((from_start, len(status.text)))

user_arr = []
for arr in user_dict.values():
  user_arr.append(arr)

user_arr.sort(key=lambda value: len(value))
user_arr.reverse()

print from_start
print len(statuses)
print len(user_dict)

f = open("parsed", "w+")
pickle.dump(user_arr, f)
f.close()
