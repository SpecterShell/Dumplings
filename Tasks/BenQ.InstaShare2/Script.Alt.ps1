# Alternative script: fully driven by the BenQ OTA version API that the app itself queries.
# The request is signed the same way the app signs it (HMAC-SHA1 over the unix timestamp).
# versionCode 100000000 is the packed form of 1.0.0.0, so the API always reports the latest release.
$UnixTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
$Hmac = [System.Security.Cryptography.HMACSHA1]::new([Text.Encoding]::UTF8.GetBytes('2fd221e03c9d7c5fe63eff1e6c02e958'))
$Object1 = Invoke-RestMethod -Uri 'https://tvservice-api.benq.com/api/v1/checkAndroidVerInfo?packageName=InstaShare2_Windows&versionCode=100000000' -Headers @{
  action        = 'checkAndroidVerInfo'
  apiversion    = '2.0'
  Accept        = 'application/json'
  appkey        = 'CSadmin'
  signature     = [Convert]::ToBase64String($Hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($UnixTime)))
  signaturetime = $UnixTime
}
if ($Object1.ResultCode -ne 9906) { throw "The OTA API did not report the latest version (ResultCode: $($Object1.ResultCode))" }

# Version
$this.CurrentState.Version = $Object1.getUpdateList.versionName

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = $Object1.getUpdateList.downloadLink | ConvertTo-UnescapedUri
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
