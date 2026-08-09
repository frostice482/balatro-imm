@echo off
setlocal enabledelayedexpansion

set "savepath=%appdata%\balatro"
set "modspath=%savepath%\Mods"
if not exist "%modspath%" md "%modspath%"

rem check for game folder
set "gamepath=C:\Program Files (x86)\Steam\steamapps\common\Balatro"
if not exist "%gamepath%" (
	set gamepath=
	echo The installer script cannot determine your Balatro install location.
	echo Provide installation folder by dragging it here, or type in the path
	echo or leave blank to go back

	:select_gamepath
	set /p gamepath=:
	if ["!gamepath!"] == [""] exit /b
	set check="resources\gamecontrollerdb.txt"
	if not exist "!gamepath!\Balatro.exe" (
		if exist "!gamepath!\Balatro\Balatro.exe" (
			set "gamepath=!gamepath!\Balatro"
		) else if exist "!gamepath!\common\Balatro\Balatro.exe" (
			set "gamepath=!gamepath!\common\Balatro"
		) else if exist "!gamepath!\steamapps\common\Balatro\Balatro.exe" (
			set "gamepath=!gamepath!\steamapps\common\Balatro"
		) else (
			echo Not a valid Balatro installation path
			goto select_gamepath
		)
	)
)

rem install lovely if not detected
if not exist "%gamepath%\version.dll" (
	echo Downloading lovely injector
	curl -fSL "https://github.com/ethangreen-dev/lovely-injector/releases/latest/download/lovely-x86_64-pc-windows-msvc.zip" -o lovely.zip
	tar -xzmf lovely.zip -C __lovely -k

	move __lovely\version.dll "%gamepath%"
	rd /s /q __lovely
)

dir /b /a "%modspath%" 2>nul | findstr . >nul
set download_smods=no
if errorlevel 1 (
	set download_smods=yes
) else (
	echo The mods folder is not empty. You might have Steamodded already installed.
	choice /c yn /m "Do you want to download Steamodded^? It will be required by most mods. "
	if !errorlevel! == 1 set download_smods=yes
)

if "%download_smods%" == "yes" (
	echo Downloading smods
	curl -fSL "https://github.com/Steamodded/smods/archive/refs/heads/stable.zip" -o "%modspath%\smods.zip"
)

echo Downloading imm
curl -fSL "https://github.com/frostice482/balatro-imm/archive/refs/heads/master.zip" -o __imm.zip

rem since it's downloaded from commit it will be one folder deep.
rem select the only folder then move it to the mods folder.
rem this won't be an issue with using release assets

echo Extracting imm
mkdir __imm
tar -xzmf __imm.zip -C __imm -k
cd __imm
for /f delims^=^ eol^= %%a in ('dir /b /w .') do (
	ren %%a imm
	move imm "%modspath%"
	goto stop_extract_imm
)
:stop_extract_imm
cd ..
rd /s /q __imm
del __imm.zip

echo Done. Your Balatro is now modded. Enjoy!
pause