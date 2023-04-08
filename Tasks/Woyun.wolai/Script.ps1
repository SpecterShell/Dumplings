# Download
$Prefix1 = 'https://cdn.wostatic.cn/dist/installers/'
$Object1 = (Invoke-RestMethod -Uri "${Prefix1}electron-versions.json").win | ConvertFrom-ElectronUpdater -Prefix $Prefix1
# Upgrade
$Prefix2 = 'https://static2.wolai.com/dist/installers/'
$Object2 = Invoke-RestMethod -Uri "${Prefix2}latest.yml" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix2

if ((Compare-Version -ReferenceVersion $Object1.Version -DifferenceVersion $Object2.Version) -gt 0) {
  $Task.CurrentState = $Object2
} else {
  $Task.CurrentState = $Object1
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
