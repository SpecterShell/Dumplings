$Prefix = 'https://fragstats.org/index.php/downloads'
$Page = Invoke-WebRequest -Uri $Prefix

# Installer
$InstallerUrl = Join-Uri $Prefix $Page.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('x64') -and $_.href -match 'setup' } catch {} }, 'First')[0].href | ConvertTo-UnescapedUri
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'zip'
  NestedInstallerType  = 'inno'
  NestedInstallerFiles = @(@{ RelativeFilePath = "$($InstallerUrl | Split-Path -LeafBase).exe" })
  InstallerUrl         = $InstallerUrl

}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $BuiltMatch = [regex]::Match($Page.Content, '\(built (\d{4})-([A-Za-z]+)-(\d{2})\)')
      if ($BuiltMatch.Success) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact("$($BuiltMatch.Groups[2].Value) $($BuiltMatch.Groups[3].Value) $($BuiltMatch.Groups[1].Value)", 'MMMM dd yyyy', [System.Globalization.CultureInfo]::GetCultureInfo('en-US'), [System.Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
      } else {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
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
