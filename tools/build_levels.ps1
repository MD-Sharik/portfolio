<#
 Parallel level build: splits the levels into chunks, generates them in several Godot processes,
 merges the parts into data/levels.json + data/layouts.bin and verifies the result.

   powershell -ExecutionPolicy Bypass -File tools/build_levels.ps1 [-Count 1000] [-Jobs 8] [-Chunk 50] [-Godot path\to\godot_console.exe]
#>
param(
  [int]$Count = 1000,
  [int]$Jobs = [Math]::Max(1, [Environment]::ProcessorCount),
  [int]$Chunk = 50,
  [string]$Godot = ""
)
$ErrorActionPreference = "Stop"
$proj = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
  $found = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "Godot*console*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($found) { $Godot = $found.FullName } else { $Godot = "godot" }
}
$tmp = Join-Path $env:TEMP "arrow_escape_parts"
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $tmp | Out-Null

# heavy (late, huge) chunks first so the cores stay busy until the end
$chunks = @()
for ($a = 1; $a -le $Count; $a += $Chunk) { $chunks += ,@($a, [Math]::Min($Count, $a + $Chunk - 1)) }
[array]::Reverse($chunks)

$running = @()
$sw = [Diagnostics.Stopwatch]::StartNew()
foreach ($c in $chunks) {
  while (@($running | Where-Object { -not $_.HasExited }).Count -ge $Jobs) { Start-Sleep -Milliseconds 500 }
  $part = Join-Path $tmp ("part_{0:0000}_{1:0000}.json" -f $c[0], $c[1])
  $log = Join-Path $tmp ("log_{0:0000}.txt" -f $c[0])
  $args = @("--headless","--path","`"$proj`"","--script","res://tools/level_maker.gd","--","--from",$c[0],"--to",$c[1],"--part","`"$part`"")
  $running += Start-Process -FilePath $Godot -ArgumentList $args -PassThru -NoNewWindow -RedirectStandardOutput $log
  Write-Host ("started levels {0}-{1}" -f $c[0], $c[1])
}
$running | Wait-Process
Write-Host ("generation done in {0:N0}s" -f $sw.Elapsed.TotalSeconds)

$parts = (Get-ChildItem $tmp -Filter "part_*.json" | ForEach-Object { $_.FullName }) -join ","
& $Godot --headless --path $proj --script res://tools/level_maker.gd -- --merge $parts
if ($LASTEXITCODE -ne 0) { throw "merge failed" }
Write-Host "Done. Run:  godot --headless --path . --script res://tools/level_maker.gd -- --verify"
