# ipk ビルド (Windows から WSL を呼ぶ薄いラッパー)
#
#   .\build.ps1 hello-nas              # ビルドのみ
#   .\build.ps1 hello-nas -Deploy      # ビルド + NAS へ scp + opkg install
#   .\build.ps1 hello-nas -Deploy -Force # 既存版を上書き再インストール
param(
    [Parameter(Mandatory = $true)][string]$Package,
    [switch]$Deploy,
    [switch]$Force,
    [string]$Target = 'HomeNAS'
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$wslRoot = '/mnt/' + $root.Substring(0, 1).ToLower() + $root.Substring(2).Replace('\', '/')

$out = & wsl bash -lc ". $wslRoot/toolchain.env && cd $wslRoot && sh mkpkg.sh packages/$Package" 2>&1
$out | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) { throw "mkpkg.sh failed (exit $LASTEXITCODE)" }

$ipk = Get-ChildItem (Join-Path $root "packages\$Package\out\*.ipk") |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $ipk) { throw "ipk が見つかりません: packages\$Package\out" }
Write-Host "ipk: $($ipk.FullName)"

if ($Deploy) {
    & scp -O -o BatchMode=yes $ipk.FullName "${Target}:/tmp/" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "scp failed (exit $LASTEXITCODE)" }
    $opt = if ($Force) { '--force-reinstall' } else { '' }
    $cmd = "cd /tmp && opkg install $opt ./$($ipk.Name) 2>&1 | grep -v 'Duplicate src'"
    & ssh -o BatchMode=yes $Target $cmd
    if ($LASTEXITCODE -ne 0) { throw "opkg install failed (exit $LASTEXITCODE)" }
    & ssh -o BatchMode=yes $Target "rm -f /tmp/$($ipk.Name)"
    Write-Host "installed on $Target"
}
