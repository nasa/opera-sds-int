# Integration Guide: Adding DIST-S1 Test Automation to opera-sds-int

This document provides step-by-step instructions for integrating the DIST-S1 Test Automation framework into the NASA OPERA SDS Integration repository.

## Prerequisites

- Access to the `nasa/opera-sds-int` repository
- Git configured with appropriate credentials
- This test automation framework ready for integration

## Integration Steps

### Step 1: Clone the Target Repository

```bash
# Clone the NASA OPERA SDS integration repository
git clone https://github.com/nasa/opera-sds-int.git
cd opera-sds-int

# Create a new branch for the integration
git checkout -b add-dist-s1-test-automation
```

### Step 2: Examine Current Structure

```bash
# Look at the current repository structure
tree -L 2  # or ls -la to see what directories exist

# Look for existing testing directories
find . -name "*test*" -type d
find . -name "*validation*" -type d
```

### Step 3: Choose Integration Directory

Based on the existing structure, choose the most appropriate location:

**Option A: If testing directory exists**
```bash
mkdir -p testing/dist-s1-automation
```

**Option B: If tests directory exists**
```bash
mkdir -p tests/dist-s1-automation
```

**Option C: Create new testing structure**
```bash
mkdir -p testing/dist-s1-automation
```

### Step 4: Copy Files

From your current test automation directory:

```bash
# Set variables
SOURCE_DIR="/Users/rverma/TestEnv/OPERA/int"
TARGET_DIR="testing/dist-s1-automation"  # Adjust based on chosen structure

# Copy all files
cp -r "$SOURCE_DIR"/* "$TARGET_DIR"/

# Verify the copy
ls -la "$TARGET_DIR"
```

### Step 5: Update Integration-Specific Files

#### Update README.md for Integration Context

The framework includes its own README.md, but you may want to create or update a higher-level README that explains the overall testing strategy.

#### Update .gitignore (if needed)

Ensure the target repository's .gitignore includes:
```
# Environment files
.env
.env.local
.env.*.local

# Test outputs
*.csv
/tmp/
```

### Step 6: Create Repository Integration Documentation

Create a file at the root level or in a docs directory:

```bash
# Example: Update main README or create testing documentation
cat >> README.md << 'EOF'

## Testing

This repository includes comprehensive test automation for OPERA DIST-S1 products:

- **Location**: `testing/dist-s1-automation/`
- **Purpose**: End-to-end testing of DIST-S1 product generation and delivery pipeline
- **Documentation**: See [testing/dist-s1-automation/README.md](testing/dist-s1-automation/README.md)

EOF
```

### Step 7: Commit and Push

```bash
# Add all files
git add .

# Create a comprehensive commit message
git commit -m "Add DIST-S1 test automation framework

- End-to-end testing for DIST-S1 product generation and delivery
- Modular 'just' command runner architecture
- Environment variable configuration for security
- Parameterized testing with custom tiles and timestamps
- Prerequisites workflow for test parameter discovery
- Automated validation with product count verification
- SLIM best practices compliance
- Comprehensive documentation and GitHub templates

Resolves: [issue-number] (if applicable)"

# Push the branch
git push -u origin add-dist-s1-test-automation
```

### Step 8: Create Pull Request

1. Go to https://github.com/nasa/opera-sds-int
2. Create a pull request from your branch
3. Use the title: "Add DIST-S1 Test Automation Framework"
4. Include description of the testing capabilities and benefits

## Post-Integration Steps

### Update CI/CD (if applicable)

If the target repository has GitHub Actions or other CI/CD:

1. Consider adding test automation to the CI pipeline
2. Add environment variable configuration for CI runs
3. Create test jobs that validate the framework

### Documentation Integration

1. Update any higher-level documentation to reference the new testing capabilities
2. Consider adding the test automation to any developer onboarding guides
3. Update any architecture documentation to include the testing layer

### Team Communication

Notify relevant team members about:
- New testing capabilities
- How to run tests
- Environment variable requirements
- Documentation location

## Verification Checklist

After integration, verify:

- [ ] All files copied successfully
- [ ] Tests run with proper environment variables
- [ ] Documentation is accessible and clear
- [ ] Integration doesn't break existing functionality
- [ ] CI/CD integration works (if applicable)
- [ ] Team members can access and use the tests

## Troubleshooting

### Common Issues

1. **Permission errors**: Ensure you have write access to the repository
2. **Merge conflicts**: Resolve any conflicts with existing files
3. **CI failures**: Check if new files need to be added to CI configuration
4. **Documentation links**: Update any broken internal links after integration

### Getting Help

- Repository maintainers: Check CONTRIBUTORS.md or repository settings
- Documentation: See testing/dist-s1-automation/README.md
- Issues: Create GitHub issues for integration problems