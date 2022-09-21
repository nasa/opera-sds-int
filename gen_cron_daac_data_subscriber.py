#!/usr/bin/env python3

import sys
from datetime import datetime, timedelta
import time
import argparse

'''Example Usage:

./gen_cron_daac_data_subscriber.py -c HLSL30 -s opera-dev-isl-fwd-pyoon -jc 10 -js 2022-01-01T00:00:00Z -mult=10

'''

_DEFAULT_JOB_DELAY = 3

def create_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument("-v", "--verbose", dest="verbose", action="store_true", help="Verbose mode.")
    parser.add_argument("-m", "--mode", dest="mode", type=str, required=True,
                             help="'full', 'query', or 'download' See daac_data_subscriber help for more info.")
    parser.add_argument("-ds", "--data-start-date", dest="data_start_date", default=False, required=True,
                             help="The ISO date time after which data should be retrieved. For Example, -ds 2021-01-14T00:00:00Z")
    parser.add_argument("-js", "--job-start-date", dest="job_start_date", default=None,
                             help="The ISO date time at which the cronjobs should start. For Example, -js 2022-07-10T20:00:00Z")
    parser.add_argument("-jd", "--job-delay-mins", dest="job_delay_mins", default=None,
                             help="Number of minutes after which the cronjobs should start. For Example, -jd 7 will start the first cronjob 7 minutes after script execution")
    parser.add_argument("-jp", "--job-period", dest="job_period", type=int, default=60,
                             help="How often, in minutes, should the cron job run (default: 60 minutes).")
    parser.add_argument("-jc", "--job-count", dest="job_count", type=int, required=True,
                             help="How many cron jobs to run.")
    parser.add_argument("-mult", "--multiplier", dest="multiplier", type=float, default=1.0,
                             help="Floating point multiplier factor for the time window. Each line item in the crontab runs every hour. If the multiplier is 1, each cronjob will cover 1 hour worth of data. If it's 0.5, it will cover 30 mins-worth. If it's 2 it will cover 2-hr worth. There is no overlap in data being fetched; the time-covered for the data will span NUM_HOURS * MULTIPLIER (default: 1.0).")
    parser.add_argument("-pass", "--pass-through", dest="pass_through", type=str, required=False,
                             help="Options to pass through to the daac_data_subscriber script directly")
    parser.add_argument("-o", "--output-file", dest="output_file", type=str, required=True,
                             help="Location of output file to send stdout to")      

    return parser

_source_profile = 'source /export/home/hysdsops/.bash_profile;' 
_python_and_subs = '/export/home/hysdsops/mozart/bin/python /export/home/hysdsops/mozart/ops/opera-pcm/data_subscriber/daac_data_subscriber.py'

parser = create_parser()
args = parser.parse_args()

date_format_str = "%Y-%m-%dT%H:%M:%SZ"
increment_mins = args.job_period * args.multiplier

start_dt = datetime.strptime(args.data_start_date, date_format_str)

# We look for job start date first and then job delay. If neither options are present, use default delay in starting jobs 
if args.job_start_date is not None:
    job_dt = datetime.strptime(args.job_start_date, date_format_str)
elif args.job_delay_mins is not None:
    job_dt = datetime.now() + timedelta(minutes=int(args.job_delay_mins))
else:
    job_dt = datetime.now() + timedelta(minutes=_DEFAULT_JOB_DELAY)

output_file_str = args.output_file
for i in range(0, args.job_count): 
    start = start_dt + timedelta(minutes=i*increment_mins)
    start_str = start.strftime(date_format_str)
    stop = start_dt + timedelta(minutes=(i+1)*increment_mins)
    stop_str = stop.strftime(date_format_str)
    cron = f"{job_dt.minute} {job_dt.hour} {job_dt.day} {job_dt.month} *"
    print(f" {cron} ({_source_profile} time  {_python_and_subs} {args.mode} -s {start_str} -e {stop_str} {args.pass_through}) >> {output_file_str} 2>&1")

    job_dt = job_dt + timedelta(minutes = args.job_period)

