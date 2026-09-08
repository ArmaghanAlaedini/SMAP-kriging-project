#!/usr/bin/env bash
# run_daily.sh -- cron entry point.
#
#   ./run_daily.sh [N_DAYS]      default 5
#
# Walks back N days, downloads any granule not already on disk, and runs the
# pipeline for dates that have not been processed yet. Re-running is safe.
#
# Crontab example (07:15 local, log to file):
#   15 7 * * * /home/YOU/projects/IA-smap-kriging/run_daily.sh >> /home/YOU/logs/smap.log 2>&1

set -uo pipefail

cd "$(dirname "$0")" || exit 1

# Cron does not read your shell profile, so activate the env explicitly.
# Adjust this path to wherever conda actually lives on the machine.
CONDA_SH="${CONDA_SH:-$HOME/miniconda3/etc/profile.d/conda.sh}"
if [ -f "$CONDA_SH" ]; then
  # shellcheck disable=SC1090
  . "$CONDA_SH"
  conda activate smap-kriging-r || { echo "could not activate conda env"; exit 1; }
fi

DAYS="${1:-5}"
FAILED=0

for i in $(seq 1 "$DAYS"); do

  D=$(date -d "-${i} day" +%Y-%m-%d)
  echo "===================== $D ====================="

  python fetch_smap.py "$D"
  rc=$?

  if [ $rc -eq 2 ]; then
    echo "no granule yet for $D, will retry tomorrow"
    continue
  elif [ $rc -ne 0 ]; then
    echo "DOWNLOAD FAILED for $D"
    FAILED=1
    continue
  fi

  if ! Rscript run_day.R "$D"; then
    echo "PIPELINE FAILED for $D"
    FAILED=1
  fi

done

exit $FAILED
