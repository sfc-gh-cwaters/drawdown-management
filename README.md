# Drawdown Management

Drawdown management for shale gas wells — built on the Snowflake IIoT Common Model.

## Overview

This project provides calculations, automation, and a production engineer UI for managing drawdown on shale gas wells. It builds on an existing IIoT Common Model schema (`DEV.CORE`) that stores SCADA/historian time series data and equipment metadata.

Key capabilities (planned):
- **Views** that filter and contextualize IIoT data for drawdown-relevant wells and attributes (pressures, rates, choke positions)
- **Functions** implementing petroleum engineering calculations (bottom-hole pressure estimation, drawdown computation)
- **Procedures and Tasks** to automate periodic calculation refresh as new data arrives
- **Web Application** (Snowflake App Runtime / Next.js) for production engineers to visualize drawdown trends, manage setpoints, and enter commentary

## Base Schema

All data originates from `DEV.CORE`, which implements the [Snowflake IIoT Common Model](https://medium.com/@chris.waters/snowflake-iiot-common-model-overview-2a79b45951c0). Key tables:

| Table | Purpose |
|-------|---------|
| `ASSET` | Equipment instances (wells, meters, compressors, etc.) |
| `ASSET_ATTR` | Business-defined attributes linked to assets and tags |
| `ATTR_DFNTN` | Attribute definitions (e.g., TUBING_PRESSURE, CASING_PRESSURE, BHP) |
| `TAG` | Signal/sensor metadata |
| `TAG_VALUE` | Raw time series fact table (all tag values, clustered by date + business unit) |
| `TAG_VALUE_INTERPOLATED` | Gap-filled values at regular intervals |
| `TAG_VALUE_AGGREGATE` | Pre-computed aggregates (min, max, avg, TWA) |
| `ASSET_HIERARCHY_ASSET` | Parent-child relationships between assets |
| `ASSET_EVENT` | Operational events (shutdowns, maintenance, mode changes) |

## Project Structure

```
├── app/              # Snowflake App Runtime (Next.js) web application
├── sql/
│   ├── views/        # Drawdown-specific views on DEV.CORE
│   ├── functions/    # UDFs (BHP correlations, unit conversions)
│   ├── procedures/   # Orchestration stored procedures
│   └── tasks/        # Scheduled computation tasks
├── .gitignore
├── README.md
└── snowflake.yml     # Snow CLI project definition
```

## Getting Started

Prerequisites:
- Snowflake account with access to `DEV.CORE`
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index) (`snow`)
- Node.js 18+ (for app development)
