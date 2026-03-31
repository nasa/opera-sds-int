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

**Preview commands without executing (dry run mode)**:
```bash
DRY_RUN=true just all
```

Dry run mode displays all commands that would be executed without actually running them. This is useful for:
- Validating test configuration before execution
- Reviewing commands and parameters
- Debugging test workflows
- Understanding what a test will do

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
2. Single polarization test (51QTA_1, 20241029T100014Z)
3. Polarization switch test (20TLP_3, 20250919T102312Z)
4. Anti-meridian edge test case
5. Historical processing test (date range: 2025-07-10T02:00:00Z to 2025-07-10T07:00:00Z)
6. Forward processing E2E test (EventBridge trigger, 3-hour wait, product verification)
7. EC2 worker node destruction test (job recovery validation)

**Preview all test commands (dry run)**:

```bash
DRY_RUN=true just dist-s1::all
```

Dry run mode shows exactly what commands would be executed without running them. All commands are displayed with their full parameters, making it easy to verify configuration and understand the test workflow.

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

**Preview test commands (dry run):**
```bash
DRY_RUN=true just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time 11SLT_0 20250614T015042Z
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

#### 4. Anti-Meridian Edge Test

Tests DIST-S1 processing for anti-meridian edge case scenarios:

```bash
just dist-s1::dist-s1-anti-meridian
```

- **Scenario**: Validates DIST-S1 processing for tiles crossing the anti-meridian (180° longitude)
- **Features**: Executes DAAC data subscriber commands in batches with user-controlled pauses between batches

**Preview test commands (dry run):**
```bash
DRY_RUN=true just dist-s1::dist-s1-anti-meridian
```

#### 5. DIST-S1 E2E Historical Processing

Tests DIST-S1 historical processing using date range queries:

```bash
just dist-s1::e2e-hist
```

- **Date Range**: 2025-07-10T02:00:00Z to 2025-07-10T07:00:00Z
- **Expected Products**: 582
- **Scenario**: Validates historical processing with date range parameters

#### 5a. DIST-S1 E2E Historical Processing (Parameterized)

A parameterized version of the historical processing test that accepts custom date ranges, expected product counts, and sleep durations. This test is designed to be reusable — the other historical tests (`e2e-hist`, `e2e-hist-small`) can be rewritten as thin wrappers around it.

**Default test (2026-01-01 full-day range):**
```bash
just dist-s1::e2e-hist-date-range::e2e-hist-date-range
```

**Custom date range and expected count:**
```bash
just dist-s1::e2e-hist-date-range::e2e-hist-date-range 2025-07-10T02:00:00Z 2025-07-10T07:00:00Z 582 43200
```

**Equivalent to e2e-hist-small:**
```bash
just dist-s1::e2e-hist-date-range::e2e-hist-date-range 2024-07-10T02:00:00Z 2024-07-10T02:22:22Z 20 43200
```

**Preview test commands (dry run):**
```bash
DRY_RUN=true just dist-s1::e2e-hist-date-range::e2e-hist-date-range
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `START_DATE` | Start of the date range (ISO 8601) | `2026-01-01T00:00:00Z` |
| `END_DATE` | End of the date range (ISO 8601) | `2026-01-01T23:59:59Z` |
| `EXPECTED_PRODUCT_COUNT` | Expected number of new products | `10` |
| `SLEEP_SECONDS` | Seconds to wait for processing | `43200` (12 hours) |

#### 6. Forward Processing E2E Test

Tests the DIST-S1 forward processing pipeline end-to-end. Enables the EventBridge forward processing trigger, waits for jobs to process, then verifies that no jobs failed and new products were created on both SDS and CMR.

```bash
just dist-s1::e2e-fwd
```

**With a custom wait time (e.g. 30 minutes instead of 3 hours):**
```bash
FWD_WAIT_SECONDS=1800 just dist-s1::e2e-fwd
```

**Preview test commands (dry run):**
```bash
DRY_RUN=true just dist-s1::e2e-fwd
```

- **Default Wait Time**: 3 hours (10800 seconds)
- **Scenario**: Captures baseline SDS/CMR product counts, enables EventBridge trigger, waits for forward processing to run, disables trigger, checks job statuses, compares product counts
- **Pass Criteria**: No failed jobs AND product counts increased on both SDS and CMR

The following environment variables can be overridden:

| Variable | Description | Default |
|----------|-------------|---------|
| `EVENTBRIDGE_RULE` | EventBridge rule name for forward processing trigger | `opera-int-fwd-rtc_for_dist-query-timer-Trigger` |
| `REGION` | AWS region | `us-west-2` |
| `FWD_WAIT_SECONDS` | Seconds to wait for forward processing | `10800` (3 hours) |

#### 7. EC2 Worker Node Destruction Test

Tests job recovery after terminating an EC2 worker node. This is an interactive test that enables forward processing, terminates a worker instance, and verifies that jobs recover automatically.

```bash
just dist-s1::dist-s1-ec2-destruction::ec2-destruction-test
```

**With a custom working directory for test artifacts:**
```bash
just dist-s1::dist-s1-ec2-destruction::ec2-destruction-test /tmp/my-test-run
```

**Preview test commands (dry run):**
```bash
DRY_RUN=true just dist-s1::dist-s1-ec2-destruction::ec2-destruction-test
```

- **Default Work Directory**: `/tmp/ec2-destruction-test`
- **Scenario**: Enables forward processing, terminates a worker node, monitors job recovery, generates a test report, then disables forward processing
- **Interactive**: Prompts for the EC2 instance ID to terminate and optional ASG capacity restore

The following environment variables can be overridden:

| Variable | Description | Default |
|----------|-------------|---------|
| `ASG_NAME` | Auto-scaling group name | `opera-int-fwd-opera-job_worker-sciflo-l3_dist_s1` |
| `EVENTBRIDGE_RULE` | EventBridge rule name | `opera-int-fwd-rtc_for_dist-query-timer-Trigger` |
| `REGION` | AWS region | `us-west-2` |
| `OPERA_SDS_BASE_URL` | Base URL for OPERA SDS Mozart | `https://opera-int-mozart-fwd.jpl.nasa.gov` |
| `RECOVERY_WAIT_SECONDS` | Seconds to wait for job recovery | `300` |

### Utility Commands

These helper commands allow you to check system state and perform individual operations:

**Check current SDS product count:**
```bash
just dist-s1::helpers::sds-get-product-count
```

**Check current DAAC product count:**
```bash
just dist-s1::helpers::daac-get-product-count
```

**Get latest product's RTC input products:**
```bash
just dist-s1::helpers::sds-get-latest-product-rtc-input-products
```

**Get latest product's S3 URLs:**
```bash
just dist-s1::helpers::sds-get-latest-product-s3-product-urls
```

**Submit a job without running full E2E test:**
```bash
just dist-s1::e2e-with-product-id-time <TILE> <TIMESTAMP>

# Example:
just dist-s1::e2e-with-product-id-time 11SLT_0 20250614T015042Z
```

**All utility commands support dry run mode:**
```bash
# Preview job submission command
DRY_RUN=true just dist-s1::e2e-with-product-id-time 11SLT_0 20250614T015042Z

# Preview product count queries
DRY_RUN=true just dist-s1::helpers::sds-get-product-count
DRY_RUN=true just dist-s1::helpers::daac-get-product-count
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
├── helpers.just                            # Common helper functions
├── prerequisites.just                      # Test preparation helpers
├── e2e-with-product-id-time.just          # E2E test with --product-id-time
├── e2e-fwd.just                           # Forward processing E2E test
├── e2e-hist.just                          # Historical processing test
├── e2e-hist-date-range.just               # Parameterized historical processing test
├── dist-s1-polarization-switch-for-a-track.just  # Polarization switch test
├── dist-s1-single-polarization.just       # Single polarization test
├── dist-s1-anti-meridian.just             # Anti-meridian edge test
├── dist-job-status-check.just             # Job status monitoring
├── dist-s1-ec2-destruction.just           # EC2 worker node destruction test
├── ec2-destruction-test.sh                # EC2 destruction test script
├── sds-product-count.json                 # OpenSearch query template
├── grq-latest-dist-s1.json                # Query for latest product
└── job-status-query-template.json         # Job status query template
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
- **`dist-s1/helpers.just`**: Common helper functions (product counts, metadata queries)
- **`dist-s1/e2e-with-product-id-time.just`**: Main E2E test orchestration
- **`dist-s1/e2e-hist.just`**: Historical processing test with date ranges
- **`dist-s1/dist-job-status-check.just`**: Job status monitoring utilities
- **`dist-s1/prerequisites.just`**: Test preparation helpers
- **`dist-s1/sds-product-count.json`**: OpenSearch query for SDS product counts
- **`dist-s1/grq-latest-dist-s1.json`**: Query template for latest product details
- **`dist-s1/job-status-query-template.json`**: Query template for job status checks

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

### Dry Run Mode

Preview commands without executing them using dry run mode:

```bash
# Preview any test
DRY_RUN=true just dist-s1::all
DRY_RUN=true just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time 11SLT_0 20250614T015042Z
DRY_RUN=true just dist-s1::prerequisites::check-tile 11SLT

# Preview utility commands
DRY_RUN=true just dist-s1::e2e-with-product-id-time 11SLT_0 20250614T015042Z
DRY_RUN=true just dist-s1::helpers::sds-get-product-count
```

**Dry run mode features:**
- Shows all commands that would be executed with full parameters
- Skips environment variable validation (useful for reviewing commands without credentials)
- Displays sleep durations instead of actually sleeping
- No external API calls or system modifications
- Cascades through all test levels automatically

**When to use dry run:**
- Before running tests in production
- To validate configuration and parameters
- To understand test workflow and command structure
- For documentation and training purposes
- When debugging test issues

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
