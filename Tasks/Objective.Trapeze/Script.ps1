# x86
$Object1 = Invoke-RestMethod -Uri 'https://s3-ap-southeast-2.amazonaws.com/trapezedownload.objective.com/Objective_Trapeze_x86.json'

# x64
$Object2 = Invoke-RestMethod -Uri 'https://s3-ap-southeast-2.amazonaws.com/trapezedownload.objective.com/Objective_Trapeze_x64.json'

if ($Object1.Details.Version -ne $Object2.Details.Version) {
  $this.Log("x86 version: $($Object1.Details.Version)")
  $this.Log("x64 version: $($Object2.Details.Version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.Details.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = 'https://s3-ap-southeast-2.amazonaws.com/trapezedownload.objective.com/Objective_Trapeze_x86.msi'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://s3-ap-southeast-2.amazonaws.com/trapezedownload.objective.com/Objective_Trapeze_x64.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.Details.Date | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://s3.ap-southeast-2.amazonaws.com/trapezedownload.objective.com/release-notes.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(text(), 'Version $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
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
