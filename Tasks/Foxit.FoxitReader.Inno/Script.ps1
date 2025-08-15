$Object1 = Invoke-RestMethod -Uri 'https://www.foxit.com/portal/download/getdownloadform.html?retJson=1&platform=Windows&formId=download-reader'

# Version
$this.CurrentState.Version = $Object1.package_info.version[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = 'https://cdn01.foxitsoftware.com' + $Object1.package_info.down
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.package_info.release, 'MM/dd/yy', $null).ToString('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.foxit.com/pdf-reader/version-history.html' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[@id='Version_$($this.CurrentState.Version)_detail']")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectNodes('./*[position()>2]') | Get-TextContent | Format-Text
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
