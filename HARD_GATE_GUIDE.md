# 🛫 Pre-Flight Hard Gate - Implementation Guide

## Overview

This repository now has a **hard gate** that enforces every critical pre-flight check automatically. No PR can be merged unless all checks pass.

## What the Gate Enforces

### 🔒 **Critical (Will Block PRs)**

1. ✅ **Runtime Versions Match**
   - Node.js: v20.11.1 (from `app/client/.nvmrc`)
   - Java: 17 (from `app/server/pom.xml`)
   - Yarn: 3.5.1+ Berry (from `app/client/package.json`)

2. ✅ **Security**
   - Gitleaks installed and scan passes
   - No `.env` files committed
   - All secrets in `.env.example` only

3. ✅ **Dependencies Clean**
   - `yarn.lock` committed and up-to-date
   - No unused dependencies (via depcheck)
   - No duplicate dependencies

4. ✅ **Git Hygiene**
   - `node_modules/` in `.gitignore`
   - `**/target/` in `.gitignore`
   - No uncommitted lock file changes

5. ✅ **Configuration Present**
   - `.editorconfig` exists
   - `.env.example` exists
   - Husky pre-commit hooks configured
   - TypeScript strict mode enabled
   - CI/CD workflows configured

## Quick Start

### 0️⃣ **One-Command Fix** (First Time Setup)

If this is your first time or you need to fix critical issues:

```bash
./scripts/fix-critical-issues.sh
```

This automatically fixes:
- ✅ Node.js version (to v20.11.1)
- ✅ Java version (to 17)
- ✅ gitleaks installation

**See [ONE_COMMAND_FIX.md](ONE_COMMAND_FIX.md) for details.**

### 1️⃣ Run Local Check (Before Every Push)

```bash
# Make executable (first time only)
chmod +x scripts/pre-flight-check.sh

# Run the check
./scripts/pre-flight-check.sh

# Or via yarn
cd app/client && yarn pre-flight
```

**Expected Output:**
```
🛫 APPSMITH PRE-FLIGHT CHECK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📦 Checking runtime versions...
✅ Node.js v20.11.1 matches .nvmrc
✅ Java 17 matches pom.xml
✅ Yarn 3.5.1 (Berry)
✅ Maven 3.9.9

🔒 Checking security tools...
✅ gitleaks 8.18.0
✅ No secrets detected
✅ No .env files committed

... (more checks)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 ALL CHECKS PASSED
✅ Safe to commit and push
```

### 2️⃣ Fix Any Issues

The script will tell you exactly what to fix:

```bash
❌ Node.js version mismatch: Expected v20.11.1, got v22.20.0
   Fix: nvm install v20.11.1 && nvm use v20.11.1
```

### 3️⃣ CI Automatically Runs the Gate

Once you push, `.github/workflows/pre-flight-gate.yml` runs automatically and enforces all checks.

## CI Gate Workflow

The gate runs on:
- ✅ All pull requests
- ✅ Pushes to `master` branch
- ✅ Pushes to `release` branch

**Status Check Name:** `pre-flight-gate / gate`

## Fix Common Issues

### ❌ Node Version Mismatch

```bash
# Current: v22.20.0
# Need: v20.11.1

nvm install v20.11.1
nvm use v20.11.1
nvm alias default v20.11.1

# Verify
node --version  # Should show v20.11.1
```

### ❌ Java Version Mismatch

```bash
# Current: Java 21
# Need: Java 17

# Ubuntu/Debian
sudo apt-get install openjdk-17-jdk
sudo update-alternatives --config java  # Select Java 17

# Verify
java -version  # Should show openjdk 17.x.x
```

### ❌ Gitleaks Not Installed

```bash
# macOS
brew install gitleaks

# Linux
wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz
tar -xzf gitleaks_8.18.0_linux_x64.tar.gz
sudo mv gitleaks /usr/local/bin/
rm gitleaks_8.18.0_linux_x64.tar.gz

# Verify
gitleaks version
```

### ❌ Yarn Version Wrong

```bash
cd app/client

# Enable Yarn Berry via corepack
corepack enable

# Verify
yarn --version  # Should show 3.5.1
```

### ❌ Dependencies Not Installed

```bash
cd app/client
corepack enable
yarn install --immutable

# Back to root
cd ../..
```

### ❌ Unused Dependencies

```bash
cd app/client

# Find unused dependencies
npx depcheck --skip-missing

# Remove them from package.json
# Then reinstall
yarn install
```

### ❌ Duplicate Dependencies

```bash
cd app/client

# Fix duplicates
yarn dedupe

# Commit the updated lock file
git add yarn.lock
git commit -m "chore: deduplicate dependencies"
```

### ❌ Lock File Has Changes

```bash
# If yarn.lock changed after yarn install:
cd app/client
git add yarn.lock
git commit -m "chore: update yarn.lock"

# If it shouldn't have changed:
git checkout app/client/yarn.lock
```

### ❌ target/ Not in .gitignore

```bash
# Already fixed - this is in .gitignore now
grep "target" .gitignore
```

## One-Command Fix (Fresh Setup)

**NEW:** We have an automated script that fixes everything!

```bash
# Fix all 3 critical issues automatically
./scripts/fix-critical-issues.sh

# Then install dependencies
cd app/client
corepack enable
yarn install --immutable
yarn init-husky
cd ../..

# Verify everything is good
./scripts/pre-flight-check.sh
```

**Or use the yarn shortcut:**

```bash
cd app/client && yarn fix:critical
```

See **[ONE_COMMAND_FIX.md](ONE_COMMAND_FIX.md)** for complete details.

## Enable Required Status Check (Repo Admin)

To make the gate **required** (block merges on failure):

1. Go to: **Settings** → **Branches** → **master**
2. Click: **Add branch protection rule**
3. Enable: ☑️ **Require status checks to pass before merging**
4. Search and select: **pre-flight-gate / gate**
5. Enable: ☑️ **Require branches to be up to date before merging**
6. Click: **Save changes**

Now **no PR can be merged** unless the gate passes ✅

## What Happens When Gate Fails

### In CI:
```
❌ pre-flight-gate / gate
   
   Node version mismatch
   Expected: v20.11.1
   Actual: v22.20.0
```

### In Your PR:
- ❌ Red X next to status check
- 🚫 "Merge" button disabled
- 📝 Comment from bot with error details

### Fix and Re-run:
1. Fix the issue locally
2. Commit and push
3. CI re-runs automatically
4. ✅ Green checkmark appears
5. 🎉 "Merge" button enabled

## Pre-Flight vs Other Checks

This gate is **separate from** but **complements**:

| Check | What It Does | When It Runs |
|-------|--------------|--------------|
| **pre-flight-gate** | Environment setup, versions, deps | Every PR/push |
| **client-lint** | ESLint checks | Every PR/push |
| **client-prettier** | Code formatting | Every PR/push |
| **client-build** | Production build | Every PR/push |
| **client-unit-tests** | Jest tests | Every PR/push |
| **server-build** | Maven build | Every PR/push |
| **server-spotless** | Java formatting | Every PR/push |

All must pass ✅ for merge to be allowed.

## Benefits

### 🎯 **For Developers**
- Know locally if PR will pass CI
- Fast feedback (< 2 minutes)
- Clear fix instructions

### 🛡️ **For Repo**
- Enforce version consistency
- Prevent dependency bloat
- Block security issues
- Maintain git hygiene

### 🚀 **For Team**
- No more "works on my machine"
- No more forgotten dependency updates
- No more version drift
- No more security scan failures

## Troubleshooting

### Gate Passed Locally But Failed in CI

**Cause:** CI uses clean environment; your local might have cached state

**Fix:**
```bash
# Clean everything
cd app/client
rm -rf node_modules .yarn/cache
yarn install --immutable

# Re-run local check
cd ../..
./scripts/pre-flight-check.sh
```

### False Positive on "Unused Dependencies"

Some dependencies are only used in specific environments (dev, test, build).

**Temporary Fix:** Add to `depcheck` ignore list in workflow:
```yaml
--ignores="your-package-name"
```

**Proper Fix:** Ensure package is actually used or remove it.

### Gitleaks False Positive

If gitleaks flags a false positive:

**Option 1:** Add to `.gitleaksignore`:
```
# False positive: test fixture
test/fixtures/fake-key.js:1
```

**Option 2:** Use inline comment:
```javascript
const apiKey = "fake-key-for-testing"; // gitleaks:allow
```

## Summary

✅ **One local script** - `./scripts/pre-flight-check.sh`  
✅ **One CI workflow** - `.github/workflows/pre-flight-gate.yml`  
✅ **Zero tolerance** - All checks must pass  
✅ **Clear fixes** - Every error shows how to resolve  

**Result:** Repository stays in "READY TO COMMIT" state 24/7 🚀

---

## Quick Reference

```bash
# Check if ready to commit
./scripts/pre-flight-check.sh

# Fix Node version
nvm use v20.11.1

# Fix dependencies
cd app/client && yarn install && cd ../..

# Fix duplicates
cd app/client && yarn dedupe && cd ../..

# Install gitleaks
brew install gitleaks  # macOS

# Check CI status
gh pr checks  # GitHub CLI
```

---

*Questions? Check the [PRE_FLIGHT_OPTIMIZATION_REPORT.md](PRE_FLIGHT_OPTIMIZATION_REPORT.md) for detailed findings.*
