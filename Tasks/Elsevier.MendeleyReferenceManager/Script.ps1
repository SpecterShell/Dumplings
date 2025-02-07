$Prefix = 'https://static.mendeley.com/bin/desktop/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'en-US'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
