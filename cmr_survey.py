#!/usr/bin/env python3

# Forked from github.com:podaac/data-subscriber.git


import argparse
import asyncio
import itertools
import socket
import json
import logging
import netrc
import os
import re
import shutil
import sys
import uuid
from contextlib import contextmanager
from datetime import datetime, timedelta
from functools import partial
from http.cookiejar import CookieJar
from multiprocessing.pool import ThreadPool
from pathlib import Path
from typing import Any, Iterable
from urllib import request
from urllib.parse import urlparse

import boto3
import requests
from hysds_commons.job_utils import submit_mozart_job
from more_itertools import map_reduce, chunked
from smart_open import open

from data_subscriber.hls.hls_catalog_connection import get_hls_catalog_connection
from data_subscriber.hls_spatial.hls_spatial_catalog_connection import get_hls_spatial_catalog_connection

_date_format_str = "%Y-%m-%dT%H:%M:%SZ"

class SessionWithHeaderRedirection(requests.Session):
    """
    Borrowed from https://wiki.earthdata.nasa.gov/display/EL/How+To+Access+Data+With+Python
    """

    def __init__(self, username, password, auth_host):
        super().__init__()
        self.auth = (username, password)
        self.auth_host = auth_host

    # Overrides from the library to keep headers when redirected to or from
    # the NASA auth host.
    def rebuild_auth(self, prepared_request, response):
        headers = prepared_request.headers
        url = prepared_request.url

        if 'Authorization' in headers:
            original_parsed = requests.utils.urlparse(response.request.url)
            redirect_parsed = requests.utils.urlparse(url)
            if (original_parsed.hostname != redirect_parsed.hostname) and \
                    redirect_parsed.hostname != self.auth_host and \
                    original_parsed.hostname != self.auth_host:
                del headers['Authorization']


async def run(argv: list[str]):
    parser = create_parser()
    args = parser.parse_args(argv[1:])
    try:
        validate(args)
    except ValueError as v:
        raise v

    HLS_CONN = get_hls_catalog_connection(logging.getLogger(__name__))
    if args.file:
        with open(args.file, "r") as f:
            update_url_index(HLS_CONN, f.readlines(), None, None)
        exit(0)

    IP_ADDR = socket.gethostbyname(socket.gethostname())
    EDL = "urs.earthdata.nasa.gov"
    CMR = "cmr.earthdata.nasa.gov"
    TOKEN_URL = f"https://{CMR}/legacy-services/rest/tokens"
    NETLOC = urlparse("https://urs.earthdata.nasa.gov").netloc

    LOGLEVEL = 'DEBUG' if args.verbose else 'INFO'
    logging.basicConfig(level=LOGLEVEL)
    logging.info("Log level set to " + LOGLEVEL)

    logging.info(f"{argv=}")

    job_id = uuid.uuid4()
    logging.info(f"{job_id=}")

    username, password = setup_earthdata_login_auth(EDL)

    with token_ctx(TOKEN_URL, IP_ADDR, EDL) as token:
        logging.info(f"{args.subparser_name=}")
        results = {}
        results["query"] = await run_query(args, token, HLS_CONN, CMR, job_id)

    logging.info(f"{results=}")
    logging.info("END")
    return results

async def run_query(args, token, HLS_CONN, CMR, job_id):
    HLS_SPATIAL_CONN = get_hls_spatial_catalog_connection(logging.getLogger(__name__))
    query_dt = datetime.now()
    granules = query_cmr(args, token, CMR)


def create_parser():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="subparser_name", required=True)
    parser.add_argument("-v", "--verbose", dest="verbose", action="store_true", help="Verbose mode.")
    parser.add_argument("-f", "--file", dest="file",
                        help="Path to file with newline-separated URIs to ingest into data product ES index (to be downloaded later).")

    query_parser = subparsers.add_parser("query")
    query_parser.add_argument("-c", "--collection-shortname", dest="collection", required=True,
                              help="The collection shortname for which you want to retrieve data.")
    query_parser.add_argument("-s", "--start-date", dest="startDate", default=None,
                              help="The ISO date time after which data should be retrieved. For Example, --start-date 2021-01-14T00:00:00Z")
    query_parser.add_argument("-e", "--end-date", dest="endDate", default=None,
                              help="The ISO date time before which data should be retrieved. For Example, --end-date 2021-01-14T00:00:00Z")
    query_parser.add_argument("-b", "--bounds", dest="bbox", default="-180,-90,180,90",
                              help="The bounding rectangle to filter result in. Format is W Longitude,S Latitude,E Longitude,N Latitude without spaces. Due to an issue with parsing arguments, to use this command, please use the -b=\"-180,-90,180,90\" syntax when calling from the command line. Default: \"-180,-90,180,90\".")
    query_parser.add_argument("-m", "--minutes", dest="minutes", type=int, default=60,
                              help="How far back in time, in minutes, should the script look for data. If running this script as a cron, this value should be equal to or greater than how often your cron runs (default: 60 minutes).")
    query_parser.add_argument("-p", "--provider", dest="provider", default='LPCLOUD',
                              help="Specify a provider for collection search. Default is LPCLOUD.")
    query_parser.add_argument("-o", "--out_csv", dest="out_csv", default='cmr_survey.csv',
                              help="Specify name of the output CSV file.")

    return parser


def validate(args):
    if hasattr(args, "bbox") and args.bbox:
        validate_bounds(args.bbox)

    if hasattr(args, "startDate") and args.startDate:
        validate_date(args.startDate, "start")

    if hasattr(args, "endDate") and args.endDate:
        validate_date(args.endDate, "end")

    if hasattr(args, "minutes") and args.minutes:
        validate_minutes(args.minutes)


def validate_bounds(bbox):
    bounds = bbox.split(',')
    value_error = ValueError(
        f"Error parsing bounds: {bbox}. Format is <W Longitude>,<S Latitude>,<E Longitude>,<N Latitude> without spaces ")

    if len(bounds) != 4:
        raise value_error

    for b in bounds:
        try:
            float(b)
        except ValueError:
            raise value_error


def validate_date(date, type='start'):
    try:
        datetime.strptime(date, '%Y-%m-%dT%H:%M:%SZ')
    except ValueError:
        raise ValueError(
            f"Error parsing {type} date: {date}. Format must be like 2021-01-14T00:00:00Z")


def validate_minutes(minutes):
    try:
        int(minutes)
    except ValueError:
        raise ValueError(f"Error parsing minutes: {minutes}. Number must be an integer.")


def setup_earthdata_login_auth(endpoint):
    # ## Authentication setup
    #
    # This function will allow Python scripts to log into any Earthdata Login
    # application programmatically.  To avoid being prompted for
    # credentials every time you run and also allow clients such as curl to log in,
    # you can add the following to a `.netrc` (`_netrc` on Windows) file in
    # your home directory:
    #
    # ```
    # machine urs.earthdata.nasa.gov
    #     login <your username>
    #     password <your password>
    # ```
    #
    # Make sure that this file is only readable by the current user
    # or you will receive an error stating
    # "netrc access too permissive."
    #
    # `$ chmod 0600 ~/.netrc`
    #
    # You'll need to authenticate using the netrc method when running from
    # command line with [`papermill`](https://papermill.readthedocs.io/en/latest/).
    # You can log in manually by executing the cell below when running in the
    # notebook client in your browser.*

    """
    Set up the request library so that it authenticates against the given
    Earthdata Login endpoint and is able to track cookies between requests.
    This looks in the .netrc file first and if no credentials are found,
    it prompts for them.

    Valid endpoints include:
        urs.earthdata.nasa.gov - Earthdata Login production
    """
    username = password = ""
    try:
        username, _, password = netrc.netrc().authenticators(endpoint)
    except FileNotFoundError as e:
        logging.error("There's no .netrc file")
        raise e
    except TypeError as e:
        logging.error("The endpoint isn't in the netrc file")
        raise e

    manager = request.HTTPPasswordMgrWithDefaultRealm()
    manager.add_password(None, endpoint, username, password)
    auth = request.HTTPBasicAuthHandler(manager)

    jar = CookieJar()
    processor = request.HTTPCookieProcessor(jar)
    opener = request.build_opener(auth, processor)
    opener.addheaders = [('User-agent', 'daac-subscriber')]
    request.install_opener(opener)

    return username, password


def get_token(url: str, client_id: str, user_ip: str, endpoint: str) -> str:
    username, _, password = netrc.netrc().authenticators(endpoint)
    xml = f"<?xml version='1.0' encoding='utf-8'?><token><username>{username}</username><password>{password}</password><client_id>{client_id}</client_id><user_ip_address>{user_ip}</user_ip_address></token>"
    headers = {'Content-Type': 'application/xml', 'Accept': 'application/json'}
    resp = requests.post(url, headers=headers, data=xml)
    response_content = json.loads(resp.content)
    token = response_content['token']['id']

    return token


def query_cmr(args, token, CMR) -> list:
    PAGE_SIZE = 2000
    now = datetime.utcnow()
    now_date = now.strftime("%Y-%m-%dT%H:%M:%SZ")

    start_dt = datetime.strptime(args.startDate, _date_format_str)
    end_dt = datetime.strptime(args.endDate, _date_format_str)

    out_csv = open(args.out_csv, 'w')
    out_csv.write("# DateTime Range:" + start_dt.strftime("%Y-%m-%dT%H:%M:%SZ") + " to " + end_dt.strftime("%Y-%m-%dT%H:%M:%SZ") + '\n')

    while start_dt < end_dt:

        start_str = start_dt.strftime("%Y-%m-%dT%H:%M:%SZ")
        end_str = (start_dt + timedelta(minutes=60)).strftime("%Y-%m-%dT%H:%M:%SZ")

        request_url = f"https://{CMR}/search/granules.umm_json"
        params = {
            'page_size': PAGE_SIZE,
            'sort_key': "-start_date",
            'provider': args.provider,
            'ShortName': args.collection,
            'updated_since': start_str,
            'token': token,
            'bounding_box': args.bbox,
        }

        temporal_range = get_temporal_range(start_str, end_str, now_date)
        #params['temporal'] = '2022-01-01T00:00:00Z,2023-01-01T01:00:00Z'
        #params['temporal'] = temporal_range
        params['revision_date'] = temporal_range

        product_granules, search_after = request_search(request_url, params)

        while search_after:
            granules, search_after = request_search(request_url, params, search_after=search_after)
            product_granules.extend(granules)

        count = len(product_granules)

        out_csv.write(start_str)
        out_csv.write(',')
        out_csv.write(end_str)
        out_csv.write(',')
        out_csv.write(str(count))
        out_csv.write('\n')

        logging.info(f"{start_str},{end_str},{str(count)}")

        start_dt = start_dt + timedelta(minutes=60)

    out_csv.close()

    logging.info("Output CSV written out to file: " + str(args.out_csv))

    return product_granules


def get_temporal_range(start, end, now):
    start = start if start is not False else None
    end = end if end is not False else None

    if start is not None and end is not None:
        return "{},{}".format(start, end)
    if start is not None and end is None:
        return "{},{}".format(start, now)
    if start is None and end is not None:
        return "1900-01-01T00:00:00Z,{}".format(end)

    raise ValueError("One of start-date or end-date must be specified.")


def request_search(request_url, params, search_after=None):
    response = requests.get(request_url, params=params, headers={'CMR-Search-After': search_after}) \
        if search_after else requests.get(request_url, params=params)
    results = response.json()
    items = results.get('items')
    next_search_after = response.headers.get('CMR-Search-After')

    if items and 'umm' in items[0]:
        return [{"granule_id": item.get("umm").get("GranuleUR"),
                 "provider": item.get("meta").get("provider-id"),
                 "production_datetime": item.get("umm").get("DataGranule").get("ProductionDateTime"),
                 "short_name": item.get("umm").get("Platforms")[0].get("ShortName"),
                 "bounding_box": [{"lat": point.get("Latitude"), "lon": point.get("Longitude")}
                                  for point
                                  in item.get("umm").get("SpatialExtent").get("HorizontalSpatialDomain")
                                      .get("Geometry").get("GPolygons")[0].get("Boundary").get("Points")],
                 "related_urls": [url_item.get("URL") for url_item in item.get("umm").get("RelatedUrls")]}
                for item in items], next_search_after
    else:
        return [], None

def convert_datetime(datetime_obj, strformat="%Y-%m-%dT%H:%M:%S.%fZ"):
    if isinstance(datetime_obj, datetime):
        return datetime_obj.strftime(strformat)
    return datetime.strptime(str(datetime_obj), strformat)


def update_url_index(ES_CONN, urls, granule_id, job_id, query_dt):
    for url in urls:
        ES_CONN.process_url(url, granule_id, job_id, query_dt)


def get_aws_creds(session):
    with session.get("https://data.lpdaac.earthdatacloud.nasa.gov/s3credentials") as r:
        if r.status_code != 200:
            r.raise_for_status()

        return r.json()

@contextmanager
def token_ctx(token_url, ip_addr, edl):
    token = get_token(token_url, 'daac-subscriber', ip_addr, edl)
    try:
        yield token
    finally:
        delete_token(token_url, token)


def delete_token(url: str, token: str) -> None:
    try:
        headers = {'Content-Type': 'application/xml', 'Accept': 'application/json'}
        url = '{}/{}'.format(url, token)
        resp = requests.request('DELETE', url, headers=headers)
        if resp.status_code == 204:
            logging.info("CMR token successfully deleted")
        else:
            logging.warning("CMR token deleting failed.")
    except Exception as e:
        logging.warning("Error deleting the token")


if __name__ == '__main__':
    asyncio.run(run(sys.argv))
