update topgrade with a global uv pip update: `uv pip freeze | ForEach-Object { ($_ -split '==')[0] } | uv pip install -U -r -`
