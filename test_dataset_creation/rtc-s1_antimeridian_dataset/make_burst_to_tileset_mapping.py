import ast
import sqlite3

import numpy as np
import pandas as pd



def flatten(xss):
    return [x for xs in xss for x in xs]


def get_mgrs_burst_db_from_sqlite_file(mgrs_tileset_db_filepath):

    cnx = sqlite3.connect(mgrs_tileset_db_filepath)

    df = pd.read_sql_query("SELECT * FROM mgrs_burst_db", cnx)
    #df.columns

    cnx.close()
    
    return df


def get_bursts_from_query(rtc_burst_list_filename):

    lines = []
    if isinstance(rtc_burst_list_filename, str):
        with open(rtc_burst_list_filename) as f:
            lines += [line.rstrip() for line in f]
    elif isinstance(rtc_burst_list_filename, (list, tuple)):
        for fname in rtc_burst_list_filename:
            with open(fname) as f:
                lines += [line.rstrip() for line in f]
    else:
        pass    
            
    # magic number:  4 is the index to get the granule ID (without the filename extensions)
    bursts_from_query = np.unique([l.split('/')[4] for l in lines])

    return bursts_from_query


def map_bursts_to_tilesets(rtc_burst_list_filename):

    df = get_mgrs_burst_db_from_sqlite_file('/Users/Sjlewis/proj/src-git/opera/dswx_s1_burst_db_data/MGRS_tile_collection_v0.3.sqlite')

    #burst_array = np.array(df.bursts)

    #burst_list = []
    #for b in burst_array:
    #    burst_list.append(ast.literal_eval(b))

    #burst_list = np.array(flatten(burst_list))

    #burst_list_unique = np.unique(burst_list)
    # this results in a numpy array with a list of unique burst IDs (list/array of text)


    #mgrs_set_ids = np.empty(burst_list_unique.shape)

    # this will take a while
    #for b, s in zip(burst_list_unique, mgrs_set_ids):
    #    s = list(df['mgrs_set_id'][df['bursts'].str.contains(b)])

    bursts_from_query = get_bursts_from_query(rtc_burst_list_filename)

    # This will take a while
    # magic number:  3 is the column to get the burstID from the granule ID
    tilesets = [list(np.where(df['bursts'].str.contains(burst.split('_')[3].lower().replace('-','_')))[0]) for burst in bursts_from_query]

    tilesets_unique = np.unique(flatten(tilesets))

    print(df['mgrs_set_id'][tilesets_unique])
    # Here's what will get printed out for the antimeridian case
    #['MS_1_58','MS_1_59','MS_1_60','MS_1_61','MS_30_65','MS_30_66','MS_66_40','MS_66_41','MS_66_171','MS_66_172','MS_81_29','MS_81_30','MS_146_103','MS_146_104','MS_146_105']


    indices_with_unique_tiles = np.array([len(a)==1 for a in tilesets])

    bursts_antimeridian_with_unique_tiles = bursts_from_query[indices_with_unique_tiles]

    # have an extra np.array(flatten(list( in there because... I think having dtype=object does something weird.
    # I just want a numpy array of the indices of the tilesets in the df
    tilesets_for_bursts_with_unique_tiles = np.array(flatten(list(np.array(tilesets, dtype=object)[indices_with_unique_tiles])))

    bursts_antimeridian_with_unique_tiles[tilesets_for_bursts_with_unique_tiles == tilesets_unique[0]]

    # get the date of the first entry of the first tileset
    bursts_antimeridian_with_unique_tiles[tilesets_for_bursts_with_unique_tiles == tilesets_unique[0]][0].split('_')[4].split('T')[0]

    # unique dates for the first tileset
    np.unique([b.split('_')[4].split('T')[0] for b in bursts_antimeridian_with_unique_tiles[tilesets_for_bursts_with_unique_tiles == tilesets_unique[0]]])

    dates, inds = np.unique([b.split('_')[4].split('T')[0] for b in bursts_antimeridian_with_unique_tiles[tilesets_for_bursts_with_unique_tiles == tilesets_unique[0]]], return_index=True)

    print(bursts_antimeridian_with_unique_tiles[tilesets_for_bursts_with_unique_tiles == tilesets_unique[0]][inds])


    for t in np.unique(tilesets_for_bursts_with_unique_tiles):
        np.unique([b.split('_')[4].split('T')[0] for b in bursts_antimeridian_with_unique_tiles[tilesets_for_bursts_with_unique_tiles == t]])
        dates, inds = np.unique([b.split('_')[4].split('T')[0] for b in bursts_antimeridian_with_unique_tiles[tilesets_for_bursts_with_unique_tiles == tilesets_unique[0]]], return_index=True)
        print(bursts_antimeridian_with_unique_tiles[tilesets_for_bursts_with_unique_tiles == t][inds])

        pass
    
    #return bursts_antimeridian_with_unique_tiles



if __name__ == '__main__':
    #map_bursts_to_tilesets(rtc_burst_list_filename = 'rtc-s1_antimeridian_through_2024-02-08_4638260145-download-s3.txt')

    map_bursts_to_tilesets(rtc_burst_list_filename = ['rtc-s1_high-latitude_2023_4539263142-download-s3.txt', 'rtc-s1_high-latitude_2024_6303412449-download-s3.txt'])
