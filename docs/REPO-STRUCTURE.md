# Repository Structure

## What's in this repo

```
bhkey/
├── bhkey.sh                  # Core script — the entire tool
├── install.sh                # One-line installer (downloads from GitHub Releases)
│
├── README.md                 # English README (default)
├── README.ko.md              # Korean README
├── README.zh.md              # Chinese (Simplified) README
│
├── LICENSE                   # MIT License
├── CHANGELOG.md              # Version history
├── CONTRIBUTING.md           # How to contribute
├── SECURITY.md               # How to report security vulnerabilities
├── CODE_OF_CONDUCT.md        # Community standards
├── DECISIONS.md              # Architecture decisions (why, not just what)
│
├── docs/
│   ├── ARCHITECTURE.md       # How bhkey works internally
│   ├── CUSTOMIZE.md          # How to change key mappings
│   ├── KEYBOARDS.md          # Known keyboard VendorID/ProductID profiles
│   ├── CHECKLIST.md          # Manual pre-flight checklist
│   └── DEMO.tape             # VHS script for recording the demo GIF
│
└── .github/
    ├── workflows/
    │   ├── ci.yml            # shellcheck on every push and PR
    │   └── release.yml       # Auto-release on version tag push
    ├── ISSUE_TEMPLATE/       # Bug report / feature request templates
    ├── pull_request_template.md
    └── FUNDING.yml           # GitHub Sponsors
```

## What is NOT in this repo

The following files exist locally but are excluded via `.gitignore`.
They are internal to the maintainer's development environment.

| File / Directory | Reason excluded |
|---|---|
| `CLAUDE.md` | AI assistant instructions (internal workflow, not relevant to users) |
| `SESSION-LOG.md` | Development session notes (internal dev log) |
| `TODO.md` | Internal task list (tracked separately) |
| `docs/superpowers/` | AI skill documentation (internal tooling) |
| `gstack-garryTan/` | Research notes unrelated to bhkey |
| `.playwright-mcp/` | Browser automation cache (local tool artifact) |
| `.DS_Store`, `*.swp` | macOS/editor artifacts |

## Decision Principle

> **Public** = useful to users or contributors, or needed to understand the project  
> **Private** = internal to the maintainer's workflow, unrelated to bhkey's purpose

If you're contributing and notice something that should or shouldn't be public, open an issue.
