$Object1 = Invoke-RestMethod -Uri 'https://www.foxit.com/portal/download/getdownloadform.html?retJson=1&platform=Windows&formId=download-phantom-bussiness'

# Version
$this.CurrentState.Version = $Object1.package_info.version[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'burn'
  InstallerUrl  = 'https://cdn01.foxitsoftware.com' + $Object1.package_info.down.Replace('_Website.exe', '.exe')
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = 'https://cdn01.foxitsoftware.com' + $Object1.package_info.down.Replace('_Website.exe', '.msi')
}
# $this.CurrentState.Installer += $Installer = [ordered]@{
#   InstallerType = 'exe'
#   InstallerUrl  = 'https://cdn01.foxitsoftware.com' + $Object1.package_info.down.Replace('_Website.exe', '.exe').Replace('.exe', '_Prom.exe')
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.package_info.release, 'MM/dd/yy', $null).ToString('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    # $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    # $InstallerFile2Root = New-TempFolder
    # 7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFile2Root}" $InstallerFile '2.msi' | Out-Host
    # $InstallerFile2 = Join-Path $InstallerFile2Root '2.msi'

    # # RealVersion
    # $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe
    # # InstallerSha256
    # $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # # AppsAndFeaturesEntries
    # $Installer['AppsAndFeaturesEntries'] = @(
    #   [ordered]@{
    #     ProductCode   = $Installer['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
    #     UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
    #     InstallerType = 'wix'
    #   }
    # )

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.foxit.com/pdf-editor/version-history.html' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[@id='tab-editor-windows']//div[@id='version_$($this.CurrentState.Version)_detail']")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectNodes('./div/*[self::p[.//a[@class="download"]] or self::p[1]][last()]/following-sibling::node()') | Get-TextContent | Format-Text
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
