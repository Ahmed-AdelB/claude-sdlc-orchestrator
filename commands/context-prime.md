# Context Prime

Load and analyze project context to prime Claude with comprehensive understanding.

## Purpose

Establish deep project context before starting complex tasks by analyzing:
- Project structure and architecture
- Configuration files and dependencies
- Code patterns and conventions
- Documentation and README files
- Recent changes and commit history

## Process

### Step 1: Project Structure Scan

```bash
# Generate directory tree
tree -L 3 -I 'node_modules|.git|dist|build|__pycache__|*.pyc|.venv|venv' . > project_structure.txt

# Count files by type
find . -type f | grep -v node_modules | grep -v .git | sed 's/.*\.//' | sort | uniq -c | sort -rn > file_types.txt

# Calculate project metrics
cloc . --exclude-dir=node_modules,.git,dist,build --json > metrics.json
```

**Output:**
```markdown
## Project Structure

### Root Layout
[Directory tree visualization]

### File Distribution
- TypeScript: 450 files
- Python: 120 files
- Markdown: 35 files
- JSON/YAML: 28 files

### Lines of Code
- Total: 45,320 lines
- Code: 32,150 lines
- Comments: 8,940 lines
- Blank: 4,230 lines
```

### Step 2: Configuration Analysis

```markdown
## Configuration Files Detected

### Package Management
- `package.json` - Node.js project
  - Dependencies: 45 packages
  - Scripts: 12 commands
  - Version: 2.4.1

### Python Environment
- `requirements.txt` / `pyproject.toml`
  - Dependencies: 23 packages
  - Python: ^3.11

### TypeScript Configuration
- `tsconfig.json`
  - Target: ES2022
  - Module: ESNext
  - Strict: enabled

### Build Tools
- `vite.config.ts` / `webpack.config.js`
- `tailwind.config.js`

### CI/CD
- `.github/workflows/` - 3 workflows
  - ci.yml - Test & Lint
  - deploy.yml - Production deployment
  - pr-checks.yml - PR validation
```

### Step 3: Dependency Tree

```bash
# Node.js dependencies
npm list --depth=1 > dependencies.txt

# Python dependencies
pip list --format=freeze > python_deps.txt

# Analyze for vulnerabilities
npm audit --json > npm_audit.json
```

**Output:**
```markdown
## Dependency Analysis

### Critical Dependencies
- React 18.2.0
- TypeScript 5.3.3
- Vite 5.0.2
- FastAPI 0.104.1

### Security Status
- ✅ No critical vulnerabilities
- ⚠️  2 moderate vulnerabilities (non-blocking)
- 📦 Dependencies up to date: 95%
```

### Step 4: Code Pattern Detection

```bash
# Find coding patterns
grep -r "export class" src/ | wc -l  # Classes
grep -r "export function" src/ | wc -l  # Functions
grep -r "export interface" src/ | wc -l  # Interfaces
grep -r "describe(" src/ | wc -l  # Tests
```

**Output:**
```markdown
## Code Patterns

### Architecture Style
- Pattern: Modular monolith
- Language: TypeScript (primary), Python (backend)
- Framework: React + FastAPI
- State Management: Zustand
- Testing: Vitest + pytest

### Code Organization
- Classes: 45
- Functions: 320
- Interfaces: 180
- Test suites: 85

### Naming Conventions
- Files: kebab-case
- Components: PascalCase
- Functions: camelCase
- Constants: UPPER_SNAKE_CASE
```

### Step 5: Git History Analysis

```bash
# Recent development activity
git log --since="1 month ago" --pretty=format:"%h - %an, %ar : %s" --numstat | head -50

# Active contributors
git shortlog -sn --since="3 months ago"

# Hot files (frequently modified)
git log --pretty=format: --name-only --since="1 month ago" | sort | uniq -c | sort -rg | head -20
```

**Output:**
```markdown
## Development Activity

### Recent Commits (Last 30 Days)
- Total commits: 147
- Active contributors: 5
- Average commits/day: 4.9

### Most Modified Files
1. `src/auth/login.ts` - 23 changes
2. `src/api/users.ts` - 18 changes
3. `tests/auth.spec.ts` - 16 changes

### Commit Types
- feat: 45%
- fix: 30%
- refactor: 15%
- docs: 7%
- test: 3%
```

### Step 6: Documentation Extraction

```bash
# Find documentation files
find . -name "README.md" -o -name "*.md" | grep -v node_modules

# Extract API documentation
grep -r "@api" src/ --include="*.ts"

# Find TODOs and FIXMEs
grep -rn "TODO\|FIXME" src/ --include="*.ts" --include="*.py"
```

**Output:**
```markdown
## Documentation Status

### Available Documentation
- ✅ README.md (comprehensive)
- ✅ CONTRIBUTING.md
- ✅ API.md (API reference)
- ⚠️  ARCHITECTURE.md (needs update)

### API Endpoints Documented
- Authentication: 5 endpoints
- Users: 8 endpoints
- Projects: 12 endpoints

### Action Items Found
- TODO: 23 items
- FIXME: 7 items
- DEPRECATED: 3 items
```

### Step 7: Test Coverage Analysis

```bash
# Run test coverage
npm run test:coverage  # or pytest --cov

# Parse coverage report
coverage report --format=json > coverage.json
```

**Output:**
```markdown
## Test Coverage

### Overall Coverage: 78%
- Statements: 76%
- Branches: 72%
- Functions: 81%
- Lines: 78%

### Coverage by Directory
- `src/auth/` - 92% ✅
- `src/api/` - 85% ✅
- `src/utils/` - 68% ⚠️
- `src/components/` - 71% ⚠️

### Low Coverage Files (<60%)
- `src/utils/legacy.ts` - 42%
- `src/components/chart.tsx` - 55%
```

## Context Summary Output

```markdown
# Project Context Summary

## Project: [Project Name]

### Quick Stats
- **Type:** Full-stack web application
- **Tech Stack:** React + TypeScript + FastAPI
- **Lines of Code:** 45,320
- **Test Coverage:** 78%
- **Contributors:** 5 active
- **Last Updated:** 2 hours ago

### Architecture Overview
[High-level architecture description based on analysis]

### Key Components
1. **Authentication System** (`src/auth/`)
   - OAuth2 + JWT
   - 92% test coverage
   - Recently modified

2. **API Layer** (`src/api/`)
   - RESTful API with FastAPI
   - 12 endpoints documented
   - 85% test coverage

3. **Frontend** (`src/components/`)
   - React with TypeScript
   - Zustand for state management
   - Needs test coverage improvement

### Current State
- ✅ Healthy: Good test coverage, active development
- ⚠️  Attention Needed: Some low-coverage modules
- 📝 Action Items: 23 TODOs, 7 FIXMEs

### Development Focus
Based on recent commits:
1. Authentication improvements (45% of recent work)
2. User management features
3. Bug fixes in API layer

### Recommended Next Steps
1. Increase test coverage in `utils/` and `components/`
2. Address FIXMEs in critical paths
3. Update ARCHITECTURE.md documentation
4. Review and resolve deprecated code

### Context Files Generated
- `project_structure.txt` - Directory tree
- `dependencies.txt` - Dependency list
- `metrics.json` - Code metrics
- `coverage.json` - Test coverage report
```

## Usage Modes

### Quick Prime
```
/context-prime
```
Generates standard context summary (30 seconds)

### Deep Prime
```
/context-prime --deep
```
Includes dependency analysis, git history, security scan (2-3 minutes)

### Specific Component
```
/context-prime src/auth/
```
Focus context on specific directory

### Export Context
```
/context-prime --export context.md
```
Save context summary to file for sharing

## Integration with Workflows

### Before Feature Development
```bash
# Prime context
/context-prime

# Review generated summary
cat project_structure.txt

# Start feature with full context
/feature [feature description]
```

### Before Code Review
```bash
# Prime with recent changes focus
/context-prime --since="1 week ago"

# Review with context
/review PR #123
```

### Before Architecture Decision
```bash
# Deep context analysis
/context-prime --deep

# Make informed decision
/sdlc:plan [architecture change]
```

## Output Artifacts

All context files saved to `.claude-context/`:
```
.claude-context/
├── project_structure.txt
├── dependencies.txt
├── metrics.json
├── coverage.json
├── git_activity.txt
└── context_summary.md
```

## Example Usage

```
/context-prime
/context-prime --deep
/context-prime src/auth/ --export auth_context.md
/context-prime --since="1 week ago"
```

## Benefits

- **Faster Onboarding:** Understand project in minutes
- **Better Decisions:** Architecture choices based on actual state
- **Accurate Estimation:** Real metrics for planning
- **Quality Insights:** Coverage gaps and technical debt visible
- **Team Alignment:** Shared understanding of codebase
