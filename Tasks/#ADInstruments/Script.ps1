$MajorVersion = 8
if ((Invoke-WebRequest -Uri "https://www.adinstruments.com/LabChart$($MajorVersion + 1)SoftwareUpdateWin.plist" -MaximumRetryCount 0 -SkipHttpErrorCheck).StatusCode -eq 200) {
  $MajorVersion += 1
  $this.Log("Next major version ${MajorVersion} available", 'Warning')
}
$Global:DumplingsStorage.ADInstrumentsApps = Invoke-RestMethod -Uri "https://www.adinstruments.com/LabChart${MajorVersion}SoftwareUpdateWin.plist" | ConvertFrom-PropertyList
