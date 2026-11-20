# Candidate Intake & AI Scoring

An n8n workflow for a recruitment agency: a candidate submits a CV as free text, an LLM extracts structured data, the candidate is saved to PostgreSQL without duplicates, a second LLM step scores the fit to the vacancy (0–100 with reasons), and the recruiter gets a Telegram message only about strong candidates. Every failure triggers an alert.

The AI sorts and explains. **The recruiter makes every decision.**

> Demo project built and tested in November 2026. All candidates, companies and vacancies are fictional.

## How it works

```
Candidate Form (n8n Form Trigger)
  → Extract Candidate Data   LLM (gpt-4.1-mini, temp 0) + JSON Schema output, null when data is missing
  → Normalize Candidate      JavaScript: email trim + lowercase, lists → text, fallbacks from the form
  → Upsert Candidate         PostgreSQL: INSERT … ON CONFLICT (email) DO UPDATE, parameterized query
  → Get Vacancy              PostgreSQL: requirements, nice-to-have, minimum experience
  → Score Candidate          LLM: rubric-based score 0–100, 2–3 reasons, missing requirements
  → Save Application         PostgreSQL: upsert by (candidate, vacancy), CHECK score 0–100
  → Is Strong Candidate?     score ≥ 70 (same threshold as the shortlist view)
  → Build Recruiter Message  JavaScript: HTML-escaped Telegram message
  → Notify Recruiter         Telegram

Error Handler (separate workflow)
  Error Trigger → Build Error Message (HTML-escaped) → Telegram alert: workflow, node, error, execution link
```

## Stack

| Part | Choice | Why |
|---|---|---|
| Orchestration | n8n (self-hosted, Node.js) | fast to build, easy for the team to follow |
| Database | PostgreSQL on Neon (EU region) | real Postgres, constraints and views |
| Extraction | gpt-4.1-mini, temperature 0, JSON Schema | cheap model for a simple task, stable output |
| Scoring | gpt-4.1-mini with an explicit rubric | transparent score; a stronger model only if tests show the need |
| Glue code | JavaScript in Code nodes | normalization, message building, escaping |
| Notifications | Telegram | recruiter sees strong candidates in seconds |

## Data model

- `vacancies` – requirements, nice-to-have skills, minimum experience, budget
- `candidates` – one row per person, `email UNIQUE`
- `applications` – candidate × vacancy, AI score and reasons, status; foreign keys, `CHECK (ai_score BETWEEN 0 AND 100)`, `UNIQUE (candidate_id, vacancy_id)`
- `recruiter_shortlist` (view) – candidates with score ≥ 70, not rejected, with `fits_budget` = yes / no / unknown

SQL files: [`sql/01_schema.sql`](sql/01_schema.sql), [`sql/02_sample_data.sql`](sql/02_sample_data.sql), [`sql/03_reporting_queries.sql`](sql/03_reporting_queries.sql).

## Scoring rubric

| Criterion | Points |
|---|---|
| Required skills (synonyms count, e.g. "card payment flows" = payments) | up to 40 |
| Experience vs the vacancy minimum | 0–5 below, 10 at minimum, 20 at minimum + 2 years |
| Nice-to-have skills | up to 20 |
| Languages | 0–5 below, 15 meets, 20 clearly exceeds |
| Salary | not scored – checked by SQL in the view |

Calibration guidance in the prompt: a typical good candidate scores 70–85; 90+ only when all required skills match, experience is well above the minimum and most nice-to-have skills match.

## Testing

16 documented test cases. Six of them found real problems, each fixed and re-tested:

| Test | Problem found | Fix |
|---|---|---|
| T1 | the role ("product management") was not extracted as a skill | prompt rule: include the role / profession |
| T4 | too literal matching ("card payment flows" ≠ "payments") | prompt rule: sub-areas and synonyms count |
| T6 | `\n` shown literally in Telegram | message built in a Code node |
| T6–T10 | every decent candidate scored 100/100 | added minimum experience and nice-to-have skills to vacancies, new rubric, calibration guidance → scores now 95 / 85 / 80 / 70 / 0 in a logical order |
| T9 | workflow crashed when the CV had no salary (parser required a number, model correctly returned null) | JSON Schema with nullable fields |
| T14 | error alert failed: Telegram Markdown broke on `_` in the error text | HTML parse mode + escaping in code |

Other checks: duplicate submission and email in different case → still one candidate; Polish-language CV; nonsense CV → score 0, nothing invented; forced score 150 → rejected by the database `CHECK`, workflow stopped, alert received.

## Results on test data

| Candidate | Score | Notification |
|---|---|---|
| 7 years, all required + most nice-to-have | 95 | yes |
| 5 years vs 3 required, no nice-to-have | 85 | yes |
| exactly the minimum experience | 80 | yes |
| below minimum experience, some nice-to-have | 70 | yes (borderline) |
| unrelated experience | 0 | no |

## Security and privacy

- Database password, API keys and Telegram bot token live only in n8n credentials – never in the workflow JSON or this repository.
- Telegram chat IDs in the exported workflows are replaced with `YOUR_TELEGRAM_CHAT_ID`.
- All queries use parameters (`$1, $2 …`) – CV text never becomes part of an SQL command.
- In a real deployment: candidate consent (GDPR), CV retention period, database access only for the people who need it.

## What I would improve next

- Flag possible duplicates by name + phone / LinkedIn for the recruiter (today deduplication is by email only).
- A "manual review" zone for scores 65–75 instead of a single hard threshold.
- Log tokens and cost per run; try the cheaper model for extraction and a stronger one for scoring only if tests show it helps.
- Intake from email and ATS webhooks, PDF CVs.
- A regression test set that runs before every prompt change.

## How to run

1. Create a PostgreSQL database and run the files in `sql/` in order.
2. Import both workflows from `workflows/` into n8n.
3. Create credentials in n8n: Postgres, OpenAI, Telegram; select them in the nodes.
4. Replace `YOUR_TELEGRAM_CHAT_ID` with your chat ID.
5. In the main workflow settings choose `Error Handler – Candidate Intake` as the error workflow.
6. Publish both workflows and open the form's production URL.

---

Author: Olena Tudos · [LinkedIn](https://www.linkedin.com/in/olena-tudos) · [Portfolio](https://sulky-table-323.notion.site/Elena-Tudos-AI-Automation-Specialist-EN-402760dd1d588192866be307375ff0cc)
