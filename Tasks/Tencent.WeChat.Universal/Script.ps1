$Uri1 = 'https://dldir1v6.qq.com/weixin/Universal/Windows/WeChatWin.exe'
$Object1 = Invoke-WebRequest -Uri $Uri1 -Method Head
# Hash
$this.CurrentState.Hash = $Object1.Headers.'X-COS-META-MD5'[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  $WinGetInstallerFiles[$Uri1] = $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = [regex]::Match((7z.exe l -ba -slt $InstallerFile), 'Path = (\d+\.\d+\.\d+\.\d+)').Groups[1].Value

  try {
    $Uri2 = "https://dldir1v6.qq.com/weixin/Universal/Windows/WeChatWin$($this.CurrentState.Version).exe"
    $Object2 = Invoke-WebRequest -Uri $Uri2 -Method Head
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture = 'x64'
      InstallerUrl = $Uri2
    }
    # Hash alternative
    $this.CurrentState.HashA = $Object2.Headers.'X-COS-META-MD5'[0]
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    $this.Log("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture = 'x64'
      InstallerUrl = $Uri1
    }
    # Mode
    $this.CurrentState.Mode = $false
  }

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is newly created
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  $WinGetInstallerFiles[$Uri1] = $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = [regex]::Match((7z.exe l -ba -slt $InstallerFile), 'Path = (\d+\.\d+\.\d+\.\d+)').Groups[1].Value

  try {
    $Uri2 = "https://dldir1v6.qq.com/weixin/Universal/Windows/WeChatWin$($this.CurrentState.Version).exe"
    $Object2 = Invoke-WebRequest -Uri $Uri2 -Method Head
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture = 'x64'
      InstallerUrl = $Uri2
    }
    # Hash alternative
    $this.CurrentState.HashA = $Object2.Headers.'X-COS-META-MD5'[0]
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    $this.Log("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture = 'x64'
      InstallerUrl = $Uri1
    }
    # Mode
    $this.CurrentState.Mode = $false
  }

  $this.Print()
  $this.Write()
  return
}

if ($this.CurrentState.Hash -eq $this.LastState.Hash) {
  # Version
  $this.CurrentState.Version = $this.LastState.Version
  # If the alternative installer URL exists, don't fallback to the main one
  if ($this.LastState.Mode -eq $true) {
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture = 'x64'
      InstallerUrl = $Uri2 = $this.LastState.Installer[0].InstallerUrl
    }
    # Mode
    $this.CurrentState.Mode = $true

    $Object2 = Invoke-WebRequest -Uri $Uri2 -Method Head
    # Hash alternative
    $this.CurrentState.HashA = $Object2.Headers.'X-COS-META-MD5'[0]

    # Case 2: The main and the alternative hash are not updated
    if ($this.CurrentState.MD5A -eq $this.LastState.MD5A) {
      $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
      return
    }

    Get-ReleaseNotes

    # Case 3: The main hash is not updated, but the alternative one has
    $this.Log('The alternative hash has updated', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
    return
  } else {
    try {
      $Uri2 = "https://dldir1v6.qq.com/weixin/Universal/Windows/WeChatWin$($this.CurrentState.Version).exe"
      $Object2 = Invoke-WebRequest -Uri $Uri2 -Method Head
      # Installer
      $this.CurrentState.Installer += [ordered]@{
        Architecture = 'x64'
        InstallerUrl = $Uri2
      }
      # Hash alternative
      $this.CurrentState.HashA = $Object2.Headers.'X-COS-META-MD5'[0]
      # Mode
      $this.CurrentState.Mode = $true

      Get-ReleaseNotes

      # Case 4: Detected an alternative installer URL
      $this.Log('Detected an alternative installer URL', 'Info')
      $this.Print()
      $this.Write()
      return
    } catch {
      # Case 5: The main MD5 was not updated, and the alternative installer URL doesn't exist
      return
    }
  }
} else {
  $WinGetInstallerFiles[$Uri1] = $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = [regex]::Match((7z.exe l -ba -slt $InstallerFile), 'Path = (\d+\.\d+\.\d+\.\d+)').Groups[1].Value

  try {
    # The main hash has updated, and the alternative installer URL exists
    $Uri2 = "https://dldir1v6.qq.com/weixin/Universal/Windows/WeChatWin$($this.CurrentState.Version).exe"
    $Object2 = Invoke-WebRequest -Uri $Uri2 -Method Head
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture = 'x64'
      InstallerUrl = $Uri2
    }
    # Hash alternative
    $this.CurrentState.HashA = $Object2.Headers.'X-COS-META-MD5'[0]
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    # The main hash has updated, but the alternative installer URL does not exist
    $this.Log("${Uri2} does not exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture = 'x64'
      InstallerUrl = $Uri1
    }
    # Mode
    $this.CurrentState.Mode = $false
  }

  switch -Regex ($this.Check()) {
    # Case 7: The installer URL has updated
    'Changed|Updated|Rollbacked' {
      $this.Print()
      $this.Write()
      $this.Message()
    }
    # Case 8: The hash and the version have updated
    'Updated|Rollbacked' {
      $this.Submit()
    }
    # Case 6: The hash has updated, but the version is not
    Default {
      $this.Log('The hash has updated, but the version is not', 'Info')
      $this.Config.IgnorePRCheck = $true
      $this.Print()
      $this.Write()
      $this.Message()
      $this.Submit()
    }
  }
}
