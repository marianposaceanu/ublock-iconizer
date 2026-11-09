# ublock-iconizer

Makes the uBlock Origin Lite toolbar icon in Safari a grey template icon, like
Apple's own, and puts the pristine App Store build back when you want updates.

uBlock Origin Lite ships a maroon toolbar icon, so Safari shows it in colour
([uBOL-home #402](https://github.com/uBlockOrigin/uBOL-home/issues/402)).
This tool recolours the toolbar PNGs inside the extension to a neutral grey and
re-signs the app so macOS will still load it.

```
   stock                      patched (grey)
+-----------+                +-----------+
|  maroon   |   ublock-      |   grey    |
|  shield   | --iconizer-->  |  shield   |     Safari toolbar
|  #800000  |    patch       |  #828282  |
+-----------+                +-----------+
      ^                            |
      |        ublock-iconizer     |
      +----------restore-----------+
```

## How it works

Safari's rules, as measured on macOS 26: a greyscale or single-colour icon is
treated as a template and tinted with the accent colour (blue) on every tab
the extension has access to, which with uBlock is every tab. A multi-colour
icon is shown as-is. The default `grey` style therefore keeps a neutral grey
body and paints the bar and border a very pale blue, which is just enough
chroma to escape the template treatment while still reading as grey.

```
  icon pixels                    Safari's decision
  -----------                    -----------------
  all channels within ~24 units  --> "template" --> tinted accent blue
  single colour                  --> "template" --> tinted accent blue
  chroma spread >= 45 units      --> "coloured" --> shown as-is   <== grey style
```

The patch touches only the four toolbar PNGs and the code signature. Everything
else in the bundle stays byte for byte as the App Store shipped it.

```
/Applications/uBlock Origin Lite.app
+-- Contents/
    +-- Info.plist                       (read: version)
    +-- _CodeSignature/                  (rewritten: re-signed)
    +-- PlugIns/
        +-- uBlock Origin Lite Extension.appex
            +-- _CodeSignature/          (rewritten: re-signed)
            +-- Contents/Resources/img/
                +-- icon_16.png      \
                +-- icon_32.png       |  recoloured (on)
                +-- icon_64.png       |
                +-- icon_128.png     /
                +-- icon_16_off.png  \
                +-- icon_32_off.png   |  recoloured (off, grey style only)
                +-- icon_64_off.png   |
                +-- icon_128_off.png /
```

## Requirements

- macOS with uBlock Origin Lite installed from the App Store at
  `/Applications/uBlock Origin Lite.app`
- Ruby 3.0+ (macOS system Ruby is 2.6 and will not work; use a version manager or Homebrew Ruby)
- ImageMagick (`brew install imagemagick`)
- An "Apple Development" signing identity in your keychain (free Apple ID via
  Xcode). Without one the tool signs ad-hoc, and Safari then needs
  Develop > Allow Unsigned Extensions on every launch.

## Usage

```sh
./ublock-iconizer status    # version, signer, icon state, backup presence
./ublock-iconizer patch     # back up, grey the icons, re-sign
./ublock-iconizer restore   # put the pristine App Store build back
```

After `patch` or `restore`: quit and reopen Safari, then enable the extension
in Safari > Settings > Extensions. Per-site permissions must be granted again
because the signing team changes.

### What `patch` does, step by step

```
  +-------------------+     no      +----------------------------------+
  | app is pristine?  | ----------> | already grey & valid?  -> "done"  |
  | (Apple-signed and |             | invalid signature?     -> error,  |
  |  seal verifies)   |             |   run `restore`                   |
  +-------------------+             | other signer?          -> error,  |
          | yes                     |   reinstall from App Store        |
          v                         +----------------------------------+
  +-------------------+
  | ditto -> backup   |   ~/Library/Application Support/ublock-iconizer/
  | (never clobbers a |      backup/<version>/uBlock Origin Lite.app
  |  verifying copy)  |
  +-------------------+
          |
          v
  +-------------------+
  | magick recolour   |   RGB only, alpha untouched
  | icon_*.png        |
  +-------------------+
          |
          v
  +-------------------+
  | codesign .appex   |   hardened runtime, original entitlements
  | codesign .app     |   minus team-bound ones
  +-------------------+
          |
          v
  +-------------------+
  | lsregister        |
  | pluginkit -a      |   so Safari picks up the re-signed bundle
  +-------------------+
          |
          v
     write state.json
```

## Updating uBlock Origin Lite

The App Store will not update a patched app. The cycle is:

```sh
./ublock-iconizer restore   # back to the Apple-signed build
# update in the App Store
./ublock-iconizer patch     # new pristine backup, icons grey again
```

```
            restore                 App Store update
  patched ----------> pristine -----------------------> pristine (new version)
     ^                (v1)                                   |
     |                                                       | patch
     +-------------------------------------------------------+
```

`status` tells you when the installed version differs from the last patch.

## Options

| Flag | Meaning |
| --- | --- |
| `--app PATH` | Operate on another bundle (useful for testing on a copy) |
| `--identity NAME` | codesign identity, default is the first "Apple Development" one |
| `--style grey\|template` | `grey` (default): fixed neutral grey, never tinted. `template`: black template that Safari tints blue on tabs it can access |
| `--delete-backup` | With `restore`, remove the pristine backup afterwards |

Backups and state live in `~/Library/Application Support/ublock-iconizer`,
one backup per app version. Set `UBLOCK_ICONIZER_HOME` to move them.

```
~/Library/Application Support/ublock-iconizer/
+-- state.json                 version, patched_at, identity, style, app
+-- backup/
    +-- 2026.1103.1743/
    |   +-- uBlock Origin Lite.app     pristine, Apple-signed
    +-- <next version>/
        +-- uBlock Origin Lite.app
```

## What patch changes

- `grey`: `img/icon_{16,32,64,128}.png` get a `#828282` body, the `_off`
  variants a lighter `#B4B4B4` body, and the white bar and border on both
  become `#C8D8F5`. Only RGB is touched, so the anti-aliased edge survives.
- `template`: the "on" icons become black on transparent with the bar and
  border cut out; the `_off` icons are already greyscale and are left alone.
- The extension and app are re-signed with hardened runtime and their original
  entitlements, minus the team-bound ones (`application-identifier`,
  `team-identifier`) that only validate for the original developer.
- `pluginkit` and LaunchServices are told about the re-signed bundle.

`restore` copies the verified backup next to the live app with `ditto`, then
swaps it in, byte for byte, including the App Store receipt and metadata.

## Safety

- `patch` only takes a backup when the app is Apple-signed **and** its seal
  still verifies. A half-patched bundle is refused with a pointer to `restore`.
- An existing backup that verifies is never overwritten.
- `restore` refuses a backup that fails `codesign --verify`.
- `restore` stages the copy next to the live app and swaps at the end, so a
  failed copy leaves the installed app untouched.

## What has been verified

Tested on the real install (uBlock Origin Lite 2026.1103.1743, macOS 26):

- The re-signed app launches under hardened runtime with an Apple Development
  certificate.
- Safari lists and loads the extension without Develop > Allow Unsigned
  Extensions.
- With the `grey` style the toolbar icon is a neutral grey shield on a tab
  where the extension is active. Tried and rejected: pure grey, a warm grey
  with a 10-unit tint, a slate with a 24-unit tint, and a single-colour maroon
  were all tinted blue by Safari.
- `restore` puts back a byte-identical App Store build, and a simulated
  mid-failure leaves the backup intact.

## Notes

- App Store installs are owned by `root`, and every App Store update
  reinstalls as root. `patch` and `restore` detect this and run
  `sudo chown -R <you>:staff` on the bundle, asking for your password, so
  expect the prompt after each update.
- The body colour lives in `STYLES` at the top of the script if you want it
  darker or lighter. Keep the detail colour at or above its current chroma:
  a 24-unit spread was still tinted, 45 was not, and nothing in between was
  measured.
- Safari sees the re-signed build as a new extension, so it starts disabled
  and per-site permissions are reset.

Not verified: the `_off` icon in Safari (only the active state was seen),
dark mode (the fixed `#828282` body is a compromise), and the full
restore, App Store update, patch round trip, which needs a new uBOL release
to exist.

## Credits

The diagrams in this README follow the plain-ASCII conventions catalogued at
[asciidiagrams.github.io](https://asciidiagrams.github.io), a browsable
collection of diagrams drawn in code comments across Chromium, Linux, LLVM
and TensorFlow.
