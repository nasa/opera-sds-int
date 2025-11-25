<!-- Header block for project -->
<hr>

<div align="center">

<h1 align="center">OPERA VNV Test Automation Framework</h1>

</div>

<pre align="center">Comprehensive end-to-end testing framework for NASA OPERA satellite data product pipelines</pre>

<!-- Header block for project -->

[![SLIM](https://img.shields.io/badge/Best%20Practices%20from-SLIM-blue)](https://nasa-ammos.github.io/slim/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-Automated-green.svg)](dist-s1/)

This repository contains a comprehensive Verification & Validation (V&V) test automation suite for **NASA OPERA** (Observational Products for End-Users from Remote Sensing Analysis) data products. The framework orchestrates end-to-end testing of complete product generation and delivery pipelines, from job submission through NASA's OPERA SDS (Science Data System) to final product delivery at NASA's CMR DAAC (Common Metadata Repository - Distributed Active Archive Center).

**Currently supported products:**
- **DIST-S1**: Displacement products from Sentinel-1 data

[OPERA Mission](https://www.jpl.nasa.gov/missions/opera) | [SLIM Best Practices](https://nasa-ammos.github.io/slim/) | [Issue Tracker](../../issues)

## Features

* **End-to-End Pipeline Testing**: Complete validation from job submission to product delivery
* **Multi-System Integration**: Tests OPERA SDS (JPL) and NASA CMR DAAC systems
* **Parameterized Testing**: Support for custom satellite tiles and timestamps
* **Automated Validation**: Before/after product count verification with success/failure reporting
* **Modular Architecture**: Individual test components can be run independently
* **Silent Operations**: Clean output with structured reporting and progress tracking
* **Robust Error Handling**: Comprehensive validation with informative error messages

## Contents

* [Quick Start](#quick-start)
* [DIST-S1 Testing](#dist-s1-testing)
  * [Test Scenarios](#test-scenarios)
  * [Prerequisites Workflow](#prerequisites-workflow)
  * [Test Architecture](#test-architecture)
* [Configuration](#configuration)
* [Troubleshooting](#troubleshooting)
* [Contributing](#contributing)
* [License](#license)
* [Support](#support)

## Quick Start

This guide provides a quick way to get started with OPERA V&V testing.

### Requirements

* **`just`** - Command runner (must be in system PATH)
* **`daac_data_subscriber.py`** - OPERA data subscription tool
* **`dist_s1_burst_db_tool.py`** - DIST-S1 burst database tool
* **`curl`** - HTTP client for API interactions
* **`jq`** - JSON processor for parsing responses
* **Standard Unix tools**: `awk`, `wc`, `grep`
* **Network Access**: OPERA SDS internal systems (JPL network) and NASA Earthdata login credentials

### Setup Instructions

1. **Install required tools**:
   ```bash
   # Install just command runner
   curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/bin

   # Ensure OPERA tools are in your PATH
   which daac_data_subscriber.py
   which dist_s1_burst_db_tool.py
   ```

2. **Clone and navigate to repository**:
   ```bash
   git clone <repository-url>
   cd opera-dist-s1-testing
   ```

3. **Configure environment variables**:
   ```bash
   # Required: Set your OPERA SDS instance URL
   export OPERA_SDS_BASE_URL="https://your-opera-sds-instance.example.com"

   # Optional: Add to your shell profile for persistence
   echo 'export OPERA_SDS_BASE_URL="https://your-opera-sds-instance.example.com"' >> ~/.bashrc
   ```

   *Note: NASA CMR settings use public defaults (UAT endpoint with C1275699124-ASF collection). See [Configuration](#configuration) for override options.*

4. **Verify system access**:
   ```bash
   # Test OPERA SDS access (required)
   curl -sk "$OPERA_SDS_BASE_URL/grq_es/grq/_search" -X GET

   # Test NASA CMR access (uses defaults)
   curl -si "https://cmr.uat.earthdata.nasa.gov/search/granules.json?collection_concept_id=C1275699124-ASF&page_size=1"
   ```

### Run Instructions

**Run all tests**:
```bash
just all
```

This executes all test suites in the framework. Currently runs all DIST-S1 test scenarios in sequence. Each test takes approximately 15 minutes to complete.

For detailed information on individual test scenarios, custom parameters, and utility commands, see the [DIST-S1 Testing](#dist-s1-testing) section below.

## DIST-S1 Testing

This section covers all DIST-S1 (Displacement products from Sentinel-1 data) test scenarios and workflows.

### Running All Tests

Run all DIST-S1 tests in sequence:

```bash
just dist-s1::all
```

This will execute:
1. E2E test with --product-id-time (default parameters: 11SLT_0, 20250614T015042Z)
2. Polarization switch test (20TLP_3, 20250919T102312Z)
3. Single polarization test (51QTA_1, 20241029T100014Z)

### Test Scenarios

The framework includes several predefined test scenarios for different DIST-S1 processing conditions:

#### 1. DIST-S1 E2E With --product-id-time

The main E2E test accepts custom tile and timestamp parameters:

**Default test (Tile: 11SLT_0, Timestamp: 20250614T015042Z):**
```bash
just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time
```

**Custom tile and timestamp:**
```bash
just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time 11SLT_0 20250614T015042Z
```

**Arctic Alaska example (HH+HV polarization):**
```bash
just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time 01WDU_5 20220101T051815Z
```

#### 2. Polarization Switch Test

Tests DIST-S1 processing for polarization switching scenarios using track 20TLP_3:

```bash
just dist-s1::dist-s1-polarization-switch-for-a-track
```

- **Track**: 20TLP_3
- **Timestamp**: 20250919T102312Z
- **Scenario**: Validates polarization switching behavior

#### 3. Single Polarization Test

Tests DIST-S1 processing for single polarization scenarios using track 51QTA_1:

```bash
just dist-s1::dist-s1-single-polarization
```

- **Track**: 51QTA_1
- **Timestamp**: 20241029T100014Z
- **Scenario**: Validates single polarization processing

### Utility Commands

These helper commands allow you to check system state and perform individual operations:

**Check current SDS product count:**
```bash
just dist-s1::e2e-with-product-id-time::sds-get-product-count
```

**Check current DAAC product count:**
```bash
just dist-s1::e2e-with-product-id-time::daac-get-product-count
```

**Submit a job without running full E2E test:**
```bash
just dist-s1::e2e-with-product-id-time::sds-submit-job <TILE> <TIMESTAMP>

# Example:
just dist-s1::e2e-with-product-id-time::sds-submit-job 11SLT_0 20250614T015042Z
```

### Prerequisites Workflow

For discovering valid test parameters and preparing test data:

#### Complete Automated Workflow

Run everything in one command:

```bash
just dist-s1::prerequisites::workflow <TILE> <START_DATE> <END_DATE> <OUTPUT_CSV>

# Example: Survey 11SLT tile for June 2024
just dist-s1::prerequisites::workflow 11SLT 2024-06-01T00:00:00Z 2024-06-30T23:59:59Z /tmp/rtc_test.csv
```

This will:
1. Check tile information
2. Survey RTC granules from CMR
3. Trigger granules for the tile
4. Show you the product IDs and timestamps to use

#### Individual Prerequisite Commands

**Check Tile Information:**
```bash
just dist-s1::prerequisites::check-tile 11SLT
```

**Survey RTC Granules:**
```bash
just dist-s1::prerequisites::survey-rtc-granules 2024-10-01T00:00:00Z 2024-10-31T23:59:59Z /tmp/rtc_oct.csv
```

Output files:
- `/tmp/rtc_oct.csv` - Summary by time period
- `/tmp/rtc_oct.csv.raw.csv` - Full granule list (use this for next step!)

**Trigger Granules for a Tile:**
```bash
just dist-s1::prerequisites::trigger-granules 11SLT /tmp/rtc_oct.csv.raw.csv
```

**Important:** Use the `.raw.csv` file from the survey command!

**Get Product ID from Granule:**
```bash
just dist-s1::prerequisites::get-product-id-from-granule OPERA_L2_RTC-S1_T066-140035-IW2_20220101T051815Z_20241216T224934Z_S1A_30_v1.0
```

### Test Architecture

The DIST-S1 test framework consists of modular components:

#### Structure

```
dist-s1/
├── mod.just                                # Module index
├── prerequisites.just                      # Helper commands
├── e2e-with-product-id-time.just          # E2E test with --product-id-time
├── dist-s1-polarization-switch-for-a-track.just  # Polarization switch test
├── dist-s1-single-polarization.just       # Single polarization test
└── sds-product-count.json                 # OpenSearch query template
```

#### Test Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `TILE` | Product ID (tile + acquisition group) | `11SLT_0` |
| `TIMESTAMP` | Acquisition timestamp | `20250614T015042Z` |

#### Tile Naming Convention

- Format: `{MGRS_TILE}_{ACQUISITION_GROUP}`
- Example: `11SLT_0` = Tile 11SLT, acquisition group 0
- A single MGRS tile can have multiple acquisition groups (0-3+)

#### CMR Survey Parameters

- `--collection-shortname`: `OPERA_L2_RTC-S1_V1`
- `--endpoint`: `OPS` (operational) or `UAT` (test)
- Date format: `YYYY-MM-DDTHH:MM:SSZ`

#### Finding Valid Test Data

**For standard VV+VH polarization:**
- Use any mid-latitude tile (e.g., 11SLT, 20TLP)
- Survey recent data (2024-2025)

**For HH+HV polarization (non-standard):**
- Use Arctic tiles: 01WDU, 01WCU, 60WWD
- Use dates: 2022-01-01 to 2022-06-30
- Antarctica tiles: dates in 2024-2025

## Test Architecture

The test framework consists of modular components:

### Core Files
- **`justfile`**: Main entry point and module loader
- **`dist-s1/mod.just`**: Module index loading submodules
- **`dist-s1/e2e-with-product-id-time.just`**: Main E2E test orchestration
- **`dist-s1/prerequisites.just`**: Test preparation helpers
- **`dist-s1/sds-product-count.json`**: OpenSearch query for SDS product counts

### Test Workflow
1. **Initial State Capture**: Record baseline product counts
2. **Job Submission**: Submit DIST-S1 reprocessing job via `daac_data_subscriber.py`
3. **Wait Period**: 15-minute wait for job completion
4. **Product Analysis**: Retrieve latest product details and S3 URLs
5. **Final State Capture**: Record final product counts
6. **Validation**: Ensure products were generated (SDS) and delivered (DAAC)
7. **Reporting**: Display before/after deltas and success/failure status

### System Integration
- **OPERA SDS**: Configurable via `$OPERA_SDS_BASE_URL`
  - GRQ Elasticsearch for product queries (`/grq_es/grq/_search`)
  - Mozart job submission and monitoring
- **NASA CMR DAAC**: Configurable via `$NASA_CMR_BASE_URL`
  - Collection ID: Configurable via `$OPERA_COLLECTION_ID`

## Configuration

### Environment Variables

#### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `OPERA_SDS_BASE_URL` | Base URL for your OPERA SDS instance (internal system) | `https://your-opera-sds.example.com` |

#### Optional Variables (with defaults)

| Variable | Description | Default | Override Example |
|----------|-------------|---------|------------------|
| `NASA_CMR_BASE_URL` | Base URL for NASA CMR instance | `https://cmr.uat.earthdata.nasa.gov` | `https://cmr.earthdata.nasa.gov` |
| `OPERA_COLLECTION_ID` | NASA CMR collection concept ID | `C1275699124-ASF` | `C1234567890-PROVIDER` |

**Setting Environment Variables:**

**Option 1: Minimal setup (only required variable)**
```bash
# Set your OPERA SDS instance URL (required)
export OPERA_SDS_BASE_URL="https://your-opera-sds.example.com"

# Optional: Add to your shell profile for persistence
echo 'export OPERA_SDS_BASE_URL="https://your-opera-sds.example.com"' >> ~/.bashrc
source ~/.bashrc
```

**Option 2: Using the provided template (for custom CMR settings)**
```bash
# Copy the example environment file
cp .env.example .env

# Edit .env with your actual values
nano .env  # or your preferred editor

# Source the environment file
source .env
```

**Option 3: Override defaults manually**
```bash
# Required
export OPERA_SDS_BASE_URL="https://your-opera-sds.example.com"

# Optional overrides (if you need different values than defaults)
export NASA_CMR_BASE_URL="https://cmr.earthdata.nasa.gov"  # Use production instead of UAT
export OPERA_COLLECTION_ID="C1234567890-PROVIDER"  # Use different collection
```

**Note**: Replace the example URLs and collection ID with your actual system values.

### Default Test Parameters
- **Tile**: `11SLT_0` (mid-latitude, VV+VH polarization)
- **Timestamp**: `20250614T015042Z`

### Supported Test Scenarios
- **Standard VV+VH Polarization**: Mid-latitude tiles (11SLT, 20TLP)
- **HH+HV Polarization**: Arctic tiles (01WDU, 01WCU, 60WWD) with 2022 data
- **Custom Scenarios**: Any valid tile/timestamp combination

## Prerequisites Workflow

For discovering valid test parameters:

```bash
# Complete automated workflow for test parameter discovery
just dist-s1::prerequisites::workflow <TILE> <START_DATE> <END_DATE> <OUTPUT_CSV>

# Example: Survey 11SLT tile for June 2024
just dist-s1::prerequisites::workflow 11SLT 2024-06-01T00:00:00Z 2024-06-30T23:59:59Z /tmp/rtc_test.csv

# Extract product-id-time from discovered granules
just dist-s1::prerequisites::get-product-id-from-granule <GRANULE_ID>
```

## Troubleshooting

### Common Issues

1. **Environment variable errors**
   - **Error**: "❌ ERROR: OPERA_SDS_BASE_URL environment variable is not set"
   - **Solution**: Set required environment variables as described in [Configuration](#configuration)
   - **Check**: Run `echo $OPERA_SDS_BASE_URL` to verify the variable is set

2. **"null DIST S1 products currently exist on the system"**
   - Check OpenSearch query format in `sds-product-count.json`
   - Verify NDJSON has proper newline termination
   - Verify `OPERA_SDS_BASE_URL` points to the correct system

3. **Job submission failures**
   - Verify `daac_data_subscriber.py` is in PATH and accessible
   - Check network access to OPERA SDS systems
   - Validate tile ID and timestamp format

4. **Product count validation failures**
   - Ensure sufficient wait time for job completion (default: 15 minutes)
   - Check system status and processing queues
   - Verify CMR DAAC access and collection ID
   - Confirm `NASA_CMR_BASE_URL` and `OPERA_COLLECTION_ID` are correct

### Debug Mode
Enable debug output by modifying the curl commands in test files to include response logging.

## Contributing

Interested in contributing to our project? Please see our: [CONTRIBUTING.md](CONTRIBUTING.md)

For guidance on how to interact with our team, please see our code of conduct located at: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)

For guidance on our governance approach, including decision-making process and our various roles, please see our governance model at: [GOVERNANCE.md](GOVERNANCE.md)

## License

See our: [LICENSE](LICENSE)

## Support

For questions and support:
- Create an issue in the [Issue Tracker](../../issues)
- Contact the OPERA team through official NASA/JPL channels
- Refer to [OPERA Mission Documentation](https://www.jpl.nasa.gov/missions/opera)

**Key maintainers**: See [CONTRIBUTORS.md](CONTRIBUTORS.md) for current team members and contact information.