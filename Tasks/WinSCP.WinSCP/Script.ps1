$ProjectName = 'winscp'
$RootPath = '/WinSCP/'
$PatternPath = '(\d+(?:\.\d+)+)/'
$PatternFilename = 'WinSCP-.+\.(?:msi|exe)'

$Object1 = Invoke-RestMethod -Uri "https://sourceforge.net/projects/${ProjectName}/rss?path=${RootPath}"
$Assets = $Object1.Where({ $_.title.'#cdata-section' -match "^$([regex]::Escape($RootPath))${PatternPath}${PatternFilename}$" })

# Installer
$Asset = $Assets.Where({ $_.title.'#cdata-section'.EndsWith('.exe') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = $Asset.link | ConvertTo-UnescapedUri
}
$VersionInno = [regex]::Match($Asset.title.'#cdata-section', "^$([regex]::Escape($RootPath))${PatternPath}${PatternFilename}").Groups[1].Value

$Asset = $Assets.Where({ $_.title.'#cdata-section'.EndsWith('.msi') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = $Asset.link | ConvertTo-UnescapedUri
}
$VersionMSI = [regex]::Match($Asset.title.'#cdata-section', "^$([regex]::Escape($RootPath))${PatternPath}${PatternFilename}").Groups[1].Value

if ($VersionInno -ne $VersionMSI) {
  $this.Log("Inconsistent versions: Inno: ${VersionInno}, MSI: ${VersionMSI}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionInno

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Asset.pubDate, 'ddd, dd MMM yyyy HH:mm:ss "UT"', (Get-Culture -Name 'en-US')) | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://winscp.net/eng/docs/history' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//header[contains(./h2, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(20\d{2}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
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
