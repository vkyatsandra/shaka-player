#!/bin/bash

##############################################################################
# Shaka Player Automated Version Upgrade Script
# 
# Purpose: Automate upgrade process with custom patch application
# Usage: ./upgrade-version.sh [NEW_VERSION] [--auto-resolve] [--run-tests]
#
# Example:
#   ./upgrade-version.sh v5.0.10                    # Interactive, manual conflict resolution
#   ./upgrade-version.sh v5.0.10 --auto-resolve     # Auto-resolve conflicts, retry on fail
#   ./upgrade-version.sh v5.0.10 --run-tests        # Run full test suite after upgrade
#
# Exit Codes:
#   0 = Success
#   1 = Invalid version or fetch failed
#   2 = Cherry-pick succeeded without conflicts
#   3 = Cherry-pick failed, conflicts detected (manual resolution required)
#   4 = Auto-resolve attempted but failed (user intervention needed)
#   5 = Tests failed (upgrade successful but tests didn't pass)
##############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
UPSTREAM_REMOTE="upstream"
ORIGIN_REMOTE="origin"
FEATURE_BRANCH_PREFIX="feature/tivo-custom"
FIXED_COMMITS_FILE=".tivo-custom-commits"  # File to track reusable commits

# Parse arguments
NEW_VERSION="${1}"
AUTO_RESOLVE=false
RUN_TESTS=false
VERBOSE=false

if [[ -z "$NEW_VERSION" ]]; then
    echo -e "${RED}Error: No version specified${NC}"
    echo "Usage: $0 [VERSION] [--auto-resolve] [--run-tests] [--verbose]"
    exit 1
fi

# Remove 'v' prefix if present (normalize to 'vX.Y.Z' format)
if [[ ! "$NEW_VERSION" =~ ^v ]]; then
    NEW_VERSION="v${NEW_VERSION}"
fi

# Parse flags
shift || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto-resolve) AUTO_RESOLVE=true ;;
        --run-tests) RUN_TESTS=true ;;
        --verbose) VERBOSE=true ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
    shift || true
done

##############################################################################
# Helper Functions
##############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}⚙️  Step: $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

abort_upgrade() {
    log_error "$1"
    echo ""
    log_info "Aborting upgrade. No changes were made to your branches."
    exit "${2:-1}"
}

load_custom_commits() {
    if [[ -f "$FIXED_COMMITS_FILE" ]]; then
        mapfile -t CUSTOM_COMMITS < "$FIXED_COMMITS_FILE"
        log_success "Loaded $(echo "${#CUSTOM_COMMITS[@]}") custom commits from $FIXED_COMMITS_FILE"
        if [[ "$VERBOSE" == true ]]; then
            for commit in "${CUSTOM_COMMITS[@]}"; do
                echo "  - $commit"
            done
        fi
    else
        log_warn "No custom commits file found. Expecting manual feature branch cherry-pick."
        CUSTOM_COMMITS=()
    fi
}

##############################################################################
# Step 1: Validation
##############################################################################

log_step "Validating environment and version"

# Check git is available
if ! command -v git &> /dev/null; then
    abort_upgrade "git is not installed or not in PATH"
fi

# Check we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    abort_upgrade "Not a git repository. Run this from the fork root."
fi

# Check remotes are configured
if ! git remote get-url "$UPSTREAM_REMOTE" > /dev/null 2>&1; then
    abort_upgrade "Remote '$UPSTREAM_REMOTE' not found. Add it with: git remote add upstream https://github.com/shaka-project/shaka-player.git"
fi

log_success "Git repository validated"

# Check if version tag exists on upstream
if ! git rev-parse "$NEW_VERSION" 2>/dev/null | grep -q .; then
    log_info "Version tag $NEW_VERSION not found locally. Fetching from upstream..."
    git fetch "$UPSTREAM_REMOTE" tag "$NEW_VERSION" || abort_upgrade "Failed to fetch tag $NEW_VERSION from upstream"
    log_success "Fetched $NEW_VERSION from upstream"
else
    log_success "Version tag $NEW_VERSION already exists locally"
fi

##############################################################################
# Step 2: Load custom commits
##############################################################################

log_step "Loading custom commits"
load_custom_commits

##############################################################################
# Step 3: Create release branch
##############################################################################

log_step "Creating release branch for $NEW_VERSION"

RELEASE_BRANCH="release/${NEW_VERSION}-tivo"

# Check if release branch already exists
if git rev-parse --verify "$RELEASE_BRANCH" > /dev/null 2>&1; then
    log_warn "Release branch $RELEASE_BRANCH already exists."
    read -p "Do you want to reset it to $NEW_VERSION? (yes/no) " -r
    if [[ $REPLY == "yes" ]]; then
        git checkout "$RELEASE_BRANCH"
        git reset --hard "$NEW_VERSION"
        log_success "Reset $RELEASE_BRANCH to $NEW_VERSION"
    else
        abort_upgrade "Cannot proceed without a clean release branch"
    fi
else
    git checkout -b "$RELEASE_BRANCH" "$NEW_VERSION"
    log_success "Created $RELEASE_BRANCH from $NEW_VERSION"
fi

# Push release branch to origin if not present
if ! git rev-parse --verify "origin/$RELEASE_BRANCH" > /dev/null 2>&1; then
    git push -u "$ORIGIN_REMOTE" "$RELEASE_BRANCH"
    log_success "Pushed $RELEASE_BRANCH to origin"
fi

##############################################################################
# Step 4: Create/update feature branch and apply custom commits
##############################################################################

log_step "Applying custom patches"

FEATURE_BRANCH="${FEATURE_BRANCH_PREFIX}-${NEW_VERSION}"

# Create feature branch from release branch
if git rev-parse --verify "$FEATURE_BRANCH" > /dev/null 2>&1; then
    log_warn "Feature branch $FEATURE_BRANCH already exists. Resetting..."
    git checkout "$FEATURE_BRANCH"
    git reset --hard "$RELEASE_BRANCH"
else
    git checkout -b "$FEATURE_BRANCH" "$RELEASE_BRANCH"
    log_success "Created $FEATURE_BRANCH from $RELEASE_BRANCH"
fi

if [[ ${#CUSTOM_COMMITS[@]} -eq 0 ]]; then
    log_warn "No custom commits to apply. Expecting manual cherry-pick."
    log_info "To manually apply a patch, run:"
    echo "  git cherry-pick -x [COMMIT_HASH]"
    echo ""
    read -p "Have you manually applied custom patches? (yes/no) " -r
    if [[ $REPLY != "yes" ]]; then
        abort_upgrade "Cannot continue without custom patches applied"
    fi
else
    # Apply each custom commit in order
    CONFLICT_DETECTED=false
    FAILED_COMMITS=()
    
    for commit_hash in "${CUSTOM_COMMITS[@]}"; do
        log_info "Applying custom commit: $commit_hash"
        
        if git cherry-pick -x "$commit_hash" 2>&1 | tee /tmp/cherry_pick.log; then
            log_success "Successfully applied $commit_hash"
        else
            CONFLICT_DETECTED=true
            FAILED_COMMITS+=("$commit_hash")
            log_error "Cherry-pick failed with conflicts: $commit_hash"
            
            # Show conflict summary
            echo ""
            log_info "Conflicted files:"
            git status --short | grep "^[UA][UA]" | awk '{print "  - " $2}'
            echo ""
            
            if [[ "$AUTO_RESOLVE" == true ]]; then
                log_info "Attempting automatic conflict resolution..."
                # Call AI-assisted resolution script
                if resolve_conflicts_auto "$commit_hash" "$NEW_VERSION"; then
                    log_success "Automatic conflict resolution succeeded"
                    if git cherry-pick --continue 2>&1; then
                        log_success "Completed cherry-pick for $commit_hash"
                        CONFLICT_DETECTED=false
                    else
                        log_error "Cherry-pick --continue failed"
                        break
                    fi
                else
                    log_error "Automatic conflict resolution failed"
                    break
                fi
            else
                log_warn "Stopping at first conflict. Use --auto-resolve to attempt automatic fixes."
                break
            fi
        fi
    done
    
    if [[ "$CONFLICT_DETECTED" == true ]]; then
        log_error "Conflicts remain. Manual intervention required."
        echo ""
        log_info "To resolve manually:"
        echo "  1. Open conflicted files and resolve changes"
        echo "  2. Run: git add [FILE]"
        echo "  3. Run: git cherry-pick --continue"
        echo "  4. Run: $0 $NEW_VERSION --continue (to complete upgrade)"
        exit 3
    fi
fi

log_success "All custom patches applied successfully"

##############################################################################
# Step 5: Merge feature branch into release branch
##############################################################################

log_step "Merging feature branch into release branch"

git checkout "$RELEASE_BRANCH"
git merge --no-ff "$FEATURE_BRANCH" -m "Merge custom patches for $NEW_VERSION"

log_success "Merged $FEATURE_BRANCH into $RELEASE_BRANCH"

##############################################################################
# Step 6: Push branches to origin
##############################################################################

log_step "Pushing branches to origin"

git push -u "$ORIGIN_REMOTE" "$RELEASE_BRANCH"
git push -u "$ORIGIN_REMOTE" "$FEATURE_BRANCH"

log_success "Pushed both branches to origin"

##############################################################################
# Step 7: Run tests (optional)
##############################################################################

if [[ "$RUN_TESTS" == true ]]; then
    log_step "Running test suite"
    
    if command -v python3 &> /dev/null && [[ -f "build/test.py" ]]; then
        log_info "Running: python3 build/test.py --quick"
        if python3 build/test.py --quick; then
            log_success "Tests passed!"
        else
            log_error "Tests failed!"
            log_warn "Your upgrade is complete, but tests did not pass."
            log_info "Review the test output above and manually verify your changes."
            exit 5
        fi
    else
        log_warn "Test runner not found. Skipping tests."
    fi
fi

##############################################################################
# Step 8: Summary and next steps
##############################################################################

log_step "Upgrade complete!"

echo ""
echo "Summary:"
echo "  Release branch: $RELEASE_BRANCH"
echo "  Feature branch: $FEATURE_BRANCH"
echo "  Status: Clean, ready for integration"
echo ""
echo "Next steps:"
echo "  1. Test the upgraded version locally"
echo "  2. Push to deployment: git checkout $RELEASE_BRANCH && git push -f $ORIGIN_REMOTE HEAD"
echo "  3. Verify in production"
echo ""
echo "To upgrade again in the future, run:"
echo "  $0 [NEW_VERSION]"
echo ""

log_success "Done!"
exit 0
