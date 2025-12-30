# Modpack Format

Modpacks are bundled in a `.tar.gz` format. The tar includes:
- `info.json`: file, modpack metadata (author, name, mods)
- `description.txt`: file, the modpack description
- `files`: directory, containing any file to overwrite the save when applied. Mostly to store config files
- `mods`: directory
	- `[index]`: directory, containing the bundled mod contents.
		Index is based from index of `info.json/mods`.
		For example, `mods/1` refers to mods in `info.json/mods[1]`.

## info.json

This is a JSON file containing the modpack metadata. The format is as follows

```ts
interface MPColors {
	bg: string // 6-digit hex, uppercase / lowercase
	fg: string // 6-digit hex, uppercase / lowercase
	text: string // 6-digit hex, uppercase / lowercase
}

interface ModpackMod {
	id: string
	version: string
	url?: string
}

interface Modpack {
	version: 2
	name: string
	author: string
	mods: ModpackMod[]
	colors: MPColors
}
```