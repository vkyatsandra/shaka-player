# Shaka Player Fork Update and Custom Fix Maintenance Manual

This document explains, step by step, how to maintain your fork of Shaka Player, sync with upstream updates, and carry your custom fixes forward (such as the subtitle fix).

Audience: Beginner to intermediate engineers.

Goal: Make updates repeatable, low-risk, and easy to troubleshoot.

---

## 1) What you have now

You currently have:

1. Upstream remote (official Shaka repository):
   - https://github.com/shaka-project/shaka-player
2. Fork remote (your repository):
   - https://github.com/vkyatsandra/shaka-player
3. Old custom repository (source of historical custom commits):
   - https://github.com/tivocorp/shaka-player

Working branch model in your fork:

1. main
   - Tracking branch for upstream main.
   - Never put custom product fixes directly here.
2. release/x.y.z-tivo
   - Release integration branch from a specific Shaka release tag.
   - Example: release/5.0.8-tivo
3. feature/<fix-name>
   - Isolated feature branch for one customization.
   - Example: feature/tivo-custom-subtitles

---

## 2) Very important concepts

### 2.1 main is not a release tag

main is the moving development branch.

- It is not the same as v5.0.0 or any fixed version.
- It is only up-to-date when you sync it.

### 2.2 Release tags are fixed snapshots

Tags like v5.0.8, v5.0.10 are immutable release points.

Best practice:

- Create release branch from tag.
- Apply custom fixes via feature branches.

### 2.3 Reuse your already-resolved custom commits

If you already resolved conflicts once and created a clean commit on your fork, reuse that commit for future versions.

Example from your work:

- Original old commit: 44c4f716aa961a5d9df773423244ad1c19ed7d38
- Reapplied and resolved in fork: d286f753a

For future upgrades, cherry-pick d286f753a first.

---

## 3) One-time repository setup

Run in your fork clone directory.

Check where you are:

  pwd

Check remotes:

  git remote -v

Expected remotes:

1. origin -> your fork
2. upstream -> official Shaka repo
3. tivo-oldcustom -> old custom repo (optional but useful)

If missing, add them:

  git remote add upstream https://github.com/shaka-project/shaka-player.git
  git remote add tivo-oldcustom https://github.com/tivocorp/shaka-player.git

Fetch all references and tags:

  git fetch upstream --tags
  git fetch origin --tags
  git fetch tivo-oldcustom --tags

---

## 4) Daily sync procedure (keep fork healthy)

Do this regularly, even when no release is happening.

1. Fetch latest refs:

  git fetch upstream --tags
  git fetch origin --tags

2. Update local main from upstream:

  git checkout main
  git merge --ff-only upstream/main

3. Push updated main to fork:

  git push origin main

If merge --ff-only fails, your main has local commits. Stop and inspect before continuing.

---

## 5) Upgrade procedure when new Shaka release arrives

Example target release: v5.0.10

### Step A: Confirm the tag exists

  git fetch upstream --tags
  git tag -l | grep '^v5.0.10$'

If no output, tag not available locally yet.

### Step B: Create new release branch from the release tag

  git checkout -b release/5.0.10-tivo v5.0.10
  git push -u origin release/5.0.10-tivo

### Step C: Create feature branch for one custom fix

  git checkout -b feature/tivo-custom-subtitles-5.0.10

### Step D: Reapply fix using your fork-resolved commit (recommended)

  git cherry-pick -x d286f753a

If cherry-pick succeeds, continue to Step F.

If cherry-pick conflicts, go to Step E.

### Step E: Resolve conflicts

1. See conflicted files:

  git status --short

2. Open each file and resolve conflict markers:

- Remove lines starting with:
  - <<<<<<<
  - =======
  - >>>>>>>

3. Keep intended logic from your custom fix while preserving upstream-compatible behavior.

4. Stage resolved files:

  git add <file1> <file2>

5. Continue cherry-pick:

  git cherry-pick --continue

Abort if needed:

  git cherry-pick --abort

### Step F: Push feature branch

  git push -u origin feature/tivo-custom-subtitles-5.0.10

### Step G: Merge feature into release branch

  git checkout release/5.0.10-tivo
  git merge --no-ff feature/tivo-custom-subtitles-5.0.10 -m "Merge subtitle fix for v5.0.10"

### Step H: Push release branch

  git push -u origin release/5.0.10-tivo

---

## 6) Optional PR workflow (recommended for auditability)

Instead of direct local merge, you can open pull requests in your fork:

1. PR 1: feature/tivo-custom-subtitles-5.0.10 -> release/5.0.10-tivo
2. Review and merge in GitHub UI

Benefits:

- Better audit trail
- Review visibility
- CI checks before merge

---

## 7) Validation checklist before finishing each release branch

Run these checks:

1. Clean working tree:

  git status --short

2. Correct branch:

  git branch

3. Recent history looks right:

  git log --oneline -n 10

4. Verify custom fix files changed as expected:

  git show --name-only --oneline HEAD

5. Run project checks as needed:

  python3 build/check.py
  python3 build/test.py --quick

If checks fail, fix before finalizing release branch.

---

## 8) Troubleshooting guide

### 8.1 Error: src refspec v5.0.5 matches more than one

Cause:

- You have both branch and tag named v5.0.5.

Verify:

  git show-ref --heads --tags | grep -E "refs/(heads|tags)/v5.0.5$"

Fix options:

1. Rename branch:

  git branch -m v5.0.5 v5.0.5-test

2. Or push explicit refs:

  git push origin refs/heads/v5.0.5:refs/heads/v5.0.5

### 8.2 Cannot cherry-pick commit from another repository

Cause:

- Commit hash not present in current repo object database.

Fix:

1. Add remote for source repo:

  git remote add tivo-oldcustom https://github.com/tivocorp/shaka-player.git

2. Fetch source branch:

  git fetch tivo-oldcustom v5.0.5-test

3. Retry cherry-pick.

### 8.3 Conflict during cherry-pick

Normal for cross-version changes.

Process:

1. Resolve conflicts file by file.
2. Stage resolved files.
3. Continue cherry-pick.

### 8.4 You accidentally edited main

If not pushed:

1. Create a feature branch immediately to save work:

  git checkout -b feature/recover-main-edits

2. Return main to upstream state carefully (manual review required).

If pushed, do not force reset blindly; coordinate with team.

---

## 9) Branch naming standard (recommended)

Use clear names:

1. release branches:
   - release/5.0.8-tivo
   - release/5.0.10-tivo
2. feature branches:
   - feature/tivo-custom-subtitles
   - feature/tivo-custom-subtitles-5.0.10
   - feature/tivo-jenkins-update

---

## 10) Suggested long-term strategy for multiple custom fixes

For each custom change, keep one dedicated feature lineage:

1. feature/tivo-custom-subtitles
2. feature/tivo-jenkins
3. feature/tivo-other-fix

At each new release:

1. Create new release branch from tag.
2. Cherry-pick latest stable commit from each feature lineage.
3. Resolve conflicts once.
4. Merge into release branch.

This keeps customizations modular and easier to maintain.

---

## 11) Fast command cheat sheet

Update main:

  git fetch upstream --tags
  git checkout main
  git merge --ff-only upstream/main
  git push origin main

Start release:

  git checkout -b release/5.0.10-tivo v5.0.10
  git push -u origin release/5.0.10-tivo

Apply subtitle fix:

  git checkout -b feature/tivo-custom-subtitles-5.0.10
  git cherry-pick -x d286f753a
  git push -u origin feature/tivo-custom-subtitles-5.0.10

Merge fix into release:

  git checkout release/5.0.10-tivo
  git merge --no-ff feature/tivo-custom-subtitles-5.0.10 -m "Merge subtitle fix for v5.0.10"
  git push -u origin release/5.0.10-tivo

---

## 12) What to do right now after reading this

1. Keep this file in the repository root.
2. Share this process with your team.
3. At next release, follow Section 5 exactly.
4. Update this manual when you add new custom fixes.

---

Maintainer note:

When you successfully resolve a conflict for a custom fix on a new Shaka version, treat that new resolved commit as the preferred source commit for future cherry-picks.