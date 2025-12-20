$Prefix = 'https://download.documentfoundation.org/libreoffice/stable/'

$Object1 = Invoke-WebRequest -Uri 'https://www.libreoffice.org/download/download-libreoffice/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Object1.SelectNodes('//span[@class="dl_version_number"]').InnerText | Sort-Object -Property { $_ -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "${Prefix}$($this.CurrentState.Version)/win/x86/LibreOffice_$($this.CurrentState.Version)_Win_x86.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "${Prefix}$($this.CurrentState.Version)/win/x86_64/LibreOffice_$($this.CurrentState.Version)_Win_x86-64.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "${Prefix}$($this.CurrentState.Version)/win/aarch64/LibreOffice_$($this.CurrentState.Version)_Win_aarch64.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

    # ReleaseNotesUrl
    # $this.CurrentState.Locale += [ordered]@{
    #   Key   = 'ReleaseNotesUrl'
    #   Value = 'https://wiki.documentfoundation.org/ReleaseNotes'
    # }

    try {
      # $this.CurrentState.Locale += [ordered]@{
      #   Key   = 'ReleaseNotesUrl'
      #   Value = $ReleaseNotesUrl = Get-RedirectedUrl -Uri "https://hub.libreoffice.org/ReleaseNotes/?LOvers=$($this.CurrentState.Version.Split('.')[0..1] -join '.')&LOlocale=en-US"
      # }

      # The release notes part has been disabled, as it always has a length over 10000 characters
      # if ($ReleaseNotesUrl.Contains(($this.CurrentState.Version.Split('.')[0..1] -join '.'))) {
      #   $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      #   # Remove images and footnotes
      #   $Object2.SelectNodes('.//*[contains(@class, "gallery")]').ForEach({ $_.Remove() })
      #   # ReleaseNotes (en-US)
      #   $this.CurrentState.Locale += [ordered]@{
      #     Locale = 'en-US'
      #     Key    = 'ReleaseNotes'
      #     Value  = $Object2.SelectNodes('//*[name()="mw:tocplace"]/following-sibling::*') | Get-TextContent | Format-Text
      #   }
      # } else {
      #   $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      # }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    # ReleaseNotesUrl
    # $this.CurrentState.Locale += [ordered]@{
    #   Locale = 'zh-CN'
    #   Key    = 'ReleaseNotesUrl'
    #   Value  = 'https://wiki.documentfoundation.org/ReleaseNotes'
    # }

    try {
      # $this.CurrentState.Locale += [ordered]@{
      #   Locale = 'zh-CN'
      #   Key    = 'ReleaseNotesUrl'
      #   Value  = $ReleaseNotesUrlCN = Get-RedirectedUrl -Uri "https://hub.libreoffice.org/ReleaseNotes/?LOvers=$($this.CurrentState.Version.Split('.')[0..1] -join '.')&LOlocale=zh-CN"
      # }

      # if ($ReleaseNotesUrlCN.Contains(($this.CurrentState.Version.Split('.')[0..1] -join '.'))) {
      #   $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrlCN | ConvertFrom-Html

      #   # Remove images and footnotes
      #   $Object3.SelectNodes('.//*[contains(@class, "gallery")]').ForEach({ $_.Remove() })
      #   # ReleaseNotes (zh-CN)
      #   $this.CurrentState.Locale += [ordered]@{
      #     Locale = 'zh-CN'
      #     Key    = 'ReleaseNotes'
      #     Value  = $Object3.SelectNodes('//*[name()="mw:tocplace"]/following-sibling::*') | Get-TextContent | Format-Text
      #   }
      # } else {
      #   $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      # }
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

    if (-not $this.Status.Contains('New')) {
      $this.CurrentState = $this.LastState

      $Prefix2 = 'https://downloadarchive.documentfoundation.org/libreoffice/old/'
      $this.CurrentState.Installer = @(
        [ordered]@{
          Architecture = 'x86'
          InstallerUrl = "${Prefix2}$($this.LastState.RealVersion)/win/x86/LibreOffice_$($this.LastState.RealVersion)_Win_x86.msi"
        }
        [ordered]@{
          Architecture = 'x64'
          InstallerUrl = "${Prefix2}$($this.LastState.RealVersion)/win/x86_64/LibreOffice_$($this.LastState.RealVersion)_Win_x86-64.msi"
        }
        [ordered]@{
          Architecture = 'arm64'
          InstallerUrl = "${Prefix2}$($this.LastState.RealVersion)/win/aarch64/LibreOffice_$($this.LastState.RealVersion)_Win_aarch64.msi"
        }
      )
      $this.ResetMessage()
      $this.Config.IgnorePRCheck = $true
      try {
        $this.Submit()
      } catch {
        $_ | Out-Host
        $this.Log($_, 'Warning')
      }
    }
  }
}
