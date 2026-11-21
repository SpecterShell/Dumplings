function Get-ReleaseNotes {
  try {
    $Object3 = Invoke-WebRequest -Uri $Object1.DEFAULT.DOWNLOAD_NOTICE_URL | ConvertFrom-Html

    $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//h2[contains(., '$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
    if ($ReleaseNotesTitleNode) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{1,2}/\d{1,2}/20\d{2})').Groups[1].Value,
        'MM/dd/yyyy',
        $null
      ).ToString('yyyy-MM-dd')

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
      }
    } else {
      $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version.Split('.')[0..2] -join '.')", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }

  try {
    $Object3 = Invoke-WebRequest -Uri "$($Object1.DEFAULT.DOWNLOAD_NOTICE_URL)&lang=zh" | ConvertFrom-Html

    $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//h2[contains(., '$($this.CurrentState.Version)')]")
    if ($ReleaseNotesTitleNode) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Matches($ReleaseNotesTitleNode.InnerText, '(20\d{2}/\d{1,2}/\d{1,2})')[-1].Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
      }
    } else {
      $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version.Split('.')[0..2] -join '.')", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

$Object1 = Invoke-RestMethod -Uri 'https://www.bandicam.com/bandicut-video-cutter/version_eng.ini' | ConvertFrom-Ini

$Uri1 = Join-Uri 'https://dl.bandicam.com/' $Object1.DEFAULT.DOWNLOAD_EXE_PATH
$Object2 = Invoke-WebRequest -Uri $Uri1 -Method Head
# ETag
$ETag = $Object2.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)

  $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = ($InstallerFile | Read-ProductVersionRawFromExe).ToString()
  # InstallerSha256
  $this.CurrentState.InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  try {
    $Uri2 = "https://dl.bandicam.com/bandicut/old/bandicut-setup-$($this.CurrentState.Version).exe"
    $null = Invoke-WebRequest -Uri $Uri2 -Method Head
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture = 'x64'
      InstallerUrl = $Uri2
    }
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    $this.Log("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture    = 'x64'
      InstallerUrl    = $Uri1
      InstallerSha256 = $this.CurrentState.InstallerSha256
    }
    # Mode
    $this.CurrentState.Mode = $false
  }

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

  $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = ($InstallerFile | Read-ProductVersionRawFromExe).ToString()
  # InstallerSha256
  $this.CurrentState.InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  try {
    $Uri2 = "https://dl.bandicam.com/bandicut/old/bandicut-setup-$($this.CurrentState.Version).exe"
    $null = Invoke-WebRequest -Uri $Uri2 -Method Head
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture = 'x64'
      InstallerUrl = $Uri2
    }
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    $this.Log("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture    = 'x64'
      InstallerUrl    = $Uri1
      InstallerSha256 = $this.CurrentState.InstallerSha256
    }
    # Mode
    $this.CurrentState.Mode = $false
  }

  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

if ($ETag -in $this.LastState.ETag) {
  # The ETag is unchanged, so let's check if the alternative installer URL exists
  if ($this.LastState.Mode -eq $true) {
    # If the alternative installer URL exists, don't fallback to the main one
    $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
    return
  } else {
    # ETag
    $this.CurrentState.ETag = $this.LastState.ETag
    # Version
    $this.CurrentState.Version = $this.LastState.Version
    # InstallerSha256
    $this.CurrentState.InstallerSha256 = $this.LastState.InstallerSha256

    try {
      $Uri2 = "https://dl.bandicam.com/bandicut/old/bandicut-setup-$($this.CurrentState.Version).exe"
      $null = Invoke-WebRequest -Uri $Uri2 -Method Head
      # Installer
      $this.CurrentState.Installer += [ordered]@{
        Architecture = 'x64'
        InstallerUrl = $Uri2
      }
      # Mode
      $this.CurrentState.Mode = $true

      Get-ReleaseNotes

      # Case 2: The ETag is unchanged, but an alternative installer URL is detected
      $this.Log('An alternative installer URL is detected', 'Info')
      $this.Print()
      $this.Write()
      return
    } catch {
      # Case 3: The ETag is unchanged, and the alternative installer URL doesn't exist
      return
    }
  }
} else {
  # The ETag has changed, but there is a chance that the hash is actually unchanged, so let's check it
  $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = ($InstallerFile | Read-ProductVersionRawFromExe).ToString()
  # InstallerSha256
  $this.CurrentState.InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  if ($this.CurrentState.InstallerSha256 -eq $this.LastState.InstallerSha256) {
    $this.Log('The ETag has changed, but the SHA256 is not', 'Info')
    # ETag
    $this.CurrentState.ETag = $this.LastState.ETag + $ETag

    if ($this.LastState.Mode -eq $true) {
      # Case 4: The ETag has changed, but the SHA256 is not, and the alternative installer URL already exists
      $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')

      # Installer
      $this.CurrentState.Installer = $this.LastState.Installer
      # Mode
      $this.CurrentState.Mode = $true

      Get-ReleaseNotes

      $this.Write()
      return
    } else {
      try {
        # Case 5: The ETag has changed, but the SHA256 is not, while an alternative installer URL is detected
        $Uri2 = "https://dl.bandicam.com/bandicut/old/bandicut-setup-$($this.CurrentState.Version).exe"
        $null = Invoke-WebRequest -Uri $Uri2 -Method Head
        # Installer
        $this.CurrentState.Installer += [ordered]@{
          Architecture = 'x64'
          InstallerUrl = $Uri2
        }
        # Mode
        $this.CurrentState.Mode = $true

        Get-ReleaseNotes

        $this.Log('An alternative installer URL is detected', 'Info')
        $this.Print()
        $this.Write()
        return
      } catch {
        # Case 6: The ETag has changed, but the SHA256 is not, and the alternative installer URL doesn't exist

        # Installer
        $this.CurrentState.Installer += [ordered]@{
          Architecture    = 'x64'
          InstallerUrl    = $Uri1
          InstallerSha256 = $this.CurrentState.InstallerSha256
        }
        # Mode
        $this.CurrentState.Mode = $false

        Get-ReleaseNotes

        $this.Write()
        return
      }
    }
  } else {
    $this.Log('Both the ETag and the SHA256 have changed', 'Info')
    # ETag
    $this.CurrentState.ETag = @($ETag)

    try {
      # The ETag and the SHA256 have changed, while the alternative installer URL exists
      $Uri2 = "https://dl.bandicam.com/bandicut/old/bandicut-setup-$($this.CurrentState.Version).exe"
      $null = Invoke-WebRequest -Uri $Uri2 -Method Head
      # Installer
      $this.CurrentState.Installer += [ordered]@{
        Architecture = 'x64'
        InstallerUrl = $Uri2
      }
      # Mode
      $this.CurrentState.Mode = $true
    } catch {
      # The ETag and the SHA256 have changed, but the alternative installer URL doesn't exist
      $this.Log("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
      # Installer
      $this.CurrentState.Installer += [ordered]@{
        Architecture    = 'x64'
        InstallerUrl    = $Uri1
        InstallerSha256 = $this.CurrentState.InstallerSha256
      }
      # Mode
      $this.CurrentState.Mode = $false
    }
  }

  Get-ReleaseNotes

  switch -Regex ($this.Check()) {
    # Case 8: The installer URL has changed
    'Changed|Updated|Rollbacked' {
      $this.Print()
      $this.Write()
      $this.Message()
    }
    # Case 9: The ETag, the SHA256 and the version have changed
    'Updated|Rollbacked' {
      $this.Submit()
    }
    # Case 7: The ETag and the SHA256 have changed, but the version is not
    default {
      $this.Log('The ETag and the SHA256 have changed, but the version is not', 'Info')
      $this.Config.IgnorePRCheck = $true
      $this.Print()
      $this.Write()
      $this.Message()
      $this.Submit()
    }
  }
}
