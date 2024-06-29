$Response = Invoke-RestMethod -Uri 'https://pkg-cdn.jianguoyun.com/static/exe/latestVersion'
# x86
$Object1 = $Response.Where({ $_.OS -eq 'yiyang-suite-win-x86' }, 'First')[0]
# x64
$Object2 = $Response.Where({ $_.OS -eq 'yiyang-suite-win-x64' }, 'First')[0]
# arm64
$Object3 = $Response.Where({ $_.OS -eq 'yiyang-suite-win-arm64' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object2.exVer

$Identical = $true
if ((@($Object1, $Object2, $Object3) | Sort-Object -Property 'exVer' -Unique).Count -gt 1) {
  $this.Log('Distinct versions detected', 'Warning')
  $this.Log("x86 version: $($Object1.exVer)")
  $this.Log("x64 version: $($Object2.exVer)")
  $this.Log("arm64 version: $($Object3.exVer)")
  $Identical = $false
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.exUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.exUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object3.exUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object4 = Invoke-WebRequest -Uri 'https://www.eo2suite.cn/update/' | ConvertFrom-Html

      $ReleaseNotesNode = $Object4.SelectSingleNode("//div[@class='container']/div[@class='row' and contains(./div[1], 'v $($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesNode.SelectSingleNode('./div[1]').InnerText,
          '(\d{4}\.\d{1,2}\.\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./div[2]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
  ({ $_ -match 'Updated' -and $Identical }) {
    $this.Submit()
  }
}
