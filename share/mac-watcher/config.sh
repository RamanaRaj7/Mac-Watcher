#!/bin/bash
#=================================================================
# MONITOR CONFIGURATION UTILITY
# 
# An interactive tool to configure monitor functions with
# email alerts, location tracking, and screenshot settings.
#=================================================================

# Color definitions - simplified and consistent palette
ACCENT='\033[0;36m'     # Cyan for headings and highlights
PRIMARY='\033[0;36m'    # Blue for primary elements
SUCCESS='\033[0;32m'    # Green for success/enabled states
WARNING='\033[0;33m'    # Yellow for warnings/optional states
ERROR='\033[0;31m'      # Red for errors/disabled states
NC='\033[0m'            # No Color
BOLD='\033[1m'          # Bold text for emphasis

# Configuration file path
CONFIG_FILE="$HOME/.config/monitor.conf"

# Current time and user info for logging purposes
CURRENT_DATE_UTC=$(date)
CURRENT_USER=$(whoami)

#=================================================================
# INITIALIZATION
#=================================================================

show_header() {
    clear
    echo -e "${ACCENT}${BOLD}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${ACCENT}${BOLD}║               MONITOR CONFIGURATION                ║${NC}"
    echo -e "${ACCENT}${BOLD}╚════════════════════════════════════════════════════╝${NC}"
    echo
}

# Create a default configuration if it doesn't exist
initialize_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${WARNING}Creating default configuration...${NC}"
        mkdir -p $(dirname "$CONFIG_FILE")
        cat > "$CONFIG_FILE" << EOL
# Monitor Configuration Default
EMAIL_FROM="onboarding@resend.dev"
EMAIL_TO=""
RESEND_API_KEY=""
EMAIL_ENABLED="no"
INITIAL_EMAIL_ENABLED="yes"
FOLLOWUP_EMAIL_ENABLED="yes"
EMAIL_TIME_RESTRICTION_ENABLED="no"
EMAIL_ACTIVE_WINDOWS=""
EMAIL_DAY_RESTRICTION_ENABLED="no"
EMAIL_ACTIVE_DAYS="Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday"
INITIAL_DELAY=2
FOLLOWUP_DELAY=25
BASE_DIR="\$HOME/Pictures/.access"
LOCATION_ENABLED="yes"
LOCATION_METHOD="corelocation_cli"
LOCATION_CONFIGURED="no"
NETWORK_INFO_ENABLED="yes"
NETWORK_CONFIGURED="no"
WEBCAM_ENABLED="yes"
SCREENSHOT_ENABLED="yes"
FOLLOWUP_SCREENSHOT_ENABLED="yes"
CUSTOM_SCHEDULE_ENABLED="no"
ACTIVE_DAYS="Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday"
SCHEDULE_ACTIVE_WINDOWS=""
AUTO_DELETE_ENABLED="no"
AUTO_DELETE_DAYS=365
EOL
        echo -e "${SUCCESS}Default configuration created${NC}"
        echo
    fi

    # Read the configuration file
    source "$CONFIG_FILE"

    # Set defaults for any missing variables (for backward compatibility)
    : ${EMAIL_ENABLED:="no"}
    : ${INITIAL_EMAIL_ENABLED:="yes"}
    : ${FOLLOWUP_EMAIL_ENABLED:="yes"}
    : ${EMAIL_TIME_RESTRICTION_ENABLED:="no"}
    : ${EMAIL_ACTIVE_WINDOWS:=""}
    : ${EMAIL_DAY_RESTRICTION_ENABLED:="no"}
    : ${EMAIL_ACTIVE_DAYS:="Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday"}
    : ${INITIAL_DELAY:=2}
    : ${FOLLOWUP_DELAY:=25}
    : ${LOCATION_ENABLED:="yes"}
    : ${LOCATION_METHOD:="corelocation_cli"}
    : ${LOCATION_CONFIGURED:="no"}
    : ${NETWORK_INFO_ENABLED:="yes"}
    : ${NETWORK_CONFIGURED:="no"}
    : ${WEBCAM_ENABLED:="yes"}
    : ${SCREENSHOT_ENABLED:="yes"}
    : ${FOLLOWUP_SCREENSHOT_ENABLED:="yes"}
    : ${CUSTOM_SCHEDULE_ENABLED:="no"}
    : ${ACTIVE_DAYS:="Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday"}
    : ${SCHEDULE_ACTIVE_WINDOWS:=""}
    : ${AUTO_DELETE_ENABLED:="no"}
    : ${AUTO_DELETE_DAYS:=365}
}

#=================================================================
# DISPLAY FUNCTIONS
#=================================================================

# Format time windows with brackets
format_time_windows() {
    local windows=$1
    local formatted=""
    
    if [ -z "$windows" ]; then
        echo ""
        return
    fi
    
    IFS=',' read -ra WINDOWS <<< "$windows"
    for window in "${WINDOWS[@]}"; do
        if [ -z "$formatted" ]; then
            formatted="[$window]"
        else
            formatted="$formatted,[$window]"
        fi
    done
    
    echo "$formatted"
}

display_summary() {
    # Email section
    echo -e "${ACCENT}◇ EMAIL${NC}"
    if [ "$EMAIL_ENABLED" = "yes" ]; then
        echo -e "  Email Status    : ${SUCCESS}Enabled${NC}"
    else
        echo -e "  Email Status    : ${WARNING}Disabled${NC}"
    fi
    echo -e "  Sender email    : ${SUCCESS}$EMAIL_FROM${NC}"

    if [ -n "$EMAIL_TO" ]; then
        echo -e "  Recipient email : ${SUCCESS}$EMAIL_TO${NC}"
    else
        echo -e "  Recipient email : ${ERROR}Not configured${NC}"
    fi
    
    if [ -n "$RESEND_API_KEY" ]; then
        echo -e "  Resend API Key  : ${SUCCESS}$RESEND_API_KEY${NC}"
    else
        echo -e "  Resend API Key  : ${ERROR}Not configured${NC}"
    fi
    
    # Initial Email Status
    if [ "$INITIAL_EMAIL_ENABLED" = "yes" ]; then
        echo -e "  Initial Email   : ${SUCCESS}Enabled${NC}"
    else
        echo -e "  Initial Email   : ${WARNING}Disabled${NC}"
    fi
    
    # Follow-up Email Status
    if [ "$FOLLOWUP_EMAIL_ENABLED" = "yes" ]; then
        echo -e "  Follow-up Email : ${SUCCESS}Enabled${NC}"
    else
        echo -e "  Follow-up Email : ${WARNING}Disabled${NC}"
    fi
    
    # Email time restriction info
    if [ "$EMAIL_TIME_RESTRICTION_ENABLED" = "yes" ]; then
        echo -e "  Time Restriction: ${SUCCESS}Enabled${NC}"
        formatted_windows=$(format_time_windows "$EMAIL_ACTIVE_WINDOWS")
        if [ -n "$formatted_windows" ]; then
            echo -e "  Active Windows  : ${SUCCESS}$formatted_windows${NC}"
        else
            echo -e "  Active Windows  : ${WARNING}None configured${NC}"
        fi
    else
        echo -e "  Time Restriction: ${WARNING}Disabled${NC}"
    fi
    
    # Email day restriction info
    if [ "$EMAIL_DAY_RESTRICTION_ENABLED" = "yes" ]; then
        echo -e "  Day Restriction : ${SUCCESS}Enabled${NC}"
        echo -e "  Active Days     : ${SUCCESS}$EMAIL_ACTIVE_DAYS${NC}"
    else
        echo -e "  Day Restriction : ${WARNING}Disabled${NC}"
    fi
    
    # Location section
    echo -e "\n${ACCENT}◇ LOCATION & NETWORK${NC}"
    if [ "$LOCATION_ENABLED" = "yes" ]; then
        echo -e "  Location  : ${SUCCESS}Enabled${NC}"
    else
        echo -e "  Location  : ${WARNING}Disabled${NC}"
    fi
    
    # Display location method
    if [ "$LOCATION_METHOD" = "corelocation_cli" ]; then
        echo -e "  Method    : ${SUCCESS}CoreLocationCLI${NC}"
    else
        echo -e "  Method    : ${SUCCESS}Apple Shortcuts${NC}"
    fi
    
    if [ "$LOCATION_CONFIGURED" = "yes" ]; then
        echo -e "  Setup     : ${SUCCESS}Configured${NC}"
    else
        echo -e "  Setup     : ${ERROR}Not configured${NC}"
    fi
    
    # Network information status
    if [ "$NETWORK_INFO_ENABLED" = "yes" ]; then
        echo -e "  Network   : ${SUCCESS}Enabled${NC}"
    else
        echo -e "  Network   : ${WARNING}Disabled${NC}"
    fi
    
    # Media Controls section
    echo -e "\n${ACCENT}◇ MEDIA CAPTURE${NC}"
    if [ "$WEBCAM_ENABLED" = "yes" ]; then
        echo -e "  Webcam    : ${SUCCESS}Enabled${NC}"
    else
        echo -e "  Webcam    : ${WARNING}Disabled${NC}"
    fi
    
    if [ "$SCREENSHOT_ENABLED" = "yes" ]; then
        echo -e "  Screenshot: ${SUCCESS}Enabled${NC}"
    else
        echo -e "  Screenshot: ${WARNING}Disabled${NC}"
    fi
    
    if [ "$FOLLOWUP_SCREENSHOT_ENABLED" = "yes" ]; then
        echo -e "  Follow-up Screenshot: ${SUCCESS}Enabled${NC}"
    else
        echo -e "  Follow-up Screenshot: ${WARNING}Disabled${NC}"
    fi
    
    # Schedule section
    echo -e "\n${ACCENT}◇ SCHEDULE${NC}"
    if [ "$CUSTOM_SCHEDULE_ENABLED" = "yes" ]; then
        echo -e "  Status        : ${SUCCESS}Custom Schedule Enabled${NC}"
    else
        echo -e "  Status        : ${WARNING}Running Every Day${NC}"
    fi
    echo -e "  Active Days   : ${SUCCESS}$ACTIVE_DAYS${NC}"
    formatted_schedule_windows=$(format_time_windows "$SCHEDULE_ACTIVE_WINDOWS")
    if [ -n "$formatted_schedule_windows" ]; then
        echo -e "  Active Windows: ${SUCCESS}$formatted_schedule_windows${NC}"
    else
        echo -e "  Active Windows: ${WARNING}None configured${NC}"
    fi
    
    # Auto-delete section
    echo -e "\n${ACCENT}◇ AUTO-DELETE${NC}"
    if [ "$AUTO_DELETE_ENABLED" = "yes" ]; then
        echo -e "  Status    : ${SUCCESS}Enabled${NC}"
        echo -e "  Keep for  : ${SUCCESS}$AUTO_DELETE_DAYS days${NC}"
    else
        echo -e "  Status    : ${WARNING}Disabled${NC}"
    fi
    
    # Timing section
    echo -e "\n${ACCENT}◇ DELAY TIMING${NC}"
    echo -e "  Initial   : ${SUCCESS}$INITIAL_DELAY seconds${NC}"
    echo -e "  Follow-up : ${SUCCESS}$FOLLOWUP_DELAY seconds${NC}"
    
    # Storage section
    echo -e "\n${ACCENT}◇ STORAGE${NC}"
    echo -e "  Path      : ${SUCCESS}$BASE_DIR${NC}"
    
    echo
    echo -e "${PRIMARY}──────────────────────────────────────────────────────${NC}"
    echo
}

#=================================================================
# CONFIGURATION FUNCTIONS
#=================================================================

toggle_setting() {
    local var_name=$1
    local var_value=${!var_name}
    
    if [ "$var_value" = "yes" ]; then
        eval "$var_name=\"no\""
        echo -e "${WARNING}$2 disabled.${NC}"
    else
        eval "$var_name=\"yes\""
        echo -e "${SUCCESS}$2 enabled.${NC}"
    fi
}

configure_email() {
    while true; do
        show_header
        echo -e "${ACCENT}${BOLD}EMAIL CONFIGURATION${NC}"
        echo
        
        if [ "$EMAIL_ENABLED" = "yes" ]; then
            echo -e "  ${PRIMARY}[1]${NC} Email Status    : ${SUCCESS}Enabled${NC}"
        else
            echo -e "  ${PRIMARY}[1]${NC} Email Status    : ${WARNING}Disabled${NC}"
        fi
        
        echo -e "  ${PRIMARY}[2]${NC} Sender Address  : ${SUCCESS}$EMAIL_FROM${NC}"
        
        if [ -n "$EMAIL_TO" ]; then
            echo -e "  ${PRIMARY}[3]${NC} Recipient email : ${SUCCESS}$EMAIL_TO${NC}"
        else
            echo -e "  ${PRIMARY}[3]${NC} Recipient email : ${ERROR}Not configured${NC}"
        fi
        
        if [ -n "$RESEND_API_KEY" ]; then
            echo -e "  ${PRIMARY}[4]${NC} Resend API Key  : ${SUCCESS}$RESEND_API_KEY${NC}"
        else
            echo -e "  ${PRIMARY}[4]${NC} Resend API Key  : ${ERROR}Not configured${NC}"
        fi
        
        # Initial Email toggle
        if [ "$INITIAL_EMAIL_ENABLED" = "yes" ]; then
            echo -e "  ${PRIMARY}[5]${NC} Initial Email   : ${SUCCESS}Enabled${NC}"
        else
            echo -e "  ${PRIMARY}[5]${NC} Initial Email   : ${WARNING}Disabled${NC}"
        fi
        
        # Follow-up Email toggle
        if [ "$FOLLOWUP_EMAIL_ENABLED" = "yes" ]; then
            echo -e "  ${PRIMARY}[6]${NC} Follow-up Email : ${SUCCESS}Enabled${NC}"
        else
            echo -e "  ${PRIMARY}[6]${NC} Follow-up Email : ${WARNING}Disabled${NC}"
        fi
        
        # Time restriction status display
        if [ "$EMAIL_TIME_RESTRICTION_ENABLED" = "yes" ]; then
            echo -e "  ${PRIMARY}[7]${NC} Time Restriction: ${SUCCESS}Enabled${NC}"
            formatted_windows=$(format_time_windows "$EMAIL_ACTIVE_WINDOWS")
            if [ -n "$formatted_windows" ]; then
                echo -e "      Active Windows  : ${SUCCESS}$formatted_windows${NC}"
            else
                echo -e "      Active Windows  : ${WARNING}None configured${NC}"
            fi
        else
            echo -e "  ${PRIMARY}[7]${NC} Time Restriction: ${WARNING}Disabled${NC}"
        fi
        
        # Day restriction status display
        if [ "$EMAIL_DAY_RESTRICTION_ENABLED" = "yes" ]; then
            echo -e "  ${PRIMARY}[8]${NC} Day Restriction : ${SUCCESS}Enabled${NC}"
            echo -e "      Active Days     : ${SUCCESS}$EMAIL_ACTIVE_DAYS${NC}"
        else
            echo -e "  ${PRIMARY}[8]${NC} Day Restriction : ${WARNING}Disabled${NC}"
        fi
        
        # Add test email option
        echo -e "  ${PRIMARY}[9]${NC} Test Email Configuration"
        
        echo -e "  ${PRIMARY}[0]${NC} Back to Main Menu"
        echo
        read -p "Select option (0-9): " email_choice
        echo
        
        case $email_choice in
            1)
                toggle_setting "EMAIL_ENABLED" "Email notifications"
                ;;
            2)
                read -p "Enter sender email (current: $EMAIL_FROM): " new_email_from
                if [ -n "$new_email_from" ]; then
                    EMAIL_FROM="$new_email_from"
                    echo -e "${SUCCESS}Email sender updated.${NC}"
                fi
                ;;
            3)
                read -p "Enter recipient email (current: $EMAIL_TO): " new_email_to
                if [ -n "$new_email_to" ]; then
                    EMAIL_TO="$new_email_to"
                    echo -e "${SUCCESS}Email recipient updated.${NC}"
                fi
                ;;
            4)
                echo -e "${ACCENT}${BOLD}Resend API Key Setup${NC}"
                echo
                echo "To send email notifications, you need an API key from Resend."
                echo "(Resend Provides 3000 emails per month for free)"
                echo
                echo "Instructions:"
                echo -e "1. Visit the Resend dashboard: ${ACCENT}https://resend.com/api-keys${NC}"
                echo -e "2. Log in or create an account with ${ACCENT}'recipient email address only'${NC}, if you don't have one."
                echo -e "3. Click ${ACCENT}'Create API Key'${NC}, give it a name (e.g., MacWatcher), and copy the key."
                echo "4. Paste the API key below when prompted."
                echo

                read -p "Enter Resend API Key: " new_resend_api_key
                if [ -n "$new_resend_api_key" ]; then
                    RESEND_API_KEY="$new_resend_api_key"
                    echo -e "${SUCCESS}API Key updated.${NC}"
                fi
                ;;
            5)
                toggle_setting "INITIAL_EMAIL_ENABLED" "Initial email"
                ;;
            6)
                toggle_setting "FOLLOWUP_EMAIL_ENABLED" "Follow-up email"
                ;;
            7)
                configure_time_restrictions
                ;;
            8)
                configure_email_day_restrictions
                ;;
            9)
                test_email
                ;;
            0)
                return
                ;;
            *)
                echo -e "${ERROR}Invalid option. Please choose between 0 and 9.${NC}"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

configure_time_restrictions() {
    while true; do
        show_header
        echo -e "${ACCENT}${BOLD}EMAIL TIME RESTRICTIONS${NC}"
        echo
        
        if [ "$EMAIL_TIME_RESTRICTION_ENABLED" = "yes" ]; then
            echo -e "  ${PRIMARY}[1]${NC} Status : ${SUCCESS}Enabled${NC}"
        else
            echo -e "  ${PRIMARY}[1]${NC} Status : ${WARNING}Disabled${NC}"
        fi
        
        echo -e "  ${PRIMARY}[2]${NC} Configure Active Time Windows"
        echo -e "  ${PRIMARY}[3]${NC} Back to Email Settings"
        echo
        
        read -p "Select option (1-3): " time_choice
        echo
        
        case $time_choice in
            1)
                toggle_setting "EMAIL_TIME_RESTRICTION_ENABLED" "Time restrictions"
                ;;
            2)
                configure_active_time_windows
                ;;
            3)
                return
                ;;
            *)
                echo -e "${ERROR}Invalid option. Please choose between 1 and 3.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

configure_email_day_restrictions() {
    while true; do
        show_header
        echo -e "${ACCENT}${BOLD}EMAIL DAY RESTRICTIONS${NC}"
        echo
        
        if [ "$EMAIL_DAY_RESTRICTION_ENABLED" = "yes" ]; then
            echo -e "  ${PRIMARY}[1]${NC} Status : ${SUCCESS}Enabled${NC}"
        else
            echo -e "  ${PRIMARY}[1]${NC} Status : ${WARNING}Disabled${NC}"
        fi
        
        echo -e "  ${PRIMARY}[2]${NC} Configure Active Days"
        echo -e "  ${PRIMARY}[3]${NC} Back to Email Settings"
        echo
        
        read -p "Select option (1-3): " day_choice
        echo
        
        case $day_choice in
            1)
                toggle_setting "EMAIL_DAY_RESTRICTION_ENABLED" "Day restrictions"
                ;;
            2)
                configure_email_active_days
                ;;
            3)
                return
                ;;
            *)
                echo -e "${ERROR}Invalid option. Please choose between 1 and 3.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

configure_active_time_windows() {
    while true; do
        show_header
        echo -e "${ACCENT}${BOLD}ACTIVE TIME WINDOWS CONFIGURATION${NC}"
        echo
        echo -e "${BOLD}Current Active Windows:${NC}"
        
        IFS=',' read -ra WINDOWS <<< "$EMAIL_ACTIVE_WINDOWS"
        if [ ${#WINDOWS[@]} -eq 0 ]; then
            echo -e "  ${WARNING}No active windows configured.${NC}"
        else
            for i in "${!WINDOWS[@]}"; do
                echo -e "  ${PRIMARY}[$((i+1))]${NC} ${SUCCESS}[${WINDOWS[$i]}]${NC}"
            done
        fi
        echo
        echo -e "${BOLD}Options:${NC}"
        echo -e "  ${PRIMARY}[1]${NC} Add new time window"
        if [ ${#WINDOWS[@]} -gt 0 ]; then
            echo -e "  ${PRIMARY}[2]${NC} Edit existing time window"
            echo -e "  ${PRIMARY}[3]${NC} Delete time window"
        fi
        echo -e "  ${PRIMARY}[4]${NC} Back to Time Restriction"
        echo
        echo -e "${WARNING}Note: Time windows must be in 12-hour format (e.g., 8:00AM-12:00PM)${NC}"
        echo
        read -p "Select an option: " window_choice
        echo
        
        case $window_choice in
            1)
                add_time_window
                ;;
            2)
                if [ ${#WINDOWS[@]} -gt 0 ]; then
                    edit_time_window
                else
                    echo -e "${ERROR}No time windows to edit.${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            3)
                if [ ${#WINDOWS[@]} -gt 0 ]; then
                    delete_time_window
                else
                    echo -e "${ERROR}No time windows to delete.${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            4)
                return 
                ;;
            *)
                echo -e "${ERROR}Invalid option.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

validate_time_format() {
    local time=$1
    if [[ $time =~ ^([1-9]|1[0-2]):([0-5][0-9])(AM|PM)-(([1-9]|1[0-2]):([0-5][0-9])(AM|PM))$ ]]; then
        return 0
    else
        return 1
    fi
}

add_time_window() {
    echo -e "${BOLD}Add New Time Window${NC}"
    echo -e "${WARNING}Format: HH:MMAM-HH:MMPM (12-hour format with AM/PM)${NC}"
    echo -e "${WARNING}Examples: 8:00AM-12:00PM, 1:30PM-5:45PM${NC}"
    echo
    
    while true; do
        read -p "Enter time window: " new_window
        
        if [ -z "$new_window" ]; then
            echo -e "${WARNING}Operation cancelled.${NC}"
            return
        fi
        
        if validate_time_format "$new_window"; then
            if [ -z "$EMAIL_ACTIVE_WINDOWS" ]; then
                EMAIL_ACTIVE_WINDOWS="$new_window"
            else
                EMAIL_ACTIVE_WINDOWS="$EMAIL_ACTIVE_WINDOWS,$new_window"
            fi
            echo -e "${SUCCESS}Time window added successfully.${NC}"
            break
        else
            echo -e "${ERROR}Invalid format. Please use the format HH:MMAM-HH:MMPM${NC}"
            echo -e "${ERROR}Examples: 8:00AM-12:00PM, 1:30PM-5:45PM${NC}"
        fi
    done
    
    read -p "Press Enter to continue..."
}

edit_time_window() {
    echo -e "${BOLD}Edit Time Window${NC}"
    IFS=',' read -ra WINDOWS <<< "$EMAIL_ACTIVE_WINDOWS"
    
    for i in "${!WINDOWS[@]}"; do
        echo -e "  ${PRIMARY}[$((i+1))]${NC} [${WINDOWS[$i]}]"
    done
    echo
    
    read -p "Select a window to edit (1-${#WINDOWS[@]}): " window_index
    
    if ! [[ "$window_index" =~ ^[0-9]+$ ]] || [ "$window_index" -lt 1 ] || [ "$window_index" -gt ${#WINDOWS[@]} ]; then
        echo -e "${ERROR}Invalid selection.${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    index=$((window_index-1))
    echo -e "Editing: ${SUCCESS}[${WINDOWS[$index]}]${NC}"
    echo -e "${WARNING}Format: HH:MMAM-HH:MMPM (12-hour format with AM/PM)${NC}"
    echo -e "${WARNING}Examples: 8:00AM-12:00PM, 1:30PM-5:45PM${NC}"
    echo
    
    while true; do
        read -p "Enter new time window: " edited_window
        
        if [ -z "$edited_window" ]; then
            echo -e "${WARNING}Edit cancelled.${NC}"
            read -p "Press Enter to continue..."
            return
        fi
        
        if validate_time_format "$edited_window"; then
            WINDOWS[$index]="$edited_window"
            EMAIL_ACTIVE_WINDOWS=$(IFS=,; echo "${WINDOWS[*]}")
            echo -e "${SUCCESS}Time window updated successfully.${NC}"
            break
        else
            echo -e "${ERROR}Invalid format. Please use the format HH:MMAM-HH:MMPM${NC}"
            echo -e "${ERROR}Examples: 8:00AM-12:00PM, 1:30PM-5:45PM${NC}"
        fi
    done
    
    read -p "Press Enter to continue..."
}

delete_time_window() {
    echo -e "${BOLD}Delete Time Window${NC}"
    IFS=',' read -ra WINDOWS <<< "$EMAIL_ACTIVE_WINDOWS"
    
    for i in "${!WINDOWS[@]}"; do
        echo -e "  ${PRIMARY}[$((i+1))]${NC} [${WINDOWS[$i]}]"
    done
    echo
    
    read -p "Select a window to delete (1-${#WINDOWS[@]}): " window_index
    
    if ! [[ "$window_index" =~ ^[0-9]+$ ]] || [ "$window_index" -lt 1 ] || [ "$window_index" -gt ${#WINDOWS[@]} ]; then
        echo -e "${ERROR}Invalid selection.${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    index=$((window_index-1))
    echo -e "Are you sure you want to delete: ${WARNING}[${WINDOWS[$index]}]${NC}?"
    read -p "Confirm deletion (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        unset 'WINDOWS[$index]'
        EMAIL_ACTIVE_WINDOWS=$(IFS=,; echo "${WINDOWS[*]}")
        echo -e "${SUCCESS}Time window deleted successfully.${NC}"
    else
        echo -e "${WARNING}Deletion cancelled.${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

configure_location() {
    while true; do
        show_header
        echo -e "${ACCENT}${BOLD}LOCATION & NETWORK CONFIGURATION${NC}"
        echo
        
        if [ "$LOCATION_ENABLED" = "yes" ]; then
            echo -e "  ${PRIMARY}[1]${NC} Location Status : ${SUCCESS}Enabled${NC}"
        else
            echo -e "  ${PRIMARY}[1]${NC} Location Status : ${WARNING}Disabled${NC}"
        fi
        
        echo -e "  ${PRIMARY}[2]${NC} Select Location Method"
        
        # Show the current method as a sub-item under option 2
        if [ "$LOCATION_METHOD" = "corelocation_cli" ]; then
            echo -e "      Current Method  : ${SUCCESS}CoreLocationCLI${NC}"
        else
            echo -e "      Current Method  : ${SUCCESS}Apple Shortcuts${NC}"
        fi
        
        # Show setup status based on the selected method
        if [ "$LOCATION_METHOD" = "corelocation_cli" ]; then
            if [ "$LOCATION_CONFIGURED" = "yes" ]; then
                echo -e "  ${PRIMARY}[3]${NC} Setup CoreLocationCLI : ${SUCCESS}Configured${NC}"
            else
                echo -e "  ${PRIMARY}[3]${NC} Setup CoreLocationCLI : ${ERROR}Not Configured${NC}"
            fi
        else
            if [ "$LOCATION_CONFIGURED" = "yes" ]; then
                echo -e "  ${PRIMARY}[3]${NC} Setup Apple Shortcut : ${SUCCESS}Configured${NC}"
            else
                echo -e "  ${PRIMARY}[3]${NC} Setup Apple Shortcut : ${ERROR}Not Configured${NC}"
            fi
        fi
        
        # Add network information toggle
        if [ "$NETWORK_INFO_ENABLED" = "yes" ]; then
            echo -e "  ${PRIMARY}[4]${NC} Network Info    : ${SUCCESS}Enabled${NC}"
        else
            echo -e "  ${PRIMARY}[4]${NC} Network Info    : ${WARNING}Disabled${NC}"
        fi
        
        # Add network info setup status using the NETWORK_CONFIGURED variable
        if [ "$NETWORK_CONFIGURED" = "yes" ]; then 
            echo -e "  ${PRIMARY}[5]${NC} Network Setup   : ${SUCCESS}Configured${NC}"
        else
            echo -e "  ${PRIMARY}[5]${NC} Network Setup   : ${ERROR}Not Configured${NC}"
        fi
        
        echo -e "  ${PRIMARY}[6]${NC} Back to Main Menu"
        echo
        read -p "Select option (1-6): " location_choice
        echo
        
        case $location_choice in
            1)
                toggle_setting "LOCATION_ENABLED" "Location tracking"
                ;;
            2)
                select_location_method
                ;;
            3)
                if [ "$LOCATION_METHOD" = "corelocation_cli" ]; then
                    setup_location_cli
                else
                    setup_location_shortcut
                fi
                ;;
            4)
                toggle_setting "NETWORK_INFO_ENABLED" "Network information"
                # Reset network configured status when toggling
                if [ "$NETWORK_INFO_ENABLED" = "no" ]; then
                    NETWORK_CONFIGURED="no"
                fi
                ;;
            5)
                setup_network_info
                ;;
            6)
                return
                ;;
            *)
                echo -e "${ERROR}Invalid option. Please choose between 1 and 6.${NC}"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Add a new function for network info setup
setup_network_info() {
    show_header
    echo -e "${ACCENT}${BOLD}NETWORK INFORMATION SETUP${NC}"
    echo
    
    if [ "$NETWORK_INFO_ENABLED" != "yes" ]; then
        echo -e "${WARNING}Network information is currently disabled.${NC}"
        echo -e "${WARNING}Please enable Network Info first.${NC}"
        NETWORK_CONFIGURED="no"
        return
    fi
    
    echo -e "${SUCCESS}Testing network information collection...${NC}"
    
    # Test WiFi SSID detection
    local wifi_ssid="Not available"
    if command -v ipconfig >/dev/null 2>&1; then
        echo -e "Testing WiFi SSID detection..."
        local ssid_output=$(ipconfig getsummary en0 2>/dev/null | awk '/ SSID/ {print $NF}')
        if [ -n "$ssid_output" ]; then
            wifi_ssid="$ssid_output"
            echo -e "${SUCCESS}WiFi SSID detected: $wifi_ssid${NC}"
        else
            echo -e "${WARNING}Could not detect WiFi SSID${NC}"
        fi
    else
        echo -e "${ERROR}ipconfig command not available${NC}"
    fi
    
    # Test local IP detection
    local local_ip="Not available"
    if command -v ipconfig >/dev/null 2>&1; then
        echo -e "Testing local IP detection..."
        local ip_output=$(ipconfig getifaddr en0 2>/dev/null)
        if [ -n "$ip_output" ]; then
            local_ip="$ip_output"
            echo -e "${SUCCESS}Local IP detected: $local_ip${NC}"
        else
            echo -e "Trying alternate interface..."
            ip_output=$(ipconfig getifaddr en1 2>/dev/null)
            if [ -n "$ip_output" ]; then
                local_ip="$ip_output"
                echo -e "${SUCCESS}Local IP detected from en1: $local_ip${NC}"
            else
                echo -e "${WARNING}Could not detect local IP address${NC}"
            fi
        fi
    fi
    
    # Test public IP detection
    local public_ip="Not available"
    echo -e "Testing internet connectivity..."
    if ping -c 1 -W 3 api.resend.com > /dev/null 2>&1 || 
       curl -s --connect-timeout 3 -I https://api.resend.com >/dev/null 2>&1; then
        echo -e "${SUCCESS}Internet connection available${NC}"
        if command -v curl >/dev/null 2>&1; then
            echo -e "Testing public IP detection..."
            local public_ip_output=$(curl -s ipinfo.io/ip 2>/dev/null)
            if [ -n "$public_ip_output" ]; then
                public_ip="$public_ip_output"
                echo -e "${SUCCESS}Public IP detected: $public_ip${NC}"
            else
                echo -e "${WARNING}Could not detect public IP${NC}"
            fi
        else
            echo -e "${ERROR}curl command not available for public IP detection${NC}"
        fi
    else
        echo -e "${WARNING}No internet connection available${NC}"
    fi
    
    echo
    echo -e "${BOLD}Network Information Summary:${NC}"
    echo -e "WiFi SSID      : ${SUCCESS}$wifi_ssid${NC}"
    echo -e "Local IP       : ${SUCCESS}$local_ip${NC}"
    echo -e "Public IP      : ${SUCCESS}$public_ip${NC}"
    echo
    
    if [ "$wifi_ssid" != "Not available" ] || [ "$local_ip" != "Not available" ] || 
       [ "$public_ip" != "Not available" ]; then
        echo -e "${SUCCESS}Network information collection is working.${NC}"
        echo -e "${SUCCESS}Network info will be included in monitoring data.${NC}"
        NETWORK_CONFIGURED="yes"
    else
        echo -e "${ERROR}All network information tests failed.${NC}"
        echo -e "${WARNING}Please check your network connection and try again.${NC}"
        NETWORK_CONFIGURED="no"
    fi
}

select_location_method() {
    show_header
    echo -e "${ACCENT}${BOLD}SELECT LOCATION METHOD${NC}"
    echo
    echo -e "${BOLD}Choose how to obtain location information:${NC}"
    echo
    if [ "$LOCATION_METHOD" = "corelocation_cli" ]; then
        echo -e "  ${PRIMARY}[1]${NC} CoreLocationCLI ${SUCCESS}[Current]${NC}"
    else
        echo -e "  ${PRIMARY}[1]${NC} CoreLocationCLI"
    fi
    
    if [ "$LOCATION_METHOD" = "apple_shortcuts" ]; then
        echo -e "  ${PRIMARY}[2]${NC} Apple Shortcuts ${SUCCESS}[Current]${NC}"
    else
        echo -e "  ${PRIMARY}[2]${NC} Apple Shortcuts"
    fi
    
    echo -e "  ${PRIMARY}[3]${NC} Back to Location Settings"
    echo
    echo -e "${BOLD}Method Comparison:${NC}"
    echo -e "  CoreLocationCLI: Direct API access, requires one-time permission"
    echo -e "  Apple Shortcuts: More flexible, may be more reliable for some users"
    echo
    
    read -p "Select option (1-3): " method_choice
    echo
    
    case $method_choice in
        1)
            if [ "$LOCATION_METHOD" != "corelocation_cli" ]; then
                LOCATION_METHOD="corelocation_cli"
                LOCATION_CONFIGURED="no"
                echo -e "${SUCCESS}Location method set to CoreLocationCLI.${NC}"
                echo -e "${WARNING}Please set up CoreLocationCLI in the next step.${NC}"
            else
                echo -e "${WARNING}CoreLocationCLI already selected.${NC}"
            fi
            ;;
        2)
            if [ "$LOCATION_METHOD" != "apple_shortcuts" ]; then
                LOCATION_METHOD="apple_shortcuts"
                LOCATION_CONFIGURED="no"
                echo -e "${SUCCESS}Location method set to Apple Shortcuts.${NC}"
                echo -e "${WARNING}Please set up Apple Shortcuts in the next step.${NC}"
            else
                echo -e "${WARNING}Apple Shortcuts already selected.${NC}"
            fi
            ;;
        3)
            return
            ;;
        *)
            echo -e "${ERROR}Invalid option. Please choose between 1 and 3.${NC}"
            ;;
    esac
}

setup_location_cli() {
    echo -e "${ACCENT}${BOLD}CORE LOCATION CLI SETUP${NC}"
    echo
    
    # Check if CoreLocationCLI is installed
    if ! command -v CoreLocationCLI &> /dev/null; then
        echo -e "${ERROR}CoreLocationCLI is not installed.${NC}"
        echo
        echo -e "${WARNING}To install CoreLocationCLI, you need to:${NC}"
        echo -e "1. Download the tool from GitHub: https://github.com/fulldecent/corelocationcli"
        echo -e "2. Or install using Homebrew with: brew install corelocationcli"
        echo
        LOCATION_CONFIGURED="no"
        read -p "Press Enter when you've installed CoreLocationCLI to continue..."
        if ! command -v CoreLocationCLI &> /dev/null; then
            echo -e "${ERROR}CoreLocationCLI still not found. Please try again later.${NC}"
            return
        fi
    fi
    
    # Check if jq is installed (needed to parse JSON output)
    if ! command -v jq &> /dev/null; then
        echo -e "${ERROR}The 'jq' command is not installed, but is required to parse location data.${NC}"
        echo -e "${WARNING}To install jq, use: brew install jq${NC}"
        echo
        LOCATION_CONFIGURED="no"
        read -p "Press Enter when you've installed jq to continue..."
        if ! command -v jq &> /dev/null; then
            echo -e "${ERROR}jq still not found. Please try again later.${NC}"
            return
        fi
    fi
    
    # Test CoreLocationCLI
    echo -e "${WARNING}Testing CoreLocationCLI...${NC}"
    echo -e "${WARNING}When prompted, grant location access permissions.${NC}"
    
    # Temporary files
    TEMP_OUTPUT=$(mktemp)
    TEMP_ERROR=$(mktemp)
    WRAPPER_SCRIPT=$(mktemp)
    
    # Create a temporary wrapper script that handles everything
    cat > "$WRAPPER_SCRIPT" << 'EOF'
#!/bin/bash
# First check if CoreLocationCLI is allowed by security
CoreLocationCLI --version >/dev/null 2>&1
STATUS=$?

# Exit with code 200 if the binary is killed by security (Gatekeeper)
if [ $STATUS -gt 128 ]; then
    exit 200
fi

# Try the actual command now
CoreLocationCLI --json
exit $?
EOF
    
    # Make the wrapper script executable
    chmod +x "$WRAPPER_SCRIPT"
    
    # Run the wrapper script in the background with our own timeout implementation
    "$WRAPPER_SCRIPT" > "$TEMP_OUTPUT" 2> "$TEMP_ERROR" &
    CLI_PID=$!
    
    # Set timeout
    TIMEOUT_SECONDS=20
    end=$((SECONDS+TIMEOUT_SECONDS))
    
    # Wait for completion or timeout
    CLI_EXIT_CODE=0
    CLI_TIMED_OUT=0
    
    while [ $SECONDS -lt $end ]; do
        if ! kill -0 $CLI_PID 2>/dev/null; then
            # Process completed
            wait $CLI_PID
            CLI_EXIT_CODE=$?
            break
        fi
        sleep 0.5
    done
    
    # Check if we need to kill due to timeout
    if kill -0 $CLI_PID 2>/dev/null; then
        kill $CLI_PID 2>/dev/null || true
        CLI_TIMED_OUT=1
        CLI_EXIT_CODE=124  # Simulate timeout exit code
    fi
    
    # Read the output and error
    CLI_OUTPUT=$(cat "$TEMP_OUTPUT")
    CLI_ERROR=$(cat "$TEMP_ERROR")
    
    # Process the results
    if [ $CLI_EXIT_CODE -eq 200 ]; then
        # Gatekeeper blocked
        echo -e "${ERROR}CoreLocationCLI was blocked by macOS security (Gatekeeper).${NC}"
        echo -e "${WARNING}Please follow these steps:${NC}"
        echo -e "1. Open System Settings → Privacy & Security"
        echo -e "2. Scroll down to the Security section"
        echo -e "3. Look for 'CoreLocationCLI was blocked' message"
        echo -e "4. Click 'Open Anyway' and authenticate with your password"
        echo -e "5. When prompted again, click 'Open'"
        echo
        echo -e "${WARNING}Opening Privacy & Security settings now...${NC}"
        open "x-apple.systempreferences:com.apple.preference.security"
        echo
        echo -e "${WARNING}After approving CoreLocationCLI, return here and run this setup again.${NC}"
        LOCATION_CONFIGURED="no"
    
    elif [[ "$CLI_OUTPUT" == *"kCLErrorDomain error 0"* ]] || [[ "$CLI_ERROR" == *"kCLErrorDomain error 0"* ]]; then
        echo -e "${ERROR}CoreLocationCLI encountered a network or location service error.${NC}"
        echo -e "${WARNING}This is often caused by network connectivity issues. Please try:${NC}"
        echo -e "1. Checking your internet connection"
        echo -e "2. Connecting to a different network if possible"
        echo -e "3. Restarting your Mac's network services (turn Wi-Fi off and on)"
        echo -e "4. Trying again in a few minutes"
        LOCATION_CONFIGURED="no"
        
    elif [[ "$CLI_OUTPUT" == *"Location services are disabled"* ]] || [[ "$CLI_ERROR" == *"Location services are disabled"* ]]; then
        echo -e "${ERROR}Location Services are disabled or access was denied for CoreLocationCLI.${NC}"
        echo -e "${WARNING}Please enable Location Services and grant access:${NC}"
        echo -e "1. Open System Settings → Privacy & Security → Location Services"
        echo -e "2. Ensure Location Services is turned ON"
        echo -e "3. Find CoreLocationCLI in the list and check the box next to it"
        echo -e "4. Return to this setup when complete"
        echo
        echo -e "${WARNING}Opening Location Services settings now...${NC}"
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
        LOCATION_CONFIGURED="no"
        
    elif [ $CLI_TIMED_OUT -eq 1 ]; then
        echo -e "${ERROR}CoreLocationCLI timed out. Location request might be pending approval.${NC}"
        echo -e "${WARNING}Please try running 'CoreLocationCLI' manually from Terminal${NC}"
        echo -e "${WARNING}and ensure you grant the location permission when prompted.${NC}"
        LOCATION_CONFIGURED="no"
        
    elif [ $CLI_EXIT_CODE -ne 0 ]; then
        echo -e "${ERROR}CoreLocationCLI failed with code $CLI_EXIT_CODE.${NC}"
        if [ -n "$CLI_OUTPUT" ]; then
            echo -e "${ERROR}Output: $CLI_OUTPUT${NC}"
        fi
        if [ -n "$CLI_ERROR" ]; then
            echo -e "${ERROR}Error: $CLI_ERROR${NC}"
        fi
        LOCATION_CONFIGURED="no"
        
    else
        # Try to parse the JSON output to verify it contains valid location data
        if echo "$CLI_OUTPUT" | jq -e '.latitude' &>/dev/null; then
            LAT=$(echo "$CLI_OUTPUT" | jq -r '.latitude')
            LON=$(echo "$CLI_OUTPUT" | jq -r '.longitude')
            LOCATION_CONFIGURED="yes"
            echo -e "${SUCCESS}CoreLocationCLI test successful!${NC}"
            echo -e "${SUCCESS}Current coordinates: $LAT, $LON${NC}"
        else
            echo -e "${ERROR}CoreLocationCLI returned invalid output:${NC}"
            echo "$CLI_OUTPUT"
            if [ -n "$CLI_ERROR" ]; then
                echo -e "${ERROR}Error output:${NC}"
                echo "$CLI_ERROR"
            fi
            LOCATION_CONFIGURED="no"
        fi
    fi
    
    # Clean up
    rm -f "$TEMP_OUTPUT" "$TEMP_ERROR" "$WRAPPER_SCRIPT"
    
    if [ "$LOCATION_CONFIGURED" = "yes" ]; then
        echo -e "${SUCCESS}Location tracking via CoreLocationCLI is now configured.${NC}"
        echo -e "${SUCCESS}Using location data from $CURRENT_USER at $(date -u '+%Y-%m-%d %H:%M:%S')${NC}"
    else
        echo -e "${ERROR}Location tracking setup failed. Please try again.${NC}"
        
        # If no specific error was handled above, provide general guidance
        if [[ "$CLI_OUTPUT" != *"kCLErrorDomain"* ]] && 
           [[ "$CLI_OUTPUT" != *"Location services are disabled"* ]] && 
           [[ "$CLI_ERROR" != *"Location services are disabled"* ]] && 
           [ $CLI_TIMED_OUT -ne 1 ] && [ $CLI_EXIT_CODE -ne 200 ]; then
            echo
            echo -e "${WARNING}To manually enable location permissions:${NC}"
            echo -e "1. Open System Settings → Privacy & Security → Privacy → Location Services"
            echo -e "2. Ensure Location Services is turned ON"
            echo -e "3. Find CoreLocationCLI or Terminal in the list and check the box next to it"
            echo
            open "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
        fi
    fi
}

setup_location_shortcut() {
    echo -e "${ACCENT}${BOLD}LOCATION SHORTCUTS SETUP${NC}"
    echo -e "To set up your Location shortcut, visit (or) hold command button and double click on the link below:"
    echo -e "${PRIMARY}https://www.icloud.com/shortcuts/15afe8819d4a40a8bb7fb56a57005d0b${NC}"
    echo
    echo "After adding the shortcut, press any key to continue..."
    echo "if prompted, select 'Allow' to grant location access."
    read -n1 -s
    echo
    
    TEMP_OUTPUT=$(mktemp)
    
    echo -e "${WARNING}Testing the shortcut with: shortcuts run \"Location\"${NC}"
    
    shortcuts run "Location" > "$TEMP_OUTPUT" 2>&1
    SHORTCUT_EXIT_CODE=$?
    SHORTCUT_OUTPUT=$(cat "$TEMP_OUTPUT")
    
    echo "$SHORTCUT_OUTPUT"
    
    if [[ "$SHORTCUT_OUTPUT" =~ "Shortcuts does not have access to your location" ]]; then
        LOCATION_CONFIGURED="no"
        echo -e "${ERROR}Location services not enabled for Shortcuts.${NC}"
        echo -e "${WARNING}Opening System Preferences. Please enable location services for Shortcuts.${NC}"
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
        echo -e "${WARNING}After enabling location services, please run this option again.${NC}"
    elif [[ "$SHORTCUT_OUTPUT" =~ "This shortcut can't access \"Location\"" ]]; then
        LOCATION_CONFIGURED="no"
        echo -e "${ERROR}This shortcut needs permission to access your location.${NC}"
        echo -e "${WARNING}Please run the shortcut manually and select 'Allow' when prompted.${NC}"
        echo -e "${WARNING}After granting permission, run this option again.${NC}"
    # NEW CONDITION: Check for JSON output with latitude/longitude
    elif [[ $SHORTCUT_EXIT_CODE -eq 0 && ("$SHORTCUT_OUTPUT" =~ \"latitude\":\"[0-9]+\.[0-9]+ && "$SHORTCUT_OUTPUT" =~ \"longitude\":\"[0-9]+\.[0-9]+) ]]; then
        LOCATION_CONFIGURED="yes"
        echo -e "${SUCCESS}Location shortcut test successful.${NC}"
    # Original conditions for raw coordinates or maps.apple.com URL
    elif [[ $SHORTCUT_EXIT_CODE -eq 0 && ("$SHORTCUT_OUTPUT" =~ [0-9]+\.[0-9]+,[0-9]+\.[0-9]+ || "$SHORTCUT_OUTPUT" =~ maps\.apple\.com) ]]; then
        LOCATION_CONFIGURED="yes"
        echo -e "${SUCCESS}Location shortcut test successful.${NC}"
    else
        LOCATION_CONFIGURED="no"
        echo -e "${ERROR}Location shortcut test failed.${NC}"
        if [[ "$SHORTCUT_OUTPUT" == "" ]]; then
            echo -e "${ERROR}No output from shortcut - might not exist or was cancelled.${NC}"
        fi
    fi
    
    rm -f "$TEMP_OUTPUT"
}
configure_path() {
    show_header
    echo -e "${ACCENT}${BOLD}STORAGE PATH CONFIGURATION${NC}"
    echo 
    echo "Note:"
    echo -e "1.If there is a dot(.) before file-name like .filename then it will be hidden in MacOS."
    echo -e "2.So to view that you have to press (${ACCENT}command + shift + .${NC} )."
    echo
    echo -e "Current path: ${SUCCESS}$BASE_DIR${NC}"
    echo
    
    read -p "Enter new path (or press Enter to keep current): " new_base_dir
    if [ -n "$new_base_dir" ]; then
        BASE_DIR="$new_base_dir"
        echo -e "${SUCCESS}Path updated to: $BASE_DIR${NC}"
    else
        echo -e "${WARNING}Path unchanged.${NC}"
    fi
}

configure_timing() {
    while true; do
        show_header
        echo -e "${ACCENT}${BOLD}TIMING CONFIGURATION${NC}"
        echo
        echo -e "  ${PRIMARY}[1]${NC} Initial Delay  : ${SUCCESS}$INITIAL_DELAY seconds${NC}"
        echo -e "  ${PRIMARY}[2]${NC} Follow-up Delay: ${SUCCESS}$FOLLOWUP_DELAY seconds${NC}"
        echo -e "  ${PRIMARY}[3]${NC} Back to Main Menu"
        echo
        read -p "Select option (1-3): " timing_choice
        echo
        
        case $timing_choice in
            1)
                read -p "Enter initial delay in seconds: " new_delay
                if [[ $new_delay =~ ^[0-9]+$ ]]; then
                    INITIAL_DELAY="$new_delay"
                    echo -e "${SUCCESS}Initial delay updated to $INITIAL_DELAY seconds${NC}"
                else
                    echo -e "${ERROR}Invalid input. Must be a number.${NC}"
                fi
                ;;
            2)
                read -p "Enter follow-up delay in seconds: " new_delay
                if [[ $new_delay =~ ^[0-9]+$ ]]; then
                    FOLLOWUP_DELAY="$new_delay"
                    echo -e "${SUCCESS}Follow-up delay updated to $FOLLOWUP_DELAY seconds${NC}"
                else
                    echo -e "${ERROR}Invalid input. Must be a number.${NC}"
                fi
                ;;
            3)
                return
                ;;
            *)
                echo -e "${ERROR}Invalid option. Please choose between 1 and 3.${NC}"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

configure_media() {
    while true; do
        show_header
        echo -e "${ACCENT}${BOLD}MEDIA CAPTURE CONFIGURATION${NC}"
        echo
        
        if [ "$WEBCAM_ENABLED" = "yes" ]; then
            echo -e "  ${PRIMARY}[1]${NC} Webcam Photos : ${SUCCESS}Enabled${NC}"
        else
            echo -e "  ${PRIMARY}[1]${NC} Webcam Photos : ${WARNING}Disabled${NC}"
        fi
        
        if [ "$SCREENSHOT_ENABLED" = "yes" ]; then
            echo -e "  ${PRIMARY}[2]${NC} Screenshots   : ${SUCCESS}Enabled${NC}"
        else
            echo -e "  ${PRIMARY}[2]${NC} Screenshots   : ${WARNING}Disabled${NC}"
        fi
        
        # Add followup screenshot toggle
        if [ "$FOLLOWUP_SCREENSHOT_ENABLED" = "yes" ]; then
            echo -e "  ${PRIMARY}[3]${NC} Follow-up Screenshots : ${SUCCESS}Enabled${NC}"
        else
            echo -e "  ${PRIMARY}[3]${NC} Follow-up Screenshots : ${WARNING}Disabled${NC}"
        fi
        
        echo -e "  ${PRIMARY}[4]${NC} Back to Main Menu"
        echo
        read -p "Select option (1-4): " media_choice
        echo
        
        case $media_choice in
            1)
                toggle_setting "WEBCAM_ENABLED" "Webcam photo capture"
                ;;
            2)
                toggle_setting "SCREENSHOT_ENABLED" "Screenshot capture"
                ;;
            3)
                toggle_setting "FOLLOWUP_SCREENSHOT_ENABLED" "Follow-up screenshot capture"
                ;;
            4)
                return
                ;;
            *)
                echo -e "${ERROR}Invalid option. Please choose between 1 and 4.${NC}"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

configure_email_active_days() {
    local all_days=("Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday" "Sunday")
    local selected_days=()
    
    IFS=',' read -ra selected_days <<< "$EMAIL_ACTIVE_DAYS"
    
    while true; do
        show_header
        echo -e "${ACCENT}${BOLD}EMAIL ACTIVE DAYS CONFIGURATION${NC}"
        echo
        echo -e "${BOLD}Select which days to send email notifications:${NC}"
        echo
        
        for i in "${!all_days[@]}"; do
            day=${all_days[$i]}
            if [[ " ${selected_days[*]} " =~ " ${day} " ]]; then
                echo -e "  ${PRIMARY}[$((i+1))]${NC} ${SUCCESS}[✓] $day${NC}"
            else
                echo -e "  ${PRIMARY}[$((i+1))]${NC} ${WARNING}[ ] $day${NC}"
            fi
        done
        
        echo -e "  ${PRIMARY}[8]${NC} Toggle Weekdays (Mon-Fri)"
        echo -e "  ${PRIMARY}[9]${NC} Toggle Weekend (Sat-Sun)"
        echo -e "  ${PRIMARY}[0]${NC} Save and Return"
        echo
        
        read -p "Select day to toggle (0-9): " day_choice
        echo
        
        case $day_choice in
            [1-7])
                day_index=$((day_choice-1))
                day=${all_days[$day_index]}
                
                if [[ " ${selected_days[*]} " =~ " ${day} " ]]; then
                    for i in "${!selected_days[@]}"; do
                        if [ "${selected_days[$i]}" = "$day" ]; then
                            unset 'selected_days[$i]'
                            break
                        fi
                    done
                    echo -e "${WARNING}$day removed from email schedule.${NC}"
                else
                    selected_days+=("$day")
                    echo -e "${SUCCESS}$day added to email schedule.${NC}"
                fi
                ;;
            8)
                local weekdays=("Monday" "Tuesday" "Wednesday" "Thursday" "Friday")
                local all_weekdays_selected=true
                for weekday in "${weekdays[@]}"; do
                    if [[ ! " ${selected_days[*]} " =~ " ${weekday} " ]]; then
                        all_weekdays_selected=false
                        break
                    fi
                done
                
                if [ "$all_weekdays_selected" = true ]; then
                    for weekday in "${weekdays[@]}"; do
                        for i in "${!selected_days[@]}"; do
                            if [ "${selected_days[$i]}" = "$weekday" ]; then
                                unset 'selected_days[$i]'
                                break
                            fi
                        done
                    done
                    echo -e "${WARNING}All weekdays removed from email schedule.${NC}"
                else
                    for weekday in "${weekdays[@]}"; do
                        if [[ ! " ${selected_days[*]} " =~ " ${weekday} " ]]; then
                            selected_days+=("$weekday")
                        fi
                    done
                    echo -e "${SUCCESS}All weekdays added to email schedule.${NC}"
                fi
                ;;
            9)
                local weekend=("Saturday" "Sunday")
                local all_weekend_selected=true
                for weekend_day in "${weekend[@]}"; do
                    if [[ ! " ${selected_days[*]} " =~ " ${weekend_day} " ]]; then
                        all_weekend_selected=false
                        break
                    fi
                done
                
                if [ "$all_weekend_selected" = true ]; then
                    for weekend_day in "${weekend[@]}"; do
                        for i in "${!selected_days[@]}"; do
                            if [ "${selected_days[$i]}" = "$weekend_day" ]; then
                                unset 'selected_days[$i]'
                                break
                            fi
                        done
                    done
                    echo -e "${WARNING}Weekend days removed from email schedule.${NC}"
                else
                    for weekend_day in "${weekend[@]}"; do
                        if [[ ! " ${selected_days[*]} " =~ " ${weekend_day} " ]]; then
                            selected_days+=("$weekend_day")
                        fi
                    done
                    echo -e "${SUCCESS}Weekend days added to email schedule.${NC}"
                fi
                ;;
            0)
                EMAIL_ACTIVE_DAYS=$(IFS=,; echo "${selected_days[*]}")
                if [ -z "$EMAIL_ACTIVE_DAYS" ]; then
                    echo -e "${ERROR}Error: At least one day must be selected.${NC}"
                    echo -e "${WARNING}Setting to default (all days).${NC}"
                    EMAIL_ACTIVE_DAYS="Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday"
                    read -p "Press Enter to continue..."
                fi
                return
                ;;
            *)
                echo -e "${ERROR}Invalid option. Please choose between 0 and 9.${NC}"
                ;;
        esac
        
        sleep 1
    done
}

# New function for configuring active time windows for schedule
configure_schedule_time_windows() {
    while true; do
        show_header
        echo -e "${ACCENT}${BOLD}SCHEDULE ACTIVE TIME WINDOWS CONFIGURATION${NC}"
        echo
        echo -e "${BOLD}Current Active Windows:${NC}"
        
        IFS=',' read -ra WINDOWS <<< "$SCHEDULE_ACTIVE_WINDOWS"
        if [ ${#WINDOWS[@]} -eq 0 ]; then
            echo -e "  ${WARNING}No active windows configured.${NC}"
        else
            for i in "${!WINDOWS[@]}"; do
                echo -e "  ${PRIMARY}[$((i+1))]${NC} ${SUCCESS}[${WINDOWS[$i]}]${NC}"
            done
        fi
        echo
        echo -e "${BOLD}Options:${NC}"
        echo -e "  ${PRIMARY}[1]${NC} Add new time window"
        if [ ${#WINDOWS[@]} -gt 0 ]; then
            echo -e "  ${PRIMARY}[2]${NC} Edit existing time window"
            echo -e "  ${PRIMARY}[3]${NC} Delete time window"
        fi
        echo -e "  ${PRIMARY}[4]${NC} Back to Schedule Settings"
        echo
        echo -e "${WARNING}Note: Time windows must be in 12-hour format (e.g., 8:00AM-12:00PM)${NC}"
        echo
        read -p "Select an option: " sched_window_choice
        echo
        
        case $sched_window_choice in
            1)
                add_schedule_time_window
                ;;
            2)
                if [ ${#WINDOWS[@]} -gt 0 ]; then
                    edit_schedule_time_window
                else
                    echo -e "${ERROR}No time windows to edit.${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            3)
                if [ ${#WINDOWS[@]} -gt 0 ]; then
                    delete_schedule_time_window
                else
                    echo -e "${ERROR}No time windows to delete.${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            4)
                return
                ;;
            *)
                echo -e "${ERROR}Invalid option.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

add_schedule_time_window() {
    echo -e "${BOLD}Add New Schedule Time Window${NC}"
    echo -e "${WARNING}Format: HH:MMAM-HH:MMPM (12-hour format with AM/PM)${NC}"
    echo -e "${WARNING}Examples: 8:00AM-12:00PM, 1:30PM-5:45PM${NC}"
    echo
    
    while true; do
        read -p "Enter schedule time window: " new_window
        
        if [ -z "$new_window" ]; then
            echo -e "${WARNING}Operation cancelled.${NC}"
            return
        fi
        
        if validate_time_format "$new_window"; then
            if [ -z "$SCHEDULE_ACTIVE_WINDOWS" ]; then
                SCHEDULE_ACTIVE_WINDOWS="$new_window"
            else
                SCHEDULE_ACTIVE_WINDOWS="$SCHEDULE_ACTIVE_WINDOWS,$new_window"
            fi
            echo -e "${SUCCESS}Schedule time window added successfully.${NC}"
            break
        else
            echo -e "${ERROR}Invalid format. Please use the format HH:MMAM-HH:MMPM${NC}"
            echo -e "${ERROR}Examples: 8:00AM-12:00PM, 1:30PM-5:45PM${NC}"
        fi
    done
    
    read -p "Press Enter to continue..."
}

edit_schedule_time_window() {
    echo -e "${BOLD}Edit Schedule Time Window${NC}"
    IFS=',' read -ra WINDOWS <<< "$SCHEDULE_ACTIVE_WINDOWS"
    
    for i in "${!WINDOWS[@]}"; do
        echo -e "  ${PRIMARY}[$((i+1))]${NC} [${WINDOWS[$i]}]"
    done
    echo
    
    read -p "Select a window to edit (1-${#WINDOWS[@]}): " window_index
    
    if ! [[ "$window_index" =~ ^[0-9]+$ ]] || [ "$window_index" -lt 1 ] || [ "$window_index" -gt ${#WINDOWS[@]} ]; then
        echo -e "${ERROR}Invalid selection.${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    index=$((window_index-1))
    echo -e "Editing: ${SUCCESS}[${WINDOWS[$index]}]${NC}"
    echo -e "${WARNING}Format: HH:MMAM-HH:MMPM (12-hour format with AM/PM)${NC}"
    echo -e "${WARNING}Examples: 8:00AM-12:00PM, 1:30PM-5:45PM${NC}"
    echo
    
    while true; do
        read -p "Enter new schedule time window: " edited_window
        
        if [ -z "$edited_window" ]; then
            echo -e "${WARNING}Edit cancelled.${NC}"
            read -p "Press Enter to continue..."
            return
        fi
        
        if validate_time_format "$edited_window"; then
            WINDOWS[$index]="$edited_window"
            SCHEDULE_ACTIVE_WINDOWS=$(IFS=,; echo "${WINDOWS[*]}")
            echo -e "${SUCCESS}Schedule time window updated successfully.${NC}"
            break
        else
            echo -e "${ERROR}Invalid format. Please use the format HH:MMAM-HH:MMPM${NC}"
            echo -e "${ERROR}Examples: 8:00AM-12:00PM, 1:30PM-5:45PM${NC}"
        fi
    done
    
    read -p "Press Enter to continue..."
}

delete_schedule_time_window() {
    echo -e "${BOLD}Delete Schedule Time Window${NC}"
    IFS=',' read -ra WINDOWS <<< "$SCHEDULE_ACTIVE_WINDOWS"
    
    for i in "${!WINDOWS[@]}"; do
        echo -e "  ${PRIMARY}[$((i+1))]${NC} [${WINDOWS[$i]}]"
    done
    echo
    
    read -p "Select a window to delete (1-${#WINDOWS[@]}): " window_index
    
    if ! [[ "$window_index" =~ ^[0-9]+$ ]] || [ "$window_index" -lt 1 ] || [ "$window_index" -gt ${#WINDOWS[@]} ]; then
        echo -e "${ERROR}Invalid selection.${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    index=$((window_index-1))
    echo -e "Are you sure you want to delete: ${WARNING}[${WINDOWS[$index]}]${NC}?"
    read -p "Confirm deletion (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        unset 'WINDOWS[$index]'
        SCHEDULE_ACTIVE_WINDOWS=$(IFS=,; echo "${WINDOWS[*]}")
        echo -e "${SUCCESS}Schedule time window deleted successfully.${NC}"
    else
        echo -e "${WARNING}Deletion cancelled.${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

configure_schedule() {
    while true; do
        show_header
        echo -e "${ACCENT}${BOLD}MONITORING SCHEDULE CONFIGURATION${NC}"
        echo
        
        if [ "$CUSTOM_SCHEDULE_ENABLED" = "yes" ]; then
            echo -e "  ${PRIMARY}[1]${NC} Custom Schedule : ${SUCCESS}Enabled${NC}"
        else
            echo -e "  ${PRIMARY}[1]${NC} Custom Schedule : ${WARNING}Disabled (Monitoring Every Day)${NC}"
        fi
        
        echo -e "  ${PRIMARY}[2]${NC} Configure Active Days"
        echo -e "  ${PRIMARY}[3]${NC} Configure Active Windows"
        echo -e "  ${PRIMARY}[4]${NC} Back to Main Menu"
        echo
        echo -e "  Current Active Days   : ${SUCCESS}$ACTIVE_DAYS${NC}"
        formatted_schedule_windows=$(format_time_windows "$SCHEDULE_ACTIVE_WINDOWS")
        if [ -n "$formatted_schedule_windows" ]; then
            echo -e "  Current Active Windows: ${SUCCESS}$formatted_schedule_windows${NC}"
        else
            echo -e "  Current Active Windows: ${WARNING}None configured${NC}"
        fi
        echo
        read -p "Select option (1-4): " schedule_choice
        echo
        
        case $schedule_choice in
            1)
                toggle_setting "CUSTOM_SCHEDULE_ENABLED" "Custom schedule"
                ;;
            2)
                configure_active_days
                ;;
            3)
                configure_schedule_time_windows
                ;;
            4)
                return
                ;;
            *)
                echo -e "${ERROR}Invalid option. Please choose between 1 and 4.${NC}"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

configure_active_days() {
    local all_days=("Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday" "Sunday")
    local selected_days=()
    
    IFS=',' read -ra selected_days <<< "$ACTIVE_DAYS"
    
    while true; do
        show_header
        echo -e "${ACCENT}${BOLD}ACTIVE DAYS CONFIGURATION${NC}"
        echo
        echo -e "${BOLD}Select which days to enable monitoring:${NC}"
        echo
        
        for i in "${!all_days[@]}"; do
            day=${all_days[$i]}
            if [[ " ${selected_days[*]} " =~ " ${day} " ]]; then
                echo -e "  ${PRIMARY}[$((i+1))]${NC} ${SUCCESS}[✓] $day${NC}"
            else
                echo -e "  ${PRIMARY}[$((i+1))]${NC} ${WARNING}[ ] $day${NC}"
            fi
        done
        
        echo -e "  ${PRIMARY}[8]${NC} Toggle Weekdays (Mon-Fri)"
        echo -e "  ${PRIMARY}[9]${NC} Toggle Weekend (Sat-Sun)"
        echo -e "  ${PRIMARY}[0]${NC} Save and Return"
        echo
        
        read -p "Select day to toggle (0-9): " day_choice
        echo
        
        case $day_choice in
            [1-7])
                day_index=$((day_choice-1))
                day=${all_days[$day_index]}
                
                if [[ " ${selected_days[*]} " =~ " ${day} " ]]; then
                    for i in "${!selected_days[@]}"; do
                        if [ "${selected_days[$i]}" = "$day" ]; then
                            unset 'selected_days[$i]'
                            break
                        fi
                    done
                    echo -e "${WARNING}$day removed from monitoring schedule.${NC}"
                else
                    selected_days+=("$day")
                    echo -e "${SUCCESS}$day added to monitoring schedule.${NC}"
                fi
                ;;
            8)
                local weekdays=("Monday" "Tuesday" "Wednesday" "Thursday" "Friday")
                local all_weekdays_selected=true
                for weekday in "${weekdays[@]}"; do
                    if [[ ! " ${selected_days[*]} " =~ " ${weekday} " ]]; then
                        all_weekdays_selected=false
                        break
                    fi
                done
                
                if [ "$all_weekdays_selected" = true ]; then
                    for weekday in "${weekdays[@]}"; do
                        for i in "${!selected_days[@]}"; do
                            if [ "${selected_days[$i]}" = "$weekday" ]; then
                                unset 'selected_days[$i]'
                                break
                            fi
                        done
                    done
                    echo -e "${WARNING}All weekdays removed from monitoring schedule.${NC}"
                else
                    for weekday in "${weekdays[@]}"; do
                        if [[ ! " ${selected_days[*]} " =~ " ${weekday} " ]]; then
                            selected_days+=("$weekday")
                        fi
                    done
                    echo -e "${SUCCESS}All weekdays added to monitoring schedule.${NC}"
                fi
                ;;
            9)
                local weekend=("Saturday" "Sunday")
                local all_weekend_selected=true
                for weekend_day in "${weekend[@]}"; do
                    if [[ ! " ${selected_days[*]} " =~ " ${weekend_day} " ]]; then
                        all_weekend_selected=false
                        break
                    fi
                done
                
                if [ "$all_weekend_selected" = true ]; then
                    for weekend_day in "${weekend[@]}"; do
                        for i in "${!selected_days[@]}"; do
                            if [ "${selected_days[$i]}" = "$weekend_day" ]; then
                                unset 'selected_days[$i]'
                                break
                            fi
                        done
                    done
                    echo -e "${WARNING}Weekend days removed from monitoring schedule.${NC}"
                else
                    for weekend_day in "${weekend[@]}"; do
                        if [[ ! " ${selected_days[*]} " =~ " ${weekend_day} " ]]; then
                            selected_days+=("$weekend_day")
                        fi
                    done
                    echo -e "${SUCCESS}Weekend days added to monitoring schedule.${NC}"
                fi
                ;;
            0)
                ACTIVE_DAYS=$(IFS=,; echo "${selected_days[*]}")
                if [ -z "$ACTIVE_DAYS" ]; then
                    echo -e "${ERROR}Error: At least one day must be selected.${NC}"
                    echo -e "${WARNING}Setting to default (all days).${NC}"
                    ACTIVE_DAYS="Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday"
                    read -p "Press Enter to continue..."
                fi
                return
                ;;
            *)
                echo -e "${ERROR}Invalid option. Please choose between 0 and 9.${NC}"
                ;;
        esac
        
        sleep 1
    done
}

# Add new function to configure auto-deletion
configure_auto_delete() {
    while true; do
        show_header
        echo -e "${ACCENT}${BOLD}AUTO-DELETE CONFIGURATION${NC}"
        echo
        
        if [ "$AUTO_DELETE_ENABLED" = "yes" ]; then
            echo -e "  ${PRIMARY}[1]${NC} Auto-Delete Status     : ${SUCCESS}Enabled${NC}"
        else
            echo -e "  ${PRIMARY}[1]${NC} Auto-Delete Status     : ${WARNING}Disabled${NC}"
        fi
        
        echo -e "  ${PRIMARY}[2]${NC} Delete Files Older Than: ${SUCCESS}$AUTO_DELETE_DAYS days${NC}"
        echo -e "  ${PRIMARY}[3]${NC} Back to Main Menu"
        echo
        read -p "Select option (1-3): " auto_delete_choice
        echo
        
        case $auto_delete_choice in
            1)
                toggle_setting "AUTO_DELETE_ENABLED" "Auto-deletion of files"
                ;;
            2)
                read -p "Enter number of days to keep files (1-365): " new_days
                if [[ $new_days =~ ^[0-9]+$ ]] && [ "$new_days" -ge 1 ] && [ "$new_days" -le 365 ]; then
                    AUTO_DELETE_DAYS="$new_days"
                    echo -e "${SUCCESS}Files will be kept for $AUTO_DELETE_DAYS days before deletion.${NC}"
                else
                    echo -e "${ERROR}Invalid input. Please enter a number between 1 and 365.${NC}"
                fi
                ;;
            3)
                return
                ;;
            *)
                echo -e "${ERROR}Invalid option. Please choose between 1 and 3.${NC}"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

save_configuration() {
    # Use the current date and user information in the configuration file header
    cat > "$CONFIG_FILE" << EOL
# Monitor Configuration
# Last updated: 2025-05-14 16:09:35 UTC
# Updated by: ${CURRENT_USER}

EMAIL_FROM="$EMAIL_FROM"
EMAIL_TO="$EMAIL_TO"
RESEND_API_KEY="$RESEND_API_KEY"
EMAIL_ENABLED="$EMAIL_ENABLED"
INITIAL_EMAIL_ENABLED="$INITIAL_EMAIL_ENABLED"
FOLLOWUP_EMAIL_ENABLED="$FOLLOWUP_EMAIL_ENABLED"
EMAIL_TIME_RESTRICTION_ENABLED="$EMAIL_TIME_RESTRICTION_ENABLED"
EMAIL_ACTIVE_WINDOWS="$EMAIL_ACTIVE_WINDOWS"
EMAIL_DAY_RESTRICTION_ENABLED="$EMAIL_DAY_RESTRICTION_ENABLED"
EMAIL_ACTIVE_DAYS="$EMAIL_ACTIVE_DAYS"
INITIAL_DELAY=$INITIAL_DELAY
FOLLOWUP_DELAY=$FOLLOWUP_DELAY
BASE_DIR="$BASE_DIR"
LOCATION_ENABLED="$LOCATION_ENABLED"
LOCATION_METHOD="$LOCATION_METHOD"
LOCATION_CONFIGURED="$LOCATION_CONFIGURED"
NETWORK_INFO_ENABLED="$NETWORK_INFO_ENABLED"
NETWORK_CONFIGURED="$NETWORK_CONFIGURED"
WEBCAM_ENABLED="$WEBCAM_ENABLED"
SCREENSHOT_ENABLED="$SCREENSHOT_ENABLED"
FOLLOWUP_SCREENSHOT_ENABLED="$FOLLOWUP_SCREENSHOT_ENABLED"
CUSTOM_SCHEDULE_ENABLED="$CUSTOM_SCHEDULE_ENABLED"
ACTIVE_DAYS="$ACTIVE_DAYS"
SCHEDULE_ACTIVE_WINDOWS="$SCHEDULE_ACTIVE_WINDOWS"
AUTO_DELETE_ENABLED="$AUTO_DELETE_ENABLED"
AUTO_DELETE_DAYS=$AUTO_DELETE_DAYS
EOL
    echo -e "${SUCCESS}Saving configuration to $CONFIG_FILE${NC}"
}

#=================================================================
# MAIN MENU
#=================================================================

display_menu() {
    show_header
    display_summary
    echo -e "${BOLD}Select an option:${NC}"
    echo
    echo -e "  ${PRIMARY}[1]${NC} Email Settings"
    echo -e "  ${PRIMARY}[2]${NC} Location & Network Settings"
    echo -e "  ${PRIMARY}[3]${NC} Media Capture Settings"
    echo -e "  ${PRIMARY}[4]${NC} Custom Schedule"
    echo -e "  ${PRIMARY}[5]${NC} Storage Path"
    echo -e "  ${PRIMARY}[6]${NC} Timing Settings"
    echo -e "  ${PRIMARY}[7]${NC} Auto-Delete Settings"
    echo -e "  ${PRIMARY}[8]${NC} Save and Exit"
    echo
    read -p "Select option (1-8): " choice
    echo
}

main_menu() {
    while true; do
        display_menu
        
        case $choice in
            1)
                configure_email
                ;;
            2)
                configure_location
                ;;
            3)
                configure_media
                ;;
            4)
                configure_schedule
                ;;
            5)
                configure_path
                read -p "Press Enter to continue..."
                ;;
            6)
                configure_timing
                ;;
            7)
                configure_auto_delete
                ;;
            8)
                save_configuration
                echo -e "\n${SUCCESS}Configuration saved. Exiting.${NC}"
                exit 0
                ;;
            *)
                echo -e "${ERROR}Invalid option. Please choose between 1 and 8.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

#=================================================================
# SCRIPT EXECUTION
#=================================================================

# Function to test email configuration
test_email() {
    show_header
    echo -e "${ACCENT}${BOLD}EMAIL CONFIGURATION TEST${NC}"
    echo
    
    # Validate email configuration
    if [ "$EMAIL_ENABLED" != "yes" ]; then
        echo -e "${ERROR}Email notifications are disabled.${NC}"
        echo -e "${WARNING}Please enable email notifications first.${NC}"
        return 1
    fi
    
    if [ -z "$EMAIL_TO" ] || [ "$EMAIL_TO" == "" ]; then
        echo -e "${ERROR}Email recipient is not configured.${NC}"
        echo -e "${WARNING}Please configure a recipient email address first.${NC}"
        return 1
    fi
    
    if [ -z "$EMAIL_FROM" ] || [ "$EMAIL_FROM" == "" ]; then
        echo -e "${ERROR}Sender email is not configured.${NC}"
        echo -e "${WARNING}Please configure a sender email address first.${NC}"
        return 1
    fi
    
    if [ -z "$RESEND_API_KEY" ] || [ "$RESEND_API_KEY" == "" ]; then
        echo -e "${ERROR}Resend API key is not configured.${NC}"
        echo -e "${WARNING}Please configure your Resend API key first.${NC}"
        return 1
    fi
    
    echo -e "${WARNING}Sending test email to ${SUCCESS}$EMAIL_TO${NC}..."
    echo -e "${WARNING}This will verify your email configuration.${NC}"
    echo
    
    # Create a temporary directory for the test
    local temp_dir=$(mktemp -d)
    local temp_html="$temp_dir/test_email.html"
    local temp_json="$temp_dir/test_email.json"
    
    # Get current user and extract first initial
    local username=$(whoami)
    local first_initial=$(echo "${username:0:1}" | tr '[:lower:]' '[:upper:]')
    
    # Create HTML template file
    cat > "$temp_html" << 'EOF'
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html dir="ltr" lang="en">
  <head>
    <meta content="text/html; charset=UTF-8" http-equiv="Content-Type" />
    <meta name="x-apple-disable-message-reformatting" />
    <title>Mac Watcher - Test Mail</title>
  </head>
  <body style="margin:0 !important; padding:0 !important; width:100% !important;" class="force-bg-black body" bgcolor="#f6f6f7">
    <div class="force-bg-black">
      <!--[if mso | IE]>
      <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" bgcolor="#f6f6f7"><tr><td>
      <![endif]-->
      <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" class="force-bg-black" bgcolor="#f6f6f7">
        <tr>
          <td align="center" valign="top" style="padding:20px;">
            <table role="presentation" width="480" border="0" cellpadding="0" cellspacing="0" class="force-bg-card" style="width:480px; max-width:480px; border-radius:20px !important;" bgcolor="#ffffff">
              <!-- Header: Full Width Title Box -->
              <tr>
                <td style="border-radius:20px 20px 0 0 !important; padding: 16px 24px;" bgcolor="#ffffff">
                  <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="border-radius:16px !important;" bgcolor="#eaf1fa">
                    <tr>
                      <td style="padding:15px 16px;"> 
                        <span style="font-size:18px; font-weight:bold; color:#007aff;">Mac Watcher - Test Mail</span>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
              <!-- User Profile -->
              <tr>
                <td style="padding:16px 24px 0 24px;">
                  <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0">
                    <tr>
                      <td width="60" height="60" valign="middle" align="center" style="width:60px !important; height:60px !important; border-radius:30px !important; background-color:#e6f0fd;">
                        <span style="font-size:24px; font-weight:bold; color:#007aff;">__FIRST_INITIAL__</span>
                      </td>
                      <td width="15" style="width:15px; font-size:1px; line-height:1px;"> </td>
                      <td valign="middle">
                        <div style="font-size:24px; font-weight:bold; color:#222222; margin-bottom:5px;">__USERNAME__</div>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
              <tr>
                <td style="padding:0 24px 24px 24px;">
                  <p style="font-size:11px; color:#86868b; text-align:center; margin:0; line-height:24px;">This is an automated Test Mail from your Mac device.</p>
                  <p style="font-size:11px; color:#86868b; text-align:center; margin:0; line-height:24px;">© 2025 Mac-Watcher</p>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
      <!--[if mso | IE]>
      </td></tr></table>
      <![endif]-->
    </div>
  </body>
</html>
EOF
    
    # Replace placeholders with actual values
    sed -i '' "s/__FIRST_INITIAL__/$first_initial/g" "$temp_html"
    sed -i '' "s/__USERNAME__/$username/g" "$temp_html"
    
    # Read the HTML content
    local html_content=$(cat "$temp_html")
    
    # Create email JSON payload
    cat > "$temp_json" << EOF
{
  "from": "Mac Watcher <${EMAIL_FROM}>",
  "to": "${EMAIL_TO}",
  "subject": "Mac-Watcher Test Email",
  "reply_to": "${EMAIL_FROM}",
  "html": $(echo "$html_content" | jq -Rs .)
}

EOF
    
    # Send the email
    echo -e "${WARNING}Sending test email...${NC}"
    local response
    response=$(curl -s -w "%{http_code}" -X POST \
      -H "Authorization: Bearer ${RESEND_API_KEY}" \
      -H "Content-Type: application/json" \
      --data-binary "@$temp_json" \
      "https://api.resend.com/emails")
    
    # Clean up
    rm -f "$temp_html" "$temp_json"
    rmdir "$temp_dir"
    
    # Check response
    local http_code=${response: -3}
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        echo -e "${SUCCESS}Test email sent successfully!${NC}"
        echo -e "${SUCCESS}Please check your inbox at ${EMAIL_TO}${NC}"
        echo
        echo -e "If you don't receive the email:"
        echo -e "1. Check your spam folder"
        echo -e "2. Verify your Resend API key is correct"
        echo -e "3. Ensure your recipient email address is valid"
        return 0
    else
        echo -e "${ERROR}Failed to send test email. Status code: $http_code${NC}"
        echo -e "${ERROR}Response: ${response%???}${NC}"
        echo
        echo -e "${WARNING}Troubleshooting:${NC}"
        echo -e "1. Verify your Resend API key is correct"
        echo -e "2. Check that your recipient email is valid"
        echo -e "3. Ensure you have internet connectivity"
        return 1
    fi
}
# Set the current user and date information
CURRENT_DATE_UTC=$(date)
CURRENT_USER=$(whoami)

initialize_config
main_menu