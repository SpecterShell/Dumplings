$Object1 = Invoke-WebRequest -Uri 'https://www.rarlab.com/download.htm'

$Link = $Object1.Links.Where({ try { $_.href -match 'winrar-x64-\d+\.exe$' } catch {} }, 'First')[0]

# Version
$this.CurrentState.Version = [regex]::Match($Link.outerHTML, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en'
  Architecture    = 'x64'
  InstallerUrl    = Join-Uri 'https://www.rarlab.com' $Link.href
}

$Object1.Links |
  ForEach-Object -Process { try { @{Value = $_.href; Match = [regex]::Match($_.href, "^.+winrar-x64-$($this.CurrentState.Version.Replace('.', ''))(.+)\.exe$") } } catch {} } |
  Where-Object -FilterScript { $_.Match.Success } |
  ForEach-Object -Process {
    $this.CurrentState.Installer += [ordered]@{
      InstallerLocale = $this.Config.LocaleMapper.Contains($_.Match.Groups[1].Value) ? $this.Config.LocaleMapper[$_.Match.Groups[1].Value] : $_.Match.Groups[1].Value
      Architecture    = 'x64'
      InstallerUrl    = Join-Uri 'https://www.rarlab.com' $_.Value
    }
  }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.win-rar.com/whatsnew.html' | ConvertFrom-Html
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(text(), 'Version $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::pre[1]').InnerText | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  { $_.Contains('Changed') -and -not $_.Contains('Updated') } {
    $this.Config.IgnorePRCheck = $true
  }
  'Changed|Updated' {
    $this.Message()
    $this.Submit()
  }
}
