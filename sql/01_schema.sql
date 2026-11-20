-- Candidate Intake & AI Scoring – PostgreSQL schema (tested on Neon, PostgreSQL 17)

CREATE TABLE vacancies (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  client TEXT,
  required_skills TEXT,
  nice_to_have TEXT,
  min_years NUMERIC(3,1),
  languages TEXT,
  salary_max_eur INTEGER,
  status TEXT DEFAULT 'open',
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE candidates (
  id SERIAL PRIMARY KEY,
  full_name TEXT NOT NULL,
  email TEXT UNIQUE,                       -- duplicate protection (email is normalized in n8n)
  skills TEXT,
  years_experience NUMERIC(3,1),
  languages TEXT,
  salary_expectation_eur INTEGER,
  source TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE applications (
  id SERIAL PRIMARY KEY,
  candidate_id INTEGER NOT NULL REFERENCES candidates(id),
  vacancy_id   INTEGER NOT NULL REFERENCES vacancies(id),
  ai_score INTEGER CHECK (ai_score BETWEEN 0 AND 100),   -- the database rejects impossible AI scores
  ai_reasons TEXT,
  status TEXT DEFAULT 'new',                            -- the recruiter, not the AI, changes the status
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE (candidate_id, vacancy_id)
);

-- Recruiter report: strong candidates that are not rejected, with a budget check
CREATE VIEW recruiter_shortlist AS
SELECT
  v.title       AS vacancy,
  c.full_name   AS candidate,
  c.email,
  c.languages,
  c.salary_expectation_eur AS salary_eur,
  v.salary_max_eur,
  a.ai_score,
  a.ai_reasons,
  a.status,
  CASE
    WHEN c.salary_expectation_eur IS NULL THEN 'unknown'
    WHEN c.salary_expectation_eur <= v.salary_max_eur THEN 'yes'
    ELSE 'no'
  END AS fits_budget
FROM applications a
JOIN candidates c ON c.id = a.candidate_id
JOIN vacancies  v ON v.id = a.vacancy_id
WHERE a.ai_score >= 70
  AND a.status <> 'rejected';
