# Telecom Customer Churn Analytics Pipeline

**Author:** Sapna Kungrani  
**Stack:** Python · Hadoop HDFS · Apache Hive · SQL · Power BI  
**Domain:** Telecom (mirrors production experience in telecom-scale data environments)

---

## Overview

An end-to-end big data analytics pipeline that ingests a 7,000+ row telecom customer dataset,
validates and cleans it in Python, stores it in HDFS, and runs 10 Hive analytics queries to
identify churn patterns. Results are visualised in a Power BI dashboard.

This project replicates real production workflows — HDFS file validation, record-level
reconciliation (≥99.95% accuracy checks), ORC storage with Snappy compression, and
ETL via Hive — the same patterns used in telecom-scale deployments.

---

## Architecture

```
Kaggle CSV
    │
    ▼
ingestion.py  ──► Schema validation ──► Record reconciliation ──► HDFS upload
    │
    ▼
HDFS /user/sapna/telecom/raw/
    │
    ▼
Hive: stg_customers  (EXTERNAL, TEXTFILE)
    │
    ▼  ETL (02_etl_and_analytics.hql)
    ▼
Hive: dim_customers  (ORC + SNAPPY)
    │
    ▼
Hive: fact_churn_analysis  (ORC, derived tenure bands & charge segments)
    │
    ▼
10 Analytics Queries  ──►  Power BI Dashboard
```

---

## Key Findings

| Metric | Value |
|--------|-------|
| Overall churn rate | ~26.5% |
| Month-to-month contract churn | ~43% |
| 0–12 month tenure churn | ~47% |
| Fiber optic + high charge churn | ~52% |
| Monthly revenue at risk | ~$139K |

---

## Repository Structure

```
├── sql/
│   ├── 01_create_tables.hql     # Hive DDL — raw, dim, fact tables
│   └── 02_etl_and_analytics.hql # ETL load + 10 analytics queries
├── python/
│   └── ingestion.py             # Download → validate → clean → HDFS upload
├── docs/
│   └── architecture.png         # Pipeline diagram
└── README.md
```

---

## How to Run

### 1. Set up local Hadoop (Docker)
```bash
docker pull sequenceiq/hadoop-docker:2.7.1
docker run -it sequenceiq/hadoop-docker:2.7.1 /etc/bootstrap.sh -bash
```

### 2. Install Python dependencies
```bash
pip install pandas kaggle
```

### 3. Set Kaggle credentials
```bash
export KAGGLE_USERNAME=your_username
export KAGGLE_KEY=your_api_key
```

### 4. Run ingestion
```bash
python python/ingestion.py
```

### 5. Run Hive pipeline
```bash
hive -f sql/01_create_tables.hql
hive -f sql/02_etl_and_analytics.hql
```

### 6. Connect Power BI
Export query results to CSV and import into Power BI Desktop (free).

---

## Skills Demonstrated

- **HDFS operations**: mkdir, put, count, file lifecycle management
- **Hive DDL/DML**: external tables, ORC/Snappy, partitioning patterns
- **SQL analytics**: window patterns, CASE bands, GROUP BY, JOIN, UNION ALL
- **Data validation**: schema checks, null handling, record reconciliation (≥99.95%)
- **Python ETL**: pandas cleaning, subprocess HDFS calls, accuracy reporting
- **Power BI**: connecting to CSV exports, building interactive dashboards

---

## Dataset

IBM Telco Customer Churn — publicly available on [Kaggle](https://www.kaggle.com/datasets/blastchar/telco-customer-churn)  
7,043 customers · 21 features · No personal data
