#!/bin/bash
# Quick push — run after updating paper.md or any files
# Usage: bash push.sh "commit message"

MSG="${1:-Update E156 submission}"

git add -A
git commit -m "$MSG"
git push origin master 2>/dev/null || git push origin main 2>/dev/null

echo ""
echo "Pushed to GitHub. View at:"
echo "  https://github.com/mahmood726-cyber/lfa"
echo "  https://mahmood726-cyber.github.io/lfa/"
echo "  https://mahmood726-cyber.github.io/lfa/e156-submission/"
