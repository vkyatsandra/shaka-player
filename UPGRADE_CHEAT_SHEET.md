# Automated Upgrade Cheat Sheet

## Quick Commands

### Manual (Local) Upgrade
```bash
./upgrade-version.sh v5.0.10                    # Interactive, manual conflicts
./upgrade-version.sh v5.0.10 --auto-resolve     # Attempt auto-fix conflicts
./upgrade-version.sh v5.0.10 --run-tests        # Run tests after upgrade
./upgrade-version.sh v5.0.10 --auto-resolve --run-tests  # Everything automated
```

### GitHub Actions (Fully Automated)
1. Go to: https://github.com/vkyatsandra/shaka-player/actions
2. Click "Automated Version Upgrade & Testing"
3. "Run workflow" button
4. Enter: `v5.0.10`, check `auto_resolve` and `run_tests`
5. Click "Run workflow"
6. Review auto-generated PR

---

## Exit Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | ✅ Success | Deploy or test further |
| 1 | ❌ Fatal error | Check git/remote setup |
| 2 | ✅ No conflicts | Proceed to test |
| 3 | ⚠️ Conflicts found | Manually resolve files |
| 4 | ⚠️ Auto-resolve failed | Review conflicts, resolve manually |
| 5 | ⚠️ Tests failed | Investigate test failures |

---

## Resolving Conflicts (Manual)

```bash
# 1. Open conflicted files (script shows them)
# 2. Find conflict markers:
#    <<<<<<< HEAD
#    ======= 
#    >>>>>>> commit-hash

# 3. Edit, remove markers, save

# 4. Stage resolved files
git add lib/text/mp4_ttml_parser.js lib/text/ttml_text_parser.js

# 5. Continue cherry-pick
git cherry-pick --continue

# 6. Script auto-detects and completes
```

---

## Common Status Checks

```bash
# Check current branches
git branch -a

# Check release branch commits
git log --oneline -n 5 release/v5.0.10-tivo

# Check if specific commit is applied
git log --grep="KST-16385" release/v5.0.10-tivo

# Verify no uncommitted changes
git status

# Review changed files
git diff release/v5.0.8-tivo release/v5.0.10-tivo -- lib/text/

# Compare upstream vs your release
git log upstream/v5.0.10..release/v5.0.10-tivo --oneline
```

---

## GitHub Actions Workflow

| Step | Time | What It Does |
|------|------|-------------|
| Checkout | 10s | Clone fork with full history |
| Setup | 20s | Install Node.js, Python |
| Fetch tags | 30s | Get latest upstream releases |
| Upgrade script | 3-5 min | Run local upgrade process |
| Lint/check | 1-2 min | Check code syntax |
| Tests | 10-15 min | Run test suite (optional) |
| Create PR | 10s | Auto-generate PR with changes |
| Total | ~20 min | From trigger to PR review-ready |

---

## Adding a New Custom Commit

```bash
# 1. Resolve fix on release branch
git checkout release/v5.0.8-tivo
# (make changes here, test thoroughly)

# 2. Get commit hash
COMMIT_HASH=$(git log --oneline -n 1 | awk '{print $1}')
echo $COMMIT_HASH

# 3. Append to registry
echo "$COMMIT_HASH  # Description of custom fix" >> .tivo-custom-commits

# 4. Commit registry change
git add .tivo-custom-commits
git commit -m "Add custom commit: [DESCRIPTION]"
git push origin main

# 5. Test with next upgrade
./upgrade-version.sh v5.0.10
```

---

## If Things Go Wrong

### Cherry-pick stuck with conflicts?
```bash
# Abort and restart
git cherry-pick --abort
./upgrade-version.sh v5.0.10  # Try again
```

### Wrong version created?
```bash
# Delete local branch (won't delete remote)
git branch -D release/v5.0.10-tivo

# Reset and try again
git fetch upstream --tags
./upgrade-version.sh v5.0.10
```

### Accidental commit in release branch?
```bash
# Reset to upstream version
git checkout release/v5.0.10-tivo
git reset --hard upstream/v5.0.10
git push -f origin release/v5.0.10-tivo  # Force push (be careful!)
```

### GitHub Actions PR has wrong content?
```bash
# Close the auto-generated PR (don't merge)
# Delete the branch: git push origin --delete automated-upgrade-v5.0.10
# Reset and retry
git fetch origin
git branch -D automated-upgrade-v5.0.10
./upgrade-version.sh v5.0.10 --auto-resolve --run-tests
```

---

## File Locations & Purposes

| File | Purpose | Edit? |
|------|---------|-------|
| `upgrade-version.sh` | Main orchestration script | No (unless customizing) |
| `resolve-conflicts-auto.sh` | AI-assisted conflict resolution | No (unless customizing) |
| `.tivo-custom-commits` | Registry of reusable commit hashes | **Yes** (add fixes here) |
| `.github/workflows/upgrade-version.yml` | GitHub Actions automation | No (unless customizing) |
| `AUTOMATED_UPGRADE_GUIDE.md` | Full documentation | Reference |
| `AGENT_SESSION_NOTES.md` | Strategic context (for AI agents) | Reference |
| `UPDATE_INSTRUCTIONS.md` | Manual upgrade walkthrough | Reference |

---

## Monitoring Progress

### While running locally:
```bash
./upgrade-version.sh v5.0.10 --verbose
# Shows each step with timestamps
```

### In GitHub Actions:
1. Go to Actions tab
2. Click running workflow
3. See live logs updating in real-time
4. Check "Annotations" for warnings/errors

### Check what was created:
```bash
# After script completes:
git branch -a
git remote -v
git log --oneline -n 10
```

---

## Testing the Upgrade

```bash
# After successful upgrade script:
git checkout release/v5.0.10-tivo

# Run quick tests
python3 build/test.py --quick

# Or full test suite
python3 build/test.py

# Verify specific functionality (subtitles)
python3 build/test.py --filter="subtitle|timing|ttml"

# Build and check for errors
python3 build/check.py
python3 build/build.py
```

---

## When New Major Features Land

**If custom commits no longer apply** (e.g., entire subtitle parser rewritten):

1. Disable old commit in `.tivo-custom-commits`:
   ```
   # d286f753a  # KST-16385: No longer applies (v6.0.0 rewrote subtitle logic)
   ```

2. Manually port fix to new code:
   ```bash
   git checkout release/v6.0.0-tivo
   # Edit files to apply same intent with new API
   git commit -am "Port subtitle fix to v6.0.0 structure"
   ```

3. Get new hash:
   ```bash
   git log --oneline -n 1 | awk '{print $1}'
   ```

4. Add to registry:
   ```
   # d286f753a  # KST-16385: (v5.0.8-5.1.x only)
   new_hash_v6  # KST-16385: (v6.0.0+ ported)
   ```

---

## Performance Tips

### For Large Team:
- Use GitHub Actions (parallelizable)
- Set up Slack notifications (`SLACK_WEBHOOK` secret)
- Auto-assign reviewers in workflow (see `reviewers:` field)
- Create issues per conflict area for tracking

### For Frequent Upgrades (often):
- Schedule weekly auto-checks (uncomment cron in workflow)
- Keep custom commits minimal (easier to port)
- Review upstream CHANGELOG weekly to anticipate conflicts

### For Minimal Infrastructure:
- Run `./upgrade-version.sh` locally
- Use `--auto-resolve` once you trust it
- Skip `--run-tests` if CI already tests before merge

---

## References

- **Full Guide**: `AUTOMATED_UPGRADE_GUIDE.md`
- **Strategic Context**: `AGENT_SESSION_NOTES.md`
- **Manual Process**: `UPDATE_INSTRUCTIONS.md`
- **Related Scripts**: `upgrade-version.sh`, `resolve-conflicts-auto.sh`

