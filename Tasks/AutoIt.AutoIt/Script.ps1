$Object1 = Invoke-RestMethod -Uri 'https://www.autoitscript.com/autoit3/files/beta/update.dat' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.AutoIt.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://www.autoitscript.com/autoit3/files/archive/autoit/autoit-v$($this.CurrentState.Version)-setup.zip"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        $Object1.AutoIt.filetime,
        'yyyyMMddHHmmss',
        $null,
        [System.Globalization.DateTimeStyles]::None
      ) | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.autoitscript.com/autoit3/docs/history.htm' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//p[@class='c4' and contains(.//strong[@class='c3'], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [datetime]::ParseExact(
          [regex]::Match(
            $ReleaseNotesNode.SelectSingleNode('.//strong[@class="c3"]').InnerText,
            '(\d{1,2}(?:st|nd|rd|th)\W+[A-Za-z]+\W+20\d{2})'
          ).Groups[1].Value,
          [string[]]@(
            "d'st' MMMM, yyyy",
            "d'nd' MMMM, yyyy",
            "d'rd' MMMM, yyyy",
            "d'th' MMMM, yyyy"
          ),
          (Get-Culture -Name 'en-US'),
          [System.Globalization.DateTimeStyles]::None
        ).ToString('yyyy-MM-dd')

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesNode.NextSibling; $Node -and $Node.Name -ne 'hr' -and -not $Node.HasClass('c4'); $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
