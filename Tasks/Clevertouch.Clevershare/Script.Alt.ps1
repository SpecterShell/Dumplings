$Body = @{
  interfaceName = 'com.ifp.ota.update.service.api.UpdateDataApiService'
  method        = 'getUpdateData'
  superParams   = @(
    @{
      type  = 'com.ifp.ota.update.service.dto.update.UpdateGetDto'
      value = @{
        appKey      = $Global:DumplingsSecret.ClevershareKey
        deviceMac   = ''
        platform    = 'android_rom'
        policyId    = ''
        tag         = ''
        versionCode = $this.Status.Contains('New') ? '5.4.2.3367' : $this.LastState.Version
      }
    }
  )
} | ConvertTo-Json -Compress -Depth 5
$TimeStamp = [System.DateTimeOffset]::Now.ToUnixTimeMilliseconds().ToString()
$Hash = [System.BitConverter]::ToString(
  [System.Security.Cryptography.MD5]::HashData(
    [System.Text.Encoding]::UTF8.GetBytes("body$($Body.Replace('"', ''))methodgetUpdateDatamoduleifp-ota-platformrpcTypedubbotimestamp${TimeStamp}$($Global:DumplingsSecret.ClevershareSecret)".Replace(' ', ''))
  )
).Replace('-', '')

$Object1 = Invoke-RestMethod -Uri 'https://api.bytello.com/' -Method Post -Headers @{
  method    = 'getUpdateData'
  module    = 'ifp-ota-platform'
  rpcType   = 'dubbo'
  timestamp = $TimeStamp
  appKey    = 'ifp-ota-app'
  sign      = $Hash
} -Body $Body -ContentType 'application/json'

if (-not $Object1.data.hasUpdate) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.data.targetVersionCode

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.downloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.updateStartTime | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.updateDesc | Format-Text
      }
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
