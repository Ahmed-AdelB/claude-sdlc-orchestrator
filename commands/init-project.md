---
name: init-project
description: Comprehensive project initialization and scaffolding for new repositories across frameworks like Next.js, FastAPI, Express, and similar. Use to create a new project with git init, CI/CD (GitHub Actions), pre-commit hooks, linting/formatting, testing, Docker, environment templates, README, .gitignore, and .env.example.
---

# Initialize Project

## Inputs
- Read `$ARGUMENTS` as `<framework> <project-name> [options]`
- Confirm package manager, runtime versions, database, deployment target, and license

## Workflow
1. Determine framework and stack
2. Scaffold the project
3. Initialize git and make the initial commit
4. Add linting and formatting
5. Add testing configuration
6. Add pre-commit hooks
7. Add Docker and docker-compose
8. Add environment templates
9. Generate README
10. Add `.gitignore` and `.env.example`

## Framework Scaffolds

### Next.js (React 19, TypeScript, Tailwind)
```bash
npx create-next-app@latest [name] --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"
cd [name]
pnpm add @tanstack/react-query zustand zod react-hook-form @hookform/resolvers
pnpm add -D vitest @testing-library/react @testing-library/jest-dom @playwright/test
npx shadcn@latest init
```

### React + Vite (TypeScript)
```bash
npm create vite@latest [name] -- --template react-ts
cd [name]
pnpm add @tanstack/react-query zustand zod react-hook-form @hookform/resolvers react-router-dom
pnpm add -D vitest @testing-library/react @testing-library/jest-dom @vitest/ui @playwright/test
```

### Express (TypeScript)
```bash
mkdir [name] && cd [name]
pnpm init -y
pnpm add express zod dotenv cors helmet pino
pnpm add -D typescript tsx @types/node @types/express vitest supertest @types/supertest eslint prettier
npx tsc --init
```

### FastAPI (Python)
```bash
mkdir [name] && cd [name]
python -m venv .venv
source .venv/bin/activate
cat > requirements.txt << 'EOF'
fastapi>=0.109.0
uvicorn[standard]>=0.27.0
sqlalchemy>=2.0.0
alembic>=1.13.0
pydantic>=2.5.0
pydantic-settings>=2.1.0
httpx>=0.26.0
pytest>=7.4.0
pytest-asyncio>=0.23.0
ruff>=0.1.0
EOF
pip install -r requirements.txt
```

### Other Frameworks
- Use the official CLI or generator
- Prefer TypeScript for Node backends
- Create a minimal `src/` entrypoint and wire the test runner and linter in the same way as the closest template above

## Git Initialization
- Run `git init -b main`
- Add `.gitignore` and `.env.example`
- Commit after scaffolding and tooling are in place

## Linting and Formatting

### Node/TypeScript
- Add ESLint + Prettier
- Add scripts: `lint`, `lint:fix`, `format`, `format:check`

### Python
- Use Ruff for lint + format
- Add `ruff check .` and `ruff format` scripts or Makefile targets

## Testing

### Node/TypeScript
- Use Vitest for unit tests
- Add `test`, `test:watch`, and `test:coverage` scripts
- Add Playwright if e2e tests are needed

### Python
- Use pytest + pytest-asyncio
- Add `pytest` and `pytest -q` scripts or Makefile targets

## Pre-commit Hooks

### Node/TypeScript (Husky + lint-staged)
```bash
pnpm add -D husky lint-staged
pnpm dlx husky-init && pnpm install
```

`package.json` snippet:
```json
{
  "lint-staged": {
    "*.{ts,tsx,js,jsx}": ["eslint --fix", "prettier --write"],
    "*.{md,json,yml,yaml}": ["prettier --write"]
  }
}
```

### Python (pre-commit)
```bash
pip install pre-commit
pre-commit install
```

`.pre-commit-config.yaml`:
```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.2.2
    hooks:
      - id: ruff
      - id: ruff-format
```

## CI/CD (GitHub Actions)

### Node/TypeScript CI
`.github/workflows/ci.yml`:
```yaml
name: ci
on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node: [18, 20]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
          cache: pnpm
      - run: corepack enable
      - run: pnpm install --frozen-lockfile
      - run: pnpm lint
      - run: pnpm test
      - run: pnpm build
```

### Python CI
`.github/workflows/ci.yml`:
```yaml
name: ci
on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python: ["3.11", "3.12"]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python }}
      - run: python -m pip install --upgrade pip
      - run: pip install -r requirements.txt
      - run: ruff check .
      - run: ruff format --check .
      - run: pytest -q
```

## Docker

### Node/TypeScript Dockerfile
`Dockerfile`:
```Dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY . .
RUN pnpm build
EXPOSE 3000
CMD ["pnpm", "start"]
```

### FastAPI Dockerfile
`Dockerfile`:
```Dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### docker-compose
`docker-compose.yml`:
```yaml
services:
  app:
    build: .
    ports:
      - "3000:3000"
    env_file:
      - .env
    depends_on:
      - db
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app
      POSTGRES_DB: app
    ports:
      - "5432:5432"
```

## Environment Templates

`.env.example`:
```bash
APP_ENV=development
PORT=3000
DATABASE_URL=postgresql://app:app@localhost:5432/app
```

- Copy `.env.example` to `.env` for local development
- Keep secrets out of git

## README

`README.md` template:
```md
# [Project Name]

## Overview
Describe the project and its purpose.

## Requirements
- Node [version] or Python [version]
- Package manager: pnpm/pip

## Setup
- Install dependencies
- Run the dev server

## Scripts
- `lint`
- `test`
- `build`
- `dev`

## Environment
See `.env.example`.

## Docker
- `docker compose up --build`

## License
[License]
```

## .gitignore

Generate a stack-appropriate `.gitignore` including:
- `node_modules/`, `dist/`, `.next/`, `.env`
- `.venv/`, `__pycache__/`, `.pytest_cache/`, `.ruff_cache/`
- IDE files: `.vscode/`, `.idea/`

## Completion Checklist
- Scaffolded project
- Git initialized with initial commit
- CI workflow added
- Pre-commit hooks configured
- Linting and formatting configured
- Tests configured
- Dockerfile and docker-compose created
- `.env.example` and `.gitignore` created
- README generated
