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


def color_for_pct(pval: int) -> str:
    return "245,158,11,255" if pval <= 25 else "74,222,128,255"


def parse_tier(entry: dict, fallback_pct: int, fallback_sub: str) -> tuple[str, int, str, str]:
    if isinstance(entry, dict) and entry.get("pct_left") is not None:
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
        try:
            pval = max(0, min(100, int(round(float(pct)))))
            return f"{pval}% left", pval, color_for_pct(pval), sub
        except Exception:
            pass

    pval = max(0, min(100, int(fallback_pct)))
    return f"{pval}% left", pval, color_for_pct(pval), fallback_sub


def main() -> None:
    ctx_limit = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 1_000_000
    day_limit = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 20_000_000
    mode = sys.argv[3] if len(sys.argv) > 3 else "compact"
    h5_limit = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4].isdigit() else 5_000_000
    wk_limit = int(sys.argv[5]) if len(sys.argv) > 5 and sys.argv[5].isdigit() else 30_000_000

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
    oldest_5h = None
    oldest_7d = None

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
                            if oldest_7d is None or ts < oldest_7d:
                                oldest_7d = ts
                        if ts >= cutoff_24h:
                            tok_24h += net
                        if ts >= cutoff_5h:
                            tok_5h += net
                            if oldest_5h is None or ts < oldest_5h:
                                oldest_5h = ts
                    except Exception:
                        pass
        except Exception:
            continue

    ctx_rem = max(0, ctx_limit - active_spent)
    spent_pct = round(min(100.0, (active_spent / ctx_limit) * 100.0)) if ctx_limit > 0 else 0
    rem_pct = max(0, 100 - spent_pct)

    day_pct = round(min(100.0, (tok_24h / day_limit) * 100.0)) if day_limit > 0 else 0
    day_rem = max(0, day_limit - tok_24h)

    h5_rem_pct = max(0, 100 - round(min(100.0, (tok_5h / h5_limit) * 100.0))) if h5_limit > 0 else 100
    wk_rem_pct = max(0, 100 - round(min(100.0, (tok_7d / wk_limit) * 100.0))) if wk_limit > 0 else 100
    h5_reset = f"Resets in {fmt_dur((oldest_5h + 5 * 3600) - now)}" if oldest_5h else "Window clear"
    wk_reset = f"Resets in {fmt_dur((oldest_7d + 7 * 86400) - now)}" if oldest_7d else "Window clear"

    if mode != "expand":
        # Trailing pipe guarantees the final regex field always terminates cleanly
        print(
            f"{rem_pct}|{fmt_tok(active_spent)} / {fmt_tok(ctx_limit)}|{spent_pct}|{fmt_tok(ctx_rem)}|"
            f"{fmt_tok(tok_24h)} / {fmt_tok(day_limit)}|{day_pct}|{fmt_tok(day_rem)}|"
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

    has_manual = any(
        isinstance(q.get(k), dict) and q[k].get("pct_left") is not None
        for k in ("gemini_weekly", "gemini_5h", "claude_weekly", "claude_5h", "argon_weekly")
    )

    if has_manual:
        h1, h2, h3 = "Gemini Models", "Claude and GPT models", "Gemini 4 Argon"
        r1_lbl, r1_val, r1_col, r1_sub = parse_tier(q.get("gemini_weekly"), wk_rem_pct, wk_reset)
        r2_lbl, r2_val, r2_col, r2_sub = parse_tier(q.get("gemini_5h"), h5_rem_pct, h5_reset)
        r3_lbl, r3_val, r3_col, r3_sub = parse_tier(q.get("claude_weekly"), wk_rem_pct, wk_reset)
        r4_lbl, r4_val, r4_col, r4_sub = parse_tier(q.get("claude_5h"), h5_rem_pct, h5_reset)
        r5_lbl, r5_val, r5_col, r5_sub = parse_tier(q.get("argon_weekly"), rem_pct, wk_reset)
        if r5_sub.startswith("Resets in "):
            r5_sub = "Weekly limit, r" + r5_sub[1:]
        r1_title, r2_title, r3_title, r4_title = "Weekly limit", "5h limit", "Weekly limit", "5h limit"
    else:
        # Honest live rolling telemetry from local Antigravity transcripts
        h1, h2, h3 = "Gemini & All Local Sessions", "Rolling Token Budgets", "Active Conversation"
        r1_title, r1_lbl, r1_val, r1_col, r1_sub = (
            "Weekly limit (7d)",
            f"{wk_rem_pct}% left", wk_rem_pct, color_for_pct(wk_rem_pct),
            f"{wk_reset} ({fmt_tok(tok_7d)} / {fmt_tok(wk_limit)})",
        )
        r2_title, r2_lbl, r2_val, r2_col, r2_sub = (
            "5h limit",
            f"{h5_rem_pct}% left", h5_rem_pct, color_for_pct(h5_rem_pct),
            f"{h5_reset} ({fmt_tok(tok_5h)} / {fmt_tok(h5_limit)})",
        )
        day_rem_pct = max(0, 100 - day_pct)
        r3_title, r3_lbl, r3_val, r3_col, r3_sub = (
            "24h limit",
            f"{day_rem_pct}% left", day_rem_pct, color_for_pct(day_rem_pct),
            f"Spent {fmt_tok(tok_24h)} / {fmt_tok(day_limit)}",
        )
        r4_title, r4_lbl, r4_val, r4_col, r4_sub = (
            "Context window",
            f"{rem_pct}% left", rem_pct, color_for_pct(rem_pct),
            f"Spent {fmt_tok(active_spent)} / {fmt_tok(ctx_limit)}",
        )
        r5_lbl, r5_val, r5_col, r5_sub = (
            f"{rem_pct}% left", rem_pct, color_for_pct(rem_pct),
            f"Remaining {fmt_tok(ctx_rem)} tokens in chat",
        )

    local_ctx = f"ctx: {fmt_tok(active_spent)} / {fmt_tok(ctx_limit)} ({rem_pct}% left)"
    local_win = f"5h: {fmt_tok(tok_5h)}  /  24h: {fmt_tok(tok_24h)}  /  7d: {fmt_tok(tok_7d)}"

    # 29 pipe-delimited fields with trailing pipe
    fields = [
        h1, h2, h3,
        r1_title, r1_lbl, str(r1_val), r1_col, r1_sub,
        r2_title, r2_lbl, str(r2_val), r2_col, r2_sub,
        r3_title, r3_lbl, str(r3_val), r3_col, r3_sub,
        r4_title, r4_lbl, str(r4_val), r4_col, r4_sub,
        r5_lbl, str(r5_val), r5_col, r5_sub,
        local_ctx, local_win,
    ]
    print("|".join(fields) + "|")


if __name__ == "__main__":
    main()
