param([string]$GamePath)
$ErrorActionPreference='Stop'
try {
    if (Get-Process -Name OLGame -ErrorAction SilentlyContinue) { throw 'Close Outlast and its launcher window before installation.' }
    if (-not $GamePath) {
        Write-Host 'Outlast M9 r4 - installer'
        Write-Host 'Enter the Outlast folder containing OutlastLauncher.exe.'
        $GamePath=Read-Host 'Path [D:\SteamLibrary\steamapps\common\Outlast]'
        if ([string]::IsNullOrWhiteSpace($GamePath)) { $GamePath='D:\SteamLibrary\steamapps\common\Outlast' }
    }
    $GamePath=[IO.Path]::GetFullPath($GamePath.Trim().Trim('"')).TrimEnd('\')
    if (-not (Test-Path -LiteralPath (Join-Path $GamePath 'OutlastLauncher.exe') -PathType Leaf)) { throw 'OutlastLauncher.exe was not found. Select the game root folder.' }
    if (-not (Test-Path -LiteralPath (Join-Path $GamePath 'OLGame\CookedPCConsole') -PathType Container)) { throw 'OLGame\CookedPCConsole was not found.' }
    if (-not (Test-Path -LiteralPath (Join-Path $GamePath 'Binaries\Win64\OLGame.exe') -PathType Leaf)) { throw 'Windows 64-bit Outlast executable was not found.' }
    $payloadRoot=Join-Path $PSScriptRoot 'Files'
    $manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
    $operations=@()
    foreach ($file in $manifest.Files) {
        $source=[IO.Path]::GetFullPath((Join-Path $payloadRoot $file.Path))
        $target=[IO.Path]::GetFullPath((Join-Path $GamePath $file.Path))
        if (-not $source.StartsWith($payloadRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or -not $target.StartsWith($GamePath+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid installation path.' }
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $file.Sha256) { throw ('Damaged installation file: '+$file.Path) }
        if (Test-Path -LiteralPath $target -PathType Container) { throw ('A folder conflicts with file: '+$target) }
        $operations+=@{Source=$source;Target=$target;Relative=$file.Path;Hash=$file.Sha256}
    }
    $backupRoot=Join-Path $GamePath ('M9_Backups\r4-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    foreach ($op in $operations) {
        if (Test-Path -LiteralPath $op.Target -PathType Leaf) {
            $backupFile=Join-Path $backupRoot $op.Relative
            New-Item -ItemType Directory -Path (Split-Path -Parent $backupFile) -Force | Out-Null
            Copy-Item -LiteralPath $op.Target -Destination $backupFile
        }
    }
    $legacyFiles=@('OLGame\CookedPCConsole\OutlastPistolMod.u','OLGame\CookedPCConsole\OutlastPistolMod.OLScript','Custom\OutlastPistolMod\Content\OutlastPistolMod.u')
    foreach ($relative in $legacyFiles) {
        $legacyPath=[IO.Path]::GetFullPath((Join-Path $GamePath $relative))
        if (-not $legacyPath.StartsWith($GamePath+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid legacy file path.' }
        if (Test-Path -LiteralPath $legacyPath -PathType Leaf) {
            $backupFile=Join-Path $backupRoot $relative
            New-Item -ItemType Directory -Path (Split-Path -Parent $backupFile) -Force | Out-Null
            Move-Item -LiteralPath $legacyPath -Destination $backupFile
        }
    }
    foreach ($op in $operations) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $op.Target) -Force | Out-Null
        Copy-Item -LiteralPath $op.Source -Destination $op.Target -Force
        if ((Get-FileHash -LiteralPath $op.Target -Algorithm SHA256).Hash -ne $op.Hash) { throw ('Installed checksum mismatch: '+$op.Relative) }
    }
    $operations | ForEach-Object { $_.Relative } | Set-Content -LiteralPath (Join-Path $backupRoot 'InstalledFiles.txt') -Encoding UTF8
    Write-Host ''
    Write-Host 'M9 r4 installed successfully.' -ForegroundColor Green
    Write-Host ('Backup: '+$backupRoot)
    Write-Host ('Start: '+(Join-Path $GamePath 'START_M9.cmd'))
    Write-Host 'Run START_M9.cmd as administrator. Keep its window open until the game exits.'
    exit 0
} catch {
    Write-Host ('Installation failed: '+$_.Exception.Message) -ForegroundColor Red
    if ($backupRoot) { Write-Host ('Previous files, if any, are saved in: '+$backupRoot) }
    exit 1
}
