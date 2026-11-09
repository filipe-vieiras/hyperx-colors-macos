#!/usr/bin/env python3
"""Build a self-contained app using only Apple's command-line tools and vendored sources."""
import hashlib
import os
from pathlib import Path
import plistlib
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
APP = ROOT / 'dist' / 'HyperX Colors.app'
VERSION = '0.5.0'
ENV = dict(os.environ, MACOSX_DEPLOYMENT_TARGET='13.0', COPYFILE_DISABLE='1', ac_cv_func_pipe2='no')

def run(*args, cwd=ROOT):
    subprocess.run([str(x) for x in args], cwd=cwd, env=ENV, check=True)

BUILD.mkdir(exist_ok=True)
archive = ROOT / 'vendor/libusb-1.0.29.tar.bz2'
assert hashlib.sha256(archive.read_bytes()).hexdigest() == '5977fc950f8d1395ccea9bd48c06b3f808fd3c2c961b44b0c2e6e29fc3a70a85', 'libusb checksum mismatch'
usb = BUILD / 'libusb-1.0.29'
if not usb.exists():
    run('tar', '-xjf', archive, '-C', BUILD)
prefix = BUILD / 'usb-install'
if not (prefix / 'lib/libusb-1.0.0.dylib').exists():
    run('./configure', f'--prefix={prefix}', '--disable-static', '--disable-dependency-tracking', cwd=usb)
    # Link the Darwin backend directly; avoids version-sensitive GNU libtool parsing.
    (prefix / 'lib').mkdir(parents=True, exist_ok=True)
    (prefix / 'include/libusb-1.0').mkdir(parents=True, exist_ok=True)
    units = ['core.c', 'descriptor.c', 'hotplug.c', 'io.c', 'strerror.c', 'sync.c',
             'os/events_posix.c', 'os/threads_posix.c', 'os/darwin_usb.c']
    library = prefix / 'lib/libusb-1.0.0.dylib'
    run('clang', '-O2', '-std=gnu11', '-fvisibility=hidden', '-dynamiclib',
        '-I' + str(usb), '-I' + str(usb / 'libusb'),
        *[usb / 'libusb' / unit for unit in units], '-lobjc',
        '-framework', 'IOKit', '-framework', 'CoreFoundation', '-framework', 'Security',
        '-Wl,-install_name,' + str(library), '-o', library)
    shutil.copyfile(usb / 'libusb/libusb.h', prefix / 'include/libusb-1.0/libusb.h')
if APP.exists():
    shutil.rmtree(APP)
mac = APP / 'Contents/MacOS'
resources = APP / 'Contents/Resources'
frameworks = APP / 'Contents/Frameworks'
for path in (mac, resources, frameworks):
    path.mkdir(parents=True, exist_ok=True)
source = ROOT / 'vendor/QuadcastRGB'
run('clang', '-O2', '-DOS_MAC', '-DVERSION="1.0.5"', '-I' + str(prefix / 'include'),
    source / 'main.c', source / 'modules/argparser.c', source / 'modules/devio.c', source / 'modules/rgbmodes.c',
    prefix / 'lib/libusb-1.0.0.dylib', '-o', mac / 'quadcastrgb')
run('install_name_tool', '-change', prefix / 'lib/libusb-1.0.0.dylib',
    '@executable_path/../Frameworks/libusb-1.0.0.dylib', mac / 'quadcastrgb')
shutil.copyfile(prefix / 'lib/libusb-1.0.0.dylib', frameworks / 'libusb-1.0.0.dylib')
run('swiftc', '-module-cache-path', BUILD / 'swift-cache', ROOT / 'Sources/main.swift',
    '-o', mac / 'HyperXColors', '-framework', 'AppKit', '-framework', 'ServiceManagement')
iconset = BUILD / 'AppIcon.iconset'
run('swift', '-module-cache-path', BUILD / 'swift-cache', ROOT / 'scripts/package-icon.swift', ROOT / 'Assets/AppIcon.png', iconset)
entries = [('icp4','16x16'),('icp5','32x32'),('icp6','32x32@2x'),('ic07','128x128'),('ic08','256x256'),('ic09','512x512'),('ic10','512x512@2x'),('ic11','16x16@2x'),('ic12','32x32@2x'),('ic13','128x128@2x'),('ic14','256x256@2x')]
chunks = []
for tag, name in entries:
    data = (iconset / f'icon_{name}.png').read_bytes()
    chunks.append(tag.encode() + struct.pack('>I', len(data) + 8) + data)
data = b''.join(chunks)
(resources / 'AppIcon.icns').write_bytes(b'icns' + struct.pack('>I', len(data) + 8) + data)
info = dict(CFBundleExecutable='HyperXColors', CFBundleIdentifier='local.hyperx.colors',
    CFBundleName='HyperX Colors', CFBundlePackageType='APPL', CFBundleShortVersionString=VERSION,
    CFBundleVersion='5', CFBundleIconFile='AppIcon', LSMinimumSystemVersion='13.0',
    NSHighResolutionCapable=True, LSUIElement=True)
(APP / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
shutil.copyfile(ROOT / 'LICENSE', resources / 'LICENSE.txt')
shutil.copyfile(ROOT / 'THIRD_PARTY.md', resources / 'THIRD_PARTY.md')
shutil.copyfile(ROOT / 'licenses/libusb-LGPL-2.1.txt', resources / 'libusb-LICENSE.txt')
for binary in (frameworks / 'libusb-1.0.0.dylib', mac / 'quadcastrgb'):
    run('codesign', '--force', '--sign', '-', binary)
# Strip only packaging metadata on the generated app; preserve download security flags.
for name in ('com.apple.FinderInfo', 'com.apple.ResourceFork'):
    subprocess.run(['xattr', '-dr', name, str(APP)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
run('codesign', '--force', '--sign', '-', APP)
run('codesign', '--verify', '--deep', '--strict', APP)
run('ditto', '-c', '-k', '--norsrc', '--keepParent', APP, ROOT / f'dist/HyperX-Colors-v{VERSION}.zip')
print(f'Built: {APP}')
