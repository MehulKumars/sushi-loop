# Sushi Loop levels (gen_version 2)

1000 levels. Pass = 0.6 x careful + 0.4 x greedy: a rough first-try pass rate for a typical player.

## By role

| Role | Levels | Greedy | Careful | Pass | Tries (1/pass) | Missed band |
|---|---|---|---|---|---|---|
| easy | 141 | 0.85 | 0.98 | 0.93 | 1.1 | 4 |
| medium | 369 | 0.56 | 0.94 | 0.78 | 1.3 | 0 |
| hard | 190 | 0.18 | 0.82 | 0.57 | 1.8 | 2 |
| super | 100 | 0.03 | 0.69 | 0.42 | 2.4 | 0 |
| rest | 200 | 0.88 | 0.99 | 0.95 | 1.1 | 0 |

## By hundred

| Levels | Pass (all) | Pass (no rest) | Hardest pass | Plates (avg) | Hard + super |
|---|---|---|---|---|---|
| 1-100 | 0.81 | 0.77 | 0.35 | 20.7 | 20 |
| 101-200 | 0.76 | 0.72 | 0.34 | 20.8 | 30 |
| 201-300 | 0.77 | 0.72 | 0.39 | 22.9 | 30 |
| 301-400 | 0.76 | 0.72 | 0.36 | 23.8 | 30 |
| 401-500 | 0.76 | 0.70 | 0.34 | 23.5 | 30 |
| 501-600 | 0.75 | 0.70 | 0.34 | 23.9 | 30 |
| 601-700 | 0.75 | 0.70 | 0.29 | 23.7 | 30 |
| 701-800 | 0.75 | 0.70 | 0.34 | 23.5 | 30 |
| 801-900 | 0.75 | 0.70 | 0.28 | 23.9 | 30 |
| 901-1000 | 0.75 | 0.70 | 0.38 | 24.0 | 30 |

## Missed bands (6)

- L282 easy: greedy 0.80, careful 0.94, par 6
- L291 easy: greedy 0.78, careful 0.94, par 6
- L431 easy: greedy 0.74, careful 0.99, par 4
- L601 easy: greedy 0.75, careful 0.93, par 7
- L605 hard: greedy 0.10, careful 0.80, par 3
- L608 hard: greedy 0.13, careful 0.85, par 5

Reskin check: greedy wins 31% of mid-chapter runs on average (keep it under 90%).
