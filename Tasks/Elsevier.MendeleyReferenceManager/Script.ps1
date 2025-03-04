$Prefix = 'https://static.mendeley.com/bin/desktop/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml

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
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://www.mendeley.com/release-notes-reference-manager/'
      }

      $ReleaseNotesUrl = "https://www.mendeley.com/release-notes-reference-manager/v$($this.CurrentState.Version)"

      $EdgeDriver = Get-EdgeDriver -Headless
      $EdgeDriver.Navigate().GoToUrl($ReleaseNotesUrl)

      # Hide cookies banner
      # Banner does not show up immediately after loaded. Put a global style here so we don't have to wait
      $EdgeDriver.ExecuteScript(@'
let element = document.createElement('style')
element.innerText = '#onetrust-consent-sdk { display: none }'
document.querySelector("head").appendChild(element)
'@, $null)

      $ReleaseNotesObject = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath("//div[contains(@class, 'rightCol')]")).GetAttribute('innerHTML') | ConvertFrom-Html
      if (-not [string]::IsNullOrWhiteSpace($ReleaseNotesObject.InnerText)) {
        $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode(".//h2[contains(text(), 'v$($this.CurrentState.Version)')]")
        if ($ReleaseNotesTitleNode) {
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }

          # ReleaseNotesUrl
          $this.CurrentState.Locale += [ordered]@{
            Key   = 'ReleaseNotesUrl'
            Value = $ReleaseNotesUrl
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
