$Object1 = Invoke-RestMethod -Uri 'https://readpaper.com/api/microService-acl/dic/public/app/getListByAppIdAndParentIdNameAvailable?appId=aiKnowledge&parentIdName=ClientDownloadManage'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.Where({ $_.groupName -eq 'windows' -and $_.downloadChannel.Contains('官方下载') }, 'First')[0].downloadUrl
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
