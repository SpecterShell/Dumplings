# Download
$Prefix1 = 'https://cdn.wostatic.cn/dist/installers/'
$Object1 = (Invoke-RestMethod -Uri "${Prefix1}electron-versions.json").win | ConvertFrom-ElectronUpdater -Prefix $Prefix1
# Upgrade
$Prefix2 = 'https://static2.wolai.com/dist/installers/'
$Object2 = Invoke-RestMethod -Uri "${Prefix2}latest.yml" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix2

if ((Compare-Version -ReferenceVersion $Object2.Version -DifferenceVersion $Object1.Version) -ge 0) {
  $Task.CurrentState = $Object1
} else {
  $Task.CurrentState = $Object2
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
