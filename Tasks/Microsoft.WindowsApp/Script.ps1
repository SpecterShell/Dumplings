$Object1 = Invoke-WebRequest -Uri 'https://learn.microsoft.com/en-us/windows-app/whats-new' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//div[contains(@class, "content")]//h2[starts-with(text(), "Version ")][1]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('//a[contains(text(), "Windows 32-bit")]').Attributes['href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('//a[contains(text(), "Windows 64-bit")]').Attributes['href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('//a[contains(text(), "Windows Arm64")]').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.SelectSingleNode('./following::text()[contains(., "Date published:")]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
