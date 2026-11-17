import datetime
import glob
import json
import os
import sys
import time


def fmt_tok(n: int) -> str:
    if n >= 1_000_000:
        return f"{n / 1_000_000:.2f}M"
    if n >= 1_000:
        return f"{n / 1_000:.1f}K"
    return str(n)


def fmt_dur(seconds: float) -> str:
    secs = max(0, int(seconds))
    days = secs // 86400
    hours = (secs % 86400) // 3600
    mins = (secs % 3600) // 60
    if days > 0:
        return f"{days}d {hours}h"
    if hours > 0:
        return f"{hours}h {mins}m"
    return f"{mins}m"


def parse_tier(entry: dict, fallback_sub: str) -> tuple[str, int, str, str]:
    """Returns (pct_label, ring_val, color_rgb, reset_line)."""
    green = "74,222,128,255"
    amber = "245,158,11,255"
    muted = "255,255,255,24"
    if not isinstance(entry, dict):
        return "--% left", 0, muted, fallback_sub

    pct = entry.get("pct_left")
    resets_at = (entry.get("resets_at") or "").strip()
    resets_in = (entry.get("resets_in") or "").strip()

    sub = fallback_sub
    if resets_at:
        try:
            target = datetime.datetime.fromisoformat(resets_at.replace("Z", "+00:00"))
            now_dt = datetime.datetime.now(target.tzinfo)
            rem_s = (target - now_dt).total_seconds()
            if rem_s <= 0:
                pct = 100
                sub = "Reset ready"
            else:
                sub = f"Resets in {fmt_dur(rem_s)}"
        except Exception:
            if resets_in:
                sub = f"Resets in {resets_in}"
    elif resets_in:
        sub = f"Resets in {resets_in}"

    if pct is None:
        return "--% left", 0, muted, sub

    try:
        pval = max(0, min(100, int(round(float(pct)))))
    except Exception:
        return "--% left", 0, muted, sub

    col = amber if pval <= 25 else green
    return f"{pval}% left", pval, col, sub


def main() -> None:
    ctx_limit = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 1_000_000
    day_limit = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 20_000_000
    mode = sys.argv[3] if len(sys.argv) > 3 else "compact"

    home = os.path.expanduser("~")
    patterns = [
        os.path.join(home, ".gemini", "antigravity", "brain", "*", ".system_generated", "logs", "transcript.jsonl"),
        os.path.join(home, ".gemini", "antigravity-cli", "brain", "*", ".system_generated", "logs", "transcript.jsonl"),
    ]
    files = []
    for pat in patterns:
        files.extend(glob.glob(pat))

    now = time.time()
    cutoff_5h = now - 5 * 3600
    cutoff_24h = now - 86400
    cutoff_7d = now - 7 * 86400

    active_spent = 0
    if files:
        files.sort(key=lambda p: os.path.getmtime(p), reverse=True)
        for path in files[:10]:
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as f:
                    last_row = None
                    for line in f:
                        if '"input_tokens"' in line or '"output_tokens"' in line:
                            try:
                                d = json.loads(line)
                                if any(k in d for k in ("input_tokens", "output_tokens", "cache_read_tokens")):
                                    last_row = d
                            except Exception:
                                pass
                    if last_row:
                        active_spent = (
                            int(last_row.get("input_tokens") or 0)
                            + int(last_row.get("cache_read_tokens") or 0)
                            + int(last_row.get("output_tokens") or 0)
                        )
                        break
            except Exception:
                continue

    tok_5h = 0
    tok_24h = 0
    tok_7d = 0
    for path in files:
        try:
            mtime = os.path.getmtime(path)
            if mtime < cutoff_7d:
                continue
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    if '"input_tokens"' not in line and '"output_tokens"' not in line:
                        continue
                    try:
                        d = json.loads(line)
                        net = int(d.get("input_tokens") or 0) + int(d.get("output_tokens") or 0)
                        ts_str = d.get("created_at") or ""
                        ts = mtime
                        if ts_str:
                            try:
                                ts = datetime.datetime.fromisoformat(ts_str.replace("Z", "+00:00")).timestamp()
                            except Exception:
                                pass
                        if ts >= cutoff_7d:
                            tok_7d += net
                        if ts >= cutoff_24h:
                            tok_24h += net
                        if ts >= cutoff_5h:
                            tok_5h += net
                    except Exception:
                        pass
        except Exception:
            continue

    ctx_rem = max(0, ctx_limit - active_spent)
    spent_pct = round(min(100.0, (active_spent / ctx_limit) * 100.0)) if ctx_limit > 0 else 0
    rem_pct = max(0, 100 - spent_pct)
    day_pct = round(min(100.0, (tok_24h / day_limit) * 100.0)) if day_limit > 0 else 0
    day_rem = max(0, day_limit - tok_24h)

    if mode != "expand":
        print(
            f"{rem_pct}|{fmt_tok(active_spent)} / {fmt_tok(ctx_limit)}|{spent_pct}|{fmt_tok(ctx_rem)}|"
            f"{fmt_tok(tok_24h)} / {fmt_tok(day_limit)}|{day_pct}|{fmt_tok(day_rem)}"
        )
        return

    quota_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "agy-quota.json")
    q = {}
    if os.path.exists(quota_path):
        try:
            with open(quota_path, "r", encoding="utf-8-sig") as f:
                q = json.load(f)
        except Exception:
            q = {}

    gw_lbl, gw_val, gw_col, gw_sub = parse_tier(q.get("gemini_weekly"), "Sync /usage via [edit]")
    g5_lbl, g5_val, g5_col, g5_sub = parse_tier(q.get("gemini_5h"), "Sync /usage via [edit]")
    cw_lbl, cw_val, cw_col, cw_sub = parse_tier(q.get("claude_weekly"), "Sync /usage via [edit]")
    c5_lbl, c5_val, c5_col, c5_sub = parse_tier(q.get("claude_5h"), "Sync /usage via [edit]")
    aw_lbl, aw_val, aw_col, aw_sub = parse_tier(q.get("argon_weekly"), "Weekly limit (sync via [edit])")
    if aw_sub.startswith("Resets in "):
        aw_sub = "Weekly limit, r" + aw_sub[1:]

    local_ctx = f"ctx: {fmt_tok(active_spent)} / {fmt_tok(ctx_limit)} ({rem_pct}% left)"
    local_win = f"local 5h: {fmt_tok(tok_5h)}  |  7d: {fmt_tok(tok_7d)}"

    # 22 pipe-delimited fields for AgyTokensExpand.ini
    fields = [
        gw_lbl, str(gw_val), gw_col, gw_sub,
        g5_lbl, str(g5_val), g5_col, g5_sub,
        cw_lbl, str(cw_val), cw_col, cw_sub,
        c5_lbl, str(c5_val), c5_col, c5_sub,
        aw_lbl, str(aw_val), aw_col, aw_sub,
        local_ctx, local_win,
    ]
    print("|".join(fields))


if __name__ == "__main__":
    main()
