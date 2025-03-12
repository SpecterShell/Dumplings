$Object1 = Invoke-WebRequest -Uri 'https://krita.org/en/download/'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'Download Krita ([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.Links.Where({ try { $_.id -eq 'windows-download' } catch {} }, 'First')[0].href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object1.Content, 'Released on: [a-zA-Z]+\W+(\d{1,2}\W+[a-zA-Z]+\W+\d{4})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://krita.org/en/release-history/'
      }

      $Object2 = (Invoke-RestMethod -Uri 'https://krita.org/en/index.xml').Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object2) {
        $ReleaseNotesObject = $Object2[0].description | ConvertFrom-Html
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and -not ($Node.Attributes.Contains('id') -and $Node.Attributes['id'].Value -eq 'download'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object2[0].link
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://krita.org/zh-cn/release-history/'
      }

      $Object3 = (Invoke-RestMethod -Uri 'https://krita.org/zh-cn/index.xml').Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object3) {
        $ReleaseNotesCNObject = $Object3[0].description | ConvertFrom-Html
        $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesCNObject.ChildNodes[0]; $Node -and -not ($Node.Attributes.Contains('id') -and $Node.Attributes['id'].Value -eq '下载'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNNodes | Get-TextContent | Format-Text
        }
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = $Object3[0].link
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) and ReleaseNotesUrl (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
