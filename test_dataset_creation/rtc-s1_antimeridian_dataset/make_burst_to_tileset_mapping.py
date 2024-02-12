import sqlite3

import numpy as np
import pandas as pd



def flatten(xss):
    return [x for xs in xss for x in xs]


cnx = sqlite3.connect('MGRS_tile_collection_v0.3.sqlite')

df = pd.read_sql_query("SELECT * FROM mgrs_burst_db", cnx)
#df.columns


burst_array = np.array(df.bursts)


burst_list = []
for b in burst_array:
    burst_list.append(ast.literal_eval(b))

burst_list = np.array(flatten(burst_list))

burst_list_unique = np.unique(burst_list)
# this results in a numpy array with a list of unique burst IDs (list/array of text)


mgrs_set_ids = np.empty(burst_list_unique.shape)

# this will take a while
for b, s in zip(burst_list_unique, mgrs_set_ids):
    s = list(df['mgrs_set_id'][df['bursts'].str.contains(b)])




with open('rtc-s1_antimeridian_through_2024-02-08_4638260145-download-s3.txt') as f:
    lines = [line.rstrip() for line in f]

# magic number:  4 is the index to get the granule ID (without the filename extensions)
bursts_antimeridian = np.unique([l.split('/')[4] for l in lines])

# magic number:  3 is the column to get the burstID from the granule ID
[np.where(df['bursts'].str.contains(burst.split('_')[3].lower().replace('-','_'))) for burst in bursts_antimeridian]

tilesets = [list(np.where(df['bursts'].str.contains(burst.split('_')[3].lower().replace('-','_')))[0]) for burst in bursts_antimeridian]

tilesets_unique = np.unique(flatten(tilesets))

print(df['mgrs_set_id'][tilesets_unique])
# Here's what will get printed out
#['MS_1_58','MS_1_59','MS_1_60','MS_1_61','MS_30_65','MS_30_66','MS_66_40','MS_66_41','MS_66_171','MS_66_172','MS_81_29','MS_81_30','MS_146_103','MS_146_104','MS_146_105']


indices_with_unique_tiles = np.array([len(a)==1 for a in tilesets])

bursts_antimeridian_with_unique_tiles = bursts_antimeridian[indices_with_unique_tiles]

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


    
