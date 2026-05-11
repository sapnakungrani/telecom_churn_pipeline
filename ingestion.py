"""
Telecom Customer Churn Analytics Pipeline
Author: Sapna Kungrani

ingestion.py  — Downloads the Kaggle dataset, validates it,
                cleans it, and uploads it to HDFS.

Run:
    python ingestion.py

Requirements:
    pip install pandas kaggle subprocess
    Set KAGGLE_USERNAME and KAGGLE_KEY env vars (from kaggle.com/account)
"""

import os
import subprocess
import pandas as pd

# ─── Config ───────────────────────────────────────────────────
KAGGLE_DATASET  = "blastchar/telco-customer-churn"
LOCAL_RAW       = "data/WA_Fn-UseC_-Telco-Customer-Churn.csv"
LOCAL_CLEAN     = "data/telco_clean.csv"
HDFS_RAW_DIR    = "/user/sapna/telecom/raw"
HDFS_CLEAN_DIR  = "/user/sapna/telecom/clean"
EXPECTED_COLS   = [
    "customerID", "gender", "SeniorCitizen", "Partner", "Dependents",
    "tenure", "PhoneService", "MultipleLines", "InternetService",
    "OnlineSecurity", "OnlineBackup", "DeviceProtection", "TechSupport",
    "StreamingTV", "StreamingMovies", "Contract", "PaperlessBilling",
    "PaymentMethod", "MonthlyCharges", "TotalCharges", "Churn"
]

# ─── Step 1: Download from Kaggle ─────────────────────────────
def download_dataset():
    os.makedirs("data", exist_ok=True)
    print("Downloading dataset from Kaggle...")
    subprocess.run(
        ["kaggle", "datasets", "download", "-d", KAGGLE_DATASET,
         "--unzip", "-p", "data/"],
        check=True
    )
    print(f"Downloaded to {LOCAL_RAW}")


# ─── Step 2: Validate schema & counts ─────────────────────────
def validate_raw(df: pd.DataFrame) -> bool:
    print("\n── Validation Report ──────────────────────────────")
    print(f"  Total records   : {len(df):,}")
    print(f"  Total columns   : {len(df.columns)}")

    missing_cols = [c for c in EXPECTED_COLS if c not in df.columns]
    if missing_cols:
        print(f"  FAIL – Missing columns: {missing_cols}")
        return False

    null_counts = df.isnull().sum()
    print(f"  Null values     : {null_counts[null_counts > 0].to_dict()}")

    blank_total_charges = (df["TotalCharges"].str.strip() == "").sum()
    print(f"  Blank TotalCharges: {blank_total_charges}")

    duplicate_ids = df["customerID"].duplicated().sum()
    print(f"  Duplicate IDs   : {duplicate_ids}")

    valid = (len(missing_cols) == 0 and duplicate_ids == 0)
    status = "PASS" if valid else "FAIL"
    print(f"  Schema check    : {status}")
    print("────────────────────────────────────────────────────\n")
    return valid


# ─── Step 3: Clean data ────────────────────────────────────────
def clean_data(df: pd.DataFrame) -> pd.DataFrame:
    # Fix blank TotalCharges → 0.0
    df["TotalCharges"] = df["TotalCharges"].str.strip().replace("", "0")
    df["TotalCharges"] = pd.to_numeric(df["TotalCharges"], errors="coerce").fillna(0.0)

    # Standardise column names to snake_case for Hive
    rename_map = {c: c.lower() for c in df.columns}
    rename_map["customerID"] = "customer_id"
    rename_map["SeniorCitizen"] = "senior_citizen"
    rename_map["PhoneService"] = "phone_service"
    rename_map["MultipleLines"] = "multiple_lines"
    rename_map["InternetService"] = "internet_service"
    rename_map["OnlineSecurity"] = "online_security"
    rename_map["OnlineBackup"] = "online_backup"
    rename_map["DeviceProtection"] = "device_protection"
    rename_map["TechSupport"] = "tech_support"
    rename_map["StreamingTV"] = "streaming_tv"
    rename_map["StreamingMovies"] = "streaming_movies"
    rename_map["PaperlessBilling"] = "paperless_billing"
    rename_map["PaymentMethod"] = "payment_method"
    rename_map["MonthlyCharges"] = "monthly_charges"
    rename_map["TotalCharges"] = "total_charges"
    df = df.rename(columns=rename_map)

    # Drop any rows with null customer_id
    before = len(df)
    df = df.dropna(subset=["customer_id"])
    after  = len(df)
    print(f"  Rows dropped (null ID): {before - after}")

    return df


# ─── Step 4: Post-clean reconciliation (data accuracy check) ──
def reconcile(raw_df: pd.DataFrame, clean_df: pd.DataFrame):
    raw_count   = len(raw_df)
    clean_count = len(clean_df)
    accuracy    = clean_count / raw_count * 100
    print("── Reconciliation ─────────────────────────────────")
    print(f"  Raw records     : {raw_count:,}")
    print(f"  Clean records   : {clean_count:,}")
    print(f"  Accuracy        : {accuracy:.4f}%")
    if accuracy >= 99.95:
        print("  STATUS          : PASS (≥99.95%)")
    else:
        print("  STATUS          : WARN (<99.95%)")
    print("────────────────────────────────────────────────────\n")


# ─── Step 5: Upload to HDFS ────────────────────────────────────
def upload_to_hdfs(local_path: str, hdfs_dir: str):
    print(f"Uploading {local_path} → HDFS:{hdfs_dir}")
    subprocess.run(["hdfs", "dfs", "-mkdir", "-p", hdfs_dir], check=True)
    subprocess.run(["hdfs", "dfs", "-put", "-f", local_path, hdfs_dir], check=True)

    # Verify file count in HDFS
    result = subprocess.run(
        ["hdfs", "dfs", "-count", hdfs_dir],
        capture_output=True, text=True, check=True
    )
    print(f"  HDFS count: {result.stdout.strip()}")
    print("  Upload complete.\n")


# ─── Main ──────────────────────────────────────────────────────
if __name__ == "__main__":
    download_dataset()

    raw_df = pd.read_csv(LOCAL_RAW)

    is_valid = validate_raw(raw_df)
    if not is_valid:
        print("Validation failed. Aborting pipeline.")
        exit(1)

    clean_df = clean_data(raw_df.copy())
    clean_df.to_csv(LOCAL_CLEAN, index=False)
    print(f"Clean file saved: {LOCAL_CLEAN}")

    reconcile(raw_df, clean_df)

    upload_to_hdfs(LOCAL_RAW,   HDFS_RAW_DIR)
    upload_to_hdfs(LOCAL_CLEAN, HDFS_CLEAN_DIR)

    print("Pipeline ingestion complete. Ready to run Hive queries.")
