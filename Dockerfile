# escape=`
FROM microsoft/windowsservercore
MAINTAINER brycem@microsoft.com
LABEL Readme.md="https://github.com/brycem/Win10build/blob/master/README.md",`
      Description="This Dockerfile will install common Microsoft VS14+Win10 build tools & Win10 SDKv10.0.26624."

# Prepare shell environment to Log-to > C:\Dockerfile.log
SHELL ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe","-command","$ErrorActionPreference = 'Stop';","$ConfirmPreference = 'None';",`
    "$VerbosePreference = 'Continue';","Start-Transcript -path C:\\Dockerfile.log -append -IncludeInvocationHeader;","$PSVersionTable|Write-Output;",`
    "$WinVer = $(Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion');",`
    "$OsVer = $('OperatingSystem:  '+ $WinVer.ProductName +' '+$WinVer.EditionId+' '+$WinVer.InstallationType);",`
    "$BldVer = $('FullBuildString:  '+ $WinVer.BuildLabEx); Write-Output -InputObject $OsVer,$BldVer; "]
WORKDIR /

# Install Microsoft Windows 10 Standalone SDK v10.0.26624
# Includes workaround for https://github.com/PowerShell/PowerShell/issues/2571
ADD UserExperienceManifest.xml /UserExperienceManifest.new
RUN New-Item -Path C:\sdksetup -Type Directory -Force|out-null;`
    $downloadUrl = 'http://download.microsoft.com/download/E/1/F/E1F1E61E-F3C6-4420-A916-FB7C47FBC89E/standalonesdk/sdksetup.exe';`
    $expectedSha = '932814CDF2D9395CB32C2A834266D880AEB37CD3855A71A7FB3BC1613DEAA7C9';`
    Invoke-WebRequest -Uri $downloadUrl -UseBasicParsing -OutFile C:\sdkstub.exe;`
    $actualSha = $(Get-FileHash -Path C:\sdkstub.exe -Algorithm SHA256).Hash;`
    If ($expectedSha -ne $actualSha) {Throw 'sdkstub.exe hash does not match!' }`
    $procArgs = @('-norestart','-quiet','-ceip off','-Log c:\sdkstub.exe.log','-Layout c:\sdksetup',`
        '-Features OptionId.NetFxSoftwareDevelopmentKit OptionId.WindowsSoftwareDevelopmentKit');`
    Write-Host 'Executing download of Win10SDK files (approximately 500mb)...';`
    $proc = Start-Process -FilePath C:\sdkstub.exe -ArgumentList $procArgs -Wait -PassThru;`
    If ($proc.ExitCode -eq 0) {`
        Write-Host 'Win10SDK download complete.'; Remove-Item 'C:\sdkstub.exe' -Force;`
        Rename-Item 'c:\sdksetup\UserExperienceManifest.xml' 'c:\sdksetup\UserExperienceManifest.xml.bak';`
        Move-Item 'c:\UserExperienceManifest.new' 'c:\sdksetup\UserExperienceManifest.xml';`
    } else {`
        Write-output -InputObject (get-content -Path C:\sdkstub.exe.log -ea Ignore);`
        Write-Host 'See C:\Dockerfile.log for more information.';`
        Throw ('C:\sdkstub.exe returned '+$proc.ExitCode)`
    } Move-Item C:\sdkstub.exe.log c:\sdksetup\sdkstub.exe.log; Set-Location C:\sdksetup;`
    $procArgs = @('-norestart','-quiet','-ceip off','-Log c:\sdksetup\sdksetup.exe.log');`
    Write-Host 'Executing Win10SDK Setup...';`
    $proc = Start-Process -FilePath C:\sdksetup\sdksetup.exe -ArgumentList $procArgs -Wait -PassThru;`
    $mcExe = ${env:ProgramFiles(x86)}+'\Windows Kits\10\bin\x64';`
    If ((Test-Path -Path $mcExe) -and ($proc.ExitCode -eq 0)) {`
        Write-Host 'Win10SDK setup complete.'`
    } else {`
        Write-Output -InputObject (Get-Content -Path C:\sdksetup\sdksetup.exe.log -ea Ignore);`
        Write-Host ('Test-Path "'+$mcExe+'"'); Test-Path $mcExe;`
        Write-Host 'See C:\Dockerfile.log for more information.';`
        Throw ('C:\sdksetup\SdkSetup.exe returned '+$proc.ExitCode+'.  Verbose logs under c:\sdksetup\')`
    } Set-Location C:\; Remove-Item 'C:\ProgramData\Package Cache\','C:\sdksetup\' -Recurse -Force

# Download and Install VC++ 2015 Build Tools v14.0.25420.1 using customized AdminFile.xml (adds MFC\ATL headers and includes)
# http://landinghub.visualstudio.com/visual-cpp-build-tools
ADD visualcppbuildtools.xml /buildtools/AdminFile.xml
RUN $downloadUrl = 'https://download.microsoft.com/download/5/f/7/5f7acaeb-8363-451f-9425-68a90f98b238/visualcppbuildtools_full.exe';`
    Invoke-WebRequest -Uri $downloadUrl -UseBasicParsing -OutFile C:\buildtools\vcpptools.exe;`
    $expectedSha = '1E1774869ABD953D05D10372B7C08BFA0C76116F5C6DF1F3D031418CCDCD8F7B';`
    $actualSha = $(Get-FileHash -Path C:\buildtools\vcpptools.exe -Algorithm SHA256).Hash;`
    If ($expectedSha -ne $actualSha) {Throw 'vcpptools.exe hash does not match!'}`
    $procArgs = @('-NoRestart','-Quiet','-Log c:\buildtools\vcpptools.exe.log','-AdminFile C:\buildtools\AdminFile.xml');`
    Write-Host 'Starting VC++ 2015 Build Tools setup...';`
    $proc = Start-Process -FilePath C:\buildtools\vcpptools.exe -ArgumentList $procArgs -wait -PassThru;`
    $vcVars = ${env:ProgramFiles(x86)}+'\Microsoft Visual Studio 14.0\Common7\Tools\vsvars32.bat';`
    $vcBld = ${env:ProgramFiles(x86)}+'\Microsoft Visual C++ Build Tools\vcbuildtools.bat';`
    If (($proc.ExitCode -eq 0) -and (Test-Path $vcBld) -and (Test-Path $VcVars)) {`
        Write-Host 'VC++ 2015 Build Tools v14.0.25420.1 setup is complete.'`
    } else {`
        Get-Content -Path c:\buildtools\vcpptools.exe.log -ea Ignore | write-output;`
        Write-Host 'See C:\Dockerfile.log for more information.';`
        Write-Host ('Test-Path "'+$vcBld+'"'); Test-Path $vcBld;echo ('Test-Path "'+$VcVars+'"');Test-Path $VcVars;`
        Throw ('C:\buildtools\vcpptools.exe returned '+$proc.ExitCode+'. Verbose logs under c:\buildtools\')`
    } Remove-Item 'C:\ProgramData\Package Cache\','C:\buildtools\' -Recurse -Force

SHELL ["CMD.EXE","/C"]
RUN del /q C:\Dockerfile.log &>c:\entrypoint.bat echo @echo off &>>c:\entrypoint.bat echo pushd C:&`
    >>c:\entrypoint.bat echo call "C:\Program Files (x86)\Microsoft Visual C++ Build Tools\vcbuildtools.bat"&`
    >>c:\entrypoint.bat echo popd&>>c:\entrypoint.bat echo powershell -c $ErrorActionPreference='Stop';$ConfirmPreference='None';%*

WORKDIR /Code
ENTRYPOINT ["C:\\entrypoint.bat"]
