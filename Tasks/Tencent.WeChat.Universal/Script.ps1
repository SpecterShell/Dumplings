$Uri1 = 'https://dldir1v6.qq.com/weixin/Universal/Windows/WeChatWin.exe'
$Object1 = Invoke-WebRequest -Uri $Uri1 -Method Head
# MD5
$this.CurrentState.MD5 = $Object1.Headers.'X-COS-META-MD5'[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  $InstallerFile = Get-TempFile -Uri $Uri1
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
    # MD5 alternative
    $this.CurrentState.MD5A = $Object2.Headers.'X-COS-META-MD5'[0]
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    $this.Log("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture    = 'x64'
      InstallerUrl    = $Uri1
      InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
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

  $InstallerFile = Get-TempFile -Uri $Uri1
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
    # MD5 alternative
    $this.CurrentState.MD5A = $Object2.Headers.'X-COS-META-MD5'[0]
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    $this.Log("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture    = 'x64'
      InstallerUrl    = $Uri1
      InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    }
    # Mode
    $this.CurrentState.Mode = $false
  }

  $this.Print()
  $this.Write()
  return
}

if ($this.CurrentState.MD5 -eq $this.LastState.MD5) {
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
    # MD5 alternative
    $this.CurrentState.MD5A = $Object2.Headers.'X-COS-META-MD5'[0]

    # Case 2: Both the main and the alternative MD5 was not updated
    if ($this.CurrentState.MD5A -eq $this.LastState.MD5A) {
      $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
      return
    }

    Get-ReleaseNotes

    # Case 3: The main MD5 wasn't updated, but the alternative one was
    $this.Log('The alternative MD5 was updated', 'Info')
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
      # MD5 alternative
      $this.CurrentState.MD5A = $Object2.Headers.'X-COS-META-MD5'[0]
      # Mode
      $this.CurrentState.Mode = $true

      Get-ReleaseNotes

      # Case 4: Detected alternative installer URL
      $this.Log('Detected alternative installer URL', 'Info')
      $this.Print()
      $this.Write()
      return
    } catch {
      # Case 5: The main MD5 was not updated, and the alternative installer URL doesn't exist
      return
    }
  }
} else {
  $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = [regex]::Match((7z.exe l -ba -slt $InstallerFile), 'Path = (\d+\.\d+\.\d+\.\d+)').Groups[1].Value

  try {
    # The main MD5 was updated, and the alternative installer URL exists
    $Uri2 = "https://dldir1v6.qq.com/weixin/Universal/Windows/WeChatWin$($this.CurrentState.Version).exe"
    $Object2 = Invoke-WebRequest -Uri $Uri2 -Method Head
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture = 'x64'
      InstallerUrl = $Uri2
    }
    # MD5 alternative
    $this.CurrentState.MD5A = $Object2.Headers.'X-COS-META-MD5'[0]
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    # The main MD5 was updated, but the alternative installer URL doesn't exist
    $this.Log("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture    = 'x64'
      InstallerUrl    = $Uri1
      InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    }
    # Mode
    $this.CurrentState.Mode = $false
  }

  switch -Regex ($this.Check()) {
    # Case 7: The installer URL was updated
    'Changed|Updated|Rollbacked' {
      $this.Print()
      $this.Write()
      $this.Message()
    }
    # Case 8: The MD5 and the version were updated
    'Updated|Rollbacked' {
      $this.Submit()
    }
    # Case 6: The MD5 was updated, but the version wasn't
    Default {
      $this.Log('The MD5 was updated, but the version is the same', 'Info')
      $this.Config.IgnorePRCheck = $true
      $this.Print()
      $this.Write()
      $this.Message()
      $this.Submit()
    }
  }
}
