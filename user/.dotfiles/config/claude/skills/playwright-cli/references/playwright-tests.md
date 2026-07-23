# Running Playwright Tests

To run Playwright tests, use `npx playwright test` or a package manager script. Set `PLAYWRIGHT_HTML_OPEN=never` to avoid opening the interactive HTML report.

```bash
# Run all tests
PLAYWRIGHT_HTML_OPEN=never npx playwright test

# Run all tests through a custom npm script
PLAYWRIGHT_HTML_OPEN=never npm run special-test-command
```

# Debugging Playwright Tests

To debug a failing test, run it with the `--debug=cli` option. This pauses the test at the start and prints debugging instructions.

**IMPORTANT**: run the command in the background and check the output until "Debugging Instructions" is printed. Stop the command once you're finished.

Once instructions containing a session name are printed, use `playwright-cli` to attach to the session and explore the page.

```bash
# Run the test
PLAYWRIGHT_HTML_OPEN=never npx playwright test --debug=cli
# ...
# ... debugging instructions for "tw-abcdef" session ...
# ...

# Attach to the test
playwright-cli attach tw-abcdef
```

Keep the test running in the background while you explore and look for a fix. It's paused at the start, so step over or pause at the location most likely to hold the problem.

Every `playwright-cli` action generates corresponding Playwright TypeScript code, shown in the output, which you can copy directly into the test. Usually a locator or expectation needs updating, but it could also be a bug in the app — use judgement.

After fixing the test, stop the background run and rerun to confirm it passes.
