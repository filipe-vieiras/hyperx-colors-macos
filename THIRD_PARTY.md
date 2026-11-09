# Third-party software and assets

## QuadcastRGB
- Author: Ors1mer and upstream contributors.
- Source: https://github.com/Ors1mer/QuadcastRGB
- Upstream revision: e15a81c98221a4ff3fbc86e24597ab2f47c1a388
- License: GPL-2.0-only; full license in vendor/QuadcastRGB/LICENSE.
- The C sources needed to build the controller are included in vendor/QuadcastRGB.
- Local modification (2026-11-09): in modules/rgbmodes.c, equalize() casts the allocation to byte_t * before offsetting across packet boundaries, avoiding undefined array indexing detected by UBSan.
- Original copyright and license notices are preserved. This project is an independent graphical front end, not the upstream project.

## libusb 1.0.29
- Source: https://github.com/libusb/libusb/releases/tag/v1.0.29
- Complete release source archive: vendor/libusb-1.0.29.tar.bz2 (includes its licenses).
- Archive SHA-256: 5977fc950f8d1395ccea9bd48c06b3f808fd3c2c961b44b0c2e6e29fc3a70a85
- Library license: LGPL-2.1-or-later; copy in licenses/libusb-LGPL-2.1.txt.
- Built unmodified and bundled as a replaceable dynamic library. The build script uses the included source and can rebuild/relink the app.

## Interface and icon
- App interface and build scripts: GPL-2.0-only, as documented by the project LICENSE.
- AppIcon.png: AI-generated skeuomorphic illustration based on a user-supplied product reference, included as part of this GPL-2.0-only project. This license grants no trademark rights.
- HyperX and QuadCast are trademarks of their respective owners. This is an unofficial community project, not affiliated with, sponsored by, or endorsed by HyperX or HP.
