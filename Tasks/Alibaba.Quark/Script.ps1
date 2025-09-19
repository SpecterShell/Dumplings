$Object1 = Invoke-RestMethod -Uri 'https://coral2.uc.cn/aggregation/quarkPcDownloadPackage' -Body @{
  req_services = '[{"module":"diamond","key":"quark-pc-download-package"}]'
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.data.Where({ $_.key -eq 'quark-pc-download-package' }, 'First')[0].data.homePageDefaultLink
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, 'V(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
