$Object1 = Invoke-WebRequest -Uri 'https://learn.microsoft.com/en-us/windows-app/whats-new' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('//a[contains(text(), "Windows 32-bit")]').Attributes['href'].Value
}
$VersionX86 = [regex]::Match($InstallerX86.InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('//a[contains(text(), "Windows 64-bit")]').Attributes['href'].Value
}
$VersionX64 = [regex]::Match($InstallerX64.InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value
$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('//a[contains(text(), "Windows Arm64")]').Attributes['href'].Value
}
$VersionARM64 = [regex]::Match($InstallerARM64.InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value

if (@(@($VersionX86, $VersionX64, $VersionARM64) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  $this.Log("arm64 version: ${VersionARM64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesTitleNode = $Object1.SelectSingleNode("//section[@id='tabpanel_2_windows']/h3[contains(text(), 'Version $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) {
          if ($Node.InnerText -match '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})') {
            if (-not $this.CurrentState['ReleaseTime']) {
              # ReleaseTime
              $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
            }
          } else {
            $Node
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
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
