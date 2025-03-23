$Object1 = (Invoke-RestMethod -Uri 'https://dist.nuget.org/index.json').artifacts.Where({ $_.name -eq 'win-x86-commandline' }, 'First')[0].versions.Where({ $_.displayName -eq 'nuget.exe - recommended latest' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.version

# Installer
# The API may not contain the version-specific entry, so we need to construct the URL manually
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://dist.nuget.org/win-x86-commandline/v$($this.CurrentState.Version)/nuget.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releasedate.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0].AppsAndFeaturesEntries = @(
      [ordered]@{
        DisplayName    = 'NuGet CLI'
        DisplayVersion = $InstallerFile | Read-FileVersionFromExe
      }
    )

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }

      $Object3 = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/NuGet/docs.microsoft.com-nuget/HEAD/docs/release-notes/NuGet-$($this.CurrentState.Version.Split('.')[0..1] -join '.').md" | Convert-MarkdownToHtml

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object3.SelectNodes('/h2[2]|/h2[2]/following-sibling::node()') | Get-TextContent | Format-Text
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://learn.microsoft.com/nuget/release-notes/nuget-$($this.CurrentState.Version.Split('.')[0..1] -join '.')"
      }

      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = "https://learn.microsoft.com/zh-cn/nuget/release-notes/nuget-$($this.CurrentState.Version.Split('.')[0..1] -join '.')"
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
