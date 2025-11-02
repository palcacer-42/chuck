#!/bin/bash

# ChucK Automated Installer for Ubuntu
# This script installs all dependencies and compiles ChucK from source

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        log_info "The script will use sudo when needed"
        exit 1
    fi
}

# Check Ubuntu version
check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "This script is designed for Ubuntu Linux"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        log_warning "This script is designed for Ubuntu, but you're running $ID"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Update system and install dependencies
install_dependencies() {
    log_info "Updating package lists..."
    sudo apt-get update
    
    log_info "Installing build dependencies..."
    sudo apt-get install -y \
        make \
        gcc \
        g++ \
        bison \
        flex \
        libasound2-dev \
        libsndfile1-dev \
        libpulse-dev \
        libjack-jackd2-dev \
        curl \
        wget
    
    log_success "Dependencies installed successfully"
}

# Download and extract ChucK source
download_chuck() {
    local chuck_url="https://github.com/ccrma/chuck/archive/refs/tags/v1.4.2.0.tar.gz"
    local temp_dir="/tmp/chuck-install"
    
    log_info "Creating temporary directory..."
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    log_info "Downloading ChucK source code..."
    if command -v wget &> /dev/null; then
        wget -O chuck.tar.gz "$chuck_url"
    elif command -v curl &> /dev/null; then
        curl -L -o chuck.tar.gz "$chuck_url"
    else
        log_error "Neither wget nor curl found. Please install one of them."
        exit 1
    fi
    
    log_info "Extracting source code..."
    tar xzf chuck.tar.gz --strip-components=1
    
    log_success "ChucK source code downloaded and extracted"
}

# Compile ChucK
compile_chuck() {
    log_info "Compiling ChucK..."
    cd src
    
    # Try different compilation targets
    local targets=("linux-all" "linux-pulse" "linux-alsa" "linux-jack")
    local compiled=false
    
    for target in "${targets[@]}"; do
        log_info "Trying compilation target: $target"
        if make clean && make "$target"; then
            compiled=true
            log_success "Successfully compiled with target: $target"
            break
        else
            log_warning "Compilation with $target failed, trying next target..."
        fi
    done
    
    if [[ "$compiled" == false ]]; then
        log_error "All compilation targets failed"
        exit 1
    fi
}

# Install ChucK
install_chuck_binary() {
    log_info "Installing ChucK system-wide..."
    sudo make install
    
    log_success "ChucK installed successfully"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    if command -v chuck &> /dev/null; then
        local version
        version=$(chuck --version 2>/dev/null || echo "unknown version")
        log_success "ChucK installed successfully: $version"
    else
        log_error "ChucK installation verification failed"
        exit 1
    fi
}

# Clean up
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf /tmp/chuck-install
    
    log_success "Cleanup completed"
}

# Install miniAudicle (optional)
install_miniaudicle() {
    read -p "Do you want to install miniAudicle IDE? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    log_info "Installing miniAudicle dependencies..."
    sudo apt-get install -y \
        libqt5widgets5 \
        libqt5core5a \
        libqt5gui5 \
        qtbase5-dev \
        qscintilla2-qt5-dev
    
    local ma_url="https://github.com/ccrma/miniAudicle/archive/refs/tags/v1.4.0.0.tar.gz"
    local temp_dir="/tmp/miniaudicle-install"
    
    log_info "Downloading miniAudicle..."
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    if command -v wget &> /dev/null; then
        wget -O miniaudicle.tar.gz "$ma_url"
    else
        curl -L -o miniaudicle.tar.gz "$ma_url"
    fi
    
    log_info "Extracting miniAudicle..."
    tar xzf miniaudicle.tar.gz --strip-components=1
    
    log_info "Compiling miniAudicle..."
    cd src
    if make && sudo make install; then
        log_success "miniAudicle installed successfully"
    else
        log_warning "miniAudicle compilation failed, but ChucK is installed"
    fi
    
    rm -rf "$temp_dir"
}

# Main installation function
main() {
    log_info "Starting ChucK installation process..."
    log_info "This will install dependencies and compile ChucK from source"
    echo
    
    check_root
    check_ubuntu
    
    # Confirm installation
    read -p "Continue with ChucK installation? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
    
    # Execute installation steps
    install_dependencies
    download_chuck
    compile_chuck
    install_chuck_binary
    verify_installation
    install_miniaudicle
    cleanup
    
    echo
    log_success "🎵 ChucK installation completed successfully!"
    log_info "You can now run ChucK programs with: chuck your_program.ck"
    log_info "Try: chuck --version"
    echo
    log_info "For more information, visit: https://chuck.cs.princeton.edu/"
}

# Handle script interrupts
trap 'log_error "Installation interrupted"; cleanup; exit 1' INT TERM

# Run main function
main "$@"