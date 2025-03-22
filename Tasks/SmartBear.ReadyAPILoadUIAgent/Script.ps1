$Object1 = Invoke-RestMethod -Uri 'https://support.smartbear.com/rest/customtableitem.org.ReReplacer?format=json&columns=Search,Replace&Where=ItemGUID%20IN%20(%279b190faf-cac2-4319-bfee-db2d71759bf1%27,%27df87774e-2b52-4905-b5c4-5906a4033ca6%27,%2738ed1a7a-7361-4ee1-8e83-126a1dd333e6%27,%276ac2d272-d91e-42ed-abca-f89eb36afa17%27,%279fb7aac1-59d1-4c62-8d44-4ca3f214bb89%27,%270abf634c-1a78-4b02-b46d-0a9e57d98ee4%27,%272a006932-618e-43e9-8c0c-372cea26b12e%27,%27957b65d6-51a9-41ca-aae8-4fb7162f5932%27,%277a3e6af0-8c20-485f-9c44-f62015b22eea%27,%271eb7f47a-6357-4d69-8a27-2c7ea2e82126%27,%27b99fb461-dc7e-43ef-8126-98ef6272735c%27,%2708b7d1aa-733b-4ba3-b5d8-7f906fe35075%27,%2758a8ffee-38aa-45d0-878e-6c0bad9689d5%27,%274bf1f213-b1db-4244-a053-ac5ce413a901%27,%270402a442-3746-4671-980e-f54665010c14%27,%27a5e620e1-66f4-4c60-8c99-6fefc1afcf57%27,%27274c7617-dedd-4ed9-90ad-70e8d92c0c78%27)&hash=0381ffae343473abd235d14ad40d4b8ba026d03b75befa003e1633b617e012df'

# Version
$this.CurrentState.Version = $Object1.customtableitem_org_ReReplacers[0].org_ReReplacer.Where({ $_.Search -eq '{{latest-readyapi-version-title-build}}' }, 'First')[0].Replace

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://dl.eviware.com/ready-api/$($this.CurrentState.Version)/LoadUIAgent-x64-$($this.CurrentState.Version).exe"
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
