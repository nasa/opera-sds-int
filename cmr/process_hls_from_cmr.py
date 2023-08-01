import os
import csv
import sys
from collections import defaultdict
from datetime import datetime

_date_format_str = "%Y-%m-%dT%H:%M:%SZ"
_date_format_str_cmr = _date_format_str[:-1] + ".%f"

''' For all granules with 200 and 201 events, create CSV file with delta time between
initial revision (201) and all subsequent revisions (200)'''

'''
Input file looks like this

"_time","native_id",status
"2023-05-02T20:21:27.542-0400","HLS.L30.T01FBE.2022035T213835.v2.0",200
"2023-04-07T20:18:19.040-0400","HLS.L30.T01FBE.2023094T213802.v2.0",201
'''

class HLSEvents:
    def __init__(self):
        # 201 code: initial revision for the granule
        self.initial_revision = None

        # 200 code: subsequent revisions for the granule. There can be several.
        self.subs_revisions = []

event_dict = defaultdict(HLSEvents)

file = sys.argv[1]
csvreader = csv.reader(open(file, 'r'))
next(csvreader) #skip the first line

for row in csvreader:
    id = row[1]
    date_str = row[0]
    date = datetime.strptime(date_str[:-5], _date_format_str_cmr)
    event = row[2]

    #print(id)

    hls_event = event_dict[id]

    if event == '201':
        hls_event.initial_revision = date

    elif event == '200':
        hls_event.subs_revisions.append(date)

with open(file+".result.csv", "w") as outfile:
    for id in event_dict:
        events = event_dict[id]
        events.subs_revisions.sort()

        # Only process for granules that have both initial revision and at least one subsequent revision
        if events.initial_revision is not None and len(events.subs_revisions) != 0:
            outfile.write(id+',')
            for sr in events.subs_revisions:
                timedelta_secs = (sr - events.initial_revision).total_seconds()
                timedelta_mins = round(timedelta_secs / 60)
                outfile.write(str(timedelta_mins))
                outfile.write(',')
            outfile.write('\n')
            #print(id)
            #print('\t', events.initial_revision)
            #print('\t', events.subs_revisions)

