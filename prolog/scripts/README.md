# scripts/ — Maintenance Utilities

## Files

| File | Purpose |
|------|---------|
| `find_duplicate_scripts.py` | SHA256-based duplicate file detection. Run with `--delete` to remove redundancies. |

## Usage

```bash
python3 find_duplicate_scripts.py /path/to/prolog/
python3 find_duplicate_scripts.py /path/to/prolog/ --delete  # remove duplicates
```
