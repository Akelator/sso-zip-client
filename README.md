# sso-zip-client

## you must have 7z enviroment path and Avalnia

### dotnet new install Avalonia.Templates

### dotnet restore

### dotnet publish -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true

## for debug the app use prod=false on MainWindow
