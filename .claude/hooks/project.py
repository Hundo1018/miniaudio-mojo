#!/usr/bin/env python3
"""Project hooks for miniaudio-mojo. Registered in .claude/settings.json.
Usage: project.py {session-start|shim-edit|bash-pre|bash-post}  (hook JSON on stdin).
Fails open: any internal error exits 0 so a bug here never blocks work."""
import sys, json, os, re, subprocess, time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
COV_CACHE = os.path.join(ROOT, "build", ".coverage-binding-last")
SHIM_RE = re.compile(r"(^|/)src/native/ma_shim[^/]*\.[ch]$")
# Same pattern as tools/check_binding_coverage.py shim_binds(); keep the two in sync.
BINDS_RE = re.compile(r"/\*\s*@binds\s+([^*]+?)\s*\*/\s*(?:[^{;]*?\bma_shim_([a-zA-Z0-9_]+)\s*\()", re.DOTALL)
# Command position only (start, or after ; & | ( or a newline), so quoted mentions don't trip it.
LONG_TASK_RE = re.compile(r"(?:^|[;&|(\n])\s*(?:time\s+)?pixi\s+run\s+(?:gate|test)(?=\s|$|[;&|)])")
HEREDOC_RE = re.compile(r"<<-?\s*(['\"]?)(\w+)\1.*?\n.*?^\s*\2\s*$", re.DOTALL | re.MULTILINE)
QUOTED_RE = re.compile(r"'[^']*'|\"(?:[^\"\\]|\\.)*\"")


def shell_code(cmd):
    """The command with heredoc bodies and quoted strings blanked out."""
    return QUOTED_RE.sub("''", HEREDOC_RE.sub("", cmd))


def emit(event, ctx):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": event, "additionalContext": ctx}}))


def git(*args):
    return subprocess.run(["git", "-C", ROOT, *args], capture_output=True, text=True, timeout=5).stdout.strip()


def session_start():
    out = [f"[miniaudio-mojo session start] branch: {git('branch', '--show-current')}"]
    dirty = git("status", "--short").splitlines()
    out.append(f"working tree: {len(dirty)} changed path(s)" + ("" if not dirty else ":\n  " + "\n  ".join(dirty[:10])))
    for b in git("branch", "--no-merged", "main", "--format=%(refname:short)").splitlines():
        ahead = git("rev-list", "--count", f"main..{b}")
        last = git("log", "-1", "--format=%cs %s", b)
        out.append(f"unmerged local branch {b}: {ahead} commit(s) ahead of main, last {last}")
    try:
        age_h = (time.time() - os.path.getmtime(COV_CACHE)) / 3600
        out.append(f"last coverage-binding ({age_h:.0f} h ago): {open(COV_CACHE).read().strip()}")
    except OSError:
        out.append("last coverage-binding: no cached result (run `pixi run coverage-binding`, ~25 s)")
    emit("SessionStart", "\n".join(out))


def shim_edit(d):
    path = (d.get("tool_input") or {}).get("file_path", "")
    if not SHIM_RE.search(path) or not os.path.exists(path):
        return
    text = open(path).read()
    covered = [m.span() for m in BINDS_RE.finditer(text)]
    bad = []
    for m in re.finditer(r"@binds\s+ma_", text):  # an annotation, not a prose mention like `@binds`
        if not any(a <= m.start() < b for a, b in covered):
            line = text.count("\n", 0, m.start()) + 1
            bad.append(f"{os.path.relpath(path, ROOT)}:{line}: {text.splitlines()[line - 1].strip()}")
    if bad:
        emit("PostToolUse", "WARNING: these @binds comments are invisible to tools/check_binding_coverage.py "
             "(it only matches `/* @binds ma_a, ma_b */` with no `*` inside, directly before a ma_shim_* definition). "
             "Rewrite each as one single-line comment or Gate 3b will fail:\n" + "\n".join(bad))


def bash_pre(d):
    ti = d.get("tool_input") or {}
    if LONG_TASK_RE.search(shell_code(ti.get("command", ""))) and not ti.get("run_in_background"):
        print("Blocked: `pixi run gate` / `pixi run test` take 15-30 min. Re-run with run_in_background=true and "
              "redirect to a log (e.g. `pixi run gate > build/gate.log 2>&1; echo EXIT=$?`), then read the log tail. "
              "For a scoped check run the family task instead (e.g. `pixi run test-sound`).", file=sys.stderr)
        sys.exit(2)


def bash_post(d):
    if "coverage-binding" not in (d.get("tool_input") or {}).get("command", ""):
        return
    resp = d.get("tool_response", "")
    resp = resp if isinstance(resp, str) else "\n".join(str(v) for v in resp.values()) if isinstance(resp, dict) else str(resp)
    m = re.search(r"^((?:PASS|FAIL)\b.*)$", resp, re.MULTILINE)
    if m:
        os.makedirs(os.path.dirname(COV_CACHE), exist_ok=True)
        open(COV_CACHE, "w").write(m.group(1).strip() + "\n")


def main():
    mode = sys.argv[1]
    if mode == "session-start":
        return session_start()
    d = json.load(sys.stdin)
    {"shim-edit": shim_edit, "bash-pre": bash_pre, "bash-post": bash_post}[mode](d)


try:
    main()
except SystemExit:
    raise
except Exception:
    sys.exit(0)
