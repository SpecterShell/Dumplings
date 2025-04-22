# $Object1 = Invoke-RestMethod -Uri 'https://datalust.co/api/releases/latest'
$Prefix = 'https://datalust.co/download'
$Object1 = Invoke-WebRequest -Uri $Prefix
$Object2 = $Object1.Links.Where({ $_.outerHTML.Contains('Windows 64-bit') }, 'First')[0]

# Version
$this.CurrentState.Version = [regex]::Match($Object2.outerHTML, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl1st -Uri (Join-Uri $Prefix $Object2.href) -Method Get
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = $Object1.Links.Where({ try { $_.outerHTML.Contains('Released') } catch {} }, 'First')[0]
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($Object3.outerHTML, 'Released (\d{1,2}/\d{1,2}/20\d{2})').Groups[1].Value,
        'MM/dd/yyyy',
        $null
      ).ToString('yyyy-MM-dd')

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object3.href
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

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
