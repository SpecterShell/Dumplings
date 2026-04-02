$VersionMatches = [regex]::Match((Get-RedirectedUrl -Uri 'https://www.visual-paradigm.com/downloads/vp/Visual_Paradigm_Win64.exe'), '/vp(\d+(?:\.\d+)+)/(\d+)/')
# Version
$this.CurrentState.Version = "$($VersionMatches.Groups[1].Value).$($VersionMatches.Groups[2].Value)"
# RealVersion
$this.CurrentState.RealVersion = $VersionMatches.Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://www.visual-paradigm.com/downloads/vp$($VersionMatches.Groups[1].Value)/Visual_Paradigm_Win64.exe"
}

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
