import pandas as pd
import json
from pathlib import Path

# ========= CONFIGURATION =========
CSV_INPUT = Path("input.csv") # Path to input CSV
JSON_OUTPUT = Path("output.json")  # Path to output JSON
LIST_COLUMNS = ["Sector"] # If you want to itemize columns
REMOVE_LAST_N = 0 # If you want to remove columns
#NUM_ROWS = 47 # If you want to read only a certain number of rows

# Optional key renaming: {old_name: new_name}
RENAME_MAP = {

}
# =================================

def smart_split(text: str) -> list:
    """
    Split a string on commas (outside parentheses), semicolons, or pipes.
    Returns a cleaned list of strings.
    """
    if text is None or (isinstance(text, float) and pd.isna(text)):
        return []
    s = str(text).strip()
    if not s:
        return []

    items, buf, depth = [], [], 0
    for ch in s:
        if ch == "(":
            depth += 1
            buf.append(ch)
        elif ch == ")":
            depth = max(0, depth - 1)
            buf.append(ch)
        elif (ch in [",", ";", "|"]) and depth == 0:
            part = "".join(buf).strip()
            if part:
                items.append(part)
            buf = []
        else:
            buf.append(ch)
    # Add last buffer content
    last = "".join(buf).strip()
    if last:
        items.append(last)

    # Final cleanup: strip quotes, remove empty, tidy punctuation
    cleaned = []
    for it in items:
        it = it.strip().strip('"').strip("'").strip()
        if it.endswith("."):
            it = it[:-1].rstrip()
        if it:
            cleaned.append(it)
    return cleaned if cleaned else None

def main():
    # Read CSV
    df = pd.read_csv(CSV_INPUT) #.head(NUM_ROWS)
    df = df.drop(columns=["Unnamed: 11"], errors="ignore")

    # Remove last N columns
    if REMOVE_LAST_N > 0:
        df = df.iloc[:, :-REMOVE_LAST_N]

    # Rename columns if mapping exists
    rename_map = {old: new for old, new in RENAME_MAP.items() if old in df.columns}
    if rename_map:
        df = df.rename(columns=rename_map)

    # Apply itemization to configured columns
    for col in LIST_COLUMNS:
        if col in df.columns:
            df[col] = df[col].map(smart_split)
    
    # NaN values are converted to null 
    df = df.where(pd.notna(df), None)

    # Convert to JSON list of records
    data = df.to_dict(orient="records")

    # Write JSON
    JSON_OUTPUT.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"Converted {CSV_INPUT} → {JSON_OUTPUT}")
    print(f"Renamed keys: {list(rename_map.values())}")
    print(f"Rows: {len(data)}")

if __name__ == "__main__":
    main()
