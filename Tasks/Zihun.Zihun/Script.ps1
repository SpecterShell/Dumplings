$Prefix = 'https://oss.izihun.com/client/download/'

$Object = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object.version

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = $Prefix + $Object.files.url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = (Get-Date -Date $Object.releaseDate).ToUniversalTime()

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
