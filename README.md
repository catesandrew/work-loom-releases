# work-loom-releases

Public release binaries + installer for **Workloom** — the `wl` CLI and the
Workloom desktop app.

![License](https://img.shields.io/github/license/catesandrew/work-loom-releases)
![Latest Release](https://img.shields.io/github/v/release/catesandrew/work-loom-releases)
![Downloads](https://img.shields.io/github/downloads/catesandrew/work-loom-releases/total)

The source code lives in the private [`catesandrew/work-loom`](https://github.com/catesandrew/work-loom)
repository. This repo exists only to serve release assets and the installer
script to anonymous `curl | sh` users (private-repo release/download links 404
without authentication). It is populated automatically by the source repo's
release workflow.

## Install the `wl` CLI

```sh
curl -fsSL https://raw.githubusercontent.com/catesandrew/work-loom-releases/main/packaging/install.sh | sh
```

Prefer inspect-before-run:

```sh
curl -fsSL https://raw.githubusercontent.com/catesandrew/work-loom-releases/main/packaging/install.sh -o install.sh
less install.sh
sh install.sh
```

See [`docs/cli-install.md`](docs/cli-install.md) for manual download + checksum
verification instructions.
