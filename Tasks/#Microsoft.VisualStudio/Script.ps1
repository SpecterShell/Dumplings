$Object1 = Invoke-RestMethod -Uri 'https://aka.ms/vs/17/release/channel'

$Global:DumplingsStorage.VisualStudioManifestFile = Get-TempFile -Uri $Object1.channelItems.Where({ $_.id -eq 'Microsoft.VisualStudio.Manifests.VisualStudio' }, 'First')[0].payloads.Where({ $_.filename -eq 'VisualStudio.vsman' }, 'First')[0].url
