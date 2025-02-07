$Object1 = (Invoke-RestMethod -Uri 'https://public-cdn.cloud.unitychina.cn/hub/prod/releases-win32.json').official.Where({ $_.version.StartsWith('2023.') }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.version
$OriginalVersion = $this.CurrentState.Version -replace 'c1$'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.downloadUrl
  ProductCode  = "Unity $($this.CurrentState.Version)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://unity.com/releases/editor/whats-new/$($OriginalVersion -creplace 'f\d+', '')"
      }

      # Documentations
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'Documentations'
        Value  = @(
          @{
            DocumentLabel = 'Unity User Manual'
            DocumentUrl   = "https://docs.unity3d.com/$($OriginalVersion.Split('.')[0..1] -join '.')/Documentation/Manual/"
          }
        )
      }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'Documentations'
        Value  = @(
          [ordered]@{
            DocumentLabel = 'Unity 用户手册'
            DocumentUrl   = "https://docs.unity3d.com/$($OriginalVersion.Split('.')[0..1] -join '.')/Documentation/Manual/"
            # DocumentUrl   = "https://docs.unity3d.com/cn/$($OriginalVersion.Split('.')[0..1] -join '.')/Manual/"
          }
        )
      }

    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Query = @'
{
  getUnityReleases(
    stream: [TECH, LTS]
    platform: WINDOWS
    architecture: [X86_64, ARM64]
    version: "2023"
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
            architecture
            modules {
              url
              id
            }
          }
        }
      }
    }
  }
}
'@
      $Object2 = (Invoke-RestMethod -Uri 'https://live-platform-api.prd.ld.unity3d.com/graphql' -Method Post -Body (@{ query = $Query } | ConvertTo-Json -Compress) -ContentType 'application/json').data.getUnityReleases.edges.Where({ $_.node.version -eq $OriginalVersion }, 'First')[0].node

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = Invoke-RestMethod -Uri $Object2.releaseNotes.url | Convert-MarkdownToHtml | Get-TextContent | Format-Text
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
