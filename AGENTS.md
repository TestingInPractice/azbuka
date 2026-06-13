# Игра "Азбука" — CodeAI Build Loop

Build Loop project. Orchestrator only manages state and delegates to sub-agents.

## Workflow (Ralph Loop)

1. Read `docs/specs/` — understand goals, contracts, acceptance criteria
2. Run decompose.sh to generate phases.json
3. Execute Ralph Loop for each pending phase:
   a. `bash scripts/build-loop/next-phase.sh --project .`
   b. `bash scripts/build-loop/run-loop.sh --project . --phase <id> --print-prompt`
   c. Delegate to sub-agent via task()
   d. Judge: `bash scripts/build-loop/run-loop.sh --project . --judge --phase <id> --summary /tmp/p<id>-summary.txt`
   e. If FAIL → re-delegate with feedback
   f. If PASS → git commit + mark-complete
4. Report summary when all phases complete

## Constraints
- NEVER implement phases directly. Always delegate via task().
- Source of truth: docs/specs/
