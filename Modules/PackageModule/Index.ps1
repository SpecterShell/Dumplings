if (-not ([System.Management.Automation.PSTypeName]'VersionParser.Versionin').Type) {
  Add-Type -Path (Join-Path $PSScriptRoot 'Assets' 'Versioning.cs')
}

# Import libraries
$Private:LibraryPath = Join-Path $PSScriptRoot 'Libraries'
if (Test-Path -Path $LibraryPath) {
  $Private:LibraryPath | Get-ChildItem -Include '*.psm1' -Recurse -File | Import-Module -Force
}

# Import models
$Private:ModelPath = Join-Path $PSScriptRoot 'Models'
if (Test-Path -Path $ModelPath) {
  $Private:ModelPath | Get-ChildItem -Include '*.ps1' -Recurse -File | ForEach-Object -Process { . $_ }
}
