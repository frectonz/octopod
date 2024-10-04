# INITIAL CHECK
GET  {{address}}/v2/

HTTP 200
Content-Type: application/json

{}


# GET IMAGES CATALOG
GET  {{address}}/v2/_catalog

HTTP 200
Content-Type: application/json

[Asserts]
jsonpath "$.repositories" count > 0

[Captures]
image_name: jsonpath "$.repositories[0]"


# GET IMAGE TAGS
GET  {{address}}/v2/{{image_name}}/tags/list

HTTP 200
Content-Type: application/json

[Asserts]
jsonpath "$.name" == {{image_name}}
jsonpath "$.tags" count > 0

[Captures]
tag_name: jsonpath "$.tags[0]"


# GET TAG MANIFEST
GET  {{address}}/v2/{{image_name}}/manifests/{{tag_name}}

HTTP 200
Content-Type: application/json

[Asserts]
jsonpath "$.schemaVersion" == 2
jsonpath "$.mediaType" == "application/vnd.docker.distribution.manifest.v2+json"

jsonpath "$.config.mediaType" =="application/vnd.docker.container.image.v1+json"
jsonpath "$.config.digest" split ":" nth 0 == "sha256"
jsonpath "$.config.size" > 0

jsonpath "$.layers" count > 0
jsonpath "$.layers[0].mediaType" == "application/vnd.docker.image.rootfs.diff.tar.gzip"
jsonpath "$.layers[0].digest" split ":" nth 0 == "sha256"
jsonpath "$.layers[0].size" > 0

[Captures]
config_digest: jsonpath "$.config.digest"


# GET IMAGE CONFIG
GET  {{address}}/v2/{{image_name}}/blobs/{{config_digest}}

HTTP 200
Content-Type: application/json
