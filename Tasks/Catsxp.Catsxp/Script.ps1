$Object1 = Invoke-RestMethod -Uri 'https://www.catsxp.com/api/service/Update?cup2key=:' -Method Post -Body @"
<?xml version="1.0" encoding="UTF-8"?>
<request>
  <app appid="{485AC8F6-31A4-3283-B765-92E31A816C51}" version="$($this.CurrentState.Contains('Version') ? $this.CurrentState.Version : '132.4.12.1')" ap="x86-release" />
  <app appid="{485AC8F6-31A4-3283-B765-92E31A816C51}" version="$($this.CurrentState.Contains('Version') ? $this.CurrentState.Version : '132.4.12.1')" ap="x64-release" />
</request>
"@

if ($Object1.response.app.updatecheck.status -contains 'noupdate') {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.response.app[1].updatecheck.manifest.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.response.app[0].updatecheck.urls.url.codebase | Select-String -Pattern 'catsxp.oss-cn-hongkong.aliyuncs.com' -Raw -SimpleMatch
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.response.app[1].updatecheck.urls.url.codebase | Select-String -Pattern 'catsxp.oss-cn-hongkong.aliyuncs.com' -Raw -SimpleMatch
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.catsxp.com/history' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@id='accordion']/div[contains(./a/h4/text()[2], '$([regex]::Match($this.CurrentState.Version, '\d+\.(\d+\.\d+\.\d+)').Groups[1].Value)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesNode.SelectSingleNode('./a/h4/i').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2} \d{2}:\d{2}:\d{2})'
        ).Groups[1].Value | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./div/div') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.catsxp.com/zh-hans/history' | ConvertFrom-Html

      $ReleaseNotesCNNode = $Object3.SelectSingleNode("//*[@id='accordion']/div[contains(./a/h4/text()[2], '$([regex]::Match($this.CurrentState.Version, '\d+\.(\d+\.\d+\.\d+)').Groups[1].Value)')]")
      if ($ReleaseNotesCNNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [regex]::Match(
          $ReleaseNotesCNNode.SelectSingleNode('./a/h4/i').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2} \d{2}:\d{2}:\d{2})'
        ).Groups[1].Value | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNNode.SelectSingleNode('./div/div') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
