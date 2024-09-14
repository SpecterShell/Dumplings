$Object1 = (Invoke-WebRequest -Uri 'https://s3.us-west-1.amazonaws.com/public.useanything.com/latest/version.txt').Content

# Version
$this.CurrentState.Version = $Object1.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://s3.us-west-1.amazonaws.com/public.useanything.com/latest/AnythingLLMDesktop.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://docs.anythingllm.com/changelog/overview'
      }

      $Object2 = Invoke-WebRequest -Uri "https://docs.anythingllm.com/changelog/v$($this.CurrentState.Version)" | ConvertFrom-Html

      # ReleaseNotes
      $ReleaseNotesNodes = for ($Node = $Object2.SelectSingleNode('//main/h2[1]'); $Node -and -not $Node.HasClass('nx-items-center'); $Node = $Node.NextSibling) { $Node }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
