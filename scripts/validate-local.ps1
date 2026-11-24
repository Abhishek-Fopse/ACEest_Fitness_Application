$ErrorActionPreference = "Stop"
python -m pytest -q -p no:cacheprovider
if ($LASTEXITCODE -ne 0) { throw "Pytest failed" }
python -m compileall -q app.py tests
if ($LASTEXITCODE -ne 0) { throw "Python compilation failed" }
$bash = "C:\Program Files\Git\bin\bash.exe"
$scripts = Get-ChildItem "scripts" -Filter "*.sh" -File

foreach ($script in $scripts) {
  Write-Host "Checking $($script.Name)"
  & $bash -n $script.FullName
  if ($LASTEXITCODE -ne 0) {
    throw "Bash syntax failed: $($script.Name)"
  }
}
python -c "import yaml,pathlib; fs=list(pathlib.Path('kubernetes').glob('*.yaml')); docs=[d for f in fs for d in yaml.safe_load_all(f.read_text(encoding='utf-8-sig')) if d is not None]; print(f'Validated {len(fs)} YAML files and {len(docs)} Kubernetes resources')"
if ($LASTEXITCODE -ne 0) { throw "YAML validation failed" }
git diff --check
if ($LASTEXITCODE -ne 0) { throw "git diff --check failed" }
Write-Host "Local validation completed."
