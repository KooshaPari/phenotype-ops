# phenotype-ops — Justfile
# Task runner for common operations

# ── Meta ────────────────────────────────────────────────────────────────────
default: help

# ── Build ───────────────────────────────────────────────────────────────────
# Build the manifest CLI (debug)
build:
    cargo build --manifest-path tools/phenotype-manifest/Cargo.toml

# Build the manifest CLI (release)
build-release:
    cargo build --release --manifest-path tools/phenotype-manifest/Cargo.toml

# ── Test ────────────────────────────────────────────────────────────────────
# Run all tests (requires cargo-nextest)
test:
    cargo nextest run --manifest-path tools/phenotype-manifest/Cargo.toml --all-targets --all-features

# Run unit tests only
test-unit:
    cargo nextest run --manifest-path tools/phenotype-manifest/Cargo.toml --lib

# ── Lint ────────────────────────────────────────────────────────────────────
# Format check
fmt:
    cargo fmt --manifest-path tools/phenotype-manifest/Cargo.toml --all -- --check

# Format fix
fmt-fix:
    cargo fmt --manifest-path tools/phenotype-manifest/Cargo.toml --all

# Clippy
clippy:
    cargo clippy --manifest-path tools/phenotype-manifest/Cargo.toml --all-targets --all-features -- -D warnings

# Spellcheck (Markdown + Rust docs)
spellcheck:
    codespell --skip="./target,./.git,./agent-devops-setups" --ignore-words=templates/codespell-ignore.txt

# ── Manifests ───────────────────────────────────────────────────────────────
# Generate attestation manifest
manifest-generate key="~/.ssh/manifest":
    phenotype-manifest generate \
        --key {{key}} \
        --output .manifest.signed.json \
        --require-all-pillars \
        --fail-below 0.90 \
        --max-age-hours 24

# Verify attestation manifest
manifest-verify manifest=".manifest.signed.json" pubkey=".github/manifest.pubkey.pem":
    phenotype-manifest verify \
        --manifest {{manifest}} \
        --pubkey {{pubkey}} \
        --require-all-pillars \
        --min-health-score 0.90 \
        --max-age-hours 24

# ── Review Surface ──────────────────────────────────────────────────────────
# Install review-surface deps
review-install:
    cd review-surface && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt

# Run review surface dev server
review-dev port="8000":
    cd review-surface && .venv/bin/uvicorn main:app --reload --port {{port}}

# ── CI Simulation ───────────────────────────────────────────────────────────
# Full CI check (local)
ci-check: fmt clippy test

# ── Governance ──────────────────────────────────────────────────────────────
# Install lefthook hooks
hooks-install:
    lefthook install

# Copy governance templates to repo root (for fleet repos)
install-templates:
    cp governance/CLAUDE.base.md CLAUDE.md
    cp governance/AGENTS.base.md AGENTS.md
    cp templates/deny.toml deny.toml
    cp templates/codespell-ignore.txt .github/codespell-ignore.txt

# ── Clean ───────────────────────────────────────────────────────────────────
# Clean build artifacts
clean:
    cargo clean --manifest-path tools/phenotype-manifest/Cargo.toml

# ── Help ────────────────────────────────────────────────────────────────────
help:
    @just --list
