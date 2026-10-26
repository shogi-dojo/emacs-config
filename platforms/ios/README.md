# iOS Emacs Reader Profile

A lightweight, terminal-first Emacs reading environment for jailbroken iOS devices
(Dopamine/rootless Procursus).  It does **not** require Doom, Evil, or any
package-manager networking — everything runs from built-ins and vendored Elisp.

## What's included

| File | Purpose |
|---|---|
| `init.el` | Standalone iOS entry-point (loaded via `~/.emacs.d/init.el` shim) |
| `reader.el` | Portable `ios/reading-mode` minor mode (shared with desktop Doom) |
| `vendor/nov.el` | EPUB reader — git `874daf5e` from emacsmirror/nov (GPL-3.0+) |
| `vendor/esxml.el` | XML/S-expression library — git `6a375888` from emacsmirror/esxml (GPL-3.0+) |
| `vendor/esxml-query.el` | jQuery-style CSS selector for esxml — same commit (GPL-3.0+) |
| `vendor/LICENSE` | Full GNU GPL version 3 license for the vendored sources |
| `test-reader.el` | ERT test suite for `reader.el` |

## Quick start

### 1. Build Emacs for iOS

```
cd emacs-ios && make build
```

The binary at `build/target/src/temacs` is a native arm64 Mach-O that links
`libxml2` (required for EPUB parsing) and `libncursesw`.

### 2. Package and install

```
make package   # creates dist/emacs_30.2-2_iphoneos-arm64.deb
```

Copy the `.deb` to your device and install:

```
dpkg -i emacs_30.2-2_iphoneos-arm64.deb
```

### 3. Deploy the config

Connect the device over USB and start `iproxy`:

```
iproxy 2222 22
```

Install your SSH public key on the device (once):

```
ssh-copy-id -p 2222 mobile@127.0.0.1
```

Then deploy:

```
./scripts/deploy-ios-reader.sh
```

### 4. Launch

In NewTerm (or any other terminal emulator):

```
/var/jb/usr/bin/emacs
```

Emacs opens `~/Books` in Dired.  Copy `.epub` files into `~/Books/` and open
them from Dired.

## Key bindings

| Key | Action |
|---|---|
| `SPC` / `DEL` | Page forward / backward |
| `n` / `p` | Next / previous EPUB chapter |
| `t` | EPUB table of contents |
| `/` | Search (isearch) |
| `g` / `G` | Beginning / end of chapter |
| `m` | Toggle compact progress mode-line |
| `e` | Leave read-only mode for editing |
| `C-c r` | Toggle reading mode |
| `q` | Close reader buffer |

## Supported file types

| Extension | Major mode | Opens as |
|---|---|---|
| `.epub` | `nov-mode` (vendored) | Read-only, EPUB reader |
| `.org` | `org-mode` (built-in) | Read-only, toggle with `e` |
| `.md` / `.markdown` | `text-mode + outline` | Read-only, toggle with `e` |

## Deployment script options

```
./scripts/deploy-ios-reader.sh                 # normal deploy
./scripts/deploy-ios-reader.sh --rollback      # restore previous init.el
FORCE=1 ./scripts/deploy-ios-reader.sh        # overwrite unmanaged init.el (creates backup)

DEVICE_HOST=192.168.1.x DEVICE_PORT=22 ./scripts/deploy-ios-reader.sh
```

The script:
- Refuses to overwrite an unmanaged `~/.emacs.d/init.el` unless `FORCE=1`
- Creates a timestamped backup when `FORCE=1`
- Preserves `nov-places`, bookmarks, and books across redeployments
- Installs Procursus `unzip` interactively when missing (credentials not stored)
- Uploads files atomically via a staging directory

## Running the test suite (Mac)

```
emacs -Q --batch \
  -L platforms/ios \
  -l ert \
  -l platforms/ios/test-reader.el \
  -f ert-run-tests-batch-and-exit
```

Expected: **18 tests, 18 passed**.

## Limitations

- Cover art and inline images are not rendered (terminal build, no image libraries)
- GnuTLS, package-el networking, dynamic modules, and native compilation are
  disabled — the profile is intentionally self-contained
- Tree-sitter is not available
- Terminal font size is controlled by NewTerm (Settings → NewTerm → Font Size;
  16–18 pt recommended for comfortable reading)
- The iOS profile is independent of your desktop Doom configuration —
  macOS, Linux, and Android Doom behaviour is unchanged

## Vendor provenance

| File | Upstream | Commit | License |
|---|---|---|---|
| `nov.el` | [emacsmirror/nov](https://github.com/emacsmirror/nov) | `874daf5e` | GPL-3.0+ |
| `esxml.el` | [emacsmirror/esxml](https://github.com/emacsmirror/esxml) | `6a375888` | GPL-3.0+ |
| `esxml-query.el` | [emacsmirror/esxml](https://github.com/emacsmirror/esxml) | `6a375888` | GPL-3.0+ |
