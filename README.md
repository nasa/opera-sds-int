# opera-sds-int

Integration and testing activities and related artifacts

# cmr_survey
cmr_survey.py is used to survey the CMR database for hourly count of granules on a specific data set. It will create a csv file named cmr_survey.csv in the current working directory by default. You can optionally name it to something else.

usage: cmr_survey.py query [-h] -c COLLECTION [-s STARTDATE] [-e ENDDATE] [-b BBOX] [-m MINUTES] [-p PROVIDER] [-o OUT_CSV]

optional arguments:
  -h, --help            show this help message and exit

  -c COLLECTION, --collection-shortname COLLECTION
                        The collection shortname for which you want to retrieve data.

  -s STARTDATE, --start-date STARTDATE
                        The ISO date time after which data should be retrieved. For Example, --start-date 2021-01-14T00:00:00Z

  -e ENDDATE, --end-date ENDDATE
                        The ISO date time before which data should be retrieved. For Example, --end-date 2021-01-14T00:00:00Z

  -b BBOX, --bounds BBOX
                        The bounding rectangle to filter result in. Format is W Longitude,S Latitude,E Longitude,N Latitude without spaces. Due to an issue with parsing arguments, to
                        use this command, please use the -b="-180,-90,180,90" syntax when calling from the command line. Default: "-180,-90,180,90".

  -m MINUTES, --minutes MINUTES
                        How far back in time, in minutes, should the script look for data. If running this script as a cron, this value should be equal to or greater than how often
                        your cron runs (default: 60 minutes).

  -p PROVIDER, --provider PROVIDER
                        Specify a provider for collection search. Default is LPCLOUD.

  -o OUT_CSV, --out_csv OUT_CSV
                        Specify name of the output CSV file.

