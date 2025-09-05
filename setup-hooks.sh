#!/bin/sh
# setup-hooks.sh - installs Git hooks for auto-regenerating docs

HOOKS_DIR=".git/hooks"

echo "🔧 Setting up Git hooks in $HOOKS_DIR ..."

if [ ! -d "$HOOKS_DIR" ]; then
    echo "❌ No .git directory found. Run this script from the repo root after git init/clone."
    exit 1
fi

# Pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/sh
echo "🔄 Running pre-commit hook: regenerating docs/DEPLOYMENT.pdf..."
make docs || { echo "❌ Failed to regenerate docs/DEPLOYMENT.pdf"; exit 1; }
git add docs/DEPLOYMENT.pdf
echo "✅ docs/DEPLOYMENT.pdf updated and staged"
EOF

# Post-merge hook
cat > "$HOOKS_DIR/post-merge" << 'EOF'
#!/bin/sh
CHANGED_FILES=$(git diff-tree -r --name-only --no-commit-id ORIG_HEAD HEAD)
if echo "$CHANGED_FILES" | grep -q "docs/DEPLOYMENT.md"; then
    echo "🔄 DEPLOYMENT.md changed, regenerating PDF..."
    make docs || { echo "❌ Failed to regenerate docs/DEPLOYMENT.pdf"; exit 1; }
    echo "✅ docs/DEPLOYMENT.pdf updated after merge"
else
    echo "ℹ️ DEPLOYMENT.md not changed, skipping PDF regeneration"
fi
EOF

# Post-checkout hook
cat > "$HOOKS_DIR/post-checkout" << 'EOF'
#!/bin/sh
if [ -f docs/DEPLOYMENT.md ]; then
    echo "🔄 Checking out branch with DEPLOYMENT.md, regenerating PDF..."
    make docs || { echo "❌ Failed to regenerate docs/DEPLOYMENT.pdf"; exit 1; }
    echo "✅ docs/DEPLOYMENT.pdf updated after checkout"
else
    echo "ℹ️ No DEPLOYMENT.md found in this branch, skipping PDF regeneration"
fi
EOF

chmod +x "$HOOKS_DIR/pre-commit" "$HOOKS_DIR/post-merge" "$HOOKS_DIR/post-checkout"

echo "✅ Git hooks installed successfully"
