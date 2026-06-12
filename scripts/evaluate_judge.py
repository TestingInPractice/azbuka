#!/usr/bin/env python3
"""
evaluate_judge.py — гибридный судья (structural + AI prompt).

Режимы:
  --check     : структурная проверка + генерация AI prompt для судьи
  --apply     : запись verdict в state.json

Structural: F-XXX → задачи, AC completeness, open questions.
AI prompt: rubric + IEEE 29148 критерии для семантической оценки.
"""

import json, os, sys, argparse

def load_json(path):
    with open(path) as f:
        return json.load(f)

def read_file(path):
    with open(path) as f:
        return f.read()

def structural_check_analyst(spec_text, tasks_dir, rubric):
    errors = []
    f_ids = set()

    for m in __import__("re").finditer(r"F-\d+", spec_text):
        f_ids.add(m.group(0))

    task_files = []
    if os.path.isdir(tasks_dir):
        task_files = [f for f in os.listdir(tasks_dir) if f.endswith(".md")]

    covered = set()
    for tf in task_files:
        content = read_file(os.path.join(tasks_dir, tf))
        for m in __import__("re").finditer(r"F-\d+", content):
            covered.add(m.group(0))

    missing = f_ids - covered
    if missing:
        errors.append(f"requirements_coverage: F-XXX без задач: {', '.join(sorted(missing))}")

    tasks_no_ac = 0
    for tf in task_files:
        content = read_file(os.path.join(tasks_dir, tf))
        if "- [ ] AC-" not in content:
            tasks_no_ac += 1
    if tasks_no_ac:
        errors.append(f"acceptance_criteria: {tasks_no_ac} задач без AC")

    return errors, sorted(f_ids), len(task_files)

def structural_check_developer(spec_text, state):
    errors = []
    dev = state.get("implement_spec_stage", {})
    tasks = dev.get("tasks", [])
    completed = sum(1 for t in tasks if t.get("status") == "completed")
    total = len(tasks)
    if total > 0 and completed < total:
        errors.append(f"tasks_not_all_completed: {completed}/{total}")
    for t in tasks:
        if t.get("status") == "completed" and not t.get("judge_verdict"):
            errors.append(f"task_no_verdict: {t.get('title')}")
    return errors

def structural_check_tester(spec_text, state):
    errors = []
    wt = state.get("write_tests", {})
    cases = wt.get("test_cases", [])
    f_ids = set(__import__("re").findall(r"F-\d+", spec_text))
    covered = set()
    for c in cases:
        ref = c.get("ref_issue", "")
        for m in __import__("re").finditer(r"F-\d+", ref):
            covered.add(m.group(0))
    missing = f_ids - covered
    if missing:
        errors.append(f"ac_coverage: F-XXX без тест-кейсов: {', '.join(sorted(missing))}")
    return errors

def build_ai_prompt(role, rubric, f_ids, task_count, errors):
    ieee_29148 = [
        ("Necessary", "Требование необходимо? Если убрать — ТЗ потеряет ценность?"),
        ("Implementation-free", "Требование не предписывает способ реализации? (Что, а не Как)"),
        ("Unambiguous", "Требование однозначно? Разработчик и агент поймут одинаково?"),
        ("Complete", "Детальность достаточна для текущего этапа?"),
        ("Atomic", "Требование можно проверить отдельно?"),
        ("Verifiable", "Есть acceptance criteria? Результат проверяем?"),
        ("Traceable", "Есть ID (F-XXX) и traceability до цели?"),
    ]

    prompt = f"""Ты — судья в роли {role}. Оцени качество артефактов по rubric.

Rubric критерии:
"""
    for c in rubric.get("rubric", []):
        prompt += f"\n- **{c['id']}**: {c['label']} (weight={c['weight']}, critical={'ДА' if c['critical'] else 'НЕТ'})"

    prompt += f"""

IEEE 29148 критерии (примени к каждому F-XXX):
"""
    for name, desc in ieee_29148:
        prompt += f"\n- **{name}**: {desc}"

    prompt += f"""

Контекст:
- F-XXX найдено в spec: {len(f_ids)}
- Задач создано: {task_count}
- Structural errors: {errors if errors else 'Нет'}

Формат ответа строго:

```
VERDICT: <PASS|FAIL|PASS_WITH_CONCERNS>
SCORE: <0.0-1.0>
CRITICAL_FAILURES: <int>
SUMMARY: <главный вывод в 1 строку>
DETAILS:
  - criterion_id: score/5 — evidence
  - criterion_id: score/5 — evidence
```
"""
    return prompt

def cmd_prepare(args):
    rubric = load_json(args.rubric)
    spec_text = read_file(args.spec) if os.path.exists(args.spec) else ""
    role = rubric.get("name", "analyst")

    if role == "analyst":
        errors, f_ids, task_count = structural_check_analyst(spec_text, args.tasks_dir, rubric)
    elif role == "developer":
        state = load_json(args.state) if args.state else {}
        errors = structural_check_developer(spec_text, state)
        f_ids = []
        task_count = len(state.get("implement_spec_stage", {}).get("tasks", []))
    elif role == "tester":
        state = load_json(args.state) if args.state else {}
        errors = structural_check_tester(spec_text, state)
        f_ids = []
        task_count = len(state.get("write_tests", {}).get("test_cases", []))
    else:
        errors, f_ids, task_count = [], [], 0

    ai_prompt = build_ai_prompt(role, rubric, f_ids, task_count, errors)

    result = {
        "structural_ok": len(errors) == 0,
        "ai_prompt": ai_prompt if len(errors) == 0 else None,
        "errors": errors,
        "f_ids_count": len(f_ids),
        "task_count": task_count,
    }

    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0 if len(errors) == 0 else 1

def cmd_apply(args):
    state = load_json(args.state)
    section_key = state["phase"].replace("-", "_")
    section = state.get(section_key, {})

    section["judge_verdict"] = args.verdict

    from transition import acquire_lock, release_lock, write_json_atomic
    fd = acquire_lock(args.state)
    try:
        state[section_key] = section
        write_json_atomic(args.state, state)
        print(json.dumps({"status": "ok", "verdict": args.verdict}))
    finally:
        release_lock(fd, args.state + ".lock")

    return 0

if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Build Loop Judge")
    sub = p.add_subparsers(dest="mode", required=True)

    prep = sub.add_parser("prepare", help="Structural check + AI prompt")
    prep.add_argument("--rubric", required=True)
    prep.add_argument("--spec", default="")
    prep.add_argument("--tasks-dir", default="")
    prep.add_argument("--state", default="")

    app = sub.add_parser("apply", help="Write verdict to state.json")
    app.add_argument("--state", required=True)
    app.add_argument("--verdict", required=True, choices=["passed", "failed", "passed_with_concerns"])

    args = p.parse_args()
    sys.exit(cmd_prepare(args) if args.mode == "prepare" else cmd_apply(args))
