
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
from shapely.geometry import Polygon
from mgrs import MGRS
import matplotlib.patches as patches

import lxml.etree as et
import numpy as np

import pandas as pd


MGRS_TILE_S2_KML_FILE_PATH = '/Users/Sjlewis/Library/CloudStorage/OneDrive-JPL/Projects/src-git/opera/anc/S2A_OPER_GIP_TILPAR_MPC__20151209T095117_V20150622T000000_21000101T000000_B00.kml'



def create_mgrs_polygon(tile_id, mgrs_tile_bboxs):
    tile_coords = mgrs_tile_bboxs[tile_id]
        
    output_polygons = [Polygon(np.array([eval(x) for x in tile_coord.split(' ')])[:, :2]) for tile_coord in tile_coords]

    return output_polygons


def plot_mgrs_tiles_on_worldmap(mgrs_tiles_to_shade, mgrs_tile_bbox_dict, savefile=None):
    # Create a plot with a global map
    fig, ax = plt.subplots(figsize=(12, 8), subplot_kw={'projection': ccrs.PlateCarree()})
    ax.set_global()
    ax.coastlines()
    ax.add_feature(cfeature.BORDERS, linestyle=':')


    # Plot each MGRS tile and shade the specified tiles
    for tile_id in mgrs_tiles_to_shade:
        if tile_id[0] == 'T':
            tile_id = tile_id[1:]
        polygon = create_mgrs_polygon(tile_id, mgrs_tile_bbox_dict)
        for poly in polygon:
            patch = patches.Polygon(list(poly.exterior.coords), closed=True, transform=ccrs.PlateCarree(), edgecolor='blue', facecolor='blue', alpha=0.5)
            ax.add_patch(patch)
            pass
        pass

    plt.title('Shaded MGRS Tiles on World Map')

    if savefile is None:
        plt.show()
    else:
        plt.savefig(savefile)


def generate_mgrs_tile_bbox_dict(MGRS_Tiles_S2_KML_file=MGRS_TILE_S2_KML_FILE_PATH):
    tree = et.parse(MGRS_Tiles_S2_KML_file)
    ns = {'kml': 'http://www.opengis.net/kml/2.2',
          'gx': "http://www.google.com/kml/ext/2.2",
          'kml2': "http://www.opengis.net/kml/2.2",
          'atom': "http://www.w3.org/2005/Atom"}
    name_list = []
    bbox_list = []
    
    for name in tree.xpath("/kml:kml/kml:Document/kml:Folder/kml:Placemark/kml:name", namespaces=ns):
        name_list.append(name.text)
        #bbox = name.xpath("following-sibling::kml:MultiGeometry//kml:Polygon//kml:outerBoundaryIs//kml:LinearRing//kml:coordinates", namespaces=ns)
        bbox = [bbx.text.strip() for bbx in name.xpath("following-sibling::kml:MultiGeometry//kml:Polygon//kml:outerBoundaryIs//kml:LinearRing//kml:coordinates", namespaces=ns)]
        bbox_list.append(bbox)
        pass
    # Some Placemarks will have two Polygons under the MultiGeometry.
    # This only seems to happen when the Tile is split across the antimeridian

    mgrs_tile_bbox_dict = dict(zip(name_list, bbox_list))

    return mgrs_tile_bbox_dict


def get_dswx_s1_tile_list_from_production_time_report(prod_time_csv):

    df = pd.read_csv(prod_time_csv, skiprows=3)

    df_dswx_s1 = df[df['OPERA Product Short Name'] == 'L3_DSWx_S1']

    tile_list = np.array([x.split('_')[3] for x in np.array(df_dswx_s1['OPERA Product File Name'])])

    return tile_list


if __name__ == '__main__':

    prod_time_csv_file = '/Users/Sjlewis/Library/CloudStorage/OneDrive-JPL/Projects/src-git/opera/anc/production-time-detailed - 2024-05-25T000000 to 2024-05-26T235959.csv'

    tile_list = get_dswx_s1_tile_list_from_production_time_report(prod_time_csv_file)

    mgrs_tile_bboxs = generate_mgrs_tile_bbox_dict()
    
    plot_mgrs_tiles_on_worldmap(tile_list, mgrs_tile_bboxs, savefile='test_display.png')

    
