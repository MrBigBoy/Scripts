@echo off
:: --- Auto elevate to admin ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

echo Running as Administrator...
echo Scanning D:\Repos for build folders...

set count=0

for %%n in (bin obj .vs .vscode) do (
    for /f "delims=" %%d in ('dir /s /b /ad "D:\Repos\%%n" 2^>nul') do (
        echo Deleting %%d
        rmdir /s /q "%%d"
        set /a count+=1
    )
)

echo.
echo Deleted %count% folders.
echo Cleanup complete!
pause