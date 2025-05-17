function Read-Installer {
  $InstallerEXEFile = Get-TempFile -Uri $InstallerEXE.InstallerUrl
  # Version
  $this.CurrentState.Version = ($InstallerEXEFile | Read-ProductVersionRawFromExe).ToString()
  # InstallerSha256
  $InstallerEXE['InstallerSha256'] = (Get-FileHash -Path $InstallerEXEFile -Algorithm SHA256).Hash
  # AppsAndFeaturesEntries
  $InstallerEXE['AppsAndFeaturesEntries'] = @(
    [ordered]@{
      DisplayVersion = $this.CurrentState.Version
    }
  )
  Remove-Item -Path $InstallerEXEFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

  $InstallerMSIFile = Get-TempFile -Uri $InstallerMSI.InstallerUrl
  # InstallerSha256
  $InstallerMSI['InstallerSha256'] = (Get-FileHash -Path $InstallerMSIFile -Algorithm SHA256).Hash
  # ProductCode
  $InstallerMSI['ProductCode'] = $InstallerMSIFile | Read-ProductCodeFromMsi
  # AppsAndFeaturesEntries
  $InstallerMSI['AppsAndFeaturesEntries'] = @(
    [ordered]@{
      DisplayName    = 'RingCentralRooms Installer'
      DisplayVersion = $this.CurrentState.Version.Split('.')[0..1] -join '.'
      UpgradeCode    = $InstallerMSIFile | Read-UpgradeCodeFromMsi
    }
  )
  Remove-Item -Path $InstallerMSIFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

function Get-ReleaseNotes {
  try {
    $Object2 = Invoke-WebRequest -Uri 'https://support.ringcentral.com/release-notes/ringex/meetings/meetings-rooms.html' | ConvertFrom-Html

    $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h3[contains(text(), 'Windows')]//following::b[contains(text(), '$($this.CurrentState.Version.Split('.')[0..1] -join '.')')]//ancestor::div[contains(@class, 'custom-text ')]")
    if ($ReleaseNotesTitleNode) {
      $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not $Node.InnerText.Contains('VERSION'); $Node = $Node.NextSibling) {
        if (-not $Node.InnerText.Contains('Release date')) {
          $Node
        }
      }
      # ReleaseNotes (en-US)
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
}

# EXE
$this.CurrentState.Installer += $InstallerEXE = [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = 'https://downloads.ringcentral.com/RCM/RC/rooms/win/RingCentralRoomsSetup.exe'
}
$Object1 = Invoke-WebRequest -Uri $InstallerEXE.InstallerUrl -Method Head
$ETag = $Object1.Headers.ETag[0]

# MSI
$this.CurrentState.Installer += $InstallerMSI = [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = 'https://downloads.ringcentral.com/RCM/RC/rooms/win/RingCentralRoomsSetup.msi'
}
$Object2 = Invoke-WebRequest -Uri $InstallerMSI.InstallerUrl -Method Head
$ETagMSI = $Object2.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)
  $this.CurrentState.ETagMSI = @($ETagMSI)

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)
  $this.CurrentState.ETagMSI = @($ETagMSI)

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The ETag is unchanged
if ($ETag -in $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (MSI)", 'Info')
  return
}
if ($ETagMSI -in $this.LastState.ETagMSI) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (EXE)", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseNotes

# Case 4: The ETag has changed, but the SHA256 is not
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The ETag has changed, but the SHA256 is not', 'Info')

  # ETag
  $this.CurrentState.ETag = $this.LastState.ETag + $ETag
  $this.CurrentState.ETagMSI = $this.LastState.ETagMSI + $ETagMSI

  $this.Write()
  return
}

# ETag
$this.CurrentState.ETag = @($ETag)
$this.CurrentState.ETagMSI = @($ETagMSI)

switch -Regex ($this.Check()) {
  # Case 6: The ETag, the SHA256 and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 5: The ETag and the SHA256 have changed, but the version is not
  Default {
    $this.Log('The ETag and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
