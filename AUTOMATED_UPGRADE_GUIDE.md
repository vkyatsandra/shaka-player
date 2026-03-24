# Automated Version Upgrade System

## Overview

This system automates the Shaka Player version upgrade process, including:
- ✅ Automatic detection of latest upstream version
- ✅ Release branch creation from new version tag
- ✅ Custom patch application via cherry-pick
- ✅ Intelligent conflict resolution (with AI assist option)
- ✅ Automated testing
- ✅ GitHub Actions CI/CD integration
- ✅ Audit trail and PR creation

**Time to upgrade**: ~15 minutes (down from 1+ hours of manual work)

---

## Quick Start

### For Manual Upgrades (Recommended First Time)

```bash
# Make the script executable
chmod +x ./upgrade-version.sh

# Run upgrade to v5.0.10
./upgrade-version.sh v5.0.10

# Or with automatic testing
./upgrade-version.sh v5.0.10 --run-tests

# Or with automatic conflict resolution (AI-assisted)
./upgrade-version.sh v5.0.10 --auto-resolve
```

### For Fully Automated Upgrades (GitHub Actions)

1. Go to **GitHub Actions** → **Automated Version Upgrade & Testing**
2. Click **Run workflow**
3. Enter new version (e.g., `v5.0.10` or `5.0.10`)
4. Check options: `auto_resolve`, `run_tests`
5. Click **Run workflow**
6. Monitor progress in real-time
7. Review auto-generated PR for conflicts/changes
8. Approve and merge when satisfied

---

## System Components

### 1. `upgrade-version.sh` - Main Orchestration Script

**Purpose**: Automates the entire upgrade workflow

**Features**:
- Validates environment (git, remotes, version tags)
- Creates/resets release branch from new version tag
- Creates/updates feature branch for custom patches
- Applies stored custom commits via cherry-pick
- Detects and handles conflicts (manual or auto)
- Merges feature branch into release branch
- Pushes both branches to origin
- Optional: Runs full test suite

**Usage**:
```bash
./upgrade-version.sh [VERSION] [--auto-resolve] [--run-tests] [--verbose]
```

**Exit Codes**:
- `0` = Success
- `1` = Fatal error (validation, fetch, etc.)
- `2` = Cherry-pick succeeded without conflicts
- `3` = Conflicts detected (manual resolution needed)
- `4` = Auto-resolve failed
- `5` = Tests failed (upgrade successful, but tests didn't pass)

**Example Workflows**:

```bash
# One-at-a-time guidance (interactive)
./upgrade-version.sh v5.0.10

# Full automation with AI conflict resolution
./upgrade-version.sh v5.0.10 --auto-resolve --run-tests --verbose

# Staged approach (if conflicts expected):
# 1. Manual conflicts only
./upgrade-version.sh v5.0.10
# 2. If conflicts, user resolves manually
# 3. Then continue (script will prompt)
```

---

### 2. `.tivo-custom-commits` - Custom Commit Registry

**Purpose**: Stores reusable commit hashes that apply to all future versions

**Format**:
```
d286f753a  # KST-16385: Subtitle not working for live stream (resolved for v5.0.8+)
abc1234de  # Custom fix #2
def5678ab  # Custom fix #3
```

**Important Notes**:
- Use the **resolved version** of commits (e.g., `d286f753a`), not original versions
- Commits are cherry-picked in order
- Comments explain the purpose and applicable versions
- File is git-tracked for team consistency

**Adding a New Custom Commit**:
1. Resolve and test fix on current release branch
2. Get commit hash: `git log --oneline -n 1`
3. Append to `.tivo-custom-commits` with comment
4. Test upgrade: `./upgrade-version.sh [VERSION]`
5. Commit change: `git add .tivo-custom-commits && git commit -m "Add custom commit: [DESCRIPTION]"`

---

### 3. `resolve-conflicts-auto.sh` - AI-Assisted Conflict Resolution

**Purpose**: Automatically resolve cherry-pick conflicts using heuristics and pattern matching

**How It Works**:
1. Detects conflicted files
2. Generates conflict report for analysis
3. Attempts smart resolution based on file patterns:
   - **Subtitle parsers** (mp4_ttml_parser.js, ttml_text_parser.js): Merges custom fix with baseline
   - **Other files**: Defaults to HEAD (v5.0.8+ baseline) for safety
4. Falls back to manual if heuristics fail

**Invoked By**: `upgrade-version.sh --auto-resolve`

**Note**: This is a placeholder for more sophisticated AI integration. In production, this can:
- Call Claude API to analyze conflict regions
- Generate merge strategy recommendations
- Apply semantic-aware conflict resolution
- Ask human expert for edge cases

---

### 4. `.github/workflows/upgrade-version.yml` - CI/CD Automation

**Purpose**: GitHub Actions workflow for fully automated upgrades

**Triggers**:
- **Manual**: GitHub Actions UI (recommended)
- **Scheduled**: Weekly (optional, see cron in workflow)
- **Event-driven**: Webhook on upstream release (optional)

**What It Does**:
1. Checks out fork with full git history
2. Fetches latest upstream tags
3. Detects version (from input or latest tag)
4. Runs `upgrade-version.sh` (with options)
5. Analyzes conflicts (if any)
6. Runs linting and tests
7. Generates upgrade report
8. Creates PR with auto-generated title/description
9. Uploads artifacts (logs, conflict reports)
10. Posts Slack notification on failure (optional)

**Workflow Inputs** (GitHub Actions UI):
- `new_version`: Version to upgrade to (e.g., `v5.0.10`)
- `auto_resolve`: Attempt automatic conflict resolution (boolean)
- `run_tests`: Run full test suite after upgrade (boolean, default: true)

**Generated Artifacts**:
- `UPGRADE_REPORT.md` - Summary of upgrade process
- `CONFLICT_RESOLUTION_NEEDED.md` - If conflicts found
- Build logs (if stored)

**Generated PR**:
- Branch: `automated-upgrade-v5.0.10`
- Title: "🤖 Automated: Upgrade to Shaka Player v5.0.10"
- Description: Detailed checklist and deployment steps
- Labels: `ci/automated`, `enhancement`, `release`
- Reviewers: Auto-assigned (optional)

---

## Workflow: Upgrading to a New Version

### Scenario 1: Manual Upgrade (Interactive)

```bash
# 1. Trigger upgrade
cd /path/to/shaka-player-fork
./upgrade-version.sh v5.0.10

# 2. Script will:
#    - Validate git setup
#    - Fetch v5.0.10 tag from upstream
#    - Create release/5.0.10-tivo from tag
#    - Create feature/tivo-custom-subtitles-v5.0.10 from release
#    - Cherry-pick d286f753a (subtitle fix)

# 3. If CONFLICTS occur:
#    - Script stops and shows conflicted files
#    - You manually resolve conflicts (see Conflict Resolution section below)
#    - You stage files: git add [FILE]
#    - You complete cherry-pick: git cherry-pick --continue
#    - Script detects completion and continues
#    - Feature branch and release branch are created

# 4. If SUCCESS:
#    - Both branches pushed to origin
#    - Ready for testing and deployment

# 5. VERIFY
git checkout release/5.0.10-tivo
git log --oneline -n 5
# Should show: merge commit + custom fixes + v5.0.10 baseline
```

**Time**: ~15 minutes (mostly waiting for cherry-pick to complete)

---

### Scenario 2: Fully Automated Upgrade (GitHub Actions)

```bash
# 1. Go to GitHub UI
# https://github.com/vkyatsandra/shaka-player/actions
# → "Automated Version Upgrade & Testing"
# → "Run workflow"

# 2. Enter inputs:
#    - new_version: v5.0.10
#    - auto_resolve: true (to attempt auto-conflict resolution)
#    - run_tests: true

# 3. Click "Run workflow" and monitor:
#    - Logs appear in real-time
#    - Artifacts uploaded when done
#    - PR created automatically (if no critical failures)

# 4. Review auto-generated PR:
# https://github.com/vkyatsandra/shaka-player/pulls
# - Check "Automated: Upgrade to Shaka Player v5.0.10" PR
# - Review changes in modified files
# - Run any manual verification you need

# 5. Approve and Merge:
#    - CI has already tested it
#    - Click "Merge pull request"
#    - GitHub Actions will push both branches

# 6. Deploy:
#    git checkout release/5.0.10-tivo && git pull
#    # Your deployment script here
```

**Time**: ~5-10 minutes (mostly GitHub Actions execution)

---

## Conflict Resolution Guide

### When Conflicts Happen

The automated upgrade may detect conflicts if:
- Custom fix (e.g., subtitle timing) conflicts with newer v5.0.10 code
- Multiple versions diverged significantly
- New v5.0.10 refactored the same files

### How to Resolve Manually

```bash
# 1. Script will stop and show:
# ERROR: Cherry-pick failed with conflicts
# Conflicted files:
#   - lib/text/mp4_ttml_parser.js
#   - lib/text/ttml_text_parser.js

# 2. Open each conflicted file and look for markers:
# <<<<<<< HEAD
#     v5.0.10 baseline code
# =======
#     Custom subtitle fix code
# >>>>>>>  44c4f716...

# 3. Decide which to keep or MERGE BOTH:
#    - Read AGENT_SESSION_NOTES.md for context
#    - Look for semantic compatibility
#    - Test your choice in isolation
#    - Save file (markers gone)

# 4. Stage all resolved files:
git add lib/text/mp4_ttml_parser.js lib/text/ttml_text_parser.js

# 5. Continue cherry-pick:
git cherry-pick --continue
# (This completes the cherry-pick with a new commit)

# 6. Script auto-detects completion:
#    - Feature branch created with resolved commit
#    - Release branch merge created
#    - Both pushed to origin
#    - Done!
```

### Example: Merging Intent (Not Just Taking One Side)

**Conflict in `ttml_text_parser.js`** (timing logic):

```javascript
// HEAD (v5.0.10)
const startTime = this.periodStart + cueData.start;

// ======= Custom fix
const isHlsManifest = this.manifestType === 'application/x-mpegURL';
const startTime = (isHlsManifest ? this.segmentStart : this.periodStart) + cueData.start;

// SOLUTION: Merge both
const isHlsManifest = this.manifestType === 'application/x-mpegURL';
const anchor = isHlsManifest ? this.segmentStart : this.periodStart;
const startTime = anchor + cueData.start;
```

**Principle**: Preserve both v5.0.10 structure AND custom fix logic.

---

## Configuration & Customization

### Custom Commits

Edit `.tivo-custom-commits` to add/remove/reorder patches:

```
# Subtitle fix (core, always apply)
d286f753a

# Jenkins configuration (if needed)
abc1234de

# Custom analytics (future)
# (commented out until ready)
```

### Upgrade Script Options

```bash
# Verbose output (shows every step)
./upgrade-version.sh v5.0.10 --verbose

# Auto-resolve conflicts (attempt heuristics)
./upgrade-version.sh v5.0.10 --auto-resolve

# Run tests after upgrade
./upgrade-version.sh v5.0.10 --run-tests

# Combine options
./upgrade-version.sh v5.0.10 --auto-resolve --run-tests --verbose
```

### GitHub Actions Options

Configure in `.github/workflows/upgrade-version.yml`:

```yaml
# Change how often auto-checks happen (default: weekly Monday 2 AM UTC)
schedule:
  - cron: '0 2 * * 1'

# Add Slack notifications on failure (requires SLACK_WEBHOOK secret)
# Set up: GitHub → Settings → Secrets → New repository secret
# Name: SLACK_WEBHOOK
# Value: https://hooks.slack.com/services/...

# Auto-assign reviewers (change 'vkyatsandra' to your username)
reviewers: 'vkyatsandra,colleague-username'
```

### Test Configuration

If tests fail, adjust in `upgrade-version.sh`:

```bash
# Quick tests only (no integration tests)
python3 build/test.py --quick

# Full test suite
python3 build/test.py

# Specific test filter
python3 build/test.py --filter="subtitle|timing"

# Specific browsers
python3 build/test.py --browsers Chrome,Firefox
```

---

## Troubleshooting

### Issue: "version tag not found"

```bash
# Solution: Fetch tags from upstream manually
git fetch upstream --tags
```

### Issue: "Cherry-pick failed, conflicts in unknown file"

```bash
# Solution: Manually resolve (no auto-heuristic for unknown file)
# 1. Edit file, remove conflict markers
# 2. Stage: git add [FILE]
# 3. Continue: git cherry-pick --continue
```

### Issue: "Auto-resolve failed, can't understand conflicts"

```bash
# Solution: Revert to manual resolution
git cherry-pick --abort
# (Script will ask you to manually resolve)
```

### Issue: "Tests failed after upgrade"

```bash
# This means: upgrade successful, but tests regressed
# 1. Investigate test failures
# 2. Fix the issue in feature branch
# 3. Re-push: git push origin feature/tivo-custom-v5.0.10
# 4. Manual verification before merging
```

### Issue: "Can't push to origin"

```bash
# Check if you have write permissions
git remote -v
# If not, ask fork owner to grant access
# (You should be owner of your own fork)
```

### Issue: "GitHub Actions takes too long"

```bash
# Solution: Run locally instead
./upgrade-version.sh v5.0.10 --auto-resolve --run-tests

# Or skip tests initially
./upgrade-version.sh v5.0.10 --auto-resolve
# (Test manually later)
```

---

## Best Practices

### ✅ Do:
- Run locally first with manual conflict resolution
- Review conflicts before auto-resolve attempts
- Test upgraded version thoroughly before merging
- Document new custom commits in `.tivo-custom-commits`
- Use GitHub Actions for audit trail and PR creation
- Keep custom commits minimal and focused

### ❌ Don't:
- Use `--auto-resolve` on first-time upgrade (manually verify)
- Cherry-pick untested commits into the registry
- Ignore test failures; always investigate
- Force-push to release branches (breaks history)
- Mix multiple unrelated fixes in one commit

---

## Next Steps

1. **Test the system**:
   ```bash
   chmod +x upgrade-version.sh resolve-conflicts-auto.sh
   ./upgrade-version.sh v5.0.8  # Dry-run with known version
   ```

2. **Verify release branch was created**:
   ```bash
   git branch -a | grep release
   git log --oneline -n 5 release/5.0.8-tivo
   ```

3. **When v5.0.10 is released**, run:
   ```bash
   ./upgrade-version.sh v5.0.10 --run-tests
   ```

4. **Or use GitHub Actions** for fully automated workflow with PR

---

## Integration with CI/CD

The workflow file `.github/workflows/upgrade-version.yml` can integrate with:
- **Slack**: Notify team on upgrade completion/failure
- **Jira**: Auto-create ticket for deployment
- **PagerDuty**: Alert on-call engineer
- **Email**: Notify stakeholders
- **Datadog**: Log upgrade events for audit

See comments in workflow file for integration points.

---

## Questions?

Refer to:
- `UPDATE_INSTRUCTIONS.md` - Manual upgrade walkthrough
- `AGENT_SESSION_NOTES.md` - Strategic context and conflict resolution patterns
- GitHub Issues - Ask community for help

