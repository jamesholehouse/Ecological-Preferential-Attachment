from __future__ import annotations

from pathlib import Path
import pandas as pd
import pyreadr


IN_DIR = Path("Data")
OUT_DIR = Path("Data_csv")
OUT_DIR.mkdir(exist_ok=True)

def to_dataframe(obj):
    # pyreadr already returns pandas DataFrames for data.frame/tibble
    if isinstance(obj, pd.DataFrame):
        return obj

    # Common fallbacks: numpy arrays / vectors / matrices
    try:
        import numpy as np
        if isinstance(obj, np.ndarray):
            if obj.ndim == 1:
                return pd.DataFrame({ "value": obj })
            if obj.ndim == 2:
                return pd.DataFrame(obj)
    except Exception:
        pass

    # If it's not tabular, we skip it (you can extend this if needed)
    return None


def main():
    rdata_files = sorted(IN_DIR.glob("*.RData")) + sorted(IN_DIR.glob("*.Rdata")) + sorted(IN_DIR.glob("*.rda"))
    if not rdata_files:
        raise SystemExit(f"No .RData/.Rdata/.rda files found in {IN_DIR.resolve()}")

    for fpath in rdata_files:
        result = pyreadr.read_r(str(fpath))  # returns a dict-like of objects in the file :contentReference[oaicite:2]{index=2}
        for obj_name, obj in result.items():
            df = to_dataframe(obj)
            if df is None:
                print(f"SKIP (non-tabular): {fpath.name} :: {obj_name} ({type(obj)})")
                continue

            # Make a nice output filename
            safe_obj = "object" if obj_name is None else str(obj_name)
            out = OUT_DIR / f"{fpath.stem}__{safe_obj}.csv"
            df.to_csv(out, index=False)
            print(f"WROTE: {out}")

if __name__ == "__main__":
    main()
