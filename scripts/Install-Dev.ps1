[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AddOnsPath
)

$ErrorActionPreference = 'Stop'
$source = Split-Path -Parent $PSScriptRoot
$addons = Get-Item -LiteralPath $AddOnsPath
if (!$addons.PSIsContainer -or $addons.Name -ne 'AddOns') {
    throw 'AddOnsPath must point to the game client''s existing Interface/AddOns directory.'
}

$target = Join-Path $addons.FullName 'QuickItemSearchDev'
if (Test-Path -LiteralPath $target) {
    $directory = Get-Item -LiteralPath $target -Force
    if (!$directory.PSIsContainer -or ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "The dev destination must be a regular directory: $target"
    }
} else {
    New-Item -ItemType Directory -Path $target | Out-Null
}

foreach ($file in @('ItemIndex.lua', 'Search.lua')) {
    Copy-Item -LiteralPath (Join-Path $source $file) -Destination $target -Force
}

$renamedFiles = [ordered]@{
    'QuickItemSearch.toc' = 'QuickItemSearchDev.toc'
    'Bindings.xml' = 'Bindings.xml'
    'UI.lua' = 'UI.lua'
}
foreach ($file in $renamedFiles.Keys) {
    $contents = Get-Content -Raw -LiteralPath (Join-Path $source $file)
    $contents.Replace('QuickItemSearch', 'QuickItemSearchDev').
        Replace('QUICKITEMSEARCH', 'QUICKITEMSEARCHDEV').
        Replace('Quick Item Search', 'Quick Item Search (Dev)').
        Replace('/itemsearch', '/itemsearchdev') |
        Set-Content -NoNewline -Encoding utf8 -LiteralPath (Join-Path $target $renamedFiles[$file])
}

Write-Host "Installed Quick Item Search (Dev) in $target"
