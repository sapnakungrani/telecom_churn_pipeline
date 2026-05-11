-- ============================================================
-- Telecom Customer Churn Analytics Pipeline
-- Author: Sapna Kungrani
-- Step 2: ETL + 10 Analytics Queries
-- ============================================================

USE telecom_churn;

-- ─── ETL: Load staging → cleaned dim table ─────────────────
INSERT OVERWRITE TABLE dim_customers
SELECT
    customer_id,
    gender,
    senior_citizen,
    partner,
    dependents,
    tenure,
    contract,
    internet_service,
    payment_method,
    paperless_billing,
    monthly_charges,
    CASE
        WHEN total_charges = '' OR total_charges IS NULL THEN 0.0
        ELSE CAST(total_charges AS DOUBLE)
    END                                                    AS total_charges,
    CASE WHEN UPPER(churn) = 'YES' THEN 1 ELSE 0 END      AS churn_flag
FROM stg_customers
WHERE customer_id IS NOT NULL
  AND customer_id != '';

-- ─── ETL: Load dim → fact table with derived bands ─────────
INSERT OVERWRITE TABLE fact_churn_analysis
SELECT
    customer_id,
    CASE
        WHEN tenure BETWEEN 0  AND 12 THEN '0-12 months'
        WHEN tenure BETWEEN 13 AND 24 THEN '13-24 months'
        WHEN tenure BETWEEN 25 AND 48 THEN '25-48 months'
        ELSE '49+ months'
    END                                                    AS tenure_band,
    CASE
        WHEN monthly_charges < 40  THEN 'Low (<40)'
        WHEN monthly_charges <= 70 THEN 'Mid (40-70)'
        ELSE 'High (>70)'
    END                                                    AS charge_segment,
    contract,
    internet_service,
    churn_flag,
    monthly_charges,
    total_charges
FROM dim_customers;


-- ============================================================
-- ANALYTICS QUERIES
-- ============================================================

-- Q1: Overall churn rate
SELECT
    COUNT(*)                                                     AS total_customers,
    SUM(churn_flag)                                              AS churned_customers,
    ROUND(SUM(churn_flag) * 100.0 / COUNT(*), 2)                AS churn_rate_pct
FROM fact_churn_analysis;


-- Q2: Churn rate by contract type
SELECT
    contract,
    COUNT(*)                                                     AS customers,
    SUM(churn_flag)                                              AS churned,
    ROUND(SUM(churn_flag) * 100.0 / COUNT(*), 2)                AS churn_rate_pct
FROM fact_churn_analysis
GROUP BY contract
ORDER BY churn_rate_pct DESC;


-- Q3: Churn rate by tenure band (key insight: newer customers churn more)
SELECT
    tenure_band,
    COUNT(*)                                                     AS customers,
    SUM(churn_flag)                                              AS churned,
    ROUND(SUM(churn_flag) * 100.0 / COUNT(*), 2)                AS churn_rate_pct
FROM fact_churn_analysis
GROUP BY tenure_band
ORDER BY
    CASE tenure_band
        WHEN '0-12 months'  THEN 1
        WHEN '13-24 months' THEN 2
        WHEN '25-48 months' THEN 3
        ELSE 4
    END;


-- Q4: Churn rate by internet service type
SELECT
    internet_service,
    COUNT(*)                                                     AS customers,
    ROUND(SUM(churn_flag) * 100.0 / COUNT(*), 2)                AS churn_rate_pct,
    ROUND(AVG(monthly_charges), 2)                              AS avg_monthly_charge
FROM fact_churn_analysis
GROUP BY internet_service
ORDER BY churn_rate_pct DESC;


-- Q5: Churn rate by monthly charge segment
SELECT
    charge_segment,
    COUNT(*)                                                     AS customers,
    SUM(churn_flag)                                              AS churned,
    ROUND(SUM(churn_flag) * 100.0 / COUNT(*), 2)                AS churn_rate_pct,
    ROUND(AVG(monthly_charges), 2)                              AS avg_charge
FROM fact_churn_analysis
GROUP BY charge_segment
ORDER BY avg_charge;


-- Q6: Revenue at risk from churned customers
SELECT
    ROUND(SUM(monthly_charges), 2)                              AS monthly_revenue_lost,
    ROUND(SUM(total_charges), 2)                                AS total_revenue_lost,
    COUNT(*)                                                     AS churned_count
FROM fact_churn_analysis
WHERE churn_flag = 1;


-- Q7: Payment method vs churn (manual vs auto-pay)
SELECT
    payment_method,
    COUNT(*)                                                     AS customers,
    ROUND(SUM(churn_flag) * 100.0 / COUNT(*), 2)                AS churn_rate_pct
FROM fact_churn_analysis
GROUP BY payment_method
ORDER BY churn_rate_pct DESC;


-- Q8: High-risk segment — month-to-month + fiber + high charge
SELECT
    COUNT(*)                                                     AS high_risk_customers,
    ROUND(SUM(churn_flag) * 100.0 / COUNT(*), 2)                AS churn_rate_pct,
    ROUND(AVG(monthly_charges), 2)                              AS avg_monthly_charge
FROM fact_churn_analysis
WHERE contract       = 'Month-to-month'
  AND internet_service = 'Fiber optic'
  AND charge_segment = 'High (>70)';


-- Q9: Churn rate by gender and senior citizen status
SELECT
    c.gender,
    c.senior_citizen,
    COUNT(*)                                                     AS customers,
    ROUND(SUM(f.churn_flag) * 100.0 / COUNT(*), 2)              AS churn_rate_pct
FROM fact_churn_analysis f
JOIN dim_customers c USING (customer_id)
GROUP BY c.gender, c.senior_citizen
ORDER BY churn_rate_pct DESC;


-- Q10: Data quality check — record count reconciliation
--      (mirrors production validation work at telecom clients)
SELECT 'stg_customers'    AS table_name, COUNT(*) AS record_count FROM stg_customers
UNION ALL
SELECT 'dim_customers'    AS table_name, COUNT(*) AS record_count FROM dim_customers
UNION ALL
SELECT 'fact_churn_analysis' AS table_name, COUNT(*) AS record_count FROM fact_churn_analysis;
-- Expected: all three counts should match (99.95%+ accuracy validation)
