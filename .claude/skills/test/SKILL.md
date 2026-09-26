---
name: test
description: >-
  Run the project's test suite and report results concisely. Use when asked to
  run tests, verify a change, or check whether things still pass.
---

Run the project's tests and summarise the outcome.

1. **Find the test setup from the repo**, don't assume one. Look for the
   build/test config — `Package.swift` / `xcodebuild` for Swift, `package.json`
   scripts for Node, `pyproject.toml` / `pytest` for Python, etc. — and use the
   project's own runner.
2. **Run the suite**, or the subset named in the request.
3. **Report concisely:** what passed, what failed, and for each failure the test
   name plus the one-line reason — not the full log. Quote only the lines that
   explain the failure.
4. If nothing runnable exists yet, say so and stop — don't scaffold a test setup
   unless asked.
