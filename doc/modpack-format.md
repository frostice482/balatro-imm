# Modpack Format

Modpacks are bundled in a `.tar.gz` format. The tar includes:
- `info.json`: file, modpack metadata (author, name, mods)
- `description.txt`: file, the modpack description
- `mods`: directory
	- `[index]`: directory, containing the bundled mod contents.
		Index is based from index of `info.json/mods`.
		For example, `mods/1` refers to mods in `info.json/mods[1]`.

## info.json

This is a JSON file containing the modpack metadata. The format is as follows

```ts
interface Modpack {
	version: 1
	name: string
	author: string
	mods: ModpackMod[]
}

interface ModpackMod {
	id: string
	version: string
	url?: string
}
```