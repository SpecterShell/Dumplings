$Query = @'
query {
  slugInfo(
    slug: "software-pages/Motion_Control"
    cultureName: "en-US"
    storeId: "Thorlabs-Website"
  ) {
    entityInfo {
      id
    }
  }
}
'@
$Object1 = Invoke-RestMethod -Uri 'https://www.thorlabs.com/graphql' -Method Post -Body (@{ query = $Query } | ConvertTo-Json -Compress) -ContentType 'application/json'

$Query = @"
query {
  page(
    storeId: "Thorlabs-Website"
    id: "$($Object1.data.slugInfo.entityInfo.id)"
    cultureName: "en-US"
  ) {
    content
    permalink
  }
}
"@
$Object2 = Invoke-RestMethod -Uri 'https://www.thorlabs.com/graphql' -Method Post -Body (@{ query = $Query } | ConvertTo-Json -Compress) -ContentType 'application/json'
$Global:DumplingsStorage.KinesisDownloadPage = $Object2.data.page.content | ConvertFrom-Json


