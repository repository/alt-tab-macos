#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
if ! xcodebuild -version >/dev/null 2>&1; then
    printf '%s\n' 'Full Xcode is required. Set DEVELOPER_DIR to Xcode.app/Contents/Developer.' >&2
    exit 1
fi
mkdir -p build/unrestricted
python3 scripts/l10n/validate_localizations.py
python3 scripts/assets/compile_illustrations.py --check
python3 scripts/assets/test_compile_illustrations.py
xcodebuild test \
    -project alt-tab-macos.xcodeproj -scheme Test -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath build/unrestricted/DerivedData \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    2>&1 | tee build/unrestricted/test.log
xcodebuild \
    -project alt-tab-macos.xcodeproj -scheme Release -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath build/unrestricted/DerivedData \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=- \
    CURRENT_PROJECT_VERSION=11.10.1 APPCENTER_SECRET= \
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) UNRESTRICTED_BUILD' \
    2>&1 | tee build/unrestricted/build.log
application='build/unrestricted/DerivedData/Build/Products/Release/AltTab.app'
test -d "$application"
codesign --force --deep --sign - "$application"
codesign --verify --deep --strict "$application"
file "$application/Contents/MacOS/AltTab"
ditto -c -k --sequesterRsrc --keepParent "$application" build/unrestricted/AltTab-Unrestricted-11.10.1-arm64.zip
shasum -a 256 build/unrestricted/AltTab-Unrestricted-11.10.1-arm64.zip > build/unrestricted/SHA256SUMS
printf '%s\n' c500294bdb01186011a5c64a412b04cef9931bef > build/unrestricted/UPSTREAM-COMMIT.txt
git diff --binary c500294bdb01186011a5c64a412b04cef9931bef > build/unrestricted/unrestricted.patch
cp LICENCE.md build/unrestricted/
printf '%s\n' 'Build complete.'
