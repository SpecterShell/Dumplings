$Object1 = Invoke-RestMethod -Uri 'https://update.viber.com/viber/viber.php?function=ClientUpdate' -Method Post -Body @{
  XMLDOC = @"
<?xml version="1.0" encoding="UTF-8"?>
<ClientUpdateRequest>
    <ClientInfo>
        <ViberVersion>$($this.Status.Contains('New') ? $this.LastState.Version : '22.4.1.0')</ViberVersion>
        <Is64>1</Is64>
    </ClientInfo>
    <SystemInfo>
        <System>Windows</System>
        <SystemVersion>10.0.22000</SystemVersion>
        <Arch>x86_64</Arch>
    </SystemInfo>
</ClientUpdateRequest>
"@
}

if ($Object1.ClientUpdateResponse -is [string]) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.ClientUpdateResponse.ViberVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = "https://download.cdn.viber.com/desktop/windows/$($this.CurrentState.Version.Split('.')[0..2] -join '.')/ViberSetup.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
  'Updated|Rollbacked' {
    $this.Submit()
  }
}
