<!-- Header block for project -->
<hr>

<div align="center">

<h1 align="center">OPERA SDS Integration</h1>

</div>

<pre align="center">Integration and testing activities for NASA OPERA Science Data System</pre>

<!-- Header block for project -->

[![SLIM](https://img.shields.io/badge/Best%20Practices%20from-SLIM-blue)](https://nasa-ammos.github.io/slim/)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

This repository serves as the central hub for **NASA OPERA (Observational Products for End-Users from Remote Sensing Analysis) Science Data System (SDS) Integration**. It provides comprehensive integration and testing infrastructure for validating satellite data processing pipelines, ensuring data product quality, and managing AWS cloud infrastructure for the OPERA mission.

The repository supports multiple OPERA data product types including **RTC-S1** (Radiometrically Terrain Corrected Sentinel-1), **CSLC** (Coregistered Single Look Complex), **DSWx-S1** (Dynamic Surface Water extent from Sentinel-1 SAR), **DSWx-HLS** (Dynamic Surface Water extent from Harmonized Landsat Sentinel-2), and **DIST-S1** (Displacement products from Sentinel-1 interferometry) with global MGRS coverage.

[OPERA Mission](https://www.jpl.nasa.gov/go/opera) | [Issue Tracker](https://github.com/nasa/opera-sds-int/issues)

## Features

* **Multi-tier Testing Framework**: Unit-level product validation, integration smoketest suites, and end-to-end pipeline testing
* **AWS Infrastructure Management**: Comprehensive HySDS cluster management with EC2, Auto-Scaling Groups, and EventBridge automation
* **Product Validation Tools**: Structure validation and comparison scripts for all OPERA data products
* **Google Earth Engine Integration**: Upload utilities and COG conversion tools for CSLC and interferogram processing
* **MGRS Tile Visualization**: Global coverage mapping and antimeridian edge case testing
* **Release Testing**: Dedicated R2 and R3 validation frameworks for different product releases
* **CMR Integration**: Common Metadata Repository survey and data subscription capabilities

## Contents

* [Quick Start](#quick-start)
* [Directory Structure](#directory-structure)
* [Data Products](#data-products)
* [Testing Frameworks](#testing-frameworks)
* [AWS Management](#aws-management)
* [Contributing](#contributing)
* [License](#license)
* [Support](#support)

## Quick Start

### Requirements

* Python 3.7+
* AWS CLI configured with appropriate credentials
* Git
* Access to NASA OPERA data systems
* Optional: Google Earth Engine account for GEE upload scripts

### Setup Instructions

1. Clone the repository:
   ```bash
   git clone https://github.com/nasa/opera-sds-int.git
   cd opera-sds-int
   ```

2. Install Python dependencies for specific tools as needed:
   ```bash
   # Individual tools may have their own dependency files
   # Check specific directories for requirements
   ```

3. Configure AWS credentials:
   ```bash
   aws configure
   ```

4. Set up environment variables as needed for specific tools

### Run Instructions

#### Running Smoketest Validation

For R2 products (RTC-S1, CSLC):
```bash
cd r2_smoketest
python rtc_compare.py /path/to/rtc/dir1 /path/to/rtc/dir2
python cslc_compare.py -r /path/to/reference.h5 -s /path/to/secondary.h5
```

For R3 products (DSWx-S1, DISP-S1):
```bash
cd r3_smoketest
./run_r3_smoketest_validation.sh gamma_0.3 DISP_S1_Version opera-int-rs-fwd
```

#### VNV Test Framework

```bash
cd vnv-test-framework
just --list  # Show available commands
just all     # Run all tests
just dist-s1 # Run DIST-S1 tests
```

#### AWS Cluster Management

```bash
python aws_hysds.py opera-int-fwd server mozart start
python aws_hysds.py opera-int-fwd server all stop
python aws_hysds.py opera-int-fwd asg worker set_desired 5
python aws_hysds.py opera-int-fwd eventbridge timer-lambda enable
```

#### MGRS Tile Visualization

```bash
# Edit plot_mgrs_tiles.py to set your desired tile list and output file
python plot_mgrs_tiles.py
```

### Usage Examples

* **Product Structure Validation**: Use `compare_products/` scripts to validate DSWx-HLS and RTC-S1 product structures against expected schemas
* **GEE Upload**: Convert CSLC products to COG format and upload to Google Earth Engine using `GEE_upload_scripts/`
* **Antimeridian Testing**: Generate test datasets that cross the antimeridian using `test_dataset_creation/` tools
* **Elasticsearch Management**: Reset GRQ clusters using `reset_grq_es.sh` for fresh testing environments

## Directory Structure

### Core Testing & Validation
- **`r2_smoketest/`** - R2 release validation scripts for RTC-S1 and CSLC products
- **`r3_smoketest/`** - R3 release validation for DSWx-S1 and DISP-S1 products with directory comparison
- **`vnv-test-framework/`** - Comprehensive V&V test automation framework for DIST-S1 end-to-end pipeline testing
- **`compare_products/`** - Product structure validation scripts for DSWx-HLS and RTC-S1

### Data Processing & Tools
- **`cmr/`** - Common Metadata Repository integration scripts (survey functionality now deprecated)
- **`GEE_upload_scripts/`** - Google Earth Engine upload utilities with COG conversion and multi-processing
- **`test_dataset_creation/`** - Antimeridian edge case dataset generation for HLS and RTC-S1

### Infrastructure Management
- **`aws_hysds.py`** - Comprehensive AWS operations for HySDS clusters (EC2, ASG, EventBridge)
- **`delete_grq_es_data_indices.py`** - Elasticsearch index cleanup for GRQ systems
- **`reset_grq_es.sh`** - Quick cluster reset functionality
- **`plot_mgrs_tiles.py`** - MGRS tile visualization and mapping tools

## Data Products

### Sentinel-1 Products
- **RTC-S1**: Radiometrically Terrain Corrected Sentinel-1 data with backscatter coefficients
- **CSLC**: Coregistered Single Look Complex data for interferometric processing
- **DIST-S1**: Displacement products from Sentinel-1 interferometry with mm-level accuracy
- **DSWx-S1**: Dynamic Surface Water extent from Sentinel-1 SAR data

### HLS Products
- **DSWx-HLS**: Dynamic Surface Water extent from Harmonized Landsat Sentinel-2 with water classification layers

### Coverage
- **Global MGRS tiles** for systematic data organization
- **Special regions**: Arctic Alaska, Antarctica for HH+HV polarization testing
- **Antimeridian validation** for boundary condition edge cases

## Testing Frameworks

### Smoketest Suites
- **R2 Smoketest**: Validates RTC-S1 and CSLC products with file structure and metadata checks
- **R3 Smoketest**: DSWx-S1 and DISP-S1 validation with enhanced directory comparison and sorting algorithms

### VNV Framework
- **End-to-End Testing**: Complete pipeline validation from job submission to NASA CMR DAAC delivery
- **DIST-S1 Focus**: Comprehensive interferometric displacement product testing
- **Automated Orchestration**: Uses `just` command runner for test coordination

### Product Validation
- **Structure Checks**: Validates file organization, naming conventions, and metadata completeness
- **Content Validation**: Ensures data integrity and format compliance
- **Regression Testing**: Compares outputs against known good reference products

## AWS Management

### HySDS Cluster Operations
- **Instance Management**: Start/stop EC2 instances with appropriate IAM roles
- **Auto-Scaling**: Configure ASG policies for dynamic resource allocation
- **Event Processing**: Enable/disable EventBridge rules for automated workflows

### Data Management
- **GRQ Integration**: Ground-data Query system management and index cleanup
- **S3 Operations**: Bulk data transfer and bucket management utilities
- **Monitoring**: CloudWatch integration for system health tracking

## Contributing

Interested in contributing to OPERA SDS Integration? Please:

1. Create a GitHub issue describing your proposed changes
2. Fork this repository
3. Make your modifications in your fork
4. Submit a pull request with detailed description and testing evidence
5. Tag appropriate reviewers from the OPERA team

**Working on your first pull request?** See guide: [How to Contribute to an Open Source Project on GitHub](https://kcd.im/pull-request)

For guidance on how to interact with our team, please see our code of conduct and contribution guidelines.

## License

This project is licensed under the Apache License 2.0 with additional Caltech/JPL copyright terms. See our: [LICENSE](LICENSE)

## Support

This project is maintained by the **NASA OPERA Science Data System team** at JPL/Caltech.

For technical questions and support:
- Create an issue in this repository
- Contact the OPERA SDS development team
- Refer to NASA OPERA mission documentation

Key areas of expertise available:
- **Data Product Validation**: Product structure and content verification
- **AWS Infrastructure**: HySDS cluster management and cloud operations
- **Testing Frameworks**: Automated validation and end-to-end testing
- **Geospatial Processing**: MGRS coordinate systems and global coverage analysis