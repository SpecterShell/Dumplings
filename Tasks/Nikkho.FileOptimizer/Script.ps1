$ProjectName = 'nikkhokkho'
$RootPath = '/FileOptimizer'

$Object1 = Invoke-RestMethod -Uri "https://sourceforge.net/projects/${ProjectName}/rss?path=${RootPath}"
$Assets = $Object1.Where({ $_.title.'#cdata-section' -match "^$([regex]::Escape($RootPath))/\d+(?:\.\d+)+/FileOptimizerSetup\.exe$" })

# Version
$this.CurrentState.Version = [regex]::Match($Assets[0].title.'#cdata-section', "^$([regex]::Escape($RootPath))/(\d+(?:\.\d+)+)/").Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Assets[0].link | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        $Assets[0].pubDate,
        'ddd, dd MMM yyyy HH:mm:ss "UT"',
        (Get-Culture -Name 'en-US')
      ) | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl -UserAgent $WinGetUserAgent
    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-FileVersionFromExe

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
