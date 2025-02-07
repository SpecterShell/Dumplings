$Query = @'
{
  getUnityReleases(
    stream: [TECH, LTS]
    platform: WINDOWS
    architecture: [X86_64, ARM64]
    version: "6000"
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

$Object1 = (Invoke-RestMethod -Uri 'https://live-platform-api.prd.ld.unity3d.com/graphql' -Method Post -Body (@{ query = $Query } | ConvertTo-Json -Compress) -ContentType 'application/json').data.getUnityReleases.edges[0].node

# Version
$this.CurrentState.Version = $Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.downloads.Where({ $_.architecture -eq 'X86_64' }, 'First')[0].url
  ProductCode  = "Unity ${Version}"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object1.downloads.Where({ $_.architecture -eq 'ARM64' }, 'First')[0].url
  ProductCode  = "Unity ${Version}"
}

# # Modules
# $this.CurrentState.Modules = [ordered]@{}
# foreach ($Module in $Object1.downloads.Where({ $_.architecture -eq 'X86_64' }, 'First')[0].modules) {
#   $this.CurrentState.Modules[$Module.id] = $Module.url
# }

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
            DocumentUrl   = "https://docs.unity3d.com/$($Version.Split('.')[0..1] -join '.')/Documentation/Manual/"
            # DocumentUrl   = "https://docs.unity3d.com/cn/$($Version.Split('.')[0..1] -join '.')/Manual/"
          }
        )
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # $OldLocale = $this.CurrentState.Locale
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

    # # Also submit manifests for sub modules
    # $OldWinGetIdentifier = $this.Config.WinGetIdentifier
    # $this.CurrentState.Locale = $OldLocale
    # foreach ($KVP in $this.Config.WinGetIdentifierModules.GetEnumerator()) {
    #   $this.Log("Handling $($KVP.Value)...", 'Info')
    #   $this.Config.WinGetIdentifier = $KVP.Value
    #   $this.CurrentState.Installer = @(
    #     [ordered]@{
    #       InstallerUrl = $this.CurrentState.Modules[$KVP.Key]
    #       Dependencies = [ordered]@{
    #         PackageDependencies = @(
    #           [ordered]@{
    #             PackageIdentifier = $OldWinGetIdentifier
    #             MinimumVersion    = $this.CurrentState.Version
    #           }
    #         )
    #       }
    #     }
    #   )
    #   try {
    #     $this.Submit()
    #   } catch {
    #     $_ | Out-Host
    #     $this.Log($_, 'Warning')
    #   }
    # }
  }
}
