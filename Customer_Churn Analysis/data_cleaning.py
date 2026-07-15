"""
Telco Customer Churn — Data Cleaning Pipeline
================================================
Author: Ayush | Data Analyst Portfolio Project
Purpose: Raw source data (as exported from a billing/CRM system) is never
         analysis-ready. This script documents and executes every cleaning
         decision, the same way a Data Analyst would in a production
         pipeline — with reasoning, not just code.

Input : data/telco_churn_unclean.csv   (7,048 rows x 21 columns, IBM Telco
        Customer Churn dataset, deliberately dirtied to simulate a raw
        operational export)
Output: data/telco_churn_clean.csv     (analysis-ready, typed, deduplicated)
"""

import pandas as pd
import numpy as np

RAW_PATH = "../data/telco_churn_unclean.csv"
CLEAN_PATH = "../data/telco_churn_clean.csv"

# ------------------------------------------------------------------
# STEP 1 — Load and profile
# ------------------------------------------------------------------
df = pd.read_csv(RAW_PATH)
print(f"Raw shape: {df.shape}")
print(df.isna().sum()[df.isna().sum() > 0])

# ------------------------------------------------------------------
# STEP 2 — Remove exact duplicate customer records
# ------------------------------------------------------------------

before = len(df)
df = df.drop_duplicates(subset="customerID", keep="first")
print(f"Removed {before - len(df)} duplicate customer rows")

# ------------------------------------------------------------------
# STEP 3 — Standardize text fields (whitespace, inconsistent casing)
# ------------------------------------------------------------------

text_cols = df.select_dtypes(include="object").columns
for col in text_cols:
    df[col] = df[col].astype(str).str.strip()

df["Contract"] = df["Contract"].replace({
    "month to month": "Month-to-month"
})
df["PaymentMethod"] = df["PaymentMethod"].str.replace(r"\s+", " ", regex=True).str.strip()

# ------------------------------------------------------------------
# STEP 4 — Fix currency-formatted numeric column (MonthlyCharges)
# ------------------------------------------------------------------

df["MonthlyCharges"] = (
    df["MonthlyCharges"].astype(str).str.replace("$", "", regex=False).str.strip()
)
df["MonthlyCharges"] = pd.to_numeric(df["MonthlyCharges"], errors="coerce")

# ------------------------------------------------------------------
# STEP 5 — Handle TotalCharges (blank strings, not true NaN)
# ------------------------------------------------------------------

df["TotalCharges"] = df["TotalCharges"].replace("", np.nan)
df["TotalCharges"] = pd.to_numeric(df["TotalCharges"], errors="coerce")

new_customer_mask = df["tenure"] == 0
print(f"New customers (tenure=0) with blank TotalCharges: {(new_customer_mask & df['TotalCharges'].isna()).sum()}")
df.loc[new_customer_mask, "TotalCharges"] = 0.0

# Any remaining unexplained nulls -> flag, don't silently drop
remaining_nulls = df["TotalCharges"].isna().sum()
if remaining_nulls:
    print(f"WARNING: {remaining_nulls} unexplained TotalCharges nulls — review before imputing")
    df["TotalCharges"] = df["TotalCharges"].fillna(df["MonthlyCharges"] * df["tenure"])

# ------------------------------------------------------------------
# STEP 6 — Standardize binary Yes/No fields to consistent labels
# ------------------------------------------------------------------
binary_map_cols = ["Partner", "Dependents", "PhoneService", "PaperlessBilling", "Churn"]
for col in binary_map_cols:
    df[col] = df[col].str.title()

df["SeniorCitizen"] = df["SeniorCitizen"].map({0: "No", 1: "Yes"})

# ------------------------------------------------------------------
# STEP 7 — Data type enforcement
# ------------------------------------------------------------------
df["tenure"] = df["tenure"].astype(int)
df["MonthlyCharges"] = df["MonthlyCharges"].round(2)
df["TotalCharges"] = df["TotalCharges"].round(2)

# ------------------------------------------------------------------
# STEP 8 — Feature engineering (for BI/SQL layer downstream)
# ------------------------------------------------------------------
def tenure_bucket(t):
    if t <= 12: return "0-1 yr"
    elif t <= 24: return "1-2 yr"
    elif t <= 48: return "2-4 yr"
    else: return "4+ yr"

df["TenureBucket"] = df["tenure"].apply(tenure_bucket)

df["ServiceCount"] = df[[
    "PhoneService", "MultipleLines", "OnlineSecurity", "OnlineBackup",
    "DeviceProtection", "TechSupport", "StreamingTV", "StreamingMovies"
]].apply(lambda row: sum(v not in ["No", "No internet service", "No phone service"] for v in row), axis=1)

df["CLTV_Proxy"] = (df["MonthlyCharges"] * df["tenure"]).round(2)  # simple CLTV proxy, refined later in SQL with real formula

# ------------------------------------------------------------------
# STEP 9 — Final validation checks (data quality gate)
# ------------------------------------------------------------------
assert df["customerID"].is_unique, "Duplicate customer IDs remain!"
assert df["MonthlyCharges"].notna().all(), "Nulls remain in MonthlyCharges!"
assert df["TotalCharges"].notna().all(), "Nulls remain in TotalCharges!"
assert set(df["Churn"].unique()) == {"Yes", "No"}, "Unexpected Churn values!"

print(f"\nFinal clean shape: {df.shape}")
print(f"Churn rate: {(df['Churn']=='Yes').mean():.2%}")

df.to_csv(CLEAN_PATH, index=False)
print(f"Saved cleaned dataset to {CLEAN_PATH}")
