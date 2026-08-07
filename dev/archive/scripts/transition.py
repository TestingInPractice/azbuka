import json, os, sys, shutil, fcntl, time, re

def read_json(path):
    with open(path) as f:
        return json.load(f)

def write_json_atomic(path, data):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)

def acquire_lock(path, timeout=10):
    lock_path = path + ".lock"
    fd = os.open(lock_path, os.O_CREAT | os.O_RDWR)
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return fd
        except BlockingIOError:
            time.sleep(0.1)
    raise TimeoutError(f"Cannot acquire lock: {path}")

def release_lock(fd, lock_path):
    try:
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)
    finally:
        try: os.remove(lock_path)
        except FileNotFoundError: pass

def _parse_flow_list(s):
    s = s.strip()
    if s.startswith("[") and s.endswith("]"):
        inner = s[1:-1].strip()
        if not inner:
            return []
        items = []
        for part in inner.split(","):
            part = part.strip().strip("\"'").strip()
            if part and part != "null":
                items.append(part)
        return items
    return None

def parse_yaml_simple(text):
    lines = text.split("\n")
    root = {}
    list_key = None
    obj = None
    obj_indent = 0
    pending_list = None

    for line in lines:
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())

        m = re.match(r"^- (\w[\w-]*):\s*(.*)$", s)
        if m:
            k, v = m.group(1), m.group(2).strip()
            new_obj = {k: v} if v and v != "null" else {}
            if list_key:
                root.setdefault(list_key, []).append(new_obj)
            obj = new_obj
            obj_indent = indent
            pending_list = None
            continue

        m = re.match(r"^- (.+)$", s)
        if m:
            val = m.group(1).strip()
            fl = _parse_flow_list(val)
            if fl is not None:
                val = fl
            elif val == "null":
                val = None
            elif (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
                val = val[1:-1]
            if pending_list is not None:
                pending_list.append(val)
            elif list_key:
                root.setdefault(list_key, []).append(val)
            continue

        m = re.match(r"^([\w-]+):\s*(.*)$", s)
        if m:
            k, v = m.group(1), m.group(2).strip()
            if v == "" or v == "null":
                val = None
            else:
                fl = _parse_flow_list(v)
                if fl is not None:
                    val = fl
                elif (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
                    val = v[1:-1]
                else:
                    val = v

            if obj and indent > obj_indent:
                obj[k] = val
                if val is None:
                    obj[k] = []
                    pending_list = obj[k]
            else:
                root[k] = val
                if val is None:
                    root[k] = []
                    list_key = k
                    pending_list = None
                obj = None
                pending_list = None
            continue

    return root

def read_config(config_path):
    if not os.path.exists(config_path):
        return {"phases": [], "transitions": []}
    with open(config_path) as f:
        raw = parse_yaml_simple(f.read())
    config = {"transitions": raw.get("transitions", []), "phases": raw.get("phases", [])}
    for phase in config["phases"]:
        entry = phase.get("entry", [])
        exit_c = phase.get("exit", [])
        phase["entry"] = entry if isinstance(entry, list) else [entry] if entry else []
        phase["exit"] = exit_c if isinstance(exit_c, list) else [exit_c] if exit_c else []
    return config

def can_transition(from_phase, to_phase, config):
    for rule in config.get("transitions", []):
        if (rule.get("from") == "any" or rule.get("from") == from_phase) and rule.get("to") == to_phase:
            return True
    phase_cfg = next((p for p in config.get("phases", []) if p.get("id") == from_phase), None)
    if phase_cfg and phase_cfg.get("allow_restart") and from_phase == to_phase:
        return True
    return False

def do_transition(project_dir, target_phase, action="transition"):
    wd = os.path.join(project_dir, ".workflow")
    state_path = os.path.join(wd, "state.json")
    phases_path = os.path.join(wd, "phases.json")
    config_path = os.path.join(wd, "config.yaml")

    fd = acquire_lock(state_path)
    try:
        state = read_json(state_path)
        phases = read_json(phases_path) if os.path.exists(phases_path) else {"phases": []}
        config = read_config(config_path)

        from validate_state import validate_state, check_invariants, check_entry_gates, check_exit_gates
        schema = read_json(os.path.join(os.path.dirname(__file__), "..", "schemas", "state.schema.json"))

        ok, err = validate_state(state, schema)
        if not ok:
            return {"status": "error", "error": f"schema: {err}"}

        inv = check_invariants(state, phases)
        if inv:
            return {"status": "error", "errors": inv}

        emergency = state.get("emergency", {}).get("active", False)

        if action == "transition":
            from_phase = state["phase"]
            if not can_transition(from_phase, target_phase, config) and not emergency:
                return {"status": "denied", "error": f"{from_phase} -> {target_phase} not allowed"}
            entry_errs = check_entry_gates({"phase": target_phase, "status": "in_progress"}, config)
            if entry_errs and not emergency:
                return {"status": "denied", "errors": entry_errs}
            if from_phase != target_phase:
                section = state.get(from_phase.replace("-", "_"))
                if isinstance(section, dict):
                    section["status"] = "completed"
                state["phase"] = target_phase
                state["status"] = "in_progress"
                state["subphase"] = None
            else:
                state["status"] = "in_progress"

        elif action == "complete":
            state["status"] = "completed"
            exit_errs = check_exit_gates(state, config)
            if exit_errs and not emergency:
                return {"status": "denied", "errors": exit_errs}
            section = state.get(state["phase"].replace("-", "_"))
            if isinstance(section, dict):
                section["status"] = "completed"

        elif action == "fail":
            state["status"] = "failed"

        elif action == "wait":
            state["status"] = "waiting_human"
            state["subphase"] = "awaiting_answer"

        elif action == "resume":
            if state["status"] != "waiting_human":
                return {"status": "error", "error": "not in waiting_human state"}
            state["status"] = "in_progress"
            state["subphase"] = None

        elif action == "override":
            state["phase"] = target_phase or state["phase"]
            state["status"] = "in_progress"
            state["emergency"] = {"active": True, "reason": f"override to {target_phase}", "approved_by": "human"}

        write_json_atomic(state_path, state)
        return {"status": "ok", "phase": state["phase"], "new_status": state["status"]}
    finally:
        release_lock(fd, state_path + ".lock")

if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--project", required=True)
    p.add_argument("--to", default=None)
    p.add_argument("--action", default="transition", choices=["transition", "complete", "fail", "override", "wait", "resume"])
    a = p.parse_args()
    r = do_transition(a.project, a.to, a.action)
    print(json.dumps(r, indent=2))
    sys.exit(0 if r["status"] == "ok" else 1)
