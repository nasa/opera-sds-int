from datetime import datetime, timedelta
import logging
import csv
import sys
import numpy as np
import matplotlib.pyplot as plt

temporal_time_limit = "2023-04-01T00:00:00.000Z"

'''Expects CSV file w 4 columns, comma-separated:
Granule ID (ignored)
Revision Time (ignored)
Temporal Time
Revision-Temporal Delta Hours'''

_date_format_str = "%Y-%m-%dT%H:%M:%SZ"
_date_format_str_cmr = _date_format_str[:-1] + ".%fZ"

temporal_time_limit = datetime.strptime(temporal_time_limit, _date_format_str_cmr)

all_deltas = []
row_count = 0

with open(sys.argv[1], 'r') as input_file:
    csvreader = csv.reader(input_file)
    for row in csvreader:
        if row[0][0] == '#':
            continue

        row_count += 1
        temporal_time = datetime.strptime(row[2], _date_format_str_cmr)
        if temporal_time >= temporal_time_limit:
            all_deltas.append(float(row[3]))

    print(f"Out of total {row_count} entries {len(all_deltas)} entries had temporal time later than {temporal_time_limit}. Difference of {len(all_deltas)-row_count}")

    hist_title = f"Histogram of Revision vs Temporal Time for all granules"
    logging.info(hist_title)
    _ = plt.hist(all_deltas, bins=50)
    #print(hist_e)
    #print(hist_v)
    plt.title(hist_title)
    histo_file = sys.argv[1]+".svg"
    print("Saving histogram figure as " + histo_file)
    plt.savefig(histo_file, format="svg", dpi=1200)
    plt.show()

