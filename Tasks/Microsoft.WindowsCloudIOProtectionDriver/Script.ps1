$Object1 = Invoke-WebRequest -Uri 'https://learn.microsoft.com/en-us/windows-365/enterprise/windows-cloud-input-protection' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('//a[contains(text(), "Windows x64")]').Attributes['href'].Value
}
$VersionX64 = [regex]::Match($InstallerX64.InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value
$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('//a[contains(text(), "Windows ARM 64")]').Attributes['href'].Value
}
$VersionARM64 = [regex]::Match($InstallerARM64.InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value

if ($VersionX64 -ne $VersionARM64) {
  $this.Log("Inconsistent versions: x64 version: ${VersionX64}, arm64 version: ${VersionARM64}", 'Error')
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

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
