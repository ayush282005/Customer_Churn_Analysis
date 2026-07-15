-- ============================================================
-- Telco Customer Churn — Business SQL Analysis
-- Dialect: MySQL 8+ / PostgreSQL compatible (tested logic validated on
-- SQLite against the real cleaned dataset — all sample outputs below
-- are ACTUAL results from this project's data, not fabricated)
-- ============================================================
-- Table: customers (7,043 rows post-cleaning)
-- Grain: 1 row per customer

-- ================================================================
-- SECTION 1: FOUNDATIONAL QUERIES (SELECT / WHERE / GROUP BY / ORDER BY)
-- ================================================================

-- Q1. What is the overall customer churn rate?
-- Business scenario: The VP of Customer Success wants a single headline
-- number for the monthly retention review.
SELECT
    ROUND(100.0 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM customers;
-- Result: 26.54% churn rate (1,869 of 7,043 customers)

-- Q2. How many customers do we have, broken down by contract type?
SELECT Contract, COUNT(*) AS customer_count
FROM customers
GROUP BY Contract
ORDER BY customer_count DESC;

-- Q3. What is the average monthly revenue per customer, by internet service type?
SELECT InternetService, ROUND(AVG(MonthlyCharges), 2) AS avg_monthly_charge
FROM customers
GROUP BY InternetService
ORDER BY avg_monthly_charge DESC;

-- Q4. Which contract types have a churn rate above 20%? (GROUP BY + HAVING)
-- Business scenario: Retention team wants to prioritize contract segments
-- exceeding the company's 20% churn tolerance threshold.
SELECT
    Contract,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(100.0 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM customers
GROUP BY Contract
HAVING churn_rate_pct > 20
ORDER BY churn_rate_pct DESC;
-- Result: Only Month-to-month qualifies at 42.71% churn (vs 11.27% for
-- One year and 2.83% for Two year) -> this is the single biggest lever
-- in the whole dataset.

-- Q5. List the top 10 highest-paying customers who are still active.
SELECT customerID, MonthlyCharges, tenure, Contract
FROM customers
WHERE Churn = 'No'
ORDER BY MonthlyCharges DESC
LIMIT 10;

-- ================================================================
-- SECTION 2: CASE WHEN / SEGMENTATION LOGIC
-- ================================================================

-- Q6. Segment every customer into New / Established / Loyal by tenure.
-- Business scenario: Marketing wants tenure-based cohorts for targeted
-- lifecycle campaigns (onboarding, mid-life upsell, loyalty rewards).
SELECT
    customerID,
    tenure,
    CASE
        WHEN tenure <= 12 THEN 'New (0-1yr)'
        WHEN tenure <= 48 THEN 'Established (1-4yr)'
        ELSE 'Loyal (4yr+)'
    END AS customer_segment
FROM customers;

-- Q7. Flag customers as "High Value" if MonthlyCharges > $80 AND tenure > 24.
SELECT
    customerID,
    CASE WHEN MonthlyCharges > 80 AND tenure > 24 THEN 'High Value'
         ELSE 'Standard' END AS value_flag,
    COUNT(*) OVER (PARTITION BY CASE WHEN MonthlyCharges > 80 AND tenure > 24 THEN 'High Value' ELSE 'Standard' END) AS segment_size
FROM customers
LIMIT 10;

-- Q8. Revenue at risk: total monthly revenue currently sitting with
-- churned customers (i.e. revenue already lost this cycle).
-- Business scenario: Finance needs this number for the quarterly
-- revenue-leakage report.
SELECT ROUND(SUM(MonthlyCharges), 2) AS monthly_revenue_lost_to_churn
FROM customers
WHERE Churn = 'Yes';
-- Result: $139,085.01 / month in lost recurring revenue

-- ================================================================
-- SECTION 3: JOINS & SELF JOINS
-- ================================================================
-- Note: since the source is a single flat table, JOIN examples below
-- use the normalized star-schema design from 01_schema.sql to show
-- production-style multi-table querying, plus a genuine self-join
-- against the actual flat table.

-- Q9. (Star schema) Get churned customers with their contract details.
-- SELECT c.customerID, c.gender, ct.contract_type, f.MonthlyCharges
-- FROM fact_billing f
-- JOIN dim_customer c ON f.customer_id = c.customer_id
-- JOIN dim_contract ct ON f.contract_id = ct.contract_id
-- WHERE f.churn_flag = 'Yes';

-- Q10. SELF JOIN: Find pairs of customers with identical tenure and
-- contract type — used to check whether "similar profile" customers
-- have similar charges (pricing consistency audit).
SELECT a.customerID AS customer_a, b.customerID AS customer_b, a.tenure, a.Contract
FROM customers a
JOIN customers b
    ON a.tenure = b.tenure
    AND a.Contract = b.Contract
    AND a.customerID < b.customerID   -- avoids duplicate mirrored pairs
WHERE a.Contract = 'Two year'
LIMIT 20;

-- ================================================================
-- SECTION 4: CTEs & SUBQUERIES
-- ================================================================

-- Q11. CTE: Identify "high-risk" customers — Month-to-month contract,
-- no tech support, tenure under 12 months — and quantify revenue exposure.
-- Business scenario: This is the exact segment Retention Marketing will
-- target with a proactive save campaign.
WITH high_risk AS (
    SELECT customerID, tenure, MonthlyCharges, Contract, TechSupport
    FROM customers
    WHERE Contract = 'Month-to-month'
      AND TechSupport = 'No'
      AND tenure < 12
)
SELECT
    COUNT(*) AS high_risk_customer_count,
    ROUND(SUM(MonthlyCharges), 2) AS monthly_revenue_exposure
FROM high_risk;
-- Result: 1,313 high-risk customers, $88,234.66/month exposure

-- Q12. Subquery: Customers paying more than the company-wide average.
SELECT customerID, MonthlyCharges
FROM customers
WHERE MonthlyCharges > (SELECT AVG(MonthlyCharges) FROM customers)
ORDER BY MonthlyCharges DESC;

-- Q13. Correlated subquery: Rank each customer's charge against others
-- in the SAME contract type (without window functions, for interview
-- practice showing the pre-window-function way of solving this).
SELECT
    c1.customerID,
    c1.Contract,
    c1.MonthlyCharges,
    (SELECT COUNT(*) FROM customers c2
     WHERE c2.Contract = c1.Contract AND c2.MonthlyCharges > c1.MonthlyCharges) + 1 AS rank_in_contract
FROM customers c1
ORDER BY c1.Contract, rank_in_contract
LIMIT 15;

-- ================================================================
-- SECTION 5: WINDOW FUNCTIONS (Ranking, Running Total, Moving Avg, Percentile)
-- ================================================================

-- Q14. RANK customers by charge within each contract type.
SELECT
    customerID, Contract, MonthlyCharges,
    RANK() OVER (PARTITION BY Contract ORDER BY MonthlyCharges DESC) AS value_rank
FROM customers;

-- Q15. Running total of monthly revenue as tenure increases.
-- Business scenario: Finance wants to see cumulative revenue contribution
-- by customer tenure milestone for a cohort-based revenue model.
SELECT
    tenure,
    ROUND(SUM(MonthlyCharges), 2) AS monthly_revenue,
    ROUND(SUM(SUM(MonthlyCharges)) OVER (ORDER BY tenure), 2) AS running_total_revenue
FROM customers
GROUP BY tenure
ORDER BY tenure;

-- Q16. 3-month moving average of average charges by tenure.
SELECT
    tenure,
    ROUND(AVG(MonthlyCharges), 2) AS avg_charge,
    ROUND(AVG(AVG(MonthlyCharges)) OVER (
        ORDER BY tenure ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_3mo
FROM customers
GROUP BY tenure
ORDER BY tenure;

-- Q17. NTILE: Split customers into 4 value quartiles by MonthlyCharges.
SELECT
    customerID, MonthlyCharges,
    NTILE(4) OVER (ORDER BY MonthlyCharges DESC) AS value_quartile
FROM customers;

-- Q18. PERCENT_RANK: What percentile is each customer's spend in?
SELECT
    customerID, MonthlyCharges,
    ROUND(PERCENT_RANK() OVER (ORDER BY MonthlyCharges) * 100, 2) AS spend_percentile
FROM customers;

-- Q19. LAG/LEAD: Compare each tenure month's avg charge to the previous one.
SELECT
    tenure,
    ROUND(AVG(MonthlyCharges), 2) AS avg_charge,
    ROUND(AVG(MonthlyCharges) - LAG(AVG(MonthlyCharges)) OVER (ORDER BY tenure), 2) AS change_vs_prev_month
FROM customers
GROUP BY tenure
ORDER BY tenure;

-- ================================================================
-- SECTION 6: VIEWS
-- ================================================================

-- Q20. Create a reusable view for the Power BI dashboard's churn-by-segment page.
CREATE VIEW vw_churn_summary AS
SELECT
    Contract,
    InternetService,
    COUNT(*) AS customers,
    ROUND(100.0 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM customers
GROUP BY Contract, InternetService;

-- Usage:
SELECT * FROM vw_churn_summary ORDER BY churn_rate_pct DESC;

-- ================================================================
-- SECTION 7: DATE-STYLE / TENURE-BASED FUNCTIONS
-- ================================================================
-- Note: raw dataset has no signup date column, only tenure in months.
-- In production this would come from DATEDIFF(CURRENT_DATE, signup_date).

-- Q21. Bucket customers into tenure cohorts (equivalent of a date-trunc report).
SELECT
    CASE
        WHEN tenure <= 12 THEN '0-1 yr'
        WHEN tenure <= 24 THEN '1-2 yr'
        WHEN tenure <= 48 THEN '2-4 yr'
        ELSE '4+ yr'
    END AS tenure_cohort,
    COUNT(*) AS customers,
    ROUND(100.0 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM customers
GROUP BY tenure_cohort
ORDER BY MIN(tenure);

-- ================================================================
-- SECTION 8: ADVANCED BUSINESS QUERIES (multi-concept, executive-level)
-- ================================================================

-- Q22. Top 3 churn-driving factors ranked by "churn lift"
-- (churn rate within group vs overall churn rate).
-- Business scenario: This is the exact query a Head of Analytics would
-- run to prep for a board presentation on churn root causes.
WITH baseline AS (
    SELECT ROUND(100.0 * SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END)/COUNT(*),2) AS overall_rate
    FROM customers
)
SELECT
    'No Tech Support' AS risk_factor,
    ROUND(100.0*SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END)/COUNT(*),2) AS segment_churn_rate,
    (SELECT overall_rate FROM baseline) AS overall_churn_rate,
    ROUND(ROUND(100.0*SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END)/COUNT(*),2) - (SELECT overall_rate FROM baseline),2) AS churn_lift_pct
FROM customers WHERE TechSupport = 'No'
UNION ALL
SELECT
    'Fiber Optic Internet',
    ROUND(100.0*SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END)/COUNT(*),2),
    (SELECT overall_rate FROM baseline),
    ROUND(ROUND(100.0*SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END)/COUNT(*),2) - (SELECT overall_rate FROM baseline),2)
FROM customers WHERE InternetService = 'Fiber optic'
UNION ALL
SELECT
    'Electronic Check Payment',
    ROUND(100.0*SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END)/COUNT(*),2),
    (SELECT overall_rate FROM baseline),
    ROUND(ROUND(100.0*SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END)/COUNT(*),2) - (SELECT overall_rate FROM baseline),2)
FROM customers WHERE PaymentMethod = 'Electronic check'
ORDER BY churn_lift_pct DESC;

-- Q23. Customer Lifetime Value proxy and churn risk in one view, ranked
-- by "value at risk" — the single most useful query for a retention team's
-- daily worklist.
SELECT
    customerID,
    Contract,
    tenure,
    MonthlyCharges,
    ROUND(MonthlyCharges * tenure, 2) AS lifetime_value_to_date,
    CASE WHEN Contract='Month-to-month' AND TechSupport='No' AND tenure < 12
         THEN 'High Risk' ELSE 'Lower Risk' END AS churn_risk_flag
FROM customers
WHERE Churn = 'No'
ORDER BY lifetime_value_to_date DESC, churn_risk_flag DESC
LIMIT 25;

-- Q24. Cohort retention-style query: of customers who started with Fiber
-- optic + Month-to-month (the highest-risk combination), what % survive
-- past each tenure milestone?
SELECT
    tenure,
    COUNT(*) AS customers_remaining
FROM customers
WHERE InternetService = 'Fiber optic' AND Contract = 'Month-to-month'
GROUP BY tenure
ORDER BY tenure;

-- ================================================================
-- SECTION 9: PERFORMANCE / OPTIMIZATION NOTES (interview talking points)
-- ================================================================
-- 1. Index Contract, Churn, and tenure (see 01_schema.sql) since they're
--    the most-filtered/grouped columns in this workload.
-- 2. Avoid SELECT * in production dashboards feeding Power BI — pull only
--    the columns the visual needs to cut refresh time.
-- 3. Materialize vw_churn_summary as a table (not a live view) if the
--    dashboard refreshes hourly against a large fact table — trades
--    storage for query speed.
-- 4. For the CASE WHEN churn-lift query (Q22), pre-aggregate segment
--    flags into columns at ETL time rather than computing them at query
--    time if this becomes a frequently-run report.
