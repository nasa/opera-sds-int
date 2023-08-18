import logging
import tempfile
import os
import glob
import numpy as np
import argparse
#import yamale
import datetime
from collections import OrderedDict
from ruamel.yaml import YAML as ruamel_yaml
from osgeo.gdalconst import GDT_Float32
from osgeo import gdal, osr
#from proteus.core import save_as_cog
from pprint import pprint



FILENAME_CONVENTION_STRING = 'Project_Level_ProductShortName-Source_BurstID_StartDateTime_ProductGenerationDateTime_Sensor_PixelSpacing_ProductVersion_LayerName.Ext'

FILENAME_CONVENTION_FIELDS = ('Project (== OPERA)',
                              'Level (== L2)',
                              'ProductShortName-Source (== RTC-S1-STATIC)',
                              'BurstID',
                              'ValidityStartDate',
                              'ProductGenerationDateTime',
                              'Sensor',
                              'PixelSpacing',
                              'ProductVersion',
                              'LayerName.Ext (== *.tif | *.tiff)',
)


TABLE_4_1_PRODUCT_IDENTIFICATION_FIELDS = {
    'FILENAME': None,
    'LAYER_NAME': None,
    'LAYER_DESCRIPTION': None,
    'ABSOLUTE_ORBIT_NUMBER': None,
    'TRACK_NUMBER': None,
    'PLATFORM':  "('Sentinel-1A', 'Sentinel-1B')",
    'INSTRUMENT_NAME': None,
    'PRODUCT_TYPE': 'RTC-S1-STATIC',
    'PROJECT': 'OPERA',
    'INSTITUTION': 'NASA JPL',
    'PRODUCT_VERSION': None,
    'PRODUCT_SPECIFICATION_VERSION': None,
    'ACQUISITION_MODE': 'Interferometric Wide (IW)',
    'CEOS_ANALYSIS_READY_DATA_PRODUCT_TYPE': None,
    'LOOK_DIRECTION': None,
    'ORBIT_PASS_DIRECTION': None,
    'PRODUCT_LEVEL': 'L2',
    'PRODUCT_ID': None,
    'PRODUCT_TYPE': "('NOMINAL', 'URGENT', 'CUSTOM', 'UNDEFINED')",
    'PROCESSING_DATETIME': None,
    'RADAR_BAND': 'C',
    'CEOS_ANALYSIS_READY_DATA_DOCUMENT_IDENTIFIER': None,
    'PRODUCT_DATA_ACCESS': None,
    'BURST_ID': None,
    'BEAM_ID': None,
    'ZERO_DOPPLER_START_TIME': None,
    'ZERO_DOPPLER_END_TIME': None,
}

#'DIAGNOSTIC_MODE_FLAG': None,
#'BOUNDING_POLYGON': None,
#'BOUNDING_POLYGON_EPSG_CODE': None,

TABLE_4_2_INPUT_DATASETS_FIELDS = {
    'INPUTS_L1_SLC_GRANULES': None,
    'INPUTS_ORBIT_FILES': None,
    'INPUTS_DEM_SOURCE': None,
    'INPUTS_ANNOTATION_FILES': None,
    'INPUTS_CONFIG_FILES': None,
}

TABLE_4_3_S1_SLC_PARAMETERS = {
    'SOURCE_DATA_ACCESS': None,
    'SOURCE_DATA_NUMBER_OF_ACQUISITIONS': 1,
    'SOURCE_DATA_INSTITUTION': 'ESA',
    'SOURCE_DATA_PROCESSING_CENTER': None,
    'SOURCE_DATA_PROCESSING_DATETIME': None,
    'SOURCE_DATA_SOFTWARE_VERSION': None,
    'SOURCE_DATA_PRODUCT_LEVEL': 'L1',
    'SOURCE_DATA_SLANT_RANGE_SPACING': None,
    'SOURCE_DATA_SLANT_RANGE_RESOLUTION_IN_METERS': None,
    'SOURCE_DATA_ZERO_DOPPLER_TIME_SPACING': None,
    'SOURCE_DATA_AZIMUTH_RESOLUTION_IN_METERS': None,
    'SOURCE_DATA_ZERO_DOPPLER_START_TIME': None,
    'SOURCE_DATA_ZERO_DOPPLER_END_TIME': None,
}

#'CENTER_FREQUENCY': None,
#'SOURCE_DATA_RANGE_BANDWIDTH': None,
#'SOURCE_DATA_SLANT_RANGE_START': None,
#'SOURCE_DATA_NUMBER_OF_RANGE_SAMPLES': None,
#'SOURCE_DATA_NUMBER_OF_AZIMUTH_LINES': None,


TABLE_4_4_RTC_S1_STATIC_PROCESSING_INFORMATION = {
    'SOFTWARE_VERSION': None,
    'ISCE3_VERSION': None,
    'S1_READER_VERSION': None,
    'AREA_OR_POINT': 'Area',
    'PROCESSING_INFORMATION_MULTILOOKING_APPLIED': None,
    'PROCESSING_INFORMATION_FILTERING_APPLIED': None,
    'PROCESSING_INFORMATION_DRY_TROPOSPHERIC_GEOLOCATION_CORRECTION_APPLIED': None,
    'PROCESSING_INFORMATION_WET_TROPOSPHERIC_GEOLOCATION_CORRECTION_APPLIED': None,
    'PROCESSING_INFORMATION_BISTATIC_DELAY_CORRECTION_APPLIED': None,
    'PROCESSING_INFORMATION_DEM_INTERPOLATION_ALGORITHM': None,
    'PROCESSING_INFORMATION_DEM_EGM_MODEL': None,
    'PROCESSING_INFORMATION_GEOCODING_ALGORITHM': None,
    'PROCESSING_INFORMATION_RADIOMETRIC_TERRAIN_CORRECTION_ALGORITHM': None,
    'PROCESSING_INFORMATION_RADIOMETRIC_TERRAIN_CORRECTION_ALGORITHM_REFERENCE': None,
    'PROCESSING_INFORMATION_GEOCODING_ALGORITHM_REFERENCE': None,
    'PROCESSING_INFORMATION_INPUT_BACKSCATTER_NORMALIZATION_CONVENTION': None,
    'PROCESSING_INFORMATION_OUTPUT_BACKSCATTER_NORMALIZATION_CONVENTION': None,
    'PROCESSING_INFORMATION_OUTPUT_BACKSCATTER_EXPRESSION_CONVENTION': None,
    'PROCESSING_INFORMATION_OUTPUT_BACKSCATTER_DECIBEL_CONVERSION_EQUATION': None,
    'PROCESSING_INFORMATION_CEOS_ANALYSIS_READY_DATA_PIXEL_COORDINATE_CONVENTION': None,
    'PROCESSING_INFORMATION_BURST_GEOGRID_SNAP_X': None,
    'PROCESSING_INFORMATION_BURST_GEOGRID_SNAP_Y': None,
}

#'PROCESSING_INFORMATION_NOISE_CORRECTION_APPLIED': None,
#'PROCESSING_INFORMATION_RADIOMETRIC_TERRAIN_CORRECTION_APPLIED': None,
#'PROCESSING_INFORMATION_NOISE_REMOVAL_ALGORITHM_REFERENCE': None,

#TABLE_4_5_RTC_S1_RFI_INFORMATION = {
#    'IS_RFI_INFO_AVAILABLE': None,
#    'RFI_MITIGATION_PERFORMED*': None,
#    'RFI_MITIGATION_DOMAIN*': None,
#    'RFI_BURST_REPORT_SWATH*': None,
#    'RFI_BURST_REPORT_AZIMUTH_TIME*': None,
#    'RFI_IN_BAND_OUT_BAND_POWER_RATIO*': None,
#    'TIME_DOMAIN_RFI_REPORT_PERCENTAGE_AFFECTED_LINES*': None,
#    'TIME_DOMAIN_RFI_REPORT_AVG_PERCENTAGE_AFFECTED_SAMPLES*': None,
#    'TIME_DOMAIN_RFI_REPORT_MAX_PERCENTAGE_AFFECTED_SAMPLES*': None,
#    'FREQUENCY_DOMAIN_RFI_BURST_REPORT_NUM_SUB_BLOCKS*': None,
#    'FREQUENCY_DOMAIN_RFI_BURST_REPORT_SUB_BLOCKS_SIZE*': None,
#    'FREQUENCY_DOMAIN_RFI_BURST_REPORT_ISOLATED_RFI_REPORT_PERCENTAGE_AFFECTED_LINES*': None,
#    'FREQUENCY_DOMAIN_RFI_BURST_REPORT_PERCENTAGE_BLOCKS_PERSISTENT_RFI*': None,
#    'FREQUENCY_DOMAIN_RFI_BURST_REPORT_MAX_PERCENTAGE_BW_AFFECTED_PERSISTENT_RFI*': None,
#}



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
        # four columns:  metadata fields name | metadata spec value | is key in metadata file? | value of metadata field in file
        #table_md.append([key, metadata_spec[key] if metadata_spec[key] is not None else "None", key in metadata_file, metadata_file[key] if key in metadata_file else "None"])

        # three columns:  metadata fields name | metadata spec value | is key in metadata file?
        table_md.append([key, metadata_spec[key] if metadata_spec[key] is not None else "None", key in metadata_file])

    #pprint(table_md)
    print_table(table_md)
    return


def compare_rtc_s1_static_metadata_structure(filepath):

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

    print('Compare Table 4-1 Metadata')
    print_metadata_comparisons(TABLE_4_1_PRODUCT_IDENTIFICATION_FIELDS, metadata)

    print('Compare Table 4-2 Metadata')
    print_metadata_comparisons(TABLE_4_2_INPUT_DATASETS_FIELDS, metadata)

    print('Compare Table 4-3 Metadata')
    print_metadata_comparisons(TABLE_4_3_S1_SLC_PARAMETERS, metadata)

    print('Compare Table 4-4 Metadata')
    print_metadata_comparisons(TABLE_4_4_RTC_S1_STATIC_PROCESSING_INFORMATION, metadata)

    #print('Compare Table 4-5 Metadata')
    #print_metadata_comparisons(TABLE_4_5_RTC_S1_RFI_INFORMATION, metadata)

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
                        help='Input image to verify')

    return parser


def main():
    parser = _get_parser()

    args = parser.parse_args()

    file_1 = args.input_file[0]
    #file_2 = args.input_file[1]

    compare_rtc_s1_static_metadata_structure(file_1)
    #compare_dswx_hls_products(file_1, file_2)


if __name__ == '__main__':
    main()




    

