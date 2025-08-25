$Object1 = Invoke-RestMethod -Uri "https://cloud8.8x8.com/vos-update/public/api/v2/asset?application=work&channel=GA&platform=win32_x64&version=$($this.LastState.Contains('FullVersion') ? $this.LastState.FullVersion : 'v0.0.0-0-0')" -StatusCodeVariable 'StatusCode'

if ($StatusCode -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$VersionMatches = [regex]::Match($Object1.version, 'v((\d+\.\d+)[\d\.]+)-(\d+)')

# Version
$this.CurrentState.Version = "$($VersionMatches.Groups[1].Value).$($VersionMatches.Groups[3].Value)"

# RealVersion
$this.CurrentState.RealVersion = $VersionMatches.Groups[1].Value

# FullVersion
$this.CurrentState.FullVersion = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType          = 'exe'
  InstallerUrl           = "https://work-desktop-assets.8x8.com/prod-publish/ga/work-64-exe-v$($VersionMatches.Groups[1].Value)-$($VersionMatches.Groups[3].Value).exe"
  AppsAndFeaturesEntries = @(
    @{
      DisplayVersion = "$($VersionMatches.Groups[1].Value)-b$($VersionMatches.Groups[3].Value)"
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = "https://work-desktop-assets.8x8.com/prod-publish/ga/work-64-msi-v$($VersionMatches.Groups[1].Value)-$($VersionMatches.Groups[3].Value).msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.pub_date, 'M/d/y, h:m tt', (Get-Culture -Name 'en-US')) | ConvertTo-UtcDateTime -Id 'UTC'

      # Only parse version for major updates
      if (-not $this.Status.Contains('New') -or $VersionMatches.Groups[2].Value -ne ($this.LastState.Version.Split('.')[0..1] -join '.')) {
        $Object2 = Invoke-WebRequest -Uri 'https://docs.8x8.com/8x8WebHelp/8x8-work-for-desktop/Content/workd/what-is-new.htm' | ConvertFrom-Html

        $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@id='mc-main-content']/h1[contains(., '$($VersionMatches.Groups[2].Value)')]")
        if ($ReleaseNotesTitleNode) {
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -notin @('h1', 'h2', 'hr'); $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
