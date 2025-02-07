# EXE (Burn)
$Object1 = Invoke-RestMethod -Uri 'https://www.foxitsoftware.cn/portal/download/getpackage.html?product=Foxit-PhantomPDF-Business&language=Chinese&platform=32-bit&package_type=exe'
# MSI (WiX)
$Object2 = Invoke-RestMethod -Uri 'https://www.foxitsoftware.cn/portal/download/getpackage.html?product=Foxit-PhantomPDF-Business&language=Chinese&platform=32-bit&package_type=msi'

if ($Object1.version[0] -ne $Object2.version[0]) {
  $this.Log("EXE version: $($Object1.version[0])")
  $this.Log("MSI version: $($Object2.version[0])")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.version[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'burn'
  InstallerUrl  = $Object1.down.Replace('cdn07.foxitsoftware.cn', 'cdn06.foxitsoftware.cn')
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = $Object2.down.Replace('cdn07.foxitsoftware.cn', 'cdn06.foxitsoftware.cn')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.release | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.foxitsoftware.cn/pdf-editor/version-history.html' | ConvertFrom-Html

      $ReleaseNotesNode = $Object3.SelectSingleNode("//div[@class='version_title' and contains(./h3, '$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]/following-sibling::div[@class='version_center']")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
