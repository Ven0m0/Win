Search ICM memory for: $ARGUMENTS

Run:
```bash
if [ -z "$ARGUMENTS" ]; then
  icm.exe wake-up --max-tokens 800
else
  icm.exe recall "$ARGUMENTS" --limit 10
fi
```
