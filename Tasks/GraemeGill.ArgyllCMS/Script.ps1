$Object1 = Invoke-WebRequest -Uri 'https://www.argyllcms.com/'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'Current Version (\d+(?:\.\d+)+)').Groups[1].Value

$Object2 = Invoke-WebRequest -Uri 'https://www.argyllcms.com/downloadwin.html'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains($this.CurrentState.Version) -and $_.href.Contains('win32') -and -not $_.href.Contains('llvm') } catch {} }, 'First')[0].href | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains($this.CurrentState.Version) -and $_.href.Contains('win64') -and -not $_.href.Contains('llvm') } catch {} }, 'First')[0].href | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.argyllcms.com/doc/ChangesSummary.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//h1[contains(text(), 'V$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match(
            $ReleaseNotesTitleNode.InnerText,
            '(\d{1,2}(?:st|nd|rd|th)\s+[a-zA-Z]+\s+\d{4})'
          ).Groups[1].Value,
          [string[]]@(
            "d'st' MMM yyyy", "d'st' MMMM yyyy",
            "d'nd' MMM yyyy", "d'nd' MMMM yyyy",
            "d'rd' MMM yyyy", "d'rd' MMMM yyyy",
            "d'th' MMM yyyy", "d'th' MMMM yyyy"
          ),
          (Get-Culture -Name 'en-US'),
          [System.Globalization.DateTimeStyles]::None
        ).ToString('yyyy-MM-dd')

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h1'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      # NestedInstallerFiles
      $Installer['NestedInstallerFiles'] = @(7z.exe l -ba -slt $InstallerFile '*\bin\*.exe' | Where-Object -FilterScript { $_ -match '^Path = ' } | ForEach-Object -Process { [ordered]@{ RelativeFilePath = [regex]::Match($_, '^Path = (.+)').Groups[1].Value } })
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
