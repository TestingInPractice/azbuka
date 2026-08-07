#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --project <path>"
  exit 1
}

PROJECT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project|-p) PROJECT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

if [ -z "$PROJECT" ]; then
  echo "Error: --project is required"
  usage
fi

SPECS_DIR="$PROJECT/docs/specs"
STATE_DIR="$PROJECT/.build-loop"
PHASES_FILE="$STATE_DIR/phases.json"

if [ ! -d "$SPECS_DIR" ]; then
  echo "Error: $SPECS_DIR does not exist. Run init.sh first."
  exit 1
fi

if [ -f "$PHASES_FILE" ]; then
  phase_count=$(python3 -c "
import json
try:
  with open('$PHASES_FILE') as f:
    data = json.load(f)
    print(len(data.get('phases', [])))
except:
  print('0')
" 2>/dev/null || echo "0")
  if [ "$phase_count" -gt 0 ]; then
    echo "=== Build Loop: phases.json already exists with $phase_count phase(s) ==="
    echo "To re-decompose, delete $PHASES_FILE and re-run this script."
    echo ""
    echo "Next:"
    echo "  bash $(cd "$(dirname "$0")" && pwd)/next-phase.sh --project \"$PROJECT\""
    exit 0
  fi
fi

echo "=== Build Loop: Decompose $PROJECT ==="
echo ""

spec_files=$(find "$SPECS_DIR" -type f \( -name "*.md" -o -name "*.MD" \) | sort || true)

if [ -z "$spec_files" ]; then
  echo "Error: no .md files found in $SPECS_DIR"
  echo "Fill docs/specs/ with your project description, then re-run."
  exit 1
fi

echo "Spec files found:"
echo "$spec_files" | sed "s|$PROJECT/|  ./|"
echo ""
echo "---"
echo ""

# ============================================================
# Auto-generate phases.json from goals.md
# ============================================================

SPECS_DIR="$SPECS_DIR" PHASES_FILE="$PHASES_FILE" PROJECT="$PROJECT" python3 << 'PYEOF'
import json, os, re, sys

specs_dir = os.environ["SPECS_DIR"]
goals_path = os.path.join(specs_dir, "goals.md")
phases_file = os.environ["PHASES_FILE"]

def fail_ai_prompt():
    """Fallback: print AI decomposition prompt so orchestrator can create phases.json manually."""
    project = os.environ.get("PROJECT", ".")
    print("""
No phases.json found — creating decomposition prompt for AI orchestrator.

## Your task

Read all files in `docs/specs/`, then:

1. **Analyze** the project goals, acceptance criteria, API contracts, and data models
2. **Split** the work into phases — each phase must be:
   - Small enough to fit in a single AI session (under ~50% context window)
   - Semantically cohesive (one logical unit of work)
   - Independently verifiable against its acceptance criteria
3. **Identify dependencies** between phases (e.g., auth must exist before users)
4. **Create `.build-loop/phases.json`** with this exact structure:

```json
{
  "phases": [
    {
      "id": "p1",
      "name": "Short Phase Name",
      "description": "Brief scope description (one line)",
      "status": "pending",
      "depends_on": [],
      "acceptance_criteria": [
        "Criterion that maps to docs/specs/acceptance-criteria.md"
      ]
    },
    {
      "id": "p2",
      "name": "Next Phase",
      "description": "...",
      "status": "pending",
      "depends_on": ["p1"],
      "acceptance_criteria": ["..."]
    }
  ]
}
```

Rules:
- IDs: `p1`, `p2`, `p3`, ...
- `depends_on`: list of phase IDs that must be completed first
- `acceptance_criteria`: copy directly from `acceptance-criteria.md`
- Status: always `"pending"` for new phases
- 5-7 phases max — no micro-phases
- First phase (`p1`) should depend on nothing (project setup / foundation)

5. After creating `.build-loop/phases.json`, run:
   ```
   bash scripts/build-loop/next-phase.sh --project "%s"
   ```

6. If you are unsure about phase boundaries, keep phases larger rather than smaller.
   You can always split a phase later with `GSD Split Phase`.
""" % project)

if not os.path.exists(goals_path):
    print("=== No goals.md found — cannot auto-decompose ===")
    fail_ai_prompt()
    sys.exit(0)

with open(goals_path) as f:
    content = f.read()

# --- Parse F-requirements from Section 5 table ---
# Format: | F-001 | Title | Description | Priority | Dependencies |
f_reqs = []
f_pattern = re.compile(
    r'\|\s*(F-\d+)\s*\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*(must|should|could|nice)?\s*\|\s*([^|]*?)\s*\|',
    re.IGNORECASE
)
for m in f_pattern.finditer(content):
    fid = m.group(1)
    title = m.group(2).strip()
    priority = (m.group(4) or "must").strip().lower()
    deps_str = m.group(5).strip()
    deps = [
        d.strip() for d in re.split(r'[,;]\s*', deps_str)
        if d.strip() and d.strip() not in ('—', '-', '', 'None', 'none')
    ]
    f_reqs.append({
        "id": fid,
        "name": title,
        "priority": priority,
        "depends_on": deps,
    })

if not f_reqs:
    print("=== No F-requirements found in goals.md — cannot auto-decompose ===")
    fail_ai_prompt()
    sys.exit(0)

# --- Parse acceptance criteria from Section 9 ---
# Grouped under: ### F-XXX: Title
# Each line: - [ ] AC-XXX: description  or  - AC-XXX: description
ac_map = {}
current_f = None
for line in content.split("\n"):
    fm = re.match(r"^###\s+(F-\d+)", line)
    if fm:
        current_f = fm.group(1)
        if current_f not in ac_map:
            ac_map[current_f] = []
        continue
    # Also handle sections like "- ### F-XXX" or "### F-XXX"
    fm2 = re.match(r".*###\s+(F-\d+)", line)
    if fm2:
        current_f = fm2.group(1)
        if current_f not in ac_map:
            ac_map[current_f] = []

    if current_f:
        line_stripped = line.strip()
        # Match: - [ ] text  or  - [x] text  or  - text starting with AC-
        ac_match = re.match(r"-\s*\[.?\]\s*(.*)", line_stripped)
        if ac_match:
            ac_text = ac_match.group(1).strip()
            if ac_text:
                ac_map.setdefault(current_f, []).append(ac_text)
        elif re.match(r"-\s*(AC-\d+:)", line_stripped):
            ac_text = re.sub(r"^-\s*", "", line_stripped).strip()
            if ac_text:
                ac_map.setdefault(current_f, []).append(ac_text)

# --- Build phases ---
# Group F-requirements by priority: must first, then should/could/nice
must_reqs = [r for r in f_reqs if r["priority"] == "must"]
other_reqs = [r for r in f_reqs if r["priority"] != "must"]

# Sort must requirements: those with no deps first, then by dep chains
def dep_sort_key(r):
    return len(r["depends_on"])

must_reqs.sort(key=dep_sort_key)

# Build a mapping from F-id to phase id
fid_to_pid = {}
phases = []
pid_counter = 1

def add_req_to_phase(req):
    global pid_counter
    fid = req["id"]
    pid = f"p{pid_counter}"
    pid_counter += 1
    fid_to_pid[fid] = pid

    # Translate F-deps to phase deps
    phase_deps = []
    for dep_fid in req["depends_on"]:
        dep_fid_clean = dep_fid.strip().upper()
        if dep_fid_clean.startswith("F-"):
            if dep_fid_clean in fid_to_pid:
                phase_deps.append(fid_to_pid[dep_fid_clean])
        else:
            # Try matching by name
            for other in f_reqs:
                if dep_fid.lower() in other["name"].lower():
                    if other["id"] in fid_to_pid:
                        phase_deps.append(fid_to_pid[other["id"]])

    acs = ac_map.get(fid, [])
    description = req["name"]
    if acs:
        description += f" ({len(acs)} acceptance criteria)"

    phases.append({
        "id": pid,
        "name": req["name"],
        "description": description,
        "status": "pending",
        "depends_on": list(set(phase_deps)),
        "acceptance_criteria": acs,
    })

for req in must_reqs:
    add_req_to_phase(req)

for req in other_reqs:
    add_req_to_phase(req)

# --- Write phases.json ---
os.makedirs(os.path.dirname(phases_file), exist_ok=True)
with open(phases_file, "w") as f:
    json.dump({"phases": phases}, f, indent=2, ensure_ascii=False)

print(f"=== Auto-decomposed {len(phases)} phases from {len(f_reqs)} requirements ===")
print(f"  Wrote: {phases_file}")
print()
for p in phases:
    dep_str = f" (after: {', '.join(p['depends_on'])})" if p["depends_on"] else ""
    print(f"  📋 Phase {p['id']}: {p['name']}{dep_str}")
    if p["acceptance_criteria"]:
        for ac in p["acceptance_criteria"]:
            print(f"       - {ac}")
print()
print("Next:")
print(f'  bash scripts/build-loop/next-phase.sh --project "{os.environ["PROJECT"]}"')
PYEOF

echo ""
echo "=== Decompose complete ==="
