balatrosub=/common/Balatro

function prompt_search() {
	local fixes=(
		".local/share/Steam/steamapps"
		"steam/steamapps"
		"steamapps"
		""
	)
	local selectedfolder

	while true; do
		echo -n ":"; read selectedfolder
		if [ ! "$selectedfolder" ]; then exit 1; fi
		selectedfolder=$(echo "$selectedfolder" | sed "s/^[\"']//;s/[\"']$//")

		local found=0
		for fix in "${fixes[@]}"; do
			local sub="$selectedfolder/$fix"
			if [ -d "$sub" -a -d "$sub/$balatrosub" ]; then
				gamefolder="$sub"
				found=1
			fi
		done
		if [ $found == 1 ]; then break; fi
		echo 'Not a valid Steam installation path / steamapps folder'
	done
}

steamfolder="$HOME/.local/share/Steam"
if [ ! -d "$steamfolder" ]; then steamfolder="$HOME/snap/steam/common/.local/share/Steam"; fi
if [ ! -d "$steamfolder" ]; then steamfolder="$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"; fi
if [ ! -d "$steamfolder" ]; then steamfolder="$HOME/.steam/steam"; fi
if [ ! -d "$steamfolder" ]; then
	echo Steam installation not found
	steamfolder=
else
	echo Steam installation at "$steamfolder"
	gamefolder="$steamfolder/steamapps"
	if [ ! -d "$gamefolder/$balatrosub" ]; then
		gamefolder=
		echo Balatro installation not found
	fi
fi

if [ ! "$gamefolder" ]; then
	echo 'The installer script cannot determine your Steam and Balatro install location.'
	echo 'Provide Steam installation folder or steamapps folder by dragging it here if supported,'
	echo 'or type in the path or leave blank to cancel.'
	echo 'You will need to have Balatro already installed.'
	echo
	prompt_search
fi
echo Balatro installation at "$gamefolder/$balatrosub"
modsfolder="$gamefolder/compatdata/2379780/pfx/drive_c/users/steamuser/AppData/Roaming/Balatro/Mods"
echo Mods folder at "$modsfolder"
mkdir -p "$modsfolder"

smods=0
if [ ! "$(ls "$modsfolder")" ]; then
	smods=1
else
	echo 'The mods folder is not empty. You might have Steamodded already installed.'
	echo -n 'Do you want to download Steamodded? It will be required by most mods. [Y/N] '
	while true; do
		read input
		valid=1
		case "$input" in
			"Y" | "y" | "yes") smods=1 ;;
			"N" | "n" | "no") smods=0 ;;
			*)
				echo -n 'Please type [y]es or [n]o: '
				valid=0
			;;
		esac
		if [ $valid == 1 ]; then break; fi
	done
fi

if [ "$smods" == 1 ]; then
	echo Downloading smods
	curl -fSL "https://github.com/Steamodded/smods/archive/refs/heads/stable.zip" -o "$modsfolder/smods.zip"
fi

echo Downloading imm
curl -fSL "https://github.com/frostice482/balatro-imm/archive/refs/heads/master.tar.gz" -o __imm.tar.gz

# since it's downloaded from commit it will be one folder deep.
# select the only folder then move it to the mods folder.
# this won't be an issue with using release assets

echo Extracting imm
mkdir __imm
tar -xzmf __imm.tar.gz -C __imm -k
#echo mv "__imm/$(ls __imm | head -1)" "$modsfolder/imm"
mv "__imm/$(ls __imm | head -1)" "$modsfolder/imm"
rm -rf __imm __imm.tar.gz

echo 'Done. Your Balatro is now modded. Enjoy!'
read