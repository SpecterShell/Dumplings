$Global:LocalStorage.HiteVisionApps = [ordered]@{}

$Object1 = Invoke-RestMethod -Uri 'https://appmanager.hitecloud.cn/service/cloud/httpCommandService?cmd=appManager&cmd_op=getAppClassificationList'

$Object1.result | ForEach-Object -Process { $_.appList } | ForEach-Object -Process {
  $Global:LocalStorage.HiteVisionApps[$_.appPackageUuid] = $_
}
