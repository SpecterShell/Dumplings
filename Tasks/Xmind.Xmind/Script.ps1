$InstallerX64Url = Join-Uri 'https://www.xmind.app/xmind/downloads/' (Get-RedirectedUrl -Uri 'https://xmind.app/zen/download/win64/' | Split-Path -Leaf)
$VersionX64 = [regex]::Match($InstallerX64Url, '(\d+(?:\.\d+){2,})').Groups[1].Value

$InstallerArm64Url = Join-Uri 'https://www.xmind.app/xmind/downloads/' (Get-RedirectedUrl -Uri 'https://xmind.app/zen/download/win_arm64/' | Split-Path -Leaf)
$VersionArm64 = [regex]::Match($InstallerArm64Url, '(\d+(?:\.\d+){2,})').Groups[1].Value

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerX64Url
}
if ($VersionArm64 -eq $VersionX64) {
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'arm64'
    InstallerUrl = $InstallerArm64Url
  }
} else {
  $this.Log("The version of arm64 installer ($VersionArm64) is different from x64 installer ($VersionX64). Skipped.", 'Warning')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
