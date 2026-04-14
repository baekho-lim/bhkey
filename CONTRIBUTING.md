# Contributing to bhkey

Thank you for your interest in contributing!

## Getting Started

```bash
git clone https://github.com/baekho-lim/bhkey.git
cd bhkey
chmod +x bhkey.sh
```

No build step required — it's a single bash script.

## Testing Your Changes

```bash
# Syntax check (requires shellcheck)
shellcheck bhkey.sh

# Functional test (connects external keyboard first)
bash bhkey.sh apply
bash bhkey.sh status
bash bhkey.sh reset
```

## Submitting a PR

1. Fork the repo
2. Create a branch: `git checkout -b fix/your-fix`
3. Make changes in `bhkey.sh` (and update `docs/` if needed)
4. Verify `shellcheck bhkey.sh` passes
5. Open a PR with a clear description of what and why

## Adding Keyboard Support

If you want to add your keyboard's default mapping:

1. Find your `VendorID` and `ProductID` via `bash bhkey.sh status`
2. Add an entry to `docs/KEYBOARDS.md`
3. Open a PR — no code change needed for keyboard profiles

## Code Style

- POSIX-compatible bash where possible
- All functions documented with `# ===` section headers
- Error messages via `log_error()`, warnings via `log_warn()`
- No external dependencies beyond `hidutil`, `launchctl`, `plutil`
