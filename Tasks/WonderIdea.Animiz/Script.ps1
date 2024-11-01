# x64
$Object1 = Invoke-RestMethod -Uri 'https://animiz.com/update/animiz-update-info.php' -Body @{
  version = $this.LastState.Contains('Version') ? $this.LastState.Version : '4.0.2'
  os      = 'Windows 10'
  digit   = '64'
}
# x86
$Object2 = Invoke-RestMethod -Uri 'https://animiz.com/update/animiz-update-info.php' -Body @{
  version = $this.LastState.Contains('Version') ? $this.LastState.Version : '4.0.2'
  os      = 'Windows 10'
  digit   = '32'
}

if ($Object1.CurrentVersionNumber -ne $Object2.CurrentVersionNumber) {
  $this.Log("x86 version: $($Object2.CurrentVersionNumber)")
  $this.Log("x64 version: $($Object1.CurrentVersionNumber)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.CurrentVersionNumber

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.FileURL | Split-Uri -LeftPart Path | ConvertTo-Https
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.FileURL | Split-Uri -LeftPart Path | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = $Object1.DescriptionURL.Replace('www.animiz.com', 'animiz.com') | ConvertTo-Https
      }

      $Object3 = Invoke-RestMethod -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object3.SelectNodes('//ul[@class="productFeatures"]/li/node()') | Get-TextContent | Format-Text
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
