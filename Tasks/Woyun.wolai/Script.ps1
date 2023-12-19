# Download
$Prefix1 = 'https://cdn.wostatic.cn/dist/installers/'
$Object1 = (Invoke-RestMethod -Uri "${Prefix1}electron-versions.json").win | ConvertFrom-ElectronUpdater -Prefix $Prefix1
# Upgrade
$Prefix2 = 'https://static2.wolai.com/dist/installers/'
$Object2 = Invoke-RestMethod -Uri "${Prefix2}latest.yml" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix2

if ((Compare-Version -ReferenceVersion $Object1.Version -DifferenceVersion $Object2.Version) -gt 0) {
  $this.CurrentState = $Object2
} else {
  $this.CurrentState = $Object1
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
