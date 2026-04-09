$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/WSJTX/wsjtx/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('win32') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('win64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.html_url
      }

      # Documentations
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'Documentations'
        Value = @(
          [ordered]@{
            DocumentLabel = 'User Guide'
            DocumentUrl   = "https://wsjt.sourceforge.io/wsjtx-doc/wsjtx-main-$($this.CurrentState.Version).html"
          }
          [ordered]@{
            DocumentLabel = 'Q65 Mode Quick-Start Guide'
            DocumentUrl   = 'https://wsjt.sourceforge.io/Q65_Quick_Start.pdf'
          }
          [ordered]@{
            DocumentLabel = 'SuperFox Mode User Guide'
            DocumentUrl   = 'https://wsjt.sourceforge.io/SuperFox_User_Guide.pdf'
          }
          [ordered]@{
            DocumentLabel = 'WSJT-X and MAP65 Quick-Start Guide'
            DocumentUrl   = 'https://wsjt.sourceforge.io/WSJTX_2.5.0_MAP65_3.0_Quick_Start.pdf'
          }
          [ordered]@{
            DocumentLabel = 'FT8 DXpedition Mode User Guide'
            DocumentUrl   = 'https://wsjt.sourceforge.io/FT8_DXpedition_Mode.pdf'
          }
        )
      }
      # Documentations (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'Documentations'
        Value  = @(
          [ordered]@{
            DocumentLabel = '用户指南'
            DocumentUrl   = "https://wsjt.sourceforge.io/wsjtx-doc/wsjtx-main-$($this.CurrentState.Version).html"
          }
          [ordered]@{
            DocumentLabel = 'Q65 模式 快速入门'
            DocumentUrl   = 'https://wsjt.sourceforge.io/Q65_Quick_Start.pdf'
          }
          [ordered]@{
            DocumentLabel = 'SuperFox 模式 使用指南'
            DocumentUrl   = 'https://wsjt.sourceforge.io/SuperFox_User_Guide.pdf'
          }
          [ordered]@{
            DocumentLabel = 'WSJT-X 和 MAP65 快速入门'
            DocumentUrl   = 'https://wsjt.sourceforge.io/WSJTX_2.5.0_MAP65_3.0_Quick_Start.pdf'
          }
          [ordered]@{
            DocumentLabel = 'FT8 远征模式 使用指南'
            DocumentUrl   = 'https://wsjt.sourceforge.io/FT8_DXpedition_Mode_Chinese.pdf'
          }
        )
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $ReleaseNotesUrl = $Object1.assets.Where({ $_.name -eq 'Release_Notes.txt' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri $ReleaseNotesUrl).RawContentStream)
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl
      }

      while (-not $Object2.EndOfStream) {
        if ($Object2.ReadLine() -match "Release: WSJT-X $([regex]::Escape($this.CurrentState.Version))") {
          1..3 | ForEach-Object { $null = $Object2.ReadLine() }
          break
        }
      }
      if (-not $Object2.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object2.EndOfStream) {
          $String = $Object2.ReadLine()
          if ($String -notmatch 'Release: WSJT-X \d+(?:\.\d+)+') {
            $ReleaseNotesObjects.Add($String)
          } else {
            break
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObjects | Format-Text
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
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
