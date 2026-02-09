#!/bin/bash
# Workaround for Xcode 26.2 beta deployment target bug
# This script wraps xcrun to add explicit deployment target flags when calling clang

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create temporary wrapper for xcrun
TMP_WRAPPER_DIR="/tmp/xcode_wrapper_bin_$$"
mkdir -p "$TMP_WRAPPER_DIR"

cat > "$TMP_WRAPPER_DIR/xcrun" << 'EOF'
#!/bin/bash
# Wrapper to fix Xcode 26.2 deployment target bug
# Filter out conflicting deployment targets

if [[ "$1" == "clang" ]]; then
    shift  # remove 'clang' from arguments
    # Call real xcrun with clang and our additional flag
    unset IPHONEOS_DEPLOYMENT_TARGET TVOS_DEPLOYMENT_TARGET WATCHOS_DEPLOYMENT_TARGET XROS_DEPLOYMENT_TARGET
    exec /usr/bin/xcrun clang -mmacos-version-min=10.15 "$@"
else
    # Pass through to real xcrun for other commands
    exec /usr/bin/xcrun "$@"
fi
EOF

chmod +x "$TMP_WRAPPER_DIR/xcrun"

# Clean up on exit
trap "rm -rf $TMP_WRAPPER_DIR" EXIT

# Add wrapper to PATH and run flutter
export PATH="$TMP_WRAPPER_DIR:$PATH"
flutter "$@"
