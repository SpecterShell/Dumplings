$Prefix = "https://muteme.io/update/win64/$($this.Status.Contains('New') ? '0.25.7' : $this.LastState.Version)/"
$Object1 = Invoke-WebRequest -Uri "${Prefix}RELEASES" | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { [RawVersion]$_.Version } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = "https://mutemedownloads.s3.us-east-2.amazonaws.com/main/$($this.CurrentState.Version)/MuteMe-Client-$($this.CurrentState.Version) Setup.exe"
}
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = "https://mutemedownloads.s3.us-east-2.amazonaws.com/main/$($this.CurrentState.Version)/MuteMe-Client.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    # ProductCode
    $Installer['ProductCode'] = "$($InstallerFile | Read-ProductCodeFromMsi).msq"

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://muteme.com/pages/release-notes' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h3[contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{1,2}-\d{1,2}-20\d{2})').Groups[1].Value,
          'M-d-yyyy',
          $null
        ).ToString('yyyy-MM-dd')

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
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
