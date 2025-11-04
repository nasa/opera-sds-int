# DIST-S1 Test Automation

Automated V&V tests for OPERA DIST-S1 product generation.

## Structure

```
dist-s1/
├── mod.just                         # Module index
├── prerequisites.just               # Helper commands (NEW!)
├── e2e-with-product-id-time.just   # E2E test with product-id-time (UPDATED!)
└── README.md                        # This file
```

## Quick Start

### 1. Using the Complete Workflow (Recommended)

Run everything in one command:

```bash
just dist-s1::prerequisites::workflow 11SLT 2024-06-01T00:00:00Z 2024-06-30T23:59:59Z /tmp/rtc_test.csv
```

This will:
1. Check tile information
2. Survey RTC granules from CMR
3. Trigger granules for the tile
4. Show you the product IDs and timestamps to use

### 2. Run the E2E Test with Variable Parameters

**Default (backward compatible):**
```bash
just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time
```

**With custom tile and timestamp:**
```bash
just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time 11SLT_0 20250614T015042Z
```

**Arctic Alaska example (HH+HV polarization):**
```bash
just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time 01WDU_5 20220101T051815Z
```

## Prerequisites Module Commands

The `prerequisites` module helps you gather information needed for testing.

### Check Tile Information

See what acquisition groups exist for a tile:

```bash
just dist-s1::prerequisites::check-tile 11SLT
```

### Survey RTC Granules

Get a list of RTC granules from CMR for a date range:

```bash
just dist-s1::prerequisites::survey-rtc-granules 2024-10-01T00:00:00Z 2024-10-31T23:59:59Z /tmp/rtc_oct.csv
```

**Output files:**
- `/tmp/rtc_oct.csv` - Summary by time period
- `/tmp/rtc_oct.csv.raw.csv` - Full granule list (use this for next step!)

### Trigger Granules for a Tile

Find which products can be generated for a tile:

```bash
just dist-s1::prerequisites::trigger-granules 11SLT /tmp/rtc_oct.csv.raw.csv
```

**Important:** Use the `.raw.csv` file from the survey command!

### Get Product ID from Granule

If you have a specific RTC granule ID:

```bash
just dist-s1::prerequisites::get-product-id-from-granule OPERA_L2_RTC-S1_T066-140035-IW2_20220101T051815Z_20241216T224934Z_S1A_30_v1.0
```

## E2E Test Details

### What the Test Does

1. ✅ Records initial product counts (SDS and DAAC)
2. ✅ Submits reprocessing job with `--product-id-time`
3. ✅ Waits 15 minutes for completion
4. ✅ Retrieves latest product details
5. ✅ Verifies new products were created and delivered
6. ✅ Shows before/after counts

### Variables

| Parameter | Description | Default |
|-----------|-------------|---------|
| `TILE` | Product ID (tile + acquisition group) | `11SLT_0` |
| `TIMESTAMP` | Acquisition timestamp | `20250614T015042Z` |

## Examples

### Example 1: Test with Default Parameters

```bash
just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time
```

### Example 2: Test with Custom Tile

```bash
# First, get valid timestamps
just dist-s1::prerequisites::workflow 11SLT 2024-06-01T00:00:00Z 2024-06-30T23:59:59Z /tmp/rtc_june.csv

# Look at the output, pick a product_id and timestamp, then:
just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time 11SLT_1 20240614T135254Z
```

### Example 3: Test with Arctic Alaska Tile (HH+HV Polarization)

```bash
# Survey Arctic Alaska data
just dist-s1::prerequisites::survey-rtc-granules 2022-01-01T00:00:00Z 2022-01-31T23:59:59Z /tmp/rtc_arctic.csv

# Trigger granules for Arctic tile
just dist-s1::prerequisites::trigger-granules 01WDU /tmp/rtc_arctic.csv.raw.csv

# Run test with HH+HV data
just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time 01WDU_5 20220101T051815Z
```

## Troubleshooting

### "KeyError: '# Granule ID'"

**Problem:** You used the wrong CSV file with `trigger-granules`

**Solution:** Use the `.raw.csv` file, not the main `.csv` file:
```bash
# ❌ Wrong
just dist-s1::prerequisites::trigger-granules 11SLT /tmp/rtc_oct.csv

# ✅ Correct
just dist-s1::prerequisites::trigger-granules 11SLT /tmp/rtc_oct.csv.raw.csv
```

### "No products were generated"

**Possible causes:**
1. Invalid product ID or timestamp
2. RTC data not available for that date
3. System issues (check Mozart logs)
4. Wait time too short (increase from 15 minutes if needed)

**Debug steps:**
1. Verify the product ID exists: `just dist-s1::prerequisites::check-tile <TILE_ID_BASE>`
2. Verify RTC data exists for that date: Use `survey-rtc-granules`
3. Check Mozart job status manually

### Finding Valid Test Data

**For standard VV+VH polarization:**
- Use any mid-latitude tile (e.g., 11SLT, 20TLP)
- Survey recent data (2024-2025)

**For HH+HV polarization (non-standard):**
- Use Arctic tiles: 01WDU, 01WCU, 60WWD
- Use dates: 2022-01-01 to 2022-06-30
- Antarctica tiles: dates in 2024-2025

## Reference

### CMR Survey Parameters
- `--collection-shortname`: `OPERA_L2_RTC-S1_V1`
- `--endpoint`: `OPS` (operational) or `UAT` (test)
- Date format: `YYYY-MM-DDTHH:MM:SSZ`

### Tile Naming Convention
- Format: `{MGRS_TILE}_{ACQUISITION_GROUP}`
- Example: `11SLT_0` = Tile 11SLT, acquisition group 0
- A single MGRS tile can have multiple acquisition groups (0-3+)

## Notes

- Survey commands can take several minutes for large date ranges
- The `.raw.csv` file contains one line per RTC granule
- Test execution takes ~15 minutes (can be adjusted)
- Default parameters maintained for backward compatibility
