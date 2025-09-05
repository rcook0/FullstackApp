#!/bin/bash
# fullstack_mega_manager.sh - Mega Manager for Fullstack App
# Handles deployment, hooks, Git push, CI/CD, Docker, MongoDB seeding

LOG_FILE="deploy.log"
DEPLOY_MODE="docker"

log_entry() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# -----------------------------
# Handle --setup
# -----------------------------
if [ "$1" = "--setup" ]; then
    echo "⚙️ Running setup-hooks.sh manually..."
    if [ -f "./setup-hooks.sh" ]; then
        ./setup-hooks.sh
        log_entry "✅ Git hooks installed via --setup"
    else
        echo "❌ setup-hooks.sh not found. Please add it to the repo root."
        log_entry "⚠️ setup-hooks.sh missing — could not install Git hooks"
        exit 1
    fi
    exit 0
fi

# Handle --setup-deps
if [[ "$1" == "--setup-deps" ]]; then
    echo "🔹 Running npm install for backend and frontend..."
    ./scripts/install-deps.sh
    echo "✅ Dependencies installed successfully"
    exit 0
fi


# -----------------------------
# Handle --reset
# -----------------------------
if [ "$1" = "--reset" ]; then
    echo "♻️ Resetting Git hooks..."
    if [ -d ".git/hooks" ]; then
        rm -f .git/hooks/pre-commit .git/hooks/post-merge .git/hooks/post-checkout
        echo "🧹 Old Git hooks removed"
    fi
    if [ -f "./setup-hooks.sh" ]; then
        ./setup-hooks.sh
        log_entry "✅ Git hooks reset via --reset"
    else
        echo "❌ setup-hooks.sh not found. Please add it to the repo root."
        log_entry "⚠️ setup-hooks.sh missing — could not reset Git hooks"
        exit 1
    fi
    exit 0
fi

# -----------------------------
# Ensure Git hooks are installed
# -----------------------------
if [ -d ".git" ]; then
    if [ ! -f ".git/hooks/pre-commit" ] || [ ! -f ".git/hooks/post-merge" ] || [ ! -f ".git/hooks/post-checkout" ]; then
        echo "⚙️  Git hooks missing — running setup-hooks.sh..."
        if [ -f "./setup-hooks.sh" ]; then
            ./setup-hooks.sh
            log_entry "✅ Git hooks installed automatically"
        else
            echo "❌ setup-hooks.sh not found. Please add it to the repo root."
            log_entry "⚠️ setup-hooks.sh missing — could not install Git hooks"
        fi
    fi
else
    echo "ℹ️ No .git directory found — skipping Git hooks setup"
    log_entry "ℹ️ Skipped Git hooks setup (no .git directory)"
fi

# -----------------------------
# Handle --push and --ci
# -----------------------------
PUSH_FLAG=false
CI_TRIGGER=false
COMMIT_MSG="Auto-commit"

for arg in "$@"; do
    case $arg in
        --push)
            PUSH_FLAG=true
            ;;
        --ci)
            CI_TRIGGER=true
            ;;
        *)
            COMMIT_MSG="$arg"
            ;;
    esac
done

# Function to trigger GitHub Actions workflow
trigger_github_ci() {
    if [ -z "$GITHUB_TOKEN" ]; then
        log_entry "⚠️ GITHUB_TOKEN not set, cannot trigger GitHub Actions workflow"
        return 1
    fi

    REPO="username/fullstack-app"
    WORKFLOW_ID="deploy.yml"
    REF=$(git rev-parse --abbrev-ref HEAD)

    log_entry "🚀 Triggering GitHub Actions workflow '$WORKFLOW_ID' on branch '$REF'"

    curl -s -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        https://api.github.com/repos/$REPO/actions/workflows/$WORKFLOW_ID/dispatches \
        -d "{\"ref\":\"$REF\"}" \
        && log_entry "✅ GitHub Actions workflow triggered" \
        || log_entry "❌ Failed to trigger workflow"
}

# Push and optionally trigger CI
if [ "$PUSH_FLAG" = true ]; then
    git add .
    git commit -m "$COMMIT_MSG" || echo "No changes to commit"
    git push origin $(git rev-parse --abbrev-ref HEAD)
    log_entry "✅ Git push complete"

    if [ "$CI_TRIGGER" = true ]; then
        trigger_github_ci
    fi
fi

# -----------------------------
# Regenerate PDF cheat sheet
# -----------------------------
if command -v make &> /dev/null; then
    make docs
    log_entry "✅ Regenerated Deployment PDF via Makefile"
fi

# -----------------------------
# Deployment logic placeholder
# -----------------------------
echo "🚀 Starting deployment in mode: $DEPLOY_MODE"
# Here you can add Docker build/push, MongoDB seeding, etc.
