#!/bin/bash
################################################################################
##  File:  import_ubuntu_base_images.sh
##  Desc:  Shared function to import Ubuntu base images for Incus
##  Usage: Source this file and call import_ubuntu_base_images
##         Can be used by incus_container.sh, incus_vm.sh, etc.
################################################################################

import_ubuntu_base_images() {
    local ARCH="${ARCH:-$(uname -m)}"
    local HELPERS_DIR="${HELPERS_DIR:-$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")}"
    
    echo ""
    echo "=========================================="
    echo " Ubuntu Base Image Import"
    echo "=========================================="
    echo ""
    echo "Choose how to import Ubuntu base images:"
    echo "1) Canonical Cloud Images (faster, pre-built)"
    echo "2) Distrobuilder (build from source)"
    echo "3) Skip (use existing images)"
    echo ""
    
    read -p "Enter choice [1-3]: " method_choice
    
    case "$method_choice" in
        1)
            echo ""
            echo "Selected: Canonical Cloud Images"
            echo "Choose Ubuntu version to import:"
            echo "1) Ubuntu 22.04 (Jammy)"
            echo "2) Ubuntu 24.04 (Noble)"
            echo "3) Both versions"
            echo ""
            
            read -p "Enter choice [1-3]: " version_choice
            
            case "$version_choice" in
                1)
                    echo ""
                    echo "Importing Ubuntu 22.04..."
                    bash "${HELPERS_DIR}/import-canonical-ubuntu-image.sh" "22.04" "${ARCH}"
                    ;;
                2)
                    echo ""
                    echo "Importing Ubuntu 24.04..."
                    bash "${HELPERS_DIR}/import-canonical-ubuntu-image.sh" "24.04" "${ARCH}"
                    ;;
                3)
                    echo ""
                    echo "Importing Ubuntu 22.04..."
                    bash "${HELPERS_DIR}/import-canonical-ubuntu-image.sh" "22.04" "${ARCH}"
                    echo ""
                    echo "Importing Ubuntu 24.04..."
                    bash "${HELPERS_DIR}/import-canonical-ubuntu-image.sh" "24.04" "${ARCH}"
                    ;;
                *)
                    echo "Invalid choice. Skipping import."
                    ;;
            esac
            ;;
        2)
            echo ""
            echo "Selected: Distrobuilder"
            echo "Choose Ubuntu version to build:"
            echo "1) Ubuntu 22.04 (Jammy)"
            echo "2) Ubuntu 24.04 (Noble)"
            echo "3) Both versions"
            echo ""
            
            read -p "Enter choice [1-3]: " version_choice
            
            case "$version_choice" in
                1)
                    echo ""
                    echo "Building Ubuntu 22.04..."
                    bash "${HELPERS_DIR}/build-distrobuilder-image.sh" "22.04" "${ARCH}"
                    ;;
                2)
                    echo ""
                    echo "Building Ubuntu 24.04..."
                    bash "${HELPERS_DIR}/build-distrobuilder-image.sh" "24.04" "${ARCH}"
                    ;;
                3)
                    echo ""
                    echo "Building Ubuntu 22.04..."
                    bash "${HELPERS_DIR}/build-distrobuilder-image.sh" "22.04" "${ARCH}"
                    echo ""
                    echo "Building Ubuntu 24.04..."
                    bash "${HELPERS_DIR}/build-distrobuilder-image.sh" "24.04" "${ARCH}"
                    ;;
                *)
                    echo "Invalid choice. Skipping build."
                    ;;
            esac
            ;;
        3)
            echo "Skipping image import. Using existing images."
            ;;
        *)
            echo "Invalid choice. Skipping image import."
            ;;
    esac
    
    echo ""
    echo "Image import step completed."
    echo ""
}

# Made with Bob