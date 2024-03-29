$Prefix = 'https://static.mendeley.com/bin/desktop/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'en-US'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Uri1 = 'https://www.mendeley.com/release-notes-reference-manager/'

      $EdgeDriver = Get-EdgeDriver
      $EdgeDriver.Navigate().GoToUrl($Uri1)

      # Hide cookies banner
      # Banner does not show up immediately after loaded. Put a global style here so we don't have to wait
      $EdgeDriver.ExecuteScript(@'
let element = document.createElement('style')
element.innerText = '#onetrust-consent-sdk { display: none }'
document.querySelector("head").appendChild(element)
'@, $null)
      # Click on the link to navigate to the release notes of specific version
      $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath("//a[contains(text(), 'v$($this.CurrentState.Version)')]")).Click()

      $ReleaseNotesObject = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath("//div[contains(@class, 'rightCol')]//div[contains(@class, 'content_item')]")).GetAttribute('innerHTML') | ConvertFrom-Html
      $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("./h2[contains(text(), 'v$($this.CurrentState.Version)')]")
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
          Value = $EdgeDriver.Url
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Uri1
        }
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Uri1
      }
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
