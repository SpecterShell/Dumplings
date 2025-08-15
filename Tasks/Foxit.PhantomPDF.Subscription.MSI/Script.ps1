$Object1 = Invoke-RestMethod -Uri 'https://www.foxit.com/portal/download/getdownloadform.html?retJson=1&platform=Windows&formId=trial-foxit-sign-suite-pro-individual'

# Version
$this.CurrentState.Version = $Object1.package_info.version[0]

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = Join-Uri 'https://cdn01.foxitsoftware.com' $Object1.package_info.down.Replace('_Website_x64.exe', '.exe').Replace('.exe', '_Prom.exe')
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = Join-Uri 'https://cdn01.foxitsoftware.com' $Object1.package_info.down.Replace('_Website_x64.exe', '.exe').Replace('.exe', '.msi')
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

    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFileExtracted}" $InstallerFile '2.msi' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted '2.msi'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe
    # ProductCode
    $Installer['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.foxit.com/pdf-editor/version-history.html' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[@id='tab-editor-suite-windows']//div[@id='Version_$($this.CurrentState.Version)_detail']")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesNode.SelectSingleNode('./p[.//a[@class="download"]]') ?? $ReleaseNotesNode.SelectSingleNode('./p[1]')).SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
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
