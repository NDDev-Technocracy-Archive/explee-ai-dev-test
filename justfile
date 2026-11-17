set shell := ["bash", "-euo", "pipefail", "-c"]
set positional-arguments

# List the maintained correctness and workflow-source commands.
default:
    @just --list

# Prepare the hash-locked CI tools without building or installing the application.
setup-checks python="python3":
    uv venv --python "$1" --no-python-downloads .venv
    uv pip install --python .venv/bin/python --require-hashes --only-binary=:all: -r requirements-ci.txt

# Regenerate the CI tool lock from its existing direct version selections.
lock-checks python="python3":
    uv pip compile requirements-ci.in --python "$1" --no-python-downloads --no-build --generate-hashes --custom-compile-command 'just lock-checks' --output-file requirements-ci.txt

# Check the complete retained source, types, consistency and workflow scope offline.
check:
    just --fmt --check
    .venv/bin/ruff check .
    .venv/bin/pyright --pythonpath .venv/bin/python
    .venv/bin/python -B tools/repo_checks.py consistency
    actionlint
    zizmor --offline --no-progress .github/workflows

# Run the original blocking unit and acceptance commands on an admitted executor.
test:
    .venv/bin/pytest tests/ -q
    .venv/bin/python -B tools/repo_checks.py acceptance

# Run all retained correctness commands.
verify: check test

# Preserve original PR-range or complete-history workflow-source secrets.
audit-workflows scope="--all":
    just --fmt --check
    actionlint
    zizmor --offline --no-progress .github/workflows
    betterleaks git --no-banner --redact "--log-opts=$1" .

# Format the maintained command source.
fix:
    just --fmt
