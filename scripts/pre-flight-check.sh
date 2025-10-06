#!/usr/bin/env bash
# Pre-Flight Check Script for Appsmith
# Run this before committing to ensure the CI gate will pass
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

FAILED_CHECKS=0
WARNINGS=0

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛫 APPSMITH PRE-FLIGHT CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Helper functions
check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
}

check_fail() {
    echo -e "${RED}❌ $1${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
}

check_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    WARNINGS=$((WARNINGS + 1))
}

check_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# ---------- LANGUAGE VERSIONS ----------
echo "📦 Checking runtime versions..."

# Node.js
NODE_EXPECTED=$(cat app/client/.nvmrc)
NODE_ACTUAL="v$(node -v | cut -d'v' -f2)"
if [[ "$NODE_ACTUAL" == "$NODE_EXPECTED" ]]; then
    check_pass "Node.js $NODE_ACTUAL matches .nvmrc"
else
    check_fail "Node.js version mismatch: Expected $NODE_EXPECTED, got $NODE_ACTUAL"
    echo "   Fix: nvm install $NODE_EXPECTED && nvm use $NODE_EXPECTED"
fi

# Java
JAVA_EXPECTED=$(grep -oP '<java\.version>\K[^<]+' app/server/pom.xml | head -1)
JAVA_ACTUAL=$(java -version 2>&1 | head -n1 | grep -oP '\d+\.\d+' | head -1)
if [[ "$JAVA_ACTUAL" == "$JAVA_EXPECTED" ]]; then
    check_pass "Java $JAVA_ACTUAL matches pom.xml"
else
    check_fail "Java version mismatch: Expected $JAVA_EXPECTED, got $JAVA_ACTUAL"
    echo "   Fix: sudo update-alternatives --config java"
fi

# Yarn
cd app/client
corepack enable 2>/dev/null || true
YARN_ACTUAL=$(yarn --version)
if [[ "$YARN_ACTUAL" =~ ^3\. ]]; then
    check_pass "Yarn $YARN_ACTUAL (Berry)"
else
    check_fail "Yarn version mismatch: Expected v3.x, got $YARN_ACTUAL"
    echo "   Fix: corepack enable"
fi
cd ../..

# Maven
if command -v mvn &> /dev/null; then
    MVN_VERSION=$(mvn -v | head -n1 | grep -oP '\d+\.\d+\.\d+')
    check_pass "Maven $MVN_VERSION"
else
    check_fail "Maven not installed"
    echo "   Fix: sudo apt-get install maven"
fi

echo ""

# ---------- SECURITY ----------
echo "🔒 Checking security tools..."

# Gitleaks
if command -v gitleaks &> /dev/null; then
    check_pass "gitleaks $(gitleaks version | head -n1)"
    
    echo "   Running gitleaks scan..."
    if gitleaks detect --source . --verbose --no-git 2>&1 | grep -q "No leaks found"; then
        check_pass "No secrets detected"
    else
        check_fail "Secrets detected in codebase!"
    fi
else
    check_fail "gitleaks not installed (required by pre-commit hooks)"
    echo "   Fix: brew install gitleaks"
    echo "   Or: wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz"
fi

# Check for .env files
if git ls-files | grep -E '^\.env$|/\.env$' | grep -v '\.env\.example' > /dev/null; then
    check_fail ".env file is committed (should be in .gitignore)"
else
    check_pass "No .env files committed"
fi

echo ""

# ---------- DEPENDENCIES ----------
echo "📚 Checking dependencies..."

# Client dependencies
cd app/client
if [ ! -d "node_modules" ]; then
    check_fail "node_modules not found"
    echo "   Fix: cd app/client && yarn install"
else
    check_pass "node_modules exists"
    
    # Check for unused deps (quick check)
    if command -v depcheck &> /dev/null; then
        check_info "Running depcheck (may take a moment)..."
        if npx depcheck --ignores="@types/*,@testing-library/*,eslint*,prettier,husky,lint-staged" --skip-missing 2>&1 | grep -q "Unused dependencies"; then
            check_warn "Unused dependencies found (run: npx depcheck for details)"
        else
            check_pass "No unused dependencies detected"
        fi
    fi
fi
cd ../..

# Server dependencies
cd app/server
if [ -d "target" ]; then
    check_info "Maven target/ directory exists (build artifacts present)"
fi
cd ../..

echo ""

# ---------- GIT HYGIENE ----------
echo "🧹 Checking git hygiene..."

# Lock files
if git diff --exit-code app/client/yarn.lock > /dev/null 2>&1; then
    check_pass "yarn.lock is clean"
else
    check_fail "yarn.lock has uncommitted changes"
    echo "   Commit your changes or run: git checkout app/client/yarn.lock"
fi

if git diff --exit-code app/server/pom.xml > /dev/null 2>&1; then
    check_pass "pom.xml is clean"
else
    check_fail "pom.xml has uncommitted changes"
fi

# Gitignore
if grep -q "node_modules" .gitignore; then
    check_pass "node_modules in .gitignore"
else
    check_fail "node_modules not in .gitignore"
fi

if grep -q "target" .gitignore; then
    check_pass "target/ in .gitignore"
else
    check_fail "Java target/ not in .gitignore"
fi

echo ""

# ---------- CONFIGURATION ----------
echo "⚙️  Checking project configuration..."

# EditorConfig
if [ -f ".editorconfig" ]; then
    check_pass ".editorconfig present"
else
    check_fail ".editorconfig missing"
fi

# .env.example
if [ -f ".env.example" ]; then
    check_pass ".env.example present"
else
    check_fail ".env.example missing"
fi

# Husky
if [ -f "app/client/.husky/pre-commit" ]; then
    check_pass "Husky pre-commit hook configured"
else
    check_fail "Husky pre-commit hook missing"
    echo "   Fix: cd app/client && yarn init-husky"
fi

# TypeScript strict mode
if grep -q '"strict":\s*true' app/client/tsconfig.json; then
    check_pass "TypeScript strict mode enabled"
else
    check_fail "TypeScript strict mode not enabled"
fi

# CI workflows
WORKFLOW_COUNT=$(find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null | wc -l)
if [ "$WORKFLOW_COUNT" -gt 0 ]; then
    check_pass "$WORKFLOW_COUNT CI/CD workflows configured"
else
    check_fail "No CI/CD workflows found"
fi

echo ""

# ---------- SUMMARY ----------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}🚀 ALL CHECKS PASSED${NC}"
    echo ""
    echo "✅ Safe to commit and push"
    echo ""
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $WARNINGS warnings (non-blocking)${NC}"
        echo ""
    fi
    exit 0
else
    echo -e "${RED}❌ $FAILED_CHECKS CHECKS FAILED${NC}"
    echo ""
    echo "Fix the issues above before committing"
    echo ""
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $WARNINGS warnings${NC}"
        echo ""
    fi
    exit 1
fi
