$Object1 = Invoke-RestMethod -Uri 'https://firmverup.brother.co.jp/KNE_APP_UPDATE/app_update.asmx/fileUpdate' -Method Post -Body @'
<?xml version="1.0" encoding="utf-8"?>
<RequestInfo xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <AppDownloaderSetting>
    <AppId>IPSW</AppId>
    <InspectMode>0</InspectMode>
  </AppDownloaderSetting>
  <ModelInfo>
    <Name>IPSWV2</Name>
    <Spec>0804</Spec>
    <AppInfo>
      <Id>IPSW</Id>
      <Version>13.1.0.0</Version>
    </AppInfo>
  </ModelInfo>
  <NeedResponse>1</NeedResponse>
</RequestInfo>
'@

if ($Object1.ResponseInfo.UpdateInfo.VersionCheck -ne '0') {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.ResponseInfo.UpdateInfo.LatestVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.ResponseInfo.UpdateInfo.Path
}

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
