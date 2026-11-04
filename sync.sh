#!/bin/sh
# sync.sh - copy the current rice from this machine into the repo.
# Run it after changing something, then commit.  (install.sh does the reverse.)
set -e
cd "$(dirname "$0")"
. ./manifest.sh

for entry in $FILES; do
    repo="${entry%%:*}"; home="$HOME/${entry#*:}"
    [ -e "$home" ] || { echo "skip (missing): $home"; continue; }
    mkdir -p "$(dirname "$repo")"
    if [ -d "$home" ]; then
        rm -rf "$repo"
        cp -a "$home" "$repo"
        # build output, caches and backups don't belong in the repo
        find "$repo" -depth \( -name out -o -name __pycache__ -o -name preview \) -type d -exec rm -rf {} +
        find "$repo" -name '*.bak*' -type f -delete
    else
        cp -p "$home" "$repo"
    fi
done
echo "synced. review with: git status && git diff"
