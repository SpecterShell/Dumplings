# $Object1 = Invoke-RestMethod -Uri 'https://omaha.formlabs.com/service/update2' -Method Post -Body @"
# <?xml version="1.0" encoding="UTF-8"?>
# <request protocol="3.0" ismachine="1" sessionid="{$((New-Guid).Guid)}" requestid="{$((New-Guid).Guid)}">
#   <os platform="win" version="10.0.22000" sp="" arch="x64" />
#   <app appid="{61EFB8FF-2024-4F3C-BCCC-46A71D341A59}" version="" nextversion="" lang="" brand="" client="">
#     <updatecheck />
#   </app>
# </request>
# "@

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = (Invoke-RestMethod -Uri 'https://downloads.formlabs.com/PreForm/Release/LATEST.win.txt').Trim()
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, 'PreForm_win_([\d\.]+)_.+?_(\d+)[_\.]').Groups[@(1, 2)].Value | Join-String -Separator '.'

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
