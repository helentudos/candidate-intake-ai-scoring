-- 1. Applications with candidate and vacancy names, best first within each vacancy
SELECT v.title AS vacancy, c.full_name AS candidate, a.ai_score, a.status
FROM applications a
JOIN candidates c ON c.id = a.candidate_id
JOIN vacancies  v ON v.id = a.vacancy_id
ORDER BY v.title, a.ai_score DESC;

-- 2. Funnel per vacancy
SELECT
  v.title AS vacancy,
  COUNT(*) AS applications,
  ROUND(AVG(a.ai_score)) AS avg_score,
  COUNT(*) FILTER (WHERE a.status IN ('shortlist','interview')) AS shortlisted,
  MAX(a.ai_score) AS best_score
FROM applications a
JOIN vacancies v ON v.id = a.vacancy_id
GROUP BY v.title
ORDER BY applications DESC;

-- 3. Recruiter shortlist
SELECT * FROM recruiter_shortlist ORDER BY ai_score DESC;
