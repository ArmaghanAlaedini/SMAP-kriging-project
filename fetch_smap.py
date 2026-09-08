#!/usr/bin/env python3
"""
fetch_smap.py -- download one day of SPL3SMP_E from NASA Earthdata.

Usage:
    python fetch_smap.py 2026-09-05 [--outdir data/raw_data]

Prints the path of the downloaded (or already present) .h5 file on stdout.

Exit codes:
    0  file is on disk and ready
    2  no granule published for that date yet (normal, not an error)
    1  something actually broke

Requires an Earthdata Login and a ~/.netrc containing:
    machine urs.earthdata.nasa.gov login YOUR_USER password YOUR_PASS
with permissions 600.
"""

import argparse
import glob
import os
import sys
from datetime import datetime

SHORT_NAME = "SPL3SMP_E"
VERSION = "006"  # confirm against https://nsidc.org/data/spl3smp_e


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("date", help="observation date, YYYY-MM-DD")
    ap.add_argument("--outdir", default="data/raw_data")
    ap.add_argument("--force", action="store_true",
                    help="re-download even if a file for this date exists")
    args = ap.parse_args()

    try:
        d = datetime.strptime(args.date, "%Y-%m-%d").date()
    except ValueError:
        sys.exit(f"bad date: {args.date}")

    tag = d.strftime("%Y%m%d")
    outdir = os.path.abspath(args.outdir)
    os.makedirs(outdir, exist_ok=True)

    # The granule filename embeds a release string (e.g. R19240) that cannot be
    # predicted from the date, so we match on the date portion only.
    pattern = os.path.join(outdir, f"SMAP_L3_SM_P_E_{tag}_*.h5")
    existing = sorted(glob.glob(pattern))
    if existing and not args.force:
        print(existing[-1])
        return 0

    import earthaccess  # imported late so --help works without the dep

    earthaccess.login(strategy="netrc")

    results = earthaccess.search_data(
        short_name=SHORT_NAME,
        version=VERSION,
        temporal=(f"{args.date}T00:00:00", f"{args.date}T23:59:59"),
    )

    if not results:
        print(f"no {SHORT_NAME} granule published for {args.date} yet",
              file=sys.stderr)
        return 2

    if len(results) > 1:
        print(f"note: {len(results)} granules matched {args.date}, "
              f"taking the first", file=sys.stderr)

    files = earthaccess.download(results[:1], local_path=outdir)
    if not files:
        print("download returned no files", file=sys.stderr)
        return 1

    print(os.path.abspath(files[0]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
