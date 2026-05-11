-- ============================================================
-- Telecom Customer Churn Analytics Pipeline
-- Author: Sapna Kungrani
-- Step 1: Create Hive tables from raw HDFS data
-- ============================================================

-- Create database
CREATE DATABASE IF NOT EXISTS telecom_churn;
USE telecom_churn;

-- Raw staging table (loaded from HDFS CSV)
CREATE EXTERNAL TABLE IF NOT EXISTS stg_customers (
    customer_id       STRING,
    gender            STRING,
    senior_citizen    INT,
    partner           STRING,
    dependents        STRING,
    tenure            INT,
    phone_service     STRING,
    multiple_lines    STRING,
    internet_service  STRING,
    online_security   STRING,
    online_backup     STRING,
    device_protection STRING,
    tech_support      STRING,
    streaming_tv      STRING,
    streaming_movies  STRING,
    contract          STRING,
    paperless_billing STRING,
    payment_method    STRING,
    monthly_charges   DOUBLE,
    total_charges     STRING,   -- raw: some blanks, cleaned downstream
    churn             STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/sapna/telecom/raw/'
TBLPROPERTIES ("skip.header.line.count"="1");


-- Cleaned ORC table (optimised for analytics)
CREATE TABLE IF NOT EXISTS dim_customers (
    customer_id       STRING,
    gender            STRING,
    senior_citizen    INT,
    partner           STRING,
    dependents        STRING,
    tenure            INT,
    contract          STRING,
    internet_service  STRING,
    payment_method    STRING,
    paperless_billing STRING,
    monthly_charges   DOUBLE,
    total_charges     DOUBLE,
    churn_flag        INT       -- 1 = churned, 0 = active
)
STORED AS ORC
TBLPROPERTIES ("orc.compress"="SNAPPY");


-- Fact table: one row per customer with derived segments
CREATE TABLE IF NOT EXISTS fact_churn_analysis (
    customer_id       STRING,
    tenure_band       STRING,   -- '0-12', '13-24', '25-48', '49+'
    charge_segment    STRING,   -- 'Low (<40)', 'Mid (40-70)', 'High (>70)'
    contract          STRING,
    internet_service  STRING,
    churn_flag        INT,
    monthly_charges   DOUBLE,
    total_charges     DOUBLE
)
STORED AS ORC
TBLPROPERTIES ("orc.compress"="SNAPPY");
