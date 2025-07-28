#!/bin/bash

# PipeWire Virtual Audio Router
# Creates a virtual output device and routes desktop audio to it while maintaining original output
# Entirely Claude-generated, do not rely on this for production grade apps lmao

set -e

# Configuration
VIRTUAL_NAME="virtual-output"
VIRTUAL_DESCRIPTION="Virtual Output Device"
SCRIPT_NAME="$(basename "$0")"

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

# Check if required commands exist
check_dependencies() {
    local missing_deps=()
    
    for cmd in pw-cli pw-link pactl; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install: pipewire-pulse pipewire-tools"
        exit 1
    fi
}

# Check if PipeWire is running
check_pipewire() {
    if ! pgrep -x "pipewire" > /dev/null; then
        log_error "PipeWire is not running"
        exit 1
    fi
    
    if ! pgrep -x "pipewire-pulse" > /dev/null; then
        log_error "PipeWire PulseAudio compatibility layer is not running"
        exit 1
    fi
}

# Clean up existing virtual devices
cleanup_virtual_devices() {
    log_info "Checking for existing virtual devices..."
    
    # Get all null-sink modules (virtual devices)
    local virtual_sinks
    virtual_sinks=$(pactl list short modules | grep "module-null-sink" | grep "$VIRTUAL_NAME" || true)
    
    if [ -n "$virtual_sinks" ]; then
        log_info "Found existing virtual devices, removing them..."
        echo "$virtual_sinks" | while read -r line; do
            local module_id
            module_id=$(echo "$line" | awk '{print $1}')
            if [ -n "$module_id" ]; then
                pactl unload-module "$module_id"
                log_success "Removed virtual device module $module_id"
            fi
        done
    else
        log_info "No existing virtual devices found"
    fi
}

# Reset all loopback devices
reset_loopbacks() {
    log_info "Resetting all loopback devices..."
    
    # Get all loopback modules
    local loopback_modules
    loopback_modules=$(pactl list short modules | grep "module-loopback" || true)
    
    if [ -n "$loopback_modules" ]; then
        log_info "Found existing loopback devices, removing them..."
        echo "$loopback_modules" | while read -r line; do
            local module_id
            module_id=$(echo "$line" | awk '{print $1}')
            if [ -n "$module_id" ]; then
                pactl unload-module "$module_id" 2>/dev/null || true
                log_success "Removed loopback module $module_id"
            fi
        done
    else
        log_info "No existing loopback devices found"
    fi
    
    log_success "All loopback devices have been reset"
    echo
    log_info "Virtual sinks remain intact. You can now reconfigure routing or run the script normally to set up new connections."
}

# Create virtual output device
create_virtual_device() {
    log_info "Creating virtual output device '$VIRTUAL_NAME'..."
    
    # Create null sink (virtual output)
    pactl load-module module-null-sink \
        sink_name="$VIRTUAL_NAME" \
        sink_properties="device.description=\"$VIRTUAL_DESCRIPTION\""
    
    # Wait a moment for the device to be created
    sleep 1
    
    # Verify creation
    if pactl list short sinks | grep -q "$VIRTUAL_NAME"; then
        log_success "Virtual output device '$VIRTUAL_NAME' created successfully"
    else
        log_error "Failed to create virtual output device"
        exit 1
    fi
}

# List available output devices
list_output_devices() {
    log_info "Available output devices:"
    echo
    
    local counter=1
    local -a sink_names=()
    local -a sink_descriptions=()
    
    # Get sink information
    while IFS=$'\t' read -r name description; do
        if [ "$name" != "$VIRTUAL_NAME" ]; then  # Exclude our virtual device
            sink_names+=("$name")
            sink_descriptions+=("$description")
            printf "%2d) %s\n" "$counter" "$description"
            ((counter++))
        fi
    done < <(pactl list sinks | awk '
        /^Sink #[0-9]+/ { 
            in_sink = 1; 
            name = ""; 
            desc = ""; 
        }
        in_sink && /^\s+Name: / { 
            name = $2; 
        }
        in_sink && /^\s+Description: / {
            desc = substr($0, index($0, $2));
        }
        in_sink && /^$/ { 
            if (name && desc) print name "\t" desc; 
            in_sink = 0; 
        }
        END { 
            if (in_sink && name && desc) print name "\t" desc; 
        }
    ')
    
    echo
    
    if [ ${#sink_names[@]} -eq 0 ]; then
        log_error "No output devices found"
        exit 1
    fi
    
    # User selection
    while true; do
        read -p "Select output device to route (1-${#sink_names[@]}): " selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#sink_names[@]} ]; then
            selected_sink="${sink_names[$((selection-1))]}"
            selected_description="${sink_descriptions[$((selection-1))]}"
            log_success "Selected: $selected_description"
            break
        else
            log_warning "Invalid selection. Please enter a number between 1 and ${#sink_names[@]}"
        fi
    done
}

# Set up audio routing
setup_routing() {
    log_info "Setting up audio routing..."
    
    # Get the monitor source of our virtual sink
    local virtual_monitor="${VIRTUAL_NAME}.monitor"
    
    # Wait for devices to be fully available
    sleep 2
    
    # Create a loopback from virtual device to selected output
    log_info "Creating loopback from virtual device to $selected_description..."
    pactl load-module module-loopback \
        source="$virtual_monitor" \
        sink="$selected_sink" \
        latency_msec=1
    
    log_success "Audio routing configured successfully"
}

# Display connection information
show_connection_info() {
    echo
    log_success "Virtual audio router setup complete!"
    echo
    echo "Configuration:"
    echo "  Virtual Device: $VIRTUAL_DESCRIPTION"
    echo "  Physical Output: $selected_description"
    echo
    echo "Usage:"
    echo "  1. Set applications to output to '$VIRTUAL_DESCRIPTION'"
    echo "  2. Audio will be routed to both the virtual device and your speakers"
    echo "  3. You can capture from '$VIRTUAL_NAME.monitor' to record desktop audio"
    echo
    echo "PulseAudio/PipeWire commands:"
    echo "  List sinks: pactl list short sinks"
    echo "  Set default: pactl set-default-sink $VIRTUAL_NAME"
    echo "  Reset default: pactl set-default-sink $selected_sink"
    echo
    log_info "To remove the virtual device, run this script with --cleanup"
    log_info "To reset loopback connections only, run this script with --reset"
}

# Cleanup function
cleanup_all() {
    log_info "Cleaning up all virtual audio devices and loopbacks..."
    
    # Remove loopback modules
    pactl list short modules | grep "module-loopback" | while read -r line; do
        local module_id
        module_id=$(echo "$line" | awk '{print $1}')
        if [ -n "$module_id" ]; then
            pactl unload-module "$module_id" 2>/dev/null || true
        fi
    done
    
    # Remove virtual sink modules
    cleanup_virtual_devices
    
    log_success "Cleanup complete"
}

# Signal handlers
trap 'log_error "Script interrupted"; exit 130' INT TERM

# Main function
main() {
    echo "PipeWire Virtual Audio Router"
    echo "============================="
    echo
    
    # Handle command line arguments
    case "${1:-}" in
        --cleanup|-c)
            check_dependencies
            check_pipewire
            cleanup_all
            exit 0
            ;;
        --reset|-r)
            check_dependencies
            check_pipewire
            reset_loopbacks
            exit 0
            ;;
        --help|-h)
            echo "Usage: $SCRIPT_NAME [OPTIONS]"
            echo
            echo "Options:"
            echo "  --cleanup, -c    Remove all virtual devices and loopbacks"
            echo "  --reset, -r      Reset all loopback connections (keeps virtual devices)"
            echo "  --help, -h       Show this help message"
            echo
            echo "Examples:"
            echo "  $SCRIPT_NAME              # Set up virtual audio routing"
            echo "  $SCRIPT_NAME --reset      # Remove loopback connections only"
            echo "  $SCRIPT_NAME --cleanup    # Remove everything and start fresh"
            echo
            exit 0
            ;;
        "")
            # Normal operation
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    
    # Main setup process
    check_dependencies
    check_pipewire
    cleanup_virtual_devices
    create_virtual_device
    list_output_devices
    setup_routing
    show_connection_info
}

# Run main function
main "$@"