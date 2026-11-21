$IndexUrl = 'https://repos.rcdevs.com/direct/Plugins/'
$Object1 = Invoke-WebRequest -Uri $IndexUrl | Read-ResponseContent | ConvertFrom-Html
$AssetName = $Object1.SelectNodes('//a[@href]').Where({ $_.Attributes['href'].Value -match '^OpenOTP_QuickSign-\d+(?:\.\d+)+-x64\.zip$' }, 'First')[0].Attributes['href'].Value

# Version
$this.CurrentState.Version = [regex]::Match($AssetName, '^OpenOTP_QuickSign-(\d+(?:\.\d+)+)-x64\.zip$').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $IndexUrl $AssetName
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
    # NestedInstallerFiles
    $this.CurrentState.Installer[0]['NestedInstallerFiles'] = @([ordered]@{ RelativeFilePath = $ZipFile.Entries.Where({ $_.FullName.EndsWith('.msix') }, 'First')[0].FullName.Replace('/', '\') })
    $ChangeLogStream = $ZipFile.Entries.Where({ $_.FullName -eq 'CHANGELOG.txt' }, 'First')[0].Open()
    $ChangeLogReader = [System.IO.StreamReader]::new($ChangeLogStream)
    $ChangeLog = $ChangeLogReader.ReadToEnd()
    $ChangeLogReader.Dispose()
    $ZipFile.Dispose()

    try {
      # ReleaseNotes (en-US)
      $ReleaseNotesMatch = [regex]::Match($ChangeLog, '(?ms)^' + [regex]::Escape($this.CurrentState.Version) + ' - [^\n]*\n(.*?)(?=^\d+\.\d+\.\d+\.\d+ - |\z)')
      if ($ReleaseNotesMatch.Success) {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesMatch.Groups[1].Value | Format-Text
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
