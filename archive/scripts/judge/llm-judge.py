#!/usr/bin/env python3
"""LLM-as-a-Judge — оценивает ответ LLM по 3 столпам качества.

Usage:
  # Прямая оценка
  python3 scripts/llm-judge.py --question "..." --response "..." --context "..."

  # Из файлов
  python3 scripts/llm-judge.py --question q.txt --response r.txt --context c.txt

  # Batch mode (каждая строка = один кейс)
  python3 scripts/llm-judge.py --batch cases.jsonl --output results.json

  # Проверка всей папки thesis-файлов
  python3 scripts/llm-judge.py --scan-docs

Основано на фреймворке из видео: youtube.com/watch?v=9MWy0M3Wqx8
Три столпа: Relevance, Faithfulness, Context Precision
"""
import argparse, json, sys, os, re, math

SCORES = {"fail": 0, "poor": 0.25, "partial": 0.5, "good": 0.75, "perfect": 1.0}


def levenshtein(a, b):
    """Normalized edit distance for faithfulness check."""
    if not a and not b: return 1.0
    n, m = len(a), len(b)
    dp = list(range(n + 1))
    for j in range(1, m + 1):
        prev, dp[0] = dp[0], j
        for i in range(1, n + 1):
            tmp = dp[i]
            dp[i] = min(dp[i - 1] + 1, dp[i] + 1, prev + (0 if a[i - 1] == b[j - 1] else 1))
            prev = tmp
    return 1 - dp[n] / max(n, m)


def tokenize(t):
    return set(re.findall(r"\w+", t.lower()))


def score_relevance(question, response):
    """Оценивает, отвечает ли response на question."""
    qw = tokenize(question)
    rw = tokenize(response)

    # Порог: минимум 20% слов вопроса должны быть в ответе
    if not qw: return 0.5, ["?empty question"]
    overlap = len(qw & rw) / len(qw)

    issues = []
    if overlap < 0.2:
        issues.append("response_words_miss_question")
    if len(response.split()) < 3:
        issues.append("response_too_short")
    if "?" in question and "?" not in response and len(response.split()) < 10:
        issues.append("question_unanswered")

    if overlap >= 0.6:
        return 1.0, issues
    elif overlap >= 0.4:
        return 0.75, issues
    elif overlap >= 0.2:
        return 0.5, issues
    return 0.25, issues


def score_faithfulness(response, context):
    """Оценивает, основан ли ответ на предоставленном контексте."""
    if not context:
        return 0.5, ["no_context_provided"]

    rw = tokenize(response)
    cw = tokenize(context)

    overlap = len(rw & cw) / len(rw) if rw else 0

    issues = []
    # Проверка на галлюцинации: слова в ответе, которых нет в контексте
    hallucinated = rw - cw
    hallucination_ratio = len(hallucinated) / len(rw) if rw else 0

    if hallucination_ratio > 0.5:
        issues.append("high_hallucination_risk")
    if overlap < 0.3:
        issues.append("response_not_grounded_in_context")
    if len(rw) > len(cw) * 3 and len(cw) > 0:
        issues.append("response_much_larger_than_context")

    if overlap >= 0.7 and hallucination_ratio <= 0.2:
        return 1.0, issues
    elif overlap >= 0.5 and hallucination_ratio <= 0.3:
        return 0.75, issues
    elif overlap >= 0.3:
        return 0.5, issues
    return 0.25, issues


def score_context_precision(context):
    """Оценивает качество самого контекста."""
    if not context:
        return 0.0, ["empty_context"]
    issues = []
    words = context.split()
    # Контекст должен быть не слишком коротким и не слишком длинным
    if len(words) < 10:
        issues.append("context_too_short")
    if len(words) > 4000:
        issues.append("context_too_long_may_dilute_precision")
    # Проверка на структурированность
    has_structure = any(m in context for m in ["\n- ", "\n1.", "\n* ", "::", "##", "**"])
    if not has_structure:
        issues.append("context_unstructured")
    return (0.75 if len(words) >= 10 and len(words) <= 2000 else 0.5), issues


def score_ac(response, phase_id="", phases_path=""):
    """Оценивает, выполнены ли acceptance criteria фазы."""
    if not phase_id or not phases_path or not os.path.isfile(phases_path):
        return 0.5, ["ac_check_skipped_no_phases_data"]
    try:
        with open(phases_path) as f:
            data = json.load(f)
    except Exception:
        return 0.5, ["ac_check_skipped_cant_read_phases"]
    ac_list = []
    for p in data.get("phases", []):
        if str(p.get("id")) == str(phase_id):
            ac_list = p.get("acceptance_criteria", [])
            break
    if not ac_list:
        return 0.5, ["ac_check_skipped_no_criteria"]
    response_lower = response.lower()
    covered = 0
    for ac in ac_list:
        ac_lower = ac.lower().strip("- []").strip()
        # Check if response mentions key terms from AC
        terms = tokenize(ac_lower)
        if terms and len(terms & tokenize(response_lower)) / len(terms) >= 0.3:
            covered += 1
    ratio = covered / len(ac_list)
    issues = []
    if ratio < 0.5:
        issues.append(f"ac_low_coverage: {covered}/{len(ac_list)} criteria met")
    score = 0.25 if ratio < 0.3 else 0.5 if ratio < 0.7 else 0.75 if ratio < 1.0 else 1.0
    return score, issues


def evaluate(question, response, context="", phase_id="", phases_path=""):
    ac = score_ac(response, phase_id, phases_path)
    r = score_relevance(question, response)
    f = score_faithfulness(response, context)
    cp = score_context_precision(context)

    overall = (ac[0] + r[0] + f[0] + cp[0]) / 4

    return {
        "ac_check": {"score": ac[0], "issues": ac[1]},
        "relevance": {"score": r[0], "issues": r[1]},
        "faithfulness": {"score": f[0], "issues": f[1]},
        "context_precision": {"score": cp[0], "issues": cp[1]},
        "overall": round(overall, 3),
        "passed": overall >= 0.5,
    }


def print_result(result, verbose=True):
    print(json.dumps(result, indent=2, ensure_ascii=False))
    if verbose:
        print(f"\n  Overall:           {result['overall']:.2f} {'PASS' if result['passed'] else 'FAIL'}")
        print(f"  AC Check:          {result['ac_check']['score']:.2f} {'!'*len(result['ac_check']['issues'])}")
        print(f"  Relevance:         {result['relevance']['score']:.2f} {'!'*len(result['relevance']['issues'])}")
        print(f"  Faithfulness:      {result['faithfulness']['score']:.2f} {'!'*len(result['faithfulness']['issues'])}")
        print(f"  Context Precision: {result['context_precision']['score']:.2f} {'!'*len(result['context_precision']['issues'])}")
        all_issues = result['ac_check']['issues'] + result['relevance']['issues'] + result['faithfulness']['issues'] + result['context_precision']['issues']
        if all_issues:
            print(f"  Issues: {', '.join(all_issues)}")


def scan_docs(docs_dir):
    """Проверяет все thesis-файлы: оценивает, есть ли оценки по 3 столпам."""
    thesis_dir = os.path.join(docs_dir, "04-best-practices")
    if not os.path.isdir(thesis_dir):
        print(f"Directory not found: {thesis_dir}")
        return

    results = {}
    for f in sorted(os.listdir(thesis_dir)):
        if not f.endswith("-thesis.md"):
            continue
        path = os.path.join(thesis_dir, f)
        with open(path) as fh:
            content = fh.read()

        # Простейшая оценка: есть ли в thesis упоминание пилларов
        has_relevance = "релевант" in content.lower() or "relevance" in content.lower()
        has_faithfulness = ("достоверн" in content.lower() or "faithful" in content.lower()
                            or "галлюцин" in content.lower())
        has_context = "контекст" in content.lower() or "context" in content.lower()
        score = sum([has_relevance, has_faithfulness, has_context]) / 3
        results[f] = {
            "relevance_mentioned": has_relevance,
            "faithfulness_mentioned": has_faithfulness,
            "context_mentioned": has_context,
            "pillar_coverage": round(score, 2),
        }
    print(json.dumps(results, indent=2, ensure_ascii=False))
    avg = sum(r["pillar_coverage"] for r in results.values()) / len(results) if results else 0
    print(f"\nAverage pillar coverage across {len(results)} thesis files: {avg:.2f}")


def main():
    ap = argparse.ArgumentParser(description="LLM-as-a-Judge: оценивает ответ по 3 столпам")
    ap.add_argument("--question", "-q", help="Вопрос пользователя")
    ap.add_argument("--response", "-r", help="Ответ LLM")
    ap.add_argument("--context", "-c", help="Контекст (документы, RAG)", default="")
    ap.add_argument("--phase-id", help="ID фазы для проверки acceptance criteria")
    ap.add_argument("--phases-path", help="Путь к phases.json для AC check")
    ap.add_argument("--batch", "-b", help="JSONL-файл с кейсами")
    ap.add_argument("--output", "-o", help="Файл для результатов batch")
    ap.add_argument("--scan-docs", action="store_true",
                    help="Проверить все thesis-файлы в docs/ на coverage 3 столпов")
    args = ap.parse_args()

    if args.scan_docs:
        scan_docs(os.path.join(os.path.dirname(__file__), "..", "scripts", "build-loop", "docs"))
        return 0

    if args.batch:
        cases = []
        with open(args.batch) as f:
            for line in f:
                if line.strip():
                    cases.append(json.loads(line))
        results = []
        for c in cases:
            res = evaluate(c.get("question", ""), c.get("response", ""), c.get("context", ""), c.get("phase_id", ""), c.get("phases_path", ""))
            res["id"] = c.get("id", len(results))
            results.append(res)
        out_path = args.output or "judge-results.json"
        with open(out_path, "w") as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
        passed = sum(1 for r in results if r["passed"])
        print(f"Batch done: {passed}/{len(results)} passed -> {out_path}")
        return 0 if passed == len(results) else 1

    if not args.question or not args.response:
        ap.print_help()
        return 1

    # Поддержка чтения из файлов
    for arg in ["question", "response", "context"]:
        val = getattr(args, arg)
        if val and os.path.isfile(val):
            with open(val) as f:
                setattr(args, arg, f.read())

    result = evaluate(args.question, args.response, args.context, args.phase_id or "", args.phases_path or "")
    print_result(result)
    return 0 if result.get("passed") else 1


if __name__ == "__main__":
    sys.exit(main())
