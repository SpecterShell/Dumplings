$Object1 = (Invoke-RestMethod -Uri 'https://cdn-ffc.oobesaas.adobe.com/core/v1/applications?name=CreativeCloud&platform=win64').applications.application.Where({ $_.name -eq 'CreativeCloud' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl    = $InstallerUrl = 'https://prod-rel-ffc-ccm.oobesaas.adobe.com/adobe-ffc-external/core/v1/wam/download?sapCode=KCCC&wamFeature=nuj-live'
  InstallerSha256 = (Get-TempFile -Uri $InstallerUrl | Get-FileHash -Algorithm SHA256).Hash
}

if (-not $this.Status.Contains('New') -and $this.CurrentState.Installer[0]['InstallerSha256'] -ne $this.LastState.Installer[0]['InstallerSha256']) {
  $this.Status.Add('Changed')
  $this.Config.IgnorePRCheck = $true
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
    $this.Submit()
  }
}
