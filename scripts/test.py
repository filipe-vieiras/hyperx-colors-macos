#!/usr/bin/env python3
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
source = root / 'vendor/QuadcastRGB/modules'
output = root / 'build/check-effects'
output.parent.mkdir(exist_ok=True)
subprocess.run(['clang', '-g', '-fsanitize=address,undefined', '-fno-sanitize-recover=all',
    '-I' + str(source), '-I' + str(root / 'build/usb-install/include'), str(root / 'tests/check-effects.c'),
    str(source / 'argparser.c'), str(source / 'rgbmodes.c'), '-o', str(output)], check=True)
subprocess.run([str(output)], check=True)

controller_tests = root / 'build/controller-tests'
subprocess.run(['swiftc', '-module-cache-path', str(root / 'build/swift-cache'),
    str(root / 'Sources/LightingController.swift'), str(root / 'tests/controller-tests.swift'),
    '-o', str(controller_tests)], check=True)
subprocess.run([str(controller_tests)], check=True)

# Native view rendering requires a logged-in graphical macOS session.
import sys
if '--ui' in sys.argv:
    interface_tests = root / 'build/interface-tests'
    subprocess.run(['swiftc', '-module-cache-path', str(root / 'build/swift-cache'),
        str(root / 'Sources/InlineColorPicker.swift'), str(root / 'Sources/MicrophonePreview.swift'),
        str(root / 'Sources/LightingPanel.swift'), str(root / 'tests/interface-tests.swift'),
        '-o', str(interface_tests), '-framework', 'AppKit'], check=True)
    subprocess.run([str(interface_tests), str(root), str(root / 'build/interface-preview.png')], check=True)
