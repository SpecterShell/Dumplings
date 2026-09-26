# x64 user
$Object1 = Invoke-RestMethod -Uri 'https://lingma-api.tongyi.aliyun.com/algo/api/qodercn/update/win32-x64-user/stable/1.0.0'
# x64 machine
$Object2 = Invoke-RestMethod -Uri 'https://lingma-api.tongyi.aliyun.com/algo/api/qodercn/update/win32-x64/stable/1.0.0'

if ($Object1.productVersion -ne $Object2.productVersion) {
  $this.Log("Inconsistent versions: x64 user: $($Object1.productVersion), x64 machine: $($Object2.productVersion)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.productVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'user'
  InstallerUrl = $Object1.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'machine'
  InstallerUrl = $Object2.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.timestamp | ConvertFrom-UnixTimeMilliseconds
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
