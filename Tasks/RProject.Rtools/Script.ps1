$Prefix = 'https://cloud.r-project.org/bin/windows/Rtools/'

$Object1 = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html

$MinorVersion = [regex]::Match(
  $Object1.SelectSingleNode('/html/body/table/tr[1]/td[1]/a').InnerText,
  'RTools ([\d\.]+)'
).Groups[1].Value
$ShortVersion = $MinorVersion.Replace('.', '')

$Object2 = (Invoke-WebRequest -Uri "${Prefix}rtools${ShortVersion}/files/").Content
$VersionMatches = [regex]::Match($Object2, "(rtools${ShortVersion}-(\d+)-\d+\.exe)")

# Version
$this.CurrentState.Version = "${MinorVersion}.$($VersionMatches.Groups[2].Value)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "${Prefix}rtools${ShortVersion}/files/$($VersionMatches.Groups[1].Value)"
  ProductCode  = "Rtools${ShortVersion}_is1"
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl = "${Prefix}rtools${ShortVersion}/news.html"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("/html/body/h3[contains(text(), '$($VersionMatches.Groups[2].Value)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    if ($this.LastState.Contains('Version') -and ($this.LastState.Version.Split('.')[0..1] -join '.') -eq $MinorVersion) {
      $this.Config.RemoveLastVersion = $true
    }
    $this.Submit()
  }
}
