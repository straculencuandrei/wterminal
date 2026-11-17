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


def main() -> None:
    ctx_limit = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 1_000_000
    day_limit = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 5_000_000

    home = os.path.expanduser("~")
    patterns = [
        os.path.join(home, ".gemini", "antigravity", "brain", "*", ".system_generated", "logs", "transcript.jsonl"),
        os.path.join(home, ".gemini", "antigravity-cli", "brain", "*", ".system_generated", "logs", "transcript.jsonl"),
    ]
    files = []
    for pat in patterns:
        files.extend(glob.glob(pat))

    if not files:
        print(f"100|0 / {fmt_tok(ctx_limit)}|0|0 / {fmt_tok(day_limit)}|{fmt_tok(ctx_limit)}|0|0|0")
        return

    now = time.time()
    cutoff_24h = now - 86400

    # Pick the newest modified transcript that actually has token usage
    files.sort(key=lambda p: os.path.getmtime(p), reverse=True)

    active_spent = 0
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

    day_uncached = 0
    day_cache = 0
    for path in files:
        try:
            if os.path.getmtime(path) < cutoff_24h:
                continue
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    if '"input_tokens"' not in line and '"output_tokens"' not in line:
                        continue
                    try:
                        d = json.loads(line)
                        day_uncached += int(d.get("input_tokens") or 0) + int(d.get("output_tokens") or 0)
                        day_cache += int(d.get("cache_read_tokens") or 0)
                    except Exception:
                        pass
        except Exception:
            continue

    ctx_rem = max(0, ctx_limit - active_spent)
    spent_pct = round(min(100.0, (active_spent / ctx_limit) * 100.0)) if ctx_limit > 0 else 0
    rem_pct = max(0, 100 - spent_pct)
    day_pct = round(min(100.0, (day_uncached / day_limit) * 100.0)) if day_limit > 0 else 0
    day_rem = max(0, day_limit - day_uncached)

    # Fields (1..8):
    # 1=rem_pct, 2=ctx_spent/limit, 3=spent_pct, 4=ctx_rem, 5=24h_net/limit, 6=day_pct, 7=24h_rem, 8=24h_cache
    print(
        f"{rem_pct}|{fmt_tok(active_spent)} / {fmt_tok(ctx_limit)}|{spent_pct}|{fmt_tok(ctx_rem)}|"
        f"{fmt_tok(day_uncached)} / {fmt_tok(day_limit)}|{day_pct}|{fmt_tok(day_rem)}|{fmt_tok(day_cache)}"
    )


if __name__ == "__main__":
    main()
