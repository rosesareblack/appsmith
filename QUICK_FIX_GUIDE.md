# Quick Fix Guide - Pre-Flight Optimization

## 🔴 Critical Fixes (Do These First)

### 1. Fix Node.js Version
```bash
# You have: v22.20.0
# You need: v20.11.1

nvm install 20.11.1
nvm use 20.11.1
nvm alias default 20.11.1

# Verify
node --version  # Should show: v20.11.1
```

### 2. Fix Java Version
```bash
# You have: Java 21
# You need: Java 17

sudo apt-get update
sudo apt-get install -y openjdk-17-jdk

# Set as default
sudo update-alternatives --config java
# Select: /usr/lib/jvm/java-17-openjdk-amd64/bin/java

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> ~/.bashrc

# Verify
java --version  # Should show: openjdk 17.x.x
```

### 3. Install Gitleaks (Secret Scanner)
```bash
wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz
tar -xzf gitleaks_8.18.0_linux_x64.tar.gz
sudo mv gitleaks /usr/local/bin/
rm gitleaks_8.18.0_linux_x64.tar.gz

# Verify
gitleaks version
```

## 🟡 Post-Fix Setup

### 4. Install Client Dependencies
```bash
cd /workspace/app/client

# Enable Yarn Berry (v3.5.1)
corepack enable

# Install dependencies
yarn install --immutable

# Initialize Husky hooks
yarn init-husky
```

### 5. Verify Everything Works
```bash
cd /workspace/app/client

# Run linters
yarn lint

# Check formatting
yarn prettier

# Type check
yarn check-types

# Run tests
yarn test:unit

# Build
yarn build
```

### 6. Test Server Build
```bash
cd /workspace/app/server

# Build (skip tests for quick check)
mvn clean package -DskipTests

# Run tests
mvn test

# Run integration tests
mvn verify
```

## ✅ Pre-Commit Test

```bash
# Test pre-commit hooks work
cd /workspace/app/client
echo "// test" >> src/test-file.ts
git add src/test-file.ts
git commit -m "test: pre-commit hooks"
# Should run ESLint, Prettier, and gitleaks

# Clean up
git reset HEAD~1
rm src/test-file.ts
```

## 📊 Verify Status

```bash
# Quick status check
cd /workspace

echo "=== Runtime Versions ==="
node --version      # Should be: v20.11.1
java --version      # Should be: openjdk 17.x.x
yarn --version      # Should be: 3.5.1
mvn --version       # Should be: 3.9.9
gitleaks version    # Should be: 8.18.0 or higher

echo -e "\n=== Dependencies ==="
test -d app/client/node_modules && echo "✅ node_modules exists" || echo "❌ node_modules missing"

echo -e "\n=== Git Status ==="
git status --short

echo -e "\n=== Ready? ==="
if [ -d app/client/node_modules ] && \
   [ "$(node --version)" = "v20.11.1" ] && \
   command -v gitleaks &> /dev/null; then
    echo "🚀 ALL SYSTEMS GO!"
else
    echo "⚠️  Still have issues to fix"
fi
```

## 🐛 Troubleshooting

### Issue: "Corepack is not enabled"
```bash
corepack enable
```

### Issue: "The current Node version does not satisfy..."
```bash
nvm use 20.11.1
```

### Issue: "Maven not found" (Already fixed)
```bash
# Already installed Maven 3.9.9 during check
mvn --version
```

### Issue: Pre-commit hooks not running
```bash
cd /workspace/app/client
yarn init-husky
chmod +x .husky/pre-commit
```

### Issue: Gitleaks command not found
```bash
# Check if installed
which gitleaks

# If not found, install (see step 3 above)
```

## ⏱️ Estimated Time

- Fix Node.js: 2 minutes
- Fix Java: 3 minutes  
- Install gitleaks: 1 minute
- Install dependencies: 5-10 minutes
- Run verification: 5-10 minutes

**Total: 15-30 minutes**

## 📝 Notes

1. **Node Version**: The `.nvmrc` file specifies `v20.11.1` - this is the source of truth
2. **Java Version**: The `pom.xml` specifies Java 17 - don't use Java 21
3. **Yarn Version**: Project uses Yarn Berry (v3.5.1) via corepack, not classic Yarn
4. **Gitignore**: Already fixed - Java `target/` directories added
5. **CI/CD**: GitHub Actions workflows are properly configured (42 workflows found)

## 🔗 Related Files

- Full report: `/workspace/PRE_FLIGHT_OPTIMIZATION_REPORT.md`
- .nvmrc: `/workspace/app/client/.nvmrc`
- package.json: `/workspace/app/client/package.json`
- pom.xml: `/workspace/app/server/pom.xml`
- .gitignore: `/workspace/.gitignore` (updated)

---

**After completing these fixes, read the full report for additional recommendations and details.**
