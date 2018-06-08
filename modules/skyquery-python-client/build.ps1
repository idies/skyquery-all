$SWAGGER_VERSION = "2.3.1"
$SWAGGER_FILE = "skyquery.json"
$SKYQUERY_HOST = "localhost"
$SKYQUERY_URL = "http://$SKYQUERY_HOST/dobos/skyquery-v1.4"
$SKYQUERY_JSON = "$SKYQUERY_URL/Apps/Api/Proxy.ashx?target=json"

# Verify JAVA
if ((Get-Command "java.exe" -ErrorAction SilentlyContinue) -eq $null) 
{ 
  Write-Host "Unable to find java.exe in your PATH"
  exit 1
}

# Download Swagger
if (-not (Test-Path "swagger-codegen-cli.jar")) {
  wget "http://central.maven.org/maven2/io/swagger/swagger-codegen-cli/$SWAGGER_VERSION/swagger-codegen-cli-$SWAGGER_VERSION.jar" -O "swagger-codegen-cli.jar"
}

Write-Host "Downloading swagger file from $SKYQUERY_JSON"
# Generate Swagger file by calling web service proxy generator
wget "$SKYQUERY_JSON" -O "$SWAGGER_FILE"

# Generate proxy
java.exe -jar .\swagger-codegen-cli.jar generate -i "$SWAGGER_FILE" -l python -o . -DpackageName=skyquery