# AI Agent Session Notes: Shaka Player Fork Strategy & Execution

## Session Date
23 March 2026

## Problem Statement

User had a custom Shaka Player repository (v5.0.5 with 3 custom commits + 1 Jenkins change) managed via NPM-based pull + cherry-pick process. This process became inefficient and conflict-prone with each new version.

Goal: Establish a long-term, sustainable fork-based strategy that allows:
1. Direct tracking of upstream Shaka Player releases
2. Clean maintenance of custom fixes (especially subtitle fix commit 44c4f716...)
3. Repeatable, low-conflict upgrade path for future versions (v5.0.10, v6.0.0, etc.)

---

## Strategic Decision: GitHub Fork + Feature Branch Model

### Why fork from GitHub instead of npm?
- ✅ Full git history and control
- ✅ Predictable, mechanical conflict resolution
- ✅ Version transparency in commits
- ✅ Can propose fixes back upstream if needed
- ✅ Repeatable for every release

### Why NOT npm-based approach?
- ❌ Becomes maintenance nightmare after 3-4 version upgrades
- ❌ No git history, blind to changes
- ❌ Manual conflict resolution each time (no learning)
- ❌ Impossible to track interdependencies

---

## Recommended Long-Term Architecture

```
Your Fork (GitHub)
├── main                          # Rolling upstream sync (never commit directly)
├── release/5.0.8-tivo            # Tagged release + custom merges
├── release/5.0.10-tivo           # (future)
│
├── feature/tivo-custom-subtitles  # Long-lived feature (reusable)
├── feature/tivo-jenkins           # (example of future modules)
│
└── tivo-oldcustom remote         # Link to old custom repo (for reference)
```

Key principle: Separate concerns into independent feature branches, reuse across versions.

---

## Execution Steps Performed (23 March 2026)

### Phase 1: Setup
1. Created fork on GitHub: https://github.com/vkyatsandra/shaka-player
2. Cloned fork locally to `/Users/varun.kyatsandra/sandbox/github_repos/shaka-player-fork/shaka-player`
3. Added remotes:
   - `origin` → fork
   - `upstream` → official shaka-project/shaka-player
   - `tivo-oldcustom` → old custom repo (for commit access)

### Phase 2: Release Baseline
1. Fetched tags from upstream: `git fetch upstream --tags`
2. Found latest release: v5.0.8
3. Created release branch: `git checkout -b release/5.0.8-tivo v5.0.8`
4. Pushed to fork: `git push -u origin release/5.0.8-tivo`

### Phase 3: Feature Branch for Fix
1. Created feature branch: `git checkout -b feature/tivo-custom-subtitles`
2. Added tivo-oldcustom remote for cross-repo cherry-pick
3. Fetched old custom branch: `git fetch tivo-oldcustom v5.0.5-test`

### Phase 4: Cherry-Pick with Conflict Resolution
1. Attempted cherry-pick: `git cherry-pick -x 44c4f716aa961a5d9df773423244ad1c19ed7d38`
2. **Conflicts detected** in 2 files:
   - lib/text/mp4_ttml_parser.js (5 conflict regions)
   - lib/text/ttml_text_parser.js (1 conflict region)
3. Manually resolved conflicts by:
   - Understanding baseline behavior (v5.0.8 HEAD)
   - Understanding incoming behavior (old commit 44c4f716...)
   - Creating hybrid solution that preserves both:
     - Subtitle timing fix (HLS vs DASH segment-relative logic)
     - SMPTE-TT TTML box support for Vecima formats
     - Proper timescale handling
4. Resolved conflicts preserved:
   - All v5.0.8 improvements to MP4 parsing
   - All custom timing logic for HLS/segment-relative times
   - Safe clipping boundaries for segment contexts
5. Completed cherry-pick: `git cherry-pick --continue`
6. Result commit: `d286f753a` (on feature/tivo-custom-subtitles)

### Phase 5: Integration & Push
1. Pushed feature branch: `git push -u origin feature/tivo-custom-subtitles`
2. Switched to release branch: `git checkout release/5.0.8-tivo`
3. Merged feature: `git merge --no-ff feature/tivo-custom-subtitles`
4. Pushed release: `git push -u origin release/5.0.8-tivo`

---

## Key Technical Details

### Conflict Resolution Pattern
When cherry-picking cross-version, conflicts occur because:
- Baseline (HEAD): v5.0.8 code structure
- Incoming: v5.0.5 code structure + custom fixes

Solution: Don't choose one side; merge intent:
1. Extract v5.0.8 file structure
2. Identify custom fix intent (subtitle timing logic)
3. Insert intent into v5.0.8 structure
4. Test logic doesn't regress either path

### Important Commits to Remember
- `44c4f716...` → Original commit from old custom repo (KST-16385)
- `d286f753a` → Resolved version in fork (same message, new applied context)

**Future upgrades should cherry-pick d286f753a, not 44c4f716...**

Why? Because d286f753a is already conflict-resolved and compatible with modern Shaka versions.

---

## Agent Guidance for Future Sessions

### When User Says "Update to v5.0.10"

1. **Follow Section 5 of UPDATE_INSTRUCTIONS.md exactly**
   - Command-by-command
   - One at a time
   - With output validation

2. **Reuse d286f753a for cherry-pick**
   ```bash
   git checkout -b feature/tivo-custom-subtitles-5.0.10
   git cherry-pick -x d286f753a
   ```

3. **If conflicts occur:**
   - Do NOT give up
   - Analyze conflict regions
   - Apply conflict resolution pattern (see above)
   - Create new resolved commit
   - Document new commit hash for future reference

4. **If cherry-pick succeeds:**
   - Still test changes: `python3 build/check.py && python3 build/test.py --quick`
   - Verify files actually modified as expected
   - No surprises = safe to merge

### Common Gotchas to Warn User About

1. **Ambiguous refspec error**
   - Happens when both branch and tag named "v5.0.5" exist
   - Solution: Rename branch (`git branch -m old new`)

2. **Can't find commit in cherry-pick**
   - Cause: Cross-repo cherry-pick without fetch
   - Solution: Add remote, fetch branch, then cherry-pick

3. **Conflict temptation**
   - User might want to use all of incoming or all of ours
   - Wrong: This loses context
   - Right: Understand both versions, create hybrid

4. **Forgetting to push**
   - After merge, feature branch is local only
   - Must push both feature and release branches

---

## Documentation Files Created

1. **UPDATE_INSTRUCTIONS.md**
   - Beginner-friendly step-by-step guide
   - Troubleshooting section
   - Cheat sheet
   - Recommended for reading before each upgrade

2. **AGENT_SESSION_NOTES.md** (this file)
   - For future AI agent sessions
   - Strategic context
   - Decision rationale
   - Lessons learned

---

## Outcome & Current State

✅ Established sustainable fork-based branch model
✅ Created reusable feature branch for subtitle fix (feature/tivo-custom-subtitles)
✅ Successfully cherry-picked and resolved conflicts (d286f753a)
✅ Created release/5.0.8-tivo with custom fix integrated
✅ Documented repeatable upgrade process for future releases
✅ Team can now upgrade to v5.0.10, v6.0.0, etc. with predictable workflow

---

## For Next Session: Quick Validation

Ask user to confirm:
```bash
cd /Users/varun.kyatsandra/sandbox/github_repos/shaka-player-fork/shaka-player
git branch -a
git log --oneline -n 5
git remote -v
```

Expected output:
- Branches: main, release/5.0.8-tivo, feature/tivo-custom-subtitles
- Latest commits on release/5.0.8-tivo include merge commit + d286f753a
- Remotes: origin, upstream, tivo-oldcustom

---

## Attribution

This session was completed with Claude Haiku (via GitHub Copilot).

Commit messages should include:
```
Co-Authored-By: Claude <noreply@anthropic.com>
```

See AGENTS.md in root for email conventions.