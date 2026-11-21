$SN = (New-Guid).Guid.Replace('-', '')
$Version = $this.Status.Contains('New') ? '3.3.0.259' : $this.LastState.Version
$Params = '{{"sn":"{0}","softList":[{{"channel":"x86","softCode":"2","version":"{1}"}}],"takeNewInstall":true}}' -f $SN, $Version
$H1 = [Convert]::ToHexString([System.Security.Cryptography.MD5CryptoServiceProvider]::HashData([Text.Encoding]::UTF8.GetBytes($Params + $Params.Length))).ToLower()
$H2 = [Convert]::ToHexString([System.Security.Cryptography.MD5CryptoServiceProvider]::HashData([Text.Encoding]::UTF8.GetBytes($H1.Substring(8, 16) + $Sn))).ToLower()
$Object1 = Invoke-RestMethod -Uri 'https://update.pc.mi.com/api/update/check.json' -Method Post -Body @{
  params = $Params
  sign   = $H1.Substring(8, 16) + $H2.Substring(8, 16)
}

if ($Object1.status -ne 0) {
  $this.Log($Object1.message, 'Warning')
  return
}

if (-not $Object1.PSObject.Properties['data'] -or $null -eq $Object1.data) {
  $this.Log("The version $($Version) from the last state is the latest", 'Info')
  return
}

$Object2 = ($Object1.data.body | ConvertFrom-Json).Where({ $_.softCode -eq '2' }, 'First')[0]
# Version
$this.CurrentState.Version = $Object2.downloads[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.downloads[0].downloadUrl
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
