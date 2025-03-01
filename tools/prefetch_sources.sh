#!/usr/bin/env bash
set -euo pipefail

# Usage: ./fetch_hashes.sh input.json output.json

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <input_json> <output_json>"
  exit 1
fi

INPUT="$1"
OUTPUT="$2"

jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$INPUT" | \
while IFS=$'\t' read -r key url; do
  hash=$(nix-prefetch-url "$url")
  echo "{\"$key\": \"$hash\"}"
done | jq -s 'add' > "$OUTPUT"

echo "Hashes have been saved to $OUTPUT"
