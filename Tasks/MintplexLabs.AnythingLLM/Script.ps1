$Object1 = Invoke-WebRequest -Uri 'https://cdn.anythingllm.com/latest/version.txt'

# Version
$this.CurrentState.Version = $Object1.Content.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://cdn.anythingllm.com/latest/AnythingLLMDesktop.exe'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = 'https://cdn.anythingllm.com/latest/AnythingLLMDesktop-Arm64.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # try {
    #   # ReleaseNotesUrl (en-US)
    #   $this.CurrentState.Locale += [ordered]@{
    #     Locale = 'en-US'
    #     Key    = 'ReleaseNotesUrl'
    #     Value  = 'https://docs.anythingllm.com/changelog/overview'
    #   }

    #   $Object2 = Invoke-WebRequest -Uri "https://docs.anythingllm.com/changelog/v$($this.CurrentState.Version)" | ConvertFrom-Html

    #   # ReleaseNotes (en-US)
    #   $ReleaseNotesNodes = for ($Node = $Object2.SelectSingleNode('//main/h2[1]'); $Node -and -not $Node.HasClass('nx-items-center'); $Node = $Node.NextSibling) { $Node }
    #   $this.CurrentState.Locale += [ordered]@{
    #     Locale = 'en-US'
    #     Key    = 'ReleaseNotes'
    #     Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
    #   }

    #   # ReleaseNotesUrl (en-US)
    #   $this.CurrentState.Locale += [ordered]@{
    #     Locale = 'en-US'
    #     Key    = 'ReleaseNotesUrl'
    #     Value  = "https://docs.anythingllm.com/changelog/v$($this.CurrentState.Version)"
    #   }
    # } catch {
    #   $_ | Out-Host
    #   $this.Log($_, 'Warning')
    # }

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
