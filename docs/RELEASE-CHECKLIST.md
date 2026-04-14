# Release Checklist

## One-Time Setup (first release only)

Complete these once after the initial public release.

- [ ] Record demo GIF: connect keyboard → `vhs docs/DEMO.tape` → commit `docs/demo.gif`
- [ ] Insert demo GIF into README x3 (EN/KO/ZH): `![Demo](docs/demo.gif)`
- [ ] Upload social preview image: GitHub repo → Settings → Social preview (1280×640)
- [ ] Register GitHub Sponsors: github.com/sponsors (review required) — FUNDING.yml already in place
- [ ] Set homepage URL: GitHub repo → About → Website (once a project page exists)
- [ ] Set `HOMEBREW_TAP_TOKEN` secret in repo Settings → Secrets (enables tap auto-update on future releases)

---

## Every Release

### 1. Pre-release (local)

- [ ] All changes committed and pushed to `main`
- [ ] `shellcheck bhkey.sh` passes with no warnings
- [ ] Tested: `bash bhkey.sh apply` / `status` / `reset` on target macOS version
- [ ] `CHANGELOG.md` updated with new version section
- [ ] Version string bumped in `bhkey.sh` (`BHKEY_VERSION`)

### 2. Tag and release

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

This triggers `release.yml` which automatically:
- Runs shellcheck
- Creates the GitHub Release with `bhkey.sh` as a downloadable asset
- Updates `Formula/bhkey.rb` in the Homebrew tap (requires `HOMEBREW_TAP_TOKEN` secret)

### 3. Post-release verification

- [ ] GitHub Release page shows the new tag and `bhkey.sh` asset
- [ ] `brew upgrade bhkey` works (wait ~5 min for tap to update)
- [ ] `curl -L .../releases/latest/download/bhkey.sh` downloads the new version
- [ ] CI badge on README shows green

### 4. Announce (optional)

- [ ] GitHub Discussions — post release note
- [ ] Close any resolved issues with the release tag

---

## SemVer Guide

| Change type | Version bump | Example |
|---|---|---|
| Bug fix | PATCH | `1.0.0` → `1.0.1` |
| New feature, backward compatible | MINOR | `1.0.0` → `1.1.0` |
| Breaking change | MAJOR | `1.0.0` → `2.0.0` |
