param(
    [Parameter(Mandatory = $true)]
    [string]$Destination
)

$ErrorActionPreference = "Stop"
$destinationPath = [System.IO.Path]::GetFullPath($Destination)
$header = Join-Path $destinationPath "include\libavcodec\avcodec.h"
$library = Join-Path $destinationPath "lib\avcodec.lib"

if ((Test-Path $header) -and (Test-Path $library)) {
    Write-Host "[ffmpeg] Development files already present."
    exit 0
}

$temporary = Join-Path $env:TEMP ("ninfer-ffmpeg-" + [Guid]::NewGuid().ToString("N"))
$archive = Join-Path $temporary "ffmpeg.zip"
$expanded = Join-Path $temporary "expanded"

try {
    New-Item -ItemType Directory -Force -Path $temporary, $expanded, $destinationPath | Out-Null
    $url = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip"
    Write-Host "[ffmpeg] Downloading shared Windows development build..."
    Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
    Expand-Archive -Path $archive -DestinationPath $expanded -Force

    $root = Get-ChildItem -Path $expanded -Directory |
        Where-Object { (Test-Path (Join-Path $_.FullName "include")) -and (Test-Path (Join-Path $_.FullName "lib")) } |
        Select-Object -First 1
    if (-not $root) {
        throw "Downloaded FFmpeg archive does not contain include/lib directories."
    }

    Copy-Item (Join-Path $root.FullName "include") $destinationPath -Recurse -Force
    Copy-Item (Join-Path $root.FullName "lib") $destinationPath -Recurse -Force
    Copy-Item (Join-Path $root.FullName "bin") $destinationPath -Recurse -Force

    if (-not ((Test-Path $header) -and (Test-Path $library))) {
        throw "FFmpeg extraction completed but required development files are missing."
    }
    Write-Host "[ffmpeg] Ready: $destinationPath"
}
finally {
    if (Test-Path $temporary) {
        Remove-Item $temporary -Recurse -Force
    }
}
