<#
  Zips the app and sideloads it to one or more Rokus in Developer Mode.

  Usage (from the repo folder):
    powershell -ExecutionPolicy Bypass -File scripts\deploy.ps1
    powershell -ExecutionPolicy Bypass -File scripts\deploy.ps1 -RokuIp 192.168.1.50,192.168.1.51
    powershell -ExecutionPolicy Bypass -File scripts\deploy.ps1 -ZipOnly

  Reads rokuIps / rokuPassword from deploy.json when not passed. Every TV
  uses the same developer password unless deploy.json gives that IP its own
  under "passwords".
  Note: a Roku holds one sideloaded app at a time, so this replaces any other dev app.
#>
param(
    [string[]]$RokuIp,
    [string]$RokuPassword,
    [switch]$ZipOnly
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$deployFile = "deploy.json"
$zipName = "church-signage.zip"
$passwords = @{}

if (Test-Path $deployFile) {
    $deploy = Get-Content $deployFile -Raw | ConvertFrom-Json
    if (-not $RokuIp) { $RokuIp = @($deploy.rokuIps) | Where-Object { $_ } }
    if (-not $RokuPassword) { $RokuPassword = $deploy.rokuPassword }
    if ($deploy.passwords) {
        foreach ($p in $deploy.passwords.PSObject.Properties) { $passwords[$p.Name] = $p.Value }
    }
}

# Build the zip with forward-slash entry names (Compress-Archive on
# Windows PowerShell 5.1 writes backslashes, which the Roku rejects).
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
New-Item -ItemType Directory -Force -Path "out" | Out-Null
$zipPath = Join-Path $root "out\$zipName"
if (Test-Path $zipPath) { Remove-Item $zipPath }

$files = @(Get-Item "manifest")
foreach ($dir in "source", "components", "images") {
    $files += Get-ChildItem -Path $dir -Recurse -File
}
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, "Create")
try {
    foreach ($f in $files) {
        $entry = $f.FullName.Substring($root.Length + 1).Replace("\", "/")
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, $entry) | Out-Null
    }
} finally {
    $zip.Dispose()
}
Write-Host "Built $zipPath"
if ($ZipOnly) { exit 0 }

# Accept "10.0.0.5,10.0.0.6" as one argument too.
$RokuIp = @($RokuIp | ForEach-Object { $_ -split "[,\s]+" } | Where-Object { $_ })
if ($RokuIp.Count -eq 0) {
    throw "Set rokuIps in $deployFile, or pass -RokuIp."
}

$failed = @()
foreach ($ip in $RokuIp) {
    $pw = $passwords[$ip]
    if (-not $pw) { $pw = $RokuPassword }
    if (-not $pw -or $pw -like "YOUR_*") {
        Write-Host "${ip}: no developer password. Set rokuPassword in $deployFile."
        $failed += $ip
        continue
    }

    Write-Host "Sideloading to $ip ..."
    # PowerShell 5.1 turns curl's stderr into a terminating error under "Stop",
    # which would skip the remaining TVs.
    $ErrorActionPreference = "Continue"
    $out = & curl.exe --silent --show-error --connect-timeout 10 --max-time 120 --digest --user "rokudev:$pw" `
        -F "mysubmit=Install" -F "archive=@$zipPath" "http://$ip/plugin_install" 2>&1
    $ErrorActionPreference = "Stop"
    $text = ($out | ForEach-Object { "$_" }) -join "`n"
    if ($text -match "Install Success|Identical to previous version") {
        Write-Host "${ip}: installed. The board is running."
    } else {
        $msg = [regex]::Matches($text, "<font color=`"red`">([^<]+)</font>") | ForEach-Object { $_.Groups[1].Value }
        if ($msg) { Write-Host ($msg -join "`n") }
        elseif ($text -match "401|Unauthorized") { Write-Host "${ip}: wrong developer password." }
        elseif ($text.Trim()) { Write-Host $text.Trim() }
        Write-Host "${ip}: FAILED. Check the IP, the developer password, and that the TV is on."
        $failed += $ip
    }
}

if ($failed.Count -gt 0) {
    throw "Sideload failed on: $($failed -join ', ')"
}
Write-Host "All $($RokuIp.Count) Roku(s) updated."
