# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.visual-paradigm.com/downloads/vpce/Visual_Paradigm_CE_Win64.exe'
}

$VersionMatches = [regex]::Match((Get-RedirectedUrl -Uri $this.CurrentState.Installer[0].InstallerUrl), '/vpce(\d+(?:\.\d+)+)/(\d+)/')
# Version
$this.CurrentState.Version = "$($VersionMatches.Groups[1].Value).$($VersionMatches.Groups[2].Value)"
# RealVersion
$this.CurrentState.RealVersion = $VersionMatches.Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }

      $ReleaseNotesUrl = "https://www.visual-paradigm.com/aboutus/newsreleases/vp$($VersionMatches.Groups[1].Value.Replace('.', '')).jsp"

      $Object1 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl
      }
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = "https://www.visual-paradigm.com/cn/aboutus/newsreleases/vp$($VersionMatches.Groups[1].Value.Replace('.', '')).jsp"
      }

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.SelectSingleNode('//td[@class="content"]') | Get-TextContent | Format-Text
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
