#!/usr/bin/env bash
set -euo pipefail

run_matrix() {
  local source_directory="$1"
  local output="$2"
  local failed=0
  local source_name level build_status run_status directory
  ulimit -c 0
  export MODULAR_CRASH_REPORTING_ENABLED=0
  {
    date --iso-8601=seconds
    uname -sm
    mojo --version
    sha256sum "$(command -v mojo)" "$source_directory/repro.mojo" "$source_directory/control.mojo"
  } | tee "$output/environment.txt"
  printf 'case\toptimization\tbuild_status\trun_status\n' > "$output/results.tsv"
  for source_name in control repro; do
    for level in 0 1 2 3; do
      directory="$output/$source_name/O$level"
      mkdir -p "$directory"
      export MODULAR_CACHE_DIR="$directory/cache"
      printf '%q ' mojo build -j 1 --optimization-level "$level" "$source_directory/$source_name.mojo" -o "$directory/program" > "$directory/command.txt"
      printf '\n' >> "$directory/command.txt"
      build_status=0
      run_status=not-run
      timeout -k 3s 45s mojo build -j 1 --optimization-level "$level" \
        "$source_directory/$source_name.mojo" -o "$directory/program" \
        > "$directory/build.log" 2>&1 || build_status=$?
      if [[ "$build_status" -eq 0 ]]; then
        run_status=0
        timeout -k 3s 10s "$directory/program" > "$directory/run.log" 2>&1 || run_status=$?
      fi
      if [[ "$build_status" -ne 0 || "$run_status" != 0 ]]; then
        failed=1
      fi
      printf '%s\t%s\t%s\t%s\n' "$source_name" "$level" "$build_status" "$run_status" | tee -a "$output/results.tsv"
    done
  done
  printf 'Evidence directory: %s\n' "$output"
  return "$failed"
}

if [[ "${1:-}" == --worker && "$#" -eq 3 ]]; then
  run_matrix "$2" "$3"
  exit "$?"
fi

if [[ "$#" -ne 1 ]]; then
  printf 'Usage: bash %s <reproduction-directory>\n' "$0" >&2
  exit 2
fi
source_directory="$(cd -- "$1" && pwd)"
for source_name in repro control; do
  if [[ ! -f "$source_directory/$source_name.mojo" ]]; then
    printf 'Missing source: %s/%s.mojo\n' "$source_directory" "$source_name" >&2
    exit 2
  fi
done
for executable in mojo timeout systemd-run sha256sum; do
  command -v "$executable" >/dev/null || {
    printf 'Required executable unavailable: %s\n' "$executable" >&2
    exit 2
  }
done
repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
mkdir -p "$repository/.temp"
output="$(mktemp -d "$repository/.temp/mojo-repro.XXXXXXXX")"
printf 'Evidence directory: %s\n' "$output"
environment=(--setenv="PATH=$PATH")
for variable in MODULAR_HOME CONDA_PREFIX LD_LIBRARY_PATH; do
  if [[ -n "${!variable:-}" ]]; then
    environment+=(--setenv="$variable=${!variable}")
  fi
done
exec systemd-run --user --unit="mojo-repro-$(basename -- "$output")" \
  --wait --pipe --collect "${environment[@]}" \
  -p MemoryMax=3G -p MemorySwapMax=0 -p LimitCORE=0 -p TasksMax=96 \
  -p RuntimeMaxSec=600 -p WorkingDirectory="$repository" \
  bash "$repository/tools/mojo-repro/reproduce.sh" --worker "$source_directory" "$output"
