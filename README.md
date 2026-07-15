## 📉Telco Customer Churn Analysis — End-to-End Data Analyst Project

An end-to-end churn analysis for a telecom customer base (~7,000 accounts): raw data
cleaning, SQL business analysis, EDA, and a Power BI dashboard design — built the way a
Data Analyst would deliver it in a real company, not as a single Kaggle notebook.

## 🛠️skills used

·SQL (window functions, CTEs, views, self-joins)
·Python (pandas, matplotlib, seaborn)
·Power BI (DAX measures, calculated columns, dashboard design)

## 🧩Why This Project

Most portfolio churn projects stop at "here's a chart, churn is 26%." This one is
built the way a Data Analyst actually delivers work at a company: a documented data
cleaning pipeline with reasoning for every decision, SQL business queries validated
against real query output (not hypothetical), a Power BI dashboard **specification**
with real DAX measures rather than a black-box file, and ROI-ranked recommendations
with cost/risk tradeoffs — not just "reduce churn" as an insight.

## 📄Steps in this projects

# Step No 1 : Data Understanding
================================================
This is a 7,043-customer telecom dataset where 26.5% churned. Contract length is the
dominant driver — month-to-month customers churn at 42.7% vs just 2.8% for two-year 
contracts — and nearly half of all churn happens in the customer's first year, making
this fundamentally an onboarding problem, not a general satisfaction problem. Churned
customers also pay more on average than retained ones, so the company is losing 
disproportionately high-value accounts. Add-ons like tech support and online security
correlate strongly with retention, likely because they raise switching cost.

# Step No 2 : Data Cleaning Pipeline
================================================
1 — Load and profile in Py
2 — Remove exact duplicate customer records
3 — Standardize text fields (whitespace, inconsistent casing)
4 — Fix currency-formatted numeric column (MonthlyCharges)
5 — Handle TotalCharges (blank strings, not true NaN)
6 — Standardize binary Yes/No fields to consistent labels
7 — Data type enforcement
8 — Feature engineering (for BI/SQL layer downstream)

# Step No 3 : Exploratory Data Analysis
==================================================
1. Outlier check on numeric fields (IQR method)
2. Key business breakdowns
3. Visualizations
charts:
<img width="1419" height="1088" alt="eda_summary_charts" src="https://github.com/user-attachments/assets/1c473044-26bc-416a-918b-a2c1da770aa9" />

# Step No 4 : Dashboard 
==================================================
📈 Dashboard Preview:
<img width="2767" height="1600" alt="Churn DataSet Dashboard-1" src="https://github.com/user-attachments/assets/c4cd2f15-a13f-46a9-886a-d8f3ada269d7" />

# Step No 5 : Business insights & Recommendations
==================================================
Top insights & Recommendations:
1. insight: Month-to-month churn is 42.71% vs 2.83% for two-year contracts.
   Recommendation: Offer a modest discount (e.g. 5-10%) to convert month-to-month customers to 1-year contracts at renewal touchpoints.

2. insight: 47.44% churn rate in the 0-1 year tenure bucket, dropping to 9.51% at 4+ years.
   Recommendation: Build a structured 90-day onboarding check-in program (welcome call, usage tips, proactive support outreach).

3. insight: 45.29% churn for electronic check vs 15.24% for credit card (automatic).
   Recommendation: Incentivize migration to autopay (small bill credit for switching) — proven retention lever in subscription businesses.
   
---

<div align="center">
Built by **Ayush Pandey** —  [ linkedin.com/in/ayush-pandey28 ](#)

</div>
