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

## Install

Everything the script calls is listed below. Only two things are not part of
macOS: ImageMagick and a code-signing certificate.

| Dependency | Used for | Comes from |
| --- | --- | --- |
| `ruby` 2.6+ | running the script | macOS (`/usr/bin/ruby`), or Homebrew |
| `magick` (ImageMagick 7) | measuring and recolouring the icon PNGs | Homebrew |
| `codesign`, `security` | re-signing and finding your identity | macOS |
| `plutil`, `ditto`, `pluginkit`, `lsregister` | reading the version, copying the bundle, telling Safari | macOS |
| "Apple Development" certificate | a signature Safari trusts without the Develop menu | Xcode, free Apple ID |

```sh
# 1. uBlock Origin Lite from the App Store, at its default location
ls "/Applications/uBlock Origin Lite.app"

# 2. ImageMagick 7 (provides the `magick` binary; ImageMagick 6 will not do)
brew install imagemagick
magick -version

# 3. Optional: a newer Ruby. The macOS system Ruby 2.6 is enough.
brew install ruby

# 4. A signing identity. Install Xcode, then:
#    Xcode > Settings > Accounts > + > sign in with your Apple ID
#    > Manage Certificates > + > Apple Development
security find-identity -v -p codesigning | grep "Apple Development"

# 5. Fetch the script and make it executable
git clone https://github.com/marianposaceanu/ublock-iconizer.git
cd ublock-iconizer
chmod +x ublock-iconizer
./ublock-iconizer status
```

Without an Apple Development identity the tool still works but signs ad-hoc,
and Safari then needs Develop > Allow Unsigned Extensions on every launch.
Pass `--identity -` to choose ad-hoc signing on purpose.

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
- The macOS system Ruby 2.6 runs `status`. `patch` and `restore` were run
  under Ruby 4.0 only, but the script uses nothing newer than Ruby 2.5.

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
- `patch` and `restore` register the bundle with Safari even when `--app`
  points at a copy, so a copy you test on shows up as a second "uBlock Origin
  Lite" in Safari > Settings > Extensions. To clean up, run `pluginkit -r` on
  the copy's `.appex`, `lsregister -u` on the copy, delete the copy, and
  relaunch Safari.

Not verified: the `_off` icon in Safari (only the active state was seen),
dark mode (the fixed `#828282` body is a compromise), and the full
restore, App Store update, patch round trip, which needs a new uBOL release
to exist.

## Code layout

The script is one file. Each class owns one thing, and the three commands only
orchestrate.

```
  CLI  --parses argv, picks a command-->  Commands::Status | Patch | Restore
                                                     |
             +-----------------+----------------+----+-----------+
             v                 v                v                v
        AppBundle         IconPainter      CodeSigner      BackupStore / State
   paths, version,     grey? / paint     sign!, verifies?,  save!, restore!,
   signing authority,  via `magick`      default_identity   state.json
   pristine?, register
             \                 |                |                /
              +--------------- Shell (Open3) ------------------+
                      run, run!, succeeds?, which
```

`STYLES` maps a style name to a `Style`, which holds a `Paint` (body and
detail colours) for the active icons and another for the "no filtering" ones.
`Commands::Patch#readiness` decides in one place whether the app is pristine,
already patched, half-patched, or signed by someone else, and `run` acts on
that answer.

## Credits

The diagrams in this README follow the plain-ASCII conventions catalogued at
[asciidiagrams.github.io](https://asciidiagrams.github.io), a browsable
collection of diagrams drawn in code comments across Chromium, Linux, LLVM
and TensorFlow.
