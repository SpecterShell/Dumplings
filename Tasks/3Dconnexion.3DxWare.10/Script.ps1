$Object1 = Invoke-WebRequest -Uri 'https://3dconnexion.com/us/drivers/' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//li[@class="drivers-latest__system" and contains(./div/@class, "drivers-latest__system-icon--windows")]')

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object2.SelectSingleNode('./div[@class="drivers-latest__system-version"]').InnerText.Trim(),
  'Version ([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.SelectSingleNode('./a').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $Object2.SelectSingleNode('./div[@class="drivers-latest__system-date"]').InnerText,
        '(\d{4}/\d{1,2}/\d{1,2})'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }

      $ReleaseNotesUrl = $Object1.SelectSingleNode('//section[@data-driver-details="windows"]//div[@class="drivers-system__specifications"]//a[contains(text(), "Release notes")]').Attributes['href'].Value
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl.Replace('/us/', '/')
      }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl.Replace('/us/', '/cn/')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      if ($Global:DumplingsStorage.Contains('3DxWare10') -and $Global:DumplingsStorage['3DxWare10'].Contains($this.CurrentState.Version)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['3DxWare10'][$this.CurrentState.Version].ReleaseNotes
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['3DxWare10'][$this.CurrentState.Version].ReleaseNotesCN
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'install.exe' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'install.exe'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe
    # AppsAndFeaturesEntries + ProductCode
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromBurn
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromBurn
        InstallerType = 'burn'
      }
    )

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
