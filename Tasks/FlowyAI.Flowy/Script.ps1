$Prefix = 'https://download.flowygpt.cn/flowy/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}beta.yml" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.files[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $ReleaseNotes = Use-PlaywrightPage -Stealth -Headless {
        param($Page)

        $null = Open-PlaywrightPage -Page $Page -Uri 'https://www.flowyaipc.com/download'

        $null = Wait-PlaywrightTask -Task $Page.Locator('xpath=/html/body/div[2]/div/button').ClickAsync()
        $null = Wait-PlaywrightTask -Task $Page.Locator('xpath=/html/body/div[2]/div/div/button[1]').ClickAsync()
        $null = Wait-PlaywrightTask -Task $Page.Locator("xpath=//h3[contains(., '$($this.CurrentState.Version)')]").ClickAsync()
        $English = Read-PlaywrightLocator -Page $Page -Selector "xpath=//h3[contains(., '$($this.CurrentState.Version)')]/following-sibling::*[1]"

        $null = Wait-PlaywrightTask -Task $Page.Locator('xpath=/html/body/div[2]/div/button').ClickAsync()
        $null = Wait-PlaywrightTask -Task $Page.Locator('xpath=/html/body/div[2]/div/div/button[2]').ClickAsync()
        $null = Wait-PlaywrightTask -Task $Page.Locator("xpath=//h3[contains(., '$($this.CurrentState.Version)')]").ClickAsync()
        [pscustomobject]@{
          English = $English
          Chinese = Read-PlaywrightLocator -Page $Page -Selector "xpath=//h3[contains(., '$($this.CurrentState.Version)')]/following-sibling::*[1]"
        }
      }

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes.English | ConvertFrom-Html | Get-TextContent | Format-Text
      }

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes.Chinese | ConvertFrom-Html | Get-TextContent | Format-Text
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
