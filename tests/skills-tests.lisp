(in-package #:nilclaw/tests)
(in-suite skills-suite)

(test skills-loader-entrypoint-available
  (is (nilclaw/skills:skills-loader-entrypoint-available-p))
  (is (not (nilclaw/skills:skills-loader-entrypoint-available-p
            (nilclaw/skills:make-skills-runtime :entrypoint "" :enabled t)))))
