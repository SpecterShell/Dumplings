# Download
$Object1 = Invoke-RestMethod -Uri 'https://jsonschema.qpic.cn/2993ffb0f5d89de287319113301f3fca/179b0d35c9b088e5e72862a680864254/config'
# Upgrade x64
$Prefix2 = 'https://dldir1v6.qq.com/weiyun/electron-update/release/x64/'
$Object2 = Invoke-RestMethod -Uri "${Prefix2}latest.yml" | ConvertFrom-Yaml
# Upgrade x86
$Prefix3 = 'https://dldir1v6.qq.com/weiyun/electron-update/release/win32/'
$Object3 = Invoke-RestMethod -Uri "${Prefix3}latest-win32.yml" | ConvertFrom-Yaml

if ([Versioning]$Object1.electron_win64.version -lt [Versioning]$Object2.version) {
  if ($Object2.version -ne $Object3.version) {
    $this.Log("x86 version: $($Object3.version)")
    $this.Log("x64 version: $($Object2.version)")
    throw 'Inconsistent versions detected'
  }

  # Version
  $this.CurrentState.Version = $Object2.version

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'x64'
    InstallerUrl = (Join-Uri $Prefix2 $Object2.files[0].url).Replace('dldir1.qq.com', 'dldir1v6.qq.com')
  }
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'x86'
    InstallerUrl = (Join-Uri $Prefix3 $Object3.files[0].url).Replace('dldir1.qq.com', 'dldir1v6.qq.com')
  }

  try {
    # ReleaseTime
    $this.CurrentState.ReleaseTime = $Object2.releaseDate | Get-Date -AsUTC
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
} else {
  if ($Object1.electron_win64.version -ne $Object1.electron_win32.version) {
    $this.Log("x86 version: $($Object1.electron_win32.version)")
    $this.Log("x64 version: $($Object1.electron_win64.version)")
    throw 'Inconsistent versions detected'
  }

  # Version
  $this.CurrentState.Version = $Object1.electron_win64.version

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'x86'
    InstallerUrl = $Object1.electron_win32.download_url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
  }
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'x64'
    InstallerUrl = $Object1.electron_win64.download_url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
  }

  # ReleaseTime
  $this.CurrentState.ReleaseTime = $Object1.electron_win64.date | Get-Date -Format 'yyyy-MM-dd'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
