$Object1 = Invoke-RestMethod -Uri 'https://update.internet.apps.samsung.com/service/update2/json' -Method Post -Headers @{ Range = 'bytes=5-' } -Body (
  @{
    request = @{
      acceptformat = 'crx3,download,puff,run'
      apps         = @(@{ appid = 'ohpjbciplfdockeiligelcjnkiejldpn'; updatecheck = @{ sameversionupdate = $true } })
      os           = @{ arch = 'x86_64'; platform = 'Windows'; version = '10.0.22000' }
      protocol     = '4.0'
    }
  } | ConvertTo-Json -Depth 5 -Compress
) -ContentType 'application/json'
$Object2 = $Object1.Substring(4) | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object2.response.apps[0].updatecheck.nextversion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = $Object2.response.apps[0].updatecheck.pipelines[0].operations[0].urls[0].url
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = $Object2.response.apps[0].updatecheck.pipelines[0].operations[1].path
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = (7z.exe e -y -so $InstallerFile 'manifest.json' | ConvertFrom-Json).version

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
