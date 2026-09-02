#!/bin/bash
set -e

# Station 1 & 2: Capture git diff and pass to Claude with Schema Enforcement
echo "[Station 1 & 2] Capturing git diff and invoking Claude..."
git diff | claude -p \
  --max-turns 3 \
  --output-format json \
  --json-schema '{
    "type": "object",
    "properties": {
      "passed": { "type": "boolean" },
      "issues": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "severity": { "type": "string", "enum": ["high", "medium", "low"] },
            "message": { "type": "string" }
          },
          "required": ["severity", "message"]
        }
      }
    },
    "required": ["passed", "issues"]
  }' \
  "Review this PR diff. Set passed to false if there are any high severity or security issues." \
  > review.json

# Station 3: Inspect Raw JSON Output
echo "[Station 3] Raw review output saved to review.json:"
cat review.json | jq .

# Station 4 & 5: Process with jq and make Pipeline Exit Decision
echo "[Station 4 & 5] Evaluating CI Gate Decision..."
if jq -e '.passed == true and ([.issues[] | select(.severity == "high")] | length == 0)' review.json > /dev/null; then
  echo "✅ CI GATE PASSED: Code is safe to merge."
  exit 0
else
  echo "❌ CI GATE FAILED: High-severity or security issues detected."
  exit 1
fi
