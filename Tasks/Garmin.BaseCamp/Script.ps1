$LastVersionParts = $this.Status.Contains('New') ? @(4, 7, 5, 0) : $this.LastState.VersionParts
$LastVersionBlock = @"
<VersionMajor>$($LastVersionParts[0])</VersionMajor>
<VersionMinor>$($LastVersionParts[1])</VersionMinor>
<BuildMajor>$($LastVersionParts[2])</BuildMajor>
<BuildMinor>$($LastVersionParts[3])</BuildMinor>
"@

$Object1 = Invoke-RestMethod -Uri 'https://www.garmin.com/support/PCSoftwareUpdate.jsp' -Method Post -Body @{
  req = @"
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<Requests xmlns="http://www.garmin.com/xmlschemas/PcSoftwareUpdate/v2">
  <Request>
    <PartNumber>006-A0346-W8</PartNumber>
    <Version>
      ${LastVersionBlock}
      <BuildType>Release</BuildType>
    </Version>
    <LanguageID>1033</LanguageID>
  </Request>
  <Request>
    <PartNumber>006-A0346-W7</PartNumber>
    <Version>
      ${LastVersionBlock}
      <BuildType>Release</BuildType>
    </Version>
    <LanguageID>1033</LanguageID>
  </Request>
  <Request>
    <PartNumber>006-A0346-VS</PartNumber>
    <Version>
      ${LastVersionBlock}
      <BuildType>Release</BuildType>
    </Version>
    <LanguageID>1033</LanguageID>
  </Request>
  <Request>
    <PartNumber>006-A0346-XP</PartNumber>
    <Version>
      ${LastVersionBlock}
      <BuildType>Release</BuildType>
    </Version>
    <LanguageID>1033</LanguageID>
  </Request>
</Requests>
"@
}
$Object2 = $Object1.GetElementsByTagName('Update') | Sort-Object -Property { [int]$_.Version.VersionMajor }, { [int]$_.Version.VersionMinor }, { [int]$_.Version.BuildMajor }, { [int]$_.Version.BuildMinor } -Bottom 1

# Version
$this.CurrentState.Version = "$($Object2.Version.VersionMajor).$($Object2.Version.VersionMinor).$($Object2.Version.BuildMajor).$($Object2.Version.BuildMinor)"
$this.CurrentState.VersionParts = @([int]$Object2.Version.VersionMajor, [int]$Object2.Version.VersionMinor, [int]$Object2.Version.BuildMajor, [int]$Object2.Version.BuildMinor)

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri 'https://download.garmin.com/software/' ($Object2.UpdateFile.Location | Split-Uri -Components Path | Split-Path -Leaf)
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.ChangeDescriptionFile | ConvertFrom-Html | Get-TextContent | Format-Text
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
