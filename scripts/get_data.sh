#!/usr/bin/env bash
# Download the Olist public dataset (MIT License) into data/raw/.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p data/raw
if [ ! -d data/_olist ]; then
  git clone --depth 1 https://github.com/olist/work-at-olist-data.git data/_olist
fi
cp data/_olist/datasets/*.csv data/raw/
echo "Data ready in data/raw/"
