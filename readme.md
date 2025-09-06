The ingame SMODS mod browser.

The mod sources are taken from [balatro-mod-index](https://github.com/skyline69/balatro-mod-index),
[modified](https://github.com/frostice482/balatro-mod-index-tiny) for the purpose of smaller API requests.

If your mod is not included, make sure your mod exists in `balatro-mod-index` and that your repo contains a valid metadata file.
See [here](https://github.com/frostice482/balatro-mod-index-tiny?tab=readme-ov-file#why-is-my-mod-not-included) for details.

For mod releases, please make sure to use the Github Releases.
I recommend that you name your tag based on your mod version, with some conversion:
- Mod version `~` is converted to `-` (e.g. `1.0.0~alpha-1` -> `1.0.0-alpha-5`)
- Tag version with leading `v` is ignored (e.g. `v1.0.0` -> `1.0.0`)

## Caches

All requests are cached, including thumbnail, releases, and downloaded files.
If you want to clear cache, simply delete `%AppData%\Balatro\immcache` (on windows).

## Todo

- Add dependencies, conflicts
- Fix & Improve UI