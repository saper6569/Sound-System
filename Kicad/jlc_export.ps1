# Export JLCPCB fabrication files (bare PCB) for SoundSystem.kicad_pcb.
# Usage (from this folder, with KiCad closed or the board saved):
#   powershell -ExecutionPolicy Bypass -File .\jlc_export.ps1
# Produces fab\gerbers\*  and  fab\SoundSystem-JLCPCB.zip  (upload the zip to jlcpcb.com).

$ErrorActionPreference = 'Stop'
$cli   = 'C:\Program Files\KiCad\10.0\bin\kicad-cli.exe'
$here  = $PSScriptRoot
$board = Join-Path $here 'SoundSystem.kicad_pcb'
$fab   = Join-Path $here 'fab'
$out   = Join-Path $fab 'gerbers'
$zip   = Join-Path $fab 'SoundSystem-JLCPCB.zip'

if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out | Out-Null

# 1. DRC first - stop if there are errors (pass -SkipDrc to export anyway).
if ($args -notcontains '-SkipDrc') {
    & $cli pcb drc $board --severity-error --exit-code-violations --schematic-parity -o (Join-Path $fab 'drc.rpt')
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "DRC reported errors - see fab\drc.rpt. Re-run with -SkipDrc to export anyway."
        exit 1
    }
}

# 2. Gerbers: 4 copper layers + mask, silk, paste, outline. Protel extensions, as JLC expects.
$layers = 'F.Cu,In1.Cu,In2.Cu,B.Cu,F.Mask,B.Mask,F.Paste,B.Paste,F.Silkscreen,B.Silkscreen,Edge.Cuts'
& $cli pcb export gerbers $board -o "$out\" --layers $layers --subtract-soldermask --check-zones
if ($LASTEXITCODE -ne 0) { throw 'Gerber export failed' }

# 3. Drill: Excellon, mm, decimal, absolute origin, separate PTH/NPTH files.
& $cli pcb export drill $board -o "$out\" --format excellon --excellon-units mm `
    --excellon-zeros-format decimal --drill-origin absolute --excellon-oval-format alternate `
    --excellon-separate-th --generate-map --map-format gerberx2
if ($LASTEXITCODE -ne 0) { throw 'Drill export failed' }

# 4. Zip for upload.
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path "$out\*" -DestinationPath $zip
Write-Host "Done: $zip"
