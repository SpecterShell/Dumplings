$Object1 = Invoke-RestMethod -Uri 'https://www.teach.nl/pad_file.xml'

# Version
$this.CurrentState.Version = $Object1.XML_DIZ_INFO.Program_Info.Program_Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = $Object1.XML_DIZ_INFO.Web_Info.Download_URLs.Primary_Download_URL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = Get-Date -Year $Object1.XML_DIZ_INFO.Program_Info.Program_Release_Year `
        -Month $Object1.XML_DIZ_INFO.Program_Info.Program_Release_Month `
        -Day $Object1.XML_DIZ_INFO.Program_Info.Program_Release_Day `
        -Format 'yyyy-MM-dd'
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
