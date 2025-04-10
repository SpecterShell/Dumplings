# x64
$Object1 = Invoke-WebRequest -Uri 'https://download.royalapps.com/royalts/versioninfo7.x64.xml' | Read-ResponseContent | ConvertFrom-Xml
$VersionX64 = "$($Object1.RoyalVersionInfo.Major).$($Object1.RoyalVersionInfo.Minor).$($Object1.RoyalVersionInfo.Build).$($Object1.RoyalVersionInfo.MinorRevision)"

# arm64
$Object2 = Invoke-WebRequest -Uri 'https://download.royalapps.com/royalts/versioninfo7.arm64.xml' | Read-ResponseContent | ConvertFrom-Xml
$VersionARM64 = "$($Object2.RoyalVersionInfo.Major).$($Object2.RoyalVersionInfo.Minor).$($Object2.RoyalVersionInfo.Build).$($Object2.RoyalVersionInfo.MinorRevision)"

if ($VersionX64 -ne $VersionARM64) {
  $this.Log("x64 version: ${VersionX64}")
  $this.Log("arm64 version: ${VersionARM64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.RoyalVersionInfo.DownloadUrlMsi
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object2.RoyalVersionInfo.DownloadUrlMsi
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesObject = $Object1.RoyalVersionInfo.ReleaseNotes | ConvertFrom-Html
      $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode('//div[@class="heading"]')
      if ($ReleaseNotesTitleNode) {
        if ($ReleaseNotesTitleNode.InnerText -match '(20\d{1,2}-\d{1,2}-\d{1,2})') {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text) -replace '(?m)^(Improved|Fixed|New)$\n', '[$1] '
        }
      } else {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesObject | Get-TextContent | Format-Text) -replace '(?m)^(Improved|Fixed|New)$\n', '[$1] '
        }
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
