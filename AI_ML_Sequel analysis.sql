/* =====================================================================
   PROJECT_3 — CROSS-DATASET SQL ANALYSIS
   Tables:
     Project_3.jobs_synthesis      (AI automation risk vs. education/salary)
     Project_3.salaries_synthesis  (tech salaries by year/experience/company size)
     Project_3.rag_synthesis       (LLM hallucination rates by model/type)

   NOTE: All three source tables are already GROUPED summaries (each row
   carries a group key + n + pre-computed averages), not raw record-level
   data. Because there is no common key across the three tables, they are
   analyzed independently below, each covering:
     1. Descriptive statistics
     2. Aggregation / GROUP BY
     3. Correlation analysis (weighted, since we only have group means)
     4. Rate analysis
     5. Distribution comparison
   Syntax: MySQL 8+ (window functions, CTEs). Adjust STDDEV_SAMP/VAR_SAMP
   naming if porting to Postgres/SQL Server.
   ===================================================================== */


/* =====================================================================
   1. JOBS_SYNTHESIS — AI Automation Risk vs Education/Salary/Exposure
   ===================================================================== */

-- 1.1 Descriptive statistics (overall, weighted by n since each row is a group avg)
SELECT
    SUM(n)                                                        AS total_records,
    ROUND(SUM(avg_salary * n) / SUM(n), 2)                        AS weighted_mean_salary,
    ROUND(SQRT(SUM(n * POWER(avg_salary - (SELECT SUM(avg_salary*n)/SUM(n) FROM Project_3.jobs_synthesis), 2)) / SUM(n)), 2) AS weighted_stddev_salary,
    ROUND(MIN(avg_salary), 2)                                     AS min_group_salary,
    ROUND(MAX(avg_salary), 2)                                     AS max_group_salary,
    ROUND(SUM(avg_automation_prob * n) / SUM(n), 4)               AS weighted_mean_automation_prob,
    ROUND(SUM(avg_ai_exposure * n) / SUM(n), 4)                   AS weighted_mean_ai_exposure
FROM Project_3.jobs_synthesis;

-- 1.2 Aggregation / GROUP BY — by Risk_Category
SELECT
    Risk_Category,
    SUM(n)                                            AS total_n,
    ROUND(SUM(avg_salary * n) / SUM(n), 2)            AS weighted_avg_salary,
    ROUND(SUM(avg_automation_prob * n) / SUM(n), 4)   AS weighted_avg_automation_prob,
    ROUND(SUM(avg_ai_exposure * n) / SUM(n), 4)       AS weighted_avg_ai_exposure
FROM Project_3.jobs_synthesis
GROUP BY Risk_Category
ORDER BY weighted_avg_automation_prob DESC;

-- 1.3 Aggregation / GROUP BY — by Education_Level
SELECT
    Education_Level,
    SUM(n)                                            AS total_n,
    ROUND(SUM(avg_salary * n) / SUM(n), 2)            AS weighted_avg_salary,
    ROUND(SUM(avg_automation_prob * n) / SUM(n), 4)   AS weighted_avg_automation_prob
FROM Project_3.jobs_synthesis
GROUP BY Education_Level
ORDER BY weighted_avg_salary DESC;

-- 1.4 Correlation analysis — weighted Pearson r between automation probability and salary
--     (grouped observations weighted by their n, using standard weighted covariance formula)
WITH stats AS (
    SELECT
        SUM(n)                                           AS N,
        SUM(avg_automation_prob * n) / SUM(n)             AS mean_x,
        SUM(avg_salary * n) / SUM(n)                      AS mean_y
    FROM Project_3.jobs_synthesis
)
SELECT
    ROUND(
        SUM(j.n * (j.avg_automation_prob - s.mean_x) * (j.avg_salary - s.mean_y))
        /
        ( SQRT(SUM(j.n * POWER(j.avg_automation_prob - s.mean_x, 2)))
          * SQRT(SUM(j.n * POWER(j.avg_salary - s.mean_y, 2))) )
    , 4) AS weighted_corr_automation_prob_vs_salary
FROM Project_3.jobs_synthesis j
CROSS JOIN stats s;

-- 1.5 Rate analysis — automation probability as a "risk rate" by category and education
SELECT
    Risk_Category,
    Education_Level,
    ROUND(avg_automation_prob * 100, 2)  AS automation_risk_rate_pct,
    ROUND(avg_ai_exposure * 100, 2)      AS ai_exposure_rate_pct
FROM Project_3.jobs_synthesis
ORDER BY automation_risk_rate_pct DESC;

-- 1.6 Distribution comparison — salary spread across Risk_Category (min/max/range of group means)
SELECT
    Risk_Category,
    COUNT(*)                                    AS n_groups,
    ROUND(MIN(avg_salary), 2)                   AS min_salary,
    ROUND(MAX(avg_salary), 2)                   AS max_salary,
    ROUND(MAX(avg_salary) - MIN(avg_salary), 2) AS salary_range,
    ROUND(AVG(avg_salary), 2)                   AS unweighted_avg_salary
FROM Project_3.jobs_synthesis
GROUP BY Risk_Category
ORDER BY Risk_Category;

/* =====================================================================
   2. SALARIES_SYNTHESIS — Tech Salaries by Year / Experience / Company Size
   ===================================================================== */

-- 2.1 Descriptive statistics (overall, weighted by n)
SELECT
    SUM(n)                                                        AS total_records,
    ROUND(SUM(avg_salary_usd * n) / SUM(n), 2)                    AS weighted_mean_salary,
    ROUND(SQRT(SUM(n * POWER(avg_salary_usd - (SELECT SUM(avg_salary_usd*n)/SUM(n) FROM Project_3.salaries_synthesis), 2)) / SUM(n)), 2) AS weighted_stddev_salary,
    ROUND(MIN(avg_salary_usd), 2)                                 AS min_group_salary,
    ROUND(MAX(avg_salary_usd), 2)                                 AS max_group_salary,
    ROUND(SUM(avg_remote_ratio * n) / SUM(n), 2)                  AS weighted_mean_remote_ratio
FROM Project_3.salaries_synthesis;

-- 2.2 Aggregation / GROUP BY — by work_year
SELECT
    work_year,
    SUM(n)                                             AS total_n,
    ROUND(SUM(avg_salary_usd * n) / SUM(n), 2)         AS weighted_avg_salary,
    ROUND(SUM(avg_remote_ratio * n) / SUM(n), 2)       AS weighted_avg_remote_ratio
FROM Project_3.salaries_synthesis
GROUP BY work_year
ORDER BY work_year;

-- 2.3 Aggregation / GROUP BY — by experience_level and company_size
SELECT
    experience_level,
    company_size,
    SUM(n)                                             AS total_n,
    ROUND(SUM(avg_salary_usd * n) / SUM(n), 2)         AS weighted_avg_salary
FROM Project_3.salaries_synthesis
GROUP BY experience_level, company_size
ORDER BY weighted_avg_salary DESC;

-- 2.4 Correlation analysis — weighted Pearson r between remote ratio and salary
WITH stats AS (
    SELECT
        SUM(avg_remote_ratio * n) / SUM(n)  AS mean_x,
        SUM(avg_salary_usd * n) / SUM(n)    AS mean_y
    FROM Project_3.salaries_synthesis
)
SELECT
    ROUND(
        SUM(sal.n * (sal.avg_remote_ratio - s.mean_x) * (sal.avg_salary_usd - s.mean_y))
        /
        ( SQRT(SUM(sal.n * POWER(sal.avg_remote_ratio - s.mean_x, 2)))
          * SQRT(SUM(sal.n * POWER(sal.avg_salary_usd - s.mean_y, 2))) )
    , 4) AS weighted_corr_remote_ratio_vs_salary
FROM Project_3.salaries_synthesis sal
CROSS JOIN stats s;

-- 2.5 Correlation analysis — weighted Pearson r between work_year and salary (salary growth trend)
WITH stats AS (
    SELECT
        SUM(work_year * n) / SUM(n)         AS mean_x,
        SUM(avg_salary_usd * n) / SUM(n)    AS mean_y
    FROM Project_3.salaries_synthesis
)
SELECT
    ROUND(
        SUM(sal.n * (sal.work_year - s.mean_x) * (sal.avg_salary_usd - s.mean_y))
        /
        ( SQRT(SUM(sal.n * POWER(sal.work_year - s.mean_x, 2)))
          * SQRT(SUM(sal.n * POWER(sal.avg_salary_usd - s.mean_y, 2))) )
    , 4) AS weighted_corr_year_vs_salary
FROM Project_3.salaries_synthesis sal
CROSS JOIN stats s;

-- 2.6 Rate analysis — year-over-year salary growth rate (%) by experience_level
WITH yearly AS (
    SELECT
        work_year,
        experience_level,
        SUM(n)                                     AS total_n,
        SUM(avg_salary_usd * n) / SUM(n)            AS weighted_avg_salary
    FROM Project_3.salaries_synthesis
    GROUP BY work_year, experience_level
)
SELECT
    work_year,
    experience_level,
    ROUND(weighted_avg_salary, 2) AS avg_salary,
    ROUND(
        (weighted_avg_salary - LAG(weighted_avg_salary) OVER (PARTITION BY experience_level ORDER BY work_year))
        / LAG(weighted_avg_salary) OVER (PARTITION BY experience_level ORDER BY work_year) * 100
    , 2) AS yoy_growth_rate_pct
FROM yearly
ORDER BY experience_level, work_year;

-- 2.7 Rate analysis — remote-work adoption rate by year
SELECT
    work_year,
    ROUND(SUM(avg_remote_ratio * n) / SUM(n), 2) AS weighted_avg_remote_ratio_pct
FROM Project_3.salaries_synthesis
GROUP BY work_year
ORDER BY work_year;

-- 2.8 Distribution comparison — salary spread across company_size
SELECT
    company_size,
    SUM(n)                          AS total_n,
    ROUND(MIN(avg_salary_usd), 2)   AS min_group_salary,
    ROUND(MAX(avg_salary_usd), 2)   AS max_group_salary,
    ROUND(AVG(avg_salary_usd), 2)   AS unweighted_avg_salary,
    ROUND(SUM(avg_salary_usd * n) / SUM(n), 2) AS weighted_avg_salary
FROM Project_3.salaries_synthesis
GROUP BY company_size;

-- 2.9 Distribution comparison — salary spread across experience_level
SELECT
    experience_level,
    SUM(n)                          AS total_n,
    ROUND(MIN(avg_salary_usd), 2)   AS min_group_salary,
    ROUND(MAX(avg_salary_usd), 2)   AS max_group_salary,
    ROUND(SUM(avg_salary_usd * n) / SUM(n), 2) AS weighted_avg_salary
FROM Project_3.salaries_synthesis
GROUP BY experience_level
ORDER BY weighted_avg_salary DESC;


/* =====================================================================
   3. RAG_SYNTHESIS — LLM Hallucination Behaviour by Model / Type
   ===================================================================== */

-- 3.1 Descriptive statistics (overall, weighted by n)
SELECT
    SUM(n)                                                                AS total_records,
    ROUND(SUM(avg_context_faithfulness * n) / SUM(n), 4)                  AS weighted_mean_faithfulness,
    ROUND(SUM(avg_answer_relevance * n) / SUM(n), 4)                      AS weighted_mean_relevance,
    ROUND(MIN(avg_context_faithfulness), 4)                               AS min_faithfulness,
    ROUND(MAX(avg_context_faithfulness), 4)                               AS max_faithfulness
FROM Project_3.rag_synthesis;

-- 3.2 Aggregation / GROUP BY — by LLM_Model_Name
SELECT
    LLM_Model_Name,
    SUM(n)                                                 AS total_n,
    ROUND(SUM(avg_context_faithfulness * n) / SUM(n), 4)   AS weighted_avg_faithfulness,
    ROUND(SUM(avg_answer_relevance * n) / SUM(n), 4)       AS weighted_avg_relevance
FROM Project_3.rag_synthesis
GROUP BY LLM_Model_Name
ORDER BY weighted_avg_faithfulness DESC;

-- 3.3 Aggregation / GROUP BY — by Hallucination_Type
SELECT
    Hallucination_Type,
    SUM(n)                                                 AS total_n,
    ROUND(SUM(avg_context_faithfulness * n) / SUM(n), 4)   AS weighted_avg_faithfulness,
    ROUND(SUM(avg_answer_relevance * n) / SUM(n), 4)       AS weighted_avg_relevance
FROM Project_3.rag_synthesis
GROUP BY Hallucination_Type
ORDER BY weighted_avg_relevance DESC;

-- 3.4 Correlation analysis — weighted Pearson r between context faithfulness and answer relevance
WITH stats AS (
    SELECT
        SUM(avg_context_faithfulness * n) / SUM(n)  AS mean_x,
        SUM(avg_answer_relevance * n) / SUM(n)      AS mean_y
    FROM Project_3.rag_synthesis
)
SELECT
    ROUND(
        SUM(r.n * (r.avg_context_faithfulness - s.mean_x) * (r.avg_answer_relevance - s.mean_y))
        /
        ( SQRT(SUM(r.n * POWER(r.avg_context_faithfulness - s.mean_x, 2)))
          * SQRT(SUM(r.n * POWER(r.avg_answer_relevance - s.mean_y, 2))) )
    , 4) AS weighted_corr_faithfulness_vs_relevance
FROM Project_3.rag_synthesis r
CROSS JOIN stats s;

-- 3.5 Rate analysis — hallucination rate & sample share by model and type
SELECT
    LLM_Model_Name,
    Hallucination_Type,
    n,
    ROUND(hallucination_rate * 100, 2) AS hallucination_rate_pct,
    ROUND(100.0 * n / SUM(n) OVER (PARTITION BY LLM_Model_Name), 2) AS pct_of_model_samples
FROM Project_3.rag_synthesis
ORDER BY LLM_Model_Name, pct_of_model_samples DESC;

-- 3.6 Distribution comparison — faithfulness/relevance spread across models
SELECT
    LLM_Model_Name,
    ROUND(MIN(avg_context_faithfulness), 4) AS min_faithfulness,
    ROUND(MAX(avg_context_faithfulness), 4) AS max_faithfulness,
    ROUND(MAX(avg_context_faithfulness) - MIN(avg_context_faithfulness), 4) AS faithfulness_range,
    ROUND(MIN(avg_answer_relevance), 4)     AS min_relevance,
    ROUND(MAX(avg_answer_relevance), 4)     AS max_relevance,
    ROUND(MAX(avg_answer_relevance) - MIN(avg_answer_relevance), 4) AS relevance_range
FROM Project_3.rag_synthesis
GROUP BY LLM_Model_Name
ORDER BY faithfulness_range DESC;

-- 3.7 Distribution comparison — faithfulness/relevance spread across hallucination types
SELECT
    Hallucination_Type,
    ROUND(AVG(avg_context_faithfulness), 4) AS avg_faithfulness_across_models,
    ROUND(STDDEV_SAMP(avg_context_faithfulness), 4) AS stddev_faithfulness_across_models,
    ROUND(AVG(avg_answer_relevance), 4)     AS avg_relevance_across_models,
    ROUND(STDDEV_SAMP(avg_answer_relevance), 4) AS stddev_relevance_across_models
FROM Project_3.rag_synthesis
GROUP BY Hallucination_Type
ORDER BY avg_relevance_across_models DESC;