
import lxml.etree as et

import numpy as np

'''
This script is really just a capture of my interactive iPython session.
I have never run this file as a script, but rather just copy+paste lines into iPython.
Turning this into a script wouldn't be hard, it just takes more time than I have to give this task at the moment.

There are hard-coded filepaths down below, so beware of those before running the code.
Most of the inputs are in the repository.  The KML file is too big for GitHub, and needs to be downloaded by the user (link in the inline comments below).

The first part of the file is parsing the KML file to get the bounding polygons for all Tiles near the antimeridian.
Any TileIDs starting with one of the elements in `name_prefixes`.
It then pulls out the bounding polygons for each of those tiles.
If a Tile has a single bounding polygon, it does NOT cross the antimeridian.
If a Tile has two bounding polygons, it DOES cross the antimeridian (this was true for the handful of tiles I inspected, and then took this as an assumption).
The script will identify all tiles that cross the antimeridian.  These are in the variable `bbox_doubles`.
There are 298 such Tiles in total (not all of these are over land, and thus not all apply to the HLS data.

There are also 2 input files taken from queries in Earthdata Search.  I queried for all HLS data (both L30 and S30) in the first half of 2022 that are (roughly) within 200km of the antimeridian (the bounding polygon for the query went up to +/-85 lat, and I calculated 200km away from the antimeridian at 5 degree lat intervals, and fed that into Earthdata Search as the bounding polygon).
Those files start with `8433462866-download`.
I read those files, pull out the unique TileIDs.  HLSL30 had 110 unique tileIDs, and HLSS30 had 108 unique tileIDs.  I take one of each unique tileIDs to make an HLS dataset that's "near the antimeridian".  This list can be found in the variables `hlsl30_unique_tileIDs` and `hlss30_unique_tileIDs`.  They were also written to text files and committed into the repository (filenames end with `_near_antimeridian_tileIDs.txt`).

I also take the HLS tiles near the antimeridian, and intersect it with the 298 tiles that ACTUALLY cross the antimeridian.  Those are in the variables `hlsl30_antimeridian_tileIDs` and `hlss30_antimeridian_tileIDs`.  These were also written to text files and committed into the repository (filenames end with `antimeridian_tileIDs.txt`, without 'near').

'''


# This file is about 106 MB in size - so I'm not putting it in the repository.
# You can download this file from this link:  https://eatlas.org.au/data/uuid/f7468d15-12be-4e3f-a246-b2882a324f59
tree = et.parse('./S2A_OPER_GIP_TILPAR_MPC__20151209T095117_V20150622T000000_21000101T000000_B00.kml')

#name_prefixes = ('01W', '01V', '01U', '01N', '01M', '01L', '01K', '01J', '01H', '01G', '01F',
#                 '60W', '60V', '60U', '60N', '60M', '60L', '60K', '60J', '60H', '60G', '60F',
#)

name_prefixes = ('01', '60', '59', '02', '58', '03')

name_list = []
bbox_list = []
for name in tree.xpath("/kml:kml/kml:Document/kml:Folder/kml:Placemark/kml:name", namespaces=ns):
    if name.text.startswith(name_prefixes):
        name_list.append(name.text)
        #bbox = name.xpath("following-sibling::kml:MultiGeometry//kml:Polygon//kml:outerBoundaryIs//kml:LinearRing//kml:coordinates", namespaces=ns)
        bbox = [bbx.text.strip() for bbx in name.xpath("following-sibling::kml:MultiGeometry//kml:Polygon//kml:outerBoundaryIs//kml:LinearRing//kml:coordinates", namespaces=ns)]
        bbox_list.append(bbox)
        pass
    pass
# Some Placemarks will have two Polygons under the MultiGeometry.
# This only seems to happen when the Tile is split across the antimeridian.


name_list = np.array(name_list)

bbox_list_lengths = np.array([len(l) for l in bbox_list])

# These are all the indices (into name_list and bbox_list) of the Tiles with two Polygons for the bounding box (because it's split across the antimeridian)
bbox_list_doubles = np.where(bbox_list_lengths == 2)[0]

# These are all the indices with a single Polygon for the bbox
bbox_list_singles = np.where(bbox_list_lengths == 1)[0]


bbox_singles = np.array([bbox_list[i] for i in bbox_list_singles])
bbox_doubles = np.array([bbox_list[i] for i in bbox_list_doubles])



# double-check that none of the bounding polygons in `bbox_singles` touch the antimeridian
ans = np.array(['180,' in l[0] for l in bbox_singles]) # the string "180," appears in the doubled bboxes
print('Count of appearances of "180," in bbox_singles:', np.sum(ans))

ans = np.array(['180,' in l[0] for l in bbox_doubles]) # the string "180," appears in the doubled bboxes
print('Count of appearances of "180," in bbox_doubles (just the first entry):', np.sum(ans))

print('Count of double-bounding polygons (due to being split across the antimeridian):', len(bbox_doubles))

# print the TileIDs of every Tile with two Polygons for the bounding box.
print(name_list[bbox_list_doubles])

# print this string to help query in Earthdata Search
print(','.join(['*'+n+'*' for n in name_list[bbox_list_doubles]]))



## This is now parsing the text files downloaded from Earthdata Search, for HLSL30 and HLSS30 over 2022-01-01 - 2022-06-30
hlsl30_text_file = np.loadtxt('8433462866-download (3) HLSL30.txt', delimiter='/', dtype=str)
hlss30_text_file = np.loadtxt('8433462866-download (3) HLSS30.txt', delimiter='/', dtype=str)

hlsl30_tiles = hlsl30_text_file[:, 5]
hlss30_tiles = hlss30_text_file[:, 5]

hlsl30_tiles_split = np.array([a.split('.') for a in hlsl30_tiles])
hlss30_tiles_split = np.array([a.split('.') for a in hlss30_tiles])

# np.union1d returns the unique, sorted array values from the two arguments.
hls_unique_tileIDs = np.union1d(hlss30_tiles_split[:,2], hlsl30_tiles_split[:,2])

print('Count of unique MGRS TileIDs:', hls_unique_tileIDs.shape[0])
print(hls_unique_tileIDs)

print('Count of unique MGRS TileIDs from HLS.L30:', np.unique(hlsl30_tiles_split[:,2]).shape[0])
print('Count of unique MGRS TileIDs from HLS.S30:', np.unique(hlss30_tiles_split[:,2]).shape[0])


# Pull out the first instance of each unique TileID from the hlsl30 & hlss30 tiles
inds = np.unique(hlsl30_tiles_split[:,2], return_index=True)[1]
hlsl30_unique_set = hlsl30_tiles_split[inds]
hlsl30_unique_tileIDs = np.array(['.'.join(l) for l in hlsl30_unique_set])  # 110 TileIDs that are within 200km of the antimeridian

inds = np.unique(hlss30_tiles_split[:,2], return_index=True)[1]
hlss30_unique_set = hlss30_tiles_split[inds]
hlss30_unique_tileIDs = np.array(['.'.join(l) for l in hlss30_unique_set])  # 108 TileIDs that are within 200km of the antimeridian


# These are the unique TileIDs from HLS (both L30 and S30) that also have double Polygons (thus splitting across the antimeridian).
hls_unique_tileIDs_antimeridian =  np.intersect1d(name_list[bbox_list_doubles], np.array([s[1:] for s in  hls_unique_tileIDs]))

# From the antimeridian sets for HLSL30 and HLSS30, find the TileIDs that overlap the antimeridian
inds = np.intersect1d(np.array([s[1:] for s in hlsl30_unique_set[:,2]]), hls_unique_tileIDs_antimeridian, return_indices=True)[1]
hlsl30_antimeridian_set = hlsl30_unique_set[inds]
hlsl30_antimeridian_tileIDs = np.array(['.'.join(l) for l in hlsl30_antimeridian_set])  # 28 TileIDs that overlap the antimeridian

inds = np.intersect1d(np.array([s[1:] for s in hlss30_unique_set[:,2]]), hls_unique_tileIDs_antimeridian, return_indices=True)[1]
hlss30_antimeridian_set = hlss30_unique_set[inds]
hlss30_antimeridian_tileIDs = np.array(['.'.join(l) for l in hlss30_antimeridian_set])  # 28 TileIDs that overlap the antimeridian




