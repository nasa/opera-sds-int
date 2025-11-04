#!/bin/bash

# OPERA DIST-S1 Test Automation Integration Script
# Helps integrate this test framework into the nasa/opera-sds-int repository

set -e

echo "🚀 OPERA DIST-S1 Test Automation Integration Helper"
echo "=================================================="

# Configuration
REPO_URL="https://github.com/nasa/opera-sds-int.git"
BRANCH_NAME="add-dist-s1-test-automation"
SOURCE_DIR="$(pwd)"

# Check if we're in the right directory
if [[ ! -f "justfile" ]] || [[ ! -d "dist-s1" ]]; then
    echo "❌ Error: Please run this script from the DIST-S1 test automation directory"
    echo "   (Should contain justfile and dist-s1/ directory)"
    exit 1
fi

# Get target directory from user
echo ""
echo "📁 Where should we clone the target repository?"
read -p "Target directory (default: ../opera-sds-int): " TARGET_BASE
TARGET_BASE="${TARGET_BASE:-../opera-sds-int}"

# Clone the repository
echo ""
echo "📥 Cloning nasa/opera-sds-int repository..."
if [[ -d "$TARGET_BASE" ]]; then
    echo "⚠️  Directory $TARGET_BASE already exists"
    read -p "Continue anyway? (y/N): " continue_choice
    if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
        echo "❌ Aborting"
        exit 1
    fi
else
    git clone "$REPO_URL" "$TARGET_BASE"
fi

cd "$TARGET_BASE"

# Create branch
echo ""
echo "🌿 Creating integration branch..."
git checkout -b "$BRANCH_NAME" 2>/dev/null || {
    echo "⚠️  Branch $BRANCH_NAME already exists, switching to it"
    git checkout "$BRANCH_NAME"
}

# Examine structure and suggest integration path
echo ""
echo "🔍 Examining repository structure..."
echo "Current directories:"
ls -la | grep "^d" | awk '{print "  - " $9}' | grep -v "^\.$\|^\.\.$"

# Look for existing test directories
echo ""
echo "🧪 Looking for existing test directories..."
TEST_DIRS=$(find . -maxdepth 2 -name "*test*" -o -name "*validation*" -o -name "*e2e*" | head -5)
if [[ -n "$TEST_DIRS" ]]; then
    echo "Found existing test-related directories:"
    echo "$TEST_DIRS" | sed 's/^/  - /'
else
    echo "No existing test directories found"
fi

# Get integration path from user
echo ""
echo "📂 Choose integration directory structure:"
echo "1. testing/dist-s1-automation/ (recommended)"
echo "2. tests/dist-s1-automation/"
echo "3. e2e-tests/dist-s1/"
echo "4. Custom path"

read -p "Choice (1-4, default: 1): " path_choice
path_choice="${path_choice:-1}"

case $path_choice in
    1) INTEGRATION_PATH="testing/dist-s1-automation" ;;
    2) INTEGRATION_PATH="tests/dist-s1-automation" ;;
    3) INTEGRATION_PATH="e2e-tests/dist-s1" ;;
    4)
        read -p "Enter custom path: " INTEGRATION_PATH
        ;;
    *)
        echo "Invalid choice, using default"
        INTEGRATION_PATH="testing/dist-s1-automation"
        ;;
esac

# Create directory and copy files
echo ""
echo "📋 Creating integration directory: $INTEGRATION_PATH"
mkdir -p "$INTEGRATION_PATH"

echo "📁 Copying test automation files..."
cp -r "$SOURCE_DIR"/* "$INTEGRATION_PATH"/

# Remove the integration helper files from the target
rm -f "$INTEGRATION_PATH/integrate.sh"
rm -f "$INTEGRATION_PATH/INTEGRATION.md"

echo "✅ Files copied successfully"

# Update .gitignore if needed
echo ""
echo "📝 Checking .gitignore..."
if [[ -f ".gitignore" ]]; then
    if ! grep -q "\.env" .gitignore; then
        echo "" >> .gitignore
        echo "# DIST-S1 Test Automation" >> .gitignore
        echo ".env" >> .gitignore
        echo ".env.local" >> .gitignore
        echo ".env.*.local" >> .gitignore
        echo "*.csv" >> .gitignore
        echo "/tmp/" >> .gitignore
        echo "✅ Updated .gitignore"
    else
        echo "✅ .gitignore already contains relevant entries"
    fi
else
    echo "⚠️  No .gitignore found, consider creating one"
fi

# Show summary
echo ""
echo "🎉 Integration Complete!"
echo "======================="
echo "Location: $INTEGRATION_PATH"
echo "Files integrated:"
ls -la "$INTEGRATION_PATH" | grep -v "^total\|^\.$\|^\.\.$" | awk '{print "  - " $9}'

echo ""
echo "📋 Next Steps:"
echo "1. Review the integrated files: cd $INTEGRATION_PATH"
echo "2. Test the integration: just dist-s1::e2e-with-product-id-time::sds-get-product-count"
echo "3. Commit the changes: git add . && git commit -m 'Add DIST-S1 test automation framework'"
echo "4. Push the branch: git push -u origin $BRANCH_NAME"
echo "5. Create a pull request on GitHub"

echo ""
echo "📖 Documentation:"
echo "- Framework docs: $INTEGRATION_PATH/README.md"
echo "- Integration guide: $SOURCE_DIR/INTEGRATION.md"

echo ""
echo "✨ Integration helper completed successfully!"