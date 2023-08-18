import logging
import tempfile
import os
import glob
import numpy as np
import argparse
import yamale
import datetime
from collections import OrderedDict
from ruamel.yaml import YAML as ruamel_yaml
from osgeo.gdalconst import GDT_Float32
from osgeo import gdal, osr
#from proteus.core import save_as_cog
from pprint import pprint


PRODUCT_VERSION = '0.1'

landcover_mask_type = 'standard'

COMPARE_DSWX_HLS_PRODUCTS_ERROR_TOLERANCE = 1e-6


FILENAME_CONVENTION_STRING = 'Project_Level_ProductShortName-Source_TileID_DateTime_ProductGenerationDateTime_Sensor_PixelSpacing_ProductVersion_LayerNumber_LayerName.Ext'

FILENAME_CONVENTION_FIELDS = ('Project (== OPERA)',
                              'Level (== L3)',
                              'ProductShortName-Source (== DSWx-HLS)',
                              'TileID',
                              'DateTime',
                              'ProductGenerationDateTime',
                              'Sensor',
                              'PixelSpacing',
                              'ProductVersion',
                              'LayerNumber',
                              'LayerName.Ext (== *.tif | *.tiff)',
)


TABLE_4_2_PRODUCT_IDENTIFICATION_FIELDS = {
    'PRODUCT_ID': None,
    'PRODUCT_VERSION': None,
    'SOFTWARE_VERSION': None,
    'PROJECT': 'OPERA',
    'PRODUCT_LEVEL': 3,
    'PRODUCT_TYPE': 'DSWx-HLS',
    'PRODUCT_SOURCE': 'HLS',
    'PROCESSING_DATETIME': None,
    'SPACECRAFT_NAME': None,
    'SENSOR': "('OLI', 'MSI')",
}

TABLE_4_3_INPUT_DATASETS_FIELDS = {
    'HLS_DATASET': None,
    'DEM_SOURCE': None,
    'LANDCOVER_SOURCE': None,
    'WORLDCOVER_SOURCE': None,
}

TABLE_4_4_HLS_PRODUCT_METADATA_FIELDS = {
    'SENSOR_PRODUCT_ID': None,
    'SENSING_TIME': None,
    'SPATIAL_COVERAGE': None,
    'CLOUD_COVERAGE': None,
    'MEAN_SUN_AZIMUTH_ANGLE': None,
    'MEAN_SUN_ZENITH_ANGLE': None,
    'MEAN_VIEW_AZIMUTH_ANGLE': None,
    'MEAN_VIEW_ZENITH_ANGLE': None,
    'NBAR_SOLAR_ZENITH': None,
    'ACCODE': None,
}

TABLE_4_5_HLS_PRODUCT_METADATA_FIELDS = {
    'AREA_OR_POINT': "Area",
    'SHADOW_MASKING_ALGORITHM': "('TERRAIN_SLOPE_AND_SUN_LOCAL_INC', 'OTSU')",
    'MIN_SLOPE_ANGLE': None,
    'MAX_SUN_LOCAL_INC_ANGLE': None,
}



def print_table(table):
    longest_cols = [
        (max([len(str(row[i])) for row in table]) + 3)
        for i in range(len(table[0]))
    ]
    row_format = "".join(["{:>" + str(longest_col) + "}" for longest_col in longest_cols])
    for row in table:
        print(row_format.format(*row))

    return


def print_metadata_comparisons(metadata_spec, metadata_file):
    table_md = []
    for key in metadata_spec.keys():
        table_md.append([key, metadata_spec[key] if metadata_spec[key] is not None else "None", key in metadata_file, metadata_file[key] if key in metadata_file else "None"])

        
    print_table(table_md)
    return


def compare_dswx_hls_metadata_structure(filepath):

    if not os.path.isfile(filepath):
        print(f'ERROR file not found: {filepath}')
        return False

    layer_gdal_dataset = gdal.Open(filepath, gdal.GA_ReadOnly)
    geotransform = layer_gdal_dataset.GetGeoTransform()
    metadata = layer_gdal_dataset.GetMetadata()
    nbands = layer_gdal_dataset.RasterCount

    filename = os.path.basename(filepath)
    
    print('\n**********\n')
    print('COMPARE FILENAME')
    print('----------')
    print(filename)
    print(FILENAME_CONVENTION_STRING)

    filename_fields = filename.split('_')

    table_fnc = []
    for fc, fn in zip(FILENAME_CONVENTION_FIELDS, filename_fields):
        #print(fc + ': ' + fn)
        table_fnc.append([fc, fn])

    print_table(table_fnc)

    print('\n**********\n')

    print('COMPARE METADATA FIELDS')

    print('Compare Table 4-2 Metadata')
    print_metadata_comparisons(TABLE_4_2_PRODUCT_IDENTIFICATION_FIELDS, metadata)

    print('Compare Table 4-3 Metadata')
    print_metadata_comparisons(TABLE_4_3_INPUT_DATASETS_FIELDS, metadata)

    print('Compare Table 4-4 Metadata')
    print_metadata_comparisons(TABLE_4_4_HLS_PRODUCT_METADATA_FIELDS, metadata)

    print('Compare Table 4-5 Metadata')
    print_metadata_comparisons(TABLE_4_5_HLS_PRODUCT_METADATA_FIELDS, metadata)

    print('\n**********\n')

    return metadata





def _get_parser():
    parser = argparse.ArgumentParser(
        description='Inspect a DSWx-HLS product',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    # Inputs
    parser.add_argument('input_file',
                        type=str,
                        nargs=1,
                        help='Input image')

    return parser


def main():
    parser = _get_parser()

    args = parser.parse_args()

    file_1 = args.input_file[0]
    #file_2 = args.input_file[1]

    compare_dswx_hls_metadata_structure(file_1)
    #compare_dswx_hls_products(file_1, file_2)


if __name__ == '__main__':
    main()




    

