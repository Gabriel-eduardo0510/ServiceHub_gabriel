param([switch]$Testar,[switch]$Postgres,[switch]$Verificar)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$bundledJdk = 'C:\Program Files\JetBrains\IntelliJ IDEA 2025.2.3\jbr'
if (-not $env:JAVA_HOME -and (Test-Path "$bundledJdk/bin/javac.exe")) { $env:JAVA_HOME = $bundledJdk }
if (-not $env:JAVA_HOME) { throw 'Configure JAVA_HOME para um JDK 21 ou superior.' }
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
$bundledMaven = 'C:\Program Files\JetBrains\IntelliJ IDEA 2025.2.3\plugins\maven\lib\maven3\bin\mvn.cmd'
$mavenCommand = Get-Command mvn.cmd -ErrorAction SilentlyContinue
if ($mavenCommand) { $maven = $mavenCommand.Source } elseif (Test-Path $bundledMaven) { $maven = $bundledMaven } else { throw 'Instale Maven 3.6.3+ e adicione mvn ao PATH.' }
if ($Verificar) { & $maven clean verify } elseif ($Testar) { & $maven test } elseif ($Postgres) { & $maven spring-boot:run '-Dspring-boot.run.profiles=postgres' } else { & $maven spring-boot:run }
exit $LASTEXITCODE
