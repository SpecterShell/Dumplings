$Query = @'
query {
  getUnityReleases(
    stream: [TECH, LTS]
    platform: WINDOWS
    architecture: X86_64
    version: "2021"
  ) {
    edges {
      node {
        version
        releaseDate
        releaseNotes {
          url
        }
        downloads {
          ... on UnityReleaseHubDownload {
            url
          }
        }
      }
    }
  }
}
'@

$Object1 = (Invoke-RestMethod -Uri 'https://live-platform-api.prd.ld.unity3d.com/graphql' -Method Post -Body (@{ query = $Query } | ConvertTo-Json -Compress) -ContentType 'application/json').data.getUnityReleases.edges[0].node

# Version
$this.CurrentState.Version = $Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.downloads[0].url
  ProductCode  = "Unity ${Version}"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate.ToUniversalTime()

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://unity.com/releases/editor/whats-new/$($Version -creplace 'f\d+', '')"
      }

      # Documentations
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'Documentations'
        Value  = @(
          @{
            DocumentLabel = 'Unity User Manual'
            DocumentUrl   = "https://docs.unity3d.com/$($Version.Split('.')[0..1] -join '.')/Documentation/Manual/"
          }
        )
      }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'Documentations'
        Value  = @(
          [ordered]@{
            DocumentLabel = 'Unity 用户手册'
            DocumentUrl   = "https://docs.unity3d.com/cn/$($Version.Split('.')[0..1] -join '.')/Manual/"
          }
        )
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = Invoke-RestMethod -Uri $Object1.releaseNotes.url | Convert-MarkdownToHtml | Get-TextContent | Format-Text
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
