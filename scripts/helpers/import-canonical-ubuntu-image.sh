#!/bin/bash
################################################################################
##  File:  import-canonical-ubuntu-image.sh
##  Desc:  Import Ubuntu cloud images from Canonical for Incus
##  Usage: ./import-canonical-ubuntu-image.sh <version> [arch]
##         version: 22.04 or 24.04
##         arch: ppc64le, s390x, or x86_64 (default: auto-detect)
################################################################################

# Note: Do NOT use 'set -e' in sourced scripts as it affects the parent shell
# Instead, use explicit error checking with || return 1

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Function to map architecture for Canonical URLs
map_architecture() {
    local arch="$1"
    
    case "$arch" in
        ppc64le) echo "ppc64el" ;;  # Canonical uses ppc64el
        x86_64)  echo "amd64" ;;    # Canonical uses amd64
        s390x)   echo "s390x" ;;    # Same naming
        *)       echo "$arch" ;;
    esac
}

# Function to get release codename
get_release_codename() {
    local version="$1"
    
    case "$version" in
        22.04) echo "jammy" ;;
        24.04) echo "noble" ;;
        *)
            log_error "Unsupported Ubuntu version: $version"
            return 1
            ;;
    esac
}

# Function to check if image already exists
check_image_exists() {
    local alias="$1"
    
    if incus image info "$alias" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Main function to import canonical Ubuntu image
import_canonical_ubuntu_image() {
    local VERSION="$1"
    local ARCH="${2:-$(uname -m)}"
    local WORKDIR="${3:-$HOME/ubuntu-images}"
    
    # Validate version
    if [[ ! "$VERSION" =~ ^(22.04|24.04)$ ]]; then
        log_error "Invalid Ubuntu version: $VERSION. Must be 22.04 or 24.04"
        return 1
    fi
    
    # Get release codename and mapped architecture
    local CODENAME
    CODENAME=$(get_release_codename "$VERSION")
    local CANONICAL_ARCH
    CANONICAL_ARCH=$(map_architecture "$ARCH")
    
    # Define image alias
    local IMAGE_ALIAS="ubuntu-${VERSION}"
    
    log_info "=========================================="
    log_info "Importing Ubuntu ${VERSION} (${CODENAME})"
    log_info "Architecture: ${ARCH} (Canonical: ${CANONICAL_ARCH})"
    log_info "Image Alias: ${IMAGE_ALIAS}"
    log_info "=========================================="
    
    # Check if image already exists
    if check_image_exists "$IMAGE_ALIAS"; then
        log_warn "Image '${IMAGE_ALIAS}' already exists in Incus"
        read -p "Do you want to re-import? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping import for ${IMAGE_ALIAS}"
            return 0
        fi
        log_info "Removing existing image..."
        incus image delete "$IMAGE_ALIAS" || true
    fi
    
    # Save original directory to restore later
    local ORIGINAL_DIR
    ORIGINAL_DIR="$(pwd)"
    
    # Create working directory
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"
    
    # Define file names
    local METADATA_FILE="ubuntu-${VERSION}-server-cloudimg-${CANONICAL_ARCH}-lxd.tar.xz"
    local ROOTFS_FILE="ubuntu-${VERSION}-server-cloudimg-${CANONICAL_ARCH}.squashfs"
    
    # Define download URLs
    local BASE_URL="https://cloud-images.ubuntu.com/releases/${CODENAME}/release"
    local METADATA_URL="${BASE_URL}/${METADATA_FILE}"
    local ROOTFS_URL="${BASE_URL}/${ROOTFS_FILE}"
    
    # Cleanup function (uses variables from parent scope)
    cleanup_files() {
        log_info "Cleaning up downloaded files..."
        if [[ -n "${WORKDIR:-}" ]] && [[ -d "$WORKDIR" ]]; then
            # Use full paths instead of cd to avoid changing parent shell's directory
            rm -f "${WORKDIR}/ubuntu-${VERSION}-server-cloudimg-${CANONICAL_ARCH}-lxd.tar.xz" \
                  "${WORKDIR}/ubuntu-${VERSION}-server-cloudimg-${CANONICAL_ARCH}.squashfs" 2>/dev/null || true
        fi
        log_success "Cleanup completed"
    }
    
    # Download metadata file
    log_info "Downloading metadata: ${METADATA_FILE}..."
    if ! wget -q --show-progress "$METADATA_URL"; then
        log_error "Failed to download metadata file"
        cleanup_files
        cd "$ORIGINAL_DIR" 2>/dev/null || true
        return 1
    fi
    log_success "Metadata downloaded"
    
    # Download rootfs file
    log_info "Downloading rootfs: ${ROOTFS_FILE}..."
    if ! wget -q --show-progress "$ROOTFS_URL"; then
        log_error "Failed to download rootfs file"
        cleanup_files
        cd "$ORIGINAL_DIR" 2>/dev/null || true
        return 1
    fi
    log_success "Rootfs downloaded"
    
    # Import into Incus
    log_info "Importing image into Incus with alias '${IMAGE_ALIAS}'..."
    if ! incus image import "$METADATA_FILE" "$ROOTFS_FILE" --alias "$IMAGE_ALIAS"; then
        log_error "Failed to import image into Incus"
        cleanup_files
        cd "$ORIGINAL_DIR" 2>/dev/null || true
        return 1
    fi
    log_success "Image imported successfully"
    
    # Verify import
    log_info "Verifying image import..."
    if check_image_exists "$IMAGE_ALIAS"; then
        log_success "Image '${IMAGE_ALIAS}' verified in Incus"
        
        # Show image info
        log_info "Image details:"
        incus image info "$IMAGE_ALIAS" | head -n 10
    else
        log_error "Image verification failed"
        cleanup_files
        cd "$ORIGINAL_DIR" 2>/dev/null || true
        return 1
    fi
    
    # Cleanup downloaded files
    log_info "Cleaning up downloaded files..."
    cleanup_files
    
    # Restore original directory
    cd "$ORIGINAL_DIR" 2>/dev/null || true
    
    log_success "=========================================="
    log_success "Import completed successfully!"
    log_success "Image alias: ${IMAGE_ALIAS}"
    log_success "=========================================="
    
    return 0
}

# Main execution if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Ensure /usr/local/bin is in PATH (where Incus is installed)
    export PATH="/usr/local/bin:$PATH"
    
    # Check if incus is available
    if ! command -v incus &>/dev/null; then
        log_error "Incus is not installed or not in PATH"
        log_error "Checked PATH: $PATH"
        return 1
    fi
    
    # Check if incus daemon is running
    if ! incus admin waitready --timeout=5 >/dev/null 2>&1; then
        log_error "Incus daemon is not running or not ready"
        return 1
    fi
    
    # Parse arguments
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <version> [arch] [workdir]"
        echo "  version: 22.04 or 24.04"
        echo "  arch: ppc64le, s390x, or x86_64 (default: auto-detect)"
        echo "  workdir: Working directory (default: ~/ubuntu-images)"
        return 1
    fi
    
    import_canonical_ubuntu_image "$@"
fi

# Made with Bob