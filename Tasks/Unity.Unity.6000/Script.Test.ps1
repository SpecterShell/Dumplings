$Object1 = (Invoke-RestMethod -Uri 'https://services.api.unity.com/unity/editor/release/v1/releases?platform=WINDOWS&stream=TECH&stream=LTS&version=6000').results[0]

# Version
$this.CurrentState.Version = $Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.downloads.Where({ $_.architecture -eq 'X86_64' }, 'First')[0].url
  ProductCode  = "Unity ${Version}"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object1.downloads.Where({ $_.architecture -eq 'ARM64' }, 'First')[0].url
  ProductCode  = "Unity ${Version}"
}

# Modules
$this.CurrentState.Modules = [ordered]@{}
foreach ($Module in $Object1.downloads.Where({ $_.architecture -eq 'X86_64' }, 'First')[0].modules) {
  $this.CurrentState.Modules[$Module.id] = $Module.url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.releaseDate.ToUniversalTime()

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = "https://unity.com/releases/editor/whats-new/$($Version -creplace 'f\d+', '')"
}

# Documentations
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'Documentations'
  Value  = @(
    @{
      DocumentLabel = 'Unity User Manual'
      DocumentUrl   = "https://docs.unity3d.com/$($Version.Split('.')[0..1] -join '.')/Documentation/Manual/"
    }
  )
}
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'Documentations'
  Value  = @(
    [ordered]@{
      DocumentLabel = 'Unity 用户手册'
      DocumentUrl   = "https://docs.unity3d.com/$($Version.Split('.')[0..1] -join '.')/Documentation/Manual/"
      # DocumentUrl   = "https://docs.unity3d.com/cn/$($Version.Split('.')[0..1] -join '.')/Manual/"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $OldLocale = $this.CurrentState.Locale
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = Invoke-RestMethod -Uri $Object1.releaseNotes.url | Convert-MarkdownToHtml | Get-TextContent | Format-Text
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

    # Also submit manifests for sub modules
    $OldWinGetIdentifier = $this.Config.WinGetIdentifier
    $this.CurrentState.Locale = $OldLocale
    foreach ($KVP in $this.Config.WinGetIdentifierModules.GetEnumerator()) {
      $this.Log("Handling $($KVP.Value)...", 'Info')
      $this.Config.WinGetIdentifier = $KVP.Value
      $this.CurrentState.Installer = @(
        [ordered]@{
          InstallerUrl = $this.CurrentState.Modules[$KVP.Key]
          Dependencies = [ordered]@{
            PackageDependencies = @(
              [ordered]@{
                PackageIdentifier = $OldWinGetIdentifier
                MinimumVersion    = $this.CurrentState.Version
              }
            )
          }
        }
      )
      try {
        $this.Submit()
      } catch {
        $_ | Out-Host
        $this.Log($_, 'Warning')
      }
    }
  }
}
