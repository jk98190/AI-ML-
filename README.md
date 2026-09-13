# Multi-Dataset Synthesis: AI Job Impact, RAG Hallucination Benchmark & Tech Salaries

> Repo description (GitHub "About" field):
> Synthesis + exploratory analytics on three independent datasets — AI automation risk by job role, LLM RAG hallucination benchmarking, and tech salary data — with per-file and combined tidy CSV outputs, correlation analysis, and a reproducible Jupyter notebook.

## Data

| File | Rows | Grain |
|---|---|---|
| `AI_Impact_on_Jobs_2030.csv` | 3,000 | one row per job role |
| `RAG_Context_Adherence_And_Hallucination_Benchmark.csv` | 30,000 | one row per LLM interaction |
| `salaries.csv` | 73,148 | one row per employee/salary record |

The three files share no join key, so each is analyzed independently rather than merged.

## Methodology

1. **Per-file synthesis** — groupby aggregation on each dataset's most informative categorical dimensions (table below), producing count, mean, and rate metrics per group.
2. **Combine step** — all three per-file summaries are melted into one long-format table (`source_file, group, metric, value`) so incompatible schemas can live in a single downloadable CSV without inventing shared columns.
3. **Correlation analysis** — Pearson correlation matrix computed on each file's numeric columns, to surface linear relationships between metrics within that file.

| File | Group by | Metrics |
|---|---|---|
| Jobs | Risk_Category × Education_Level | avg salary, avg automation probability, avg AI exposure index |
| RAG benchmark | LLM_Model_Name × Hallucination_Type | hallucination rate, avg context faithfulness, avg answer relevance |
| Salaries | work_year × experience_level × company_size | avg salary (USD), avg remote ratio |

## Correlation analysis

Run separately per file (numeric columns only, Pearson):

- **Jobs** — `AI_Exposure_Index`, `Tech_Growth_Factor`, `Automation_Probability_2030`, `Average_Salary`, `Years_Experience`, `Skill_1..10`. Checks e.g. whether AI exposure tracks automation probability, and whether either correlates with salary.
- **RAG benchmark** — `Vector_DB_Similarity_Score`, `Context_Response_Overlap_Ratio`, `Entity_Match_Score`, `Contradiction_Words_Count`, `Answer_Relevance_Score`, `Context_Faithfulness_Score`, `Is_Hallucination`, `Temperature_Setting`. Checks e.g. whether low context-faithfulness/entity-match correlates with `Is_Hallucination`, and whether temperature setting correlates with hallucination rate.
- **Salaries** — `salary_in_usd`, `remote_ratio`, `work_year`. Checks e.g. whether remote ratio correlates with salary.

## Types of analytics performed

- **Descriptive statistics** — `.describe()` (mean, std, quartiles) per numeric column, per file.
- **Aggregation / groupby** — category-level rollups (table above).
- **Correlation analysis** — numeric-numeric Pearson matrices per file (see above).
- **Rate analysis** — hallucination rate and remote-work ratio as proportions within groups.
- **Distribution comparison** — metric spread compared across categories (risk category, model, seniority).

Not performed (candidate extensions, not in scope here): cross-file joins (no shared key), time-series forecasting, causal inference.

## Outputs

- `jobs_synthesis.csv`, `rag_synthesis.csv`, `salaries_synthesis.csv` — per-file group summaries (wide format).
- `combined_synthesis.csv` — all three stacked (long format: `source_file, group, metric, value`).
- `file_synthesis.ipynb` — notebook that generates all of the above end-to-end, plus the correlation matrices.
- `METHODOLOGY.md` — detailed write-up of what was computed and why.

## Usage

```bash
pip install pandas
jupyter notebook file_synthesis.ipynb
```

Run all cells top to bottom; each dataset's section is self-contained and writes its own CSV, and the final cell writes the combined CSV.
