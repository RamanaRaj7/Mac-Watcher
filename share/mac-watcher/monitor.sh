#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

#############################
# Configuration and Directory Setup
#############################
CONFIG_FILE="$HOME/.config/monitor.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo "Using configuration from $CONFIG_FILE"
else
    echo "Error: Configuration file not found at $CONFIG_FILE"
    echo "Please run 'mac-watcher --setup' to create the configuration file."
    exit 1
fi
# Verify essential dependencies
for cmd in jq imagesnap; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required dependency '$cmd' not found."
        echo "Please run 'mac-watcher --dependencies' to install missing dependencies."
        exit 1
    fi
done
# Verify location dependencies if enabled
if [ "$LOCATION_ENABLED" = "yes" ] && [ "$LOCATION_METHOD" = "corelocation_cli" ]; then
    if ! command -v CoreLocationCLI &> /dev/null; then
        echo "Error: CoreLocationCLI not found but location tracking is enabled."
        echo "Please run 'mac-watcher --dependencies' to install missing dependencies."
        exit 1
    fi
fi
# Set defaults for any missing variables (for backward compatibility)
: ${EMAIL_ENABLED:="no"}
: ${INITIAL_EMAIL_ENABLED:="yes"} # New setting for initial email
: ${FOLLOWUP_EMAIL_ENABLED:="yes"}
: ${EMAIL_TIME_RESTRICTION_ENABLED:="no"}
: ${EMAIL_ACTIVE_WINDOWS:=""}
: ${EMAIL_DAY_RESTRICTION_ENABLED:="no"}
: ${EMAIL_ACTIVE_DAYS:="Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday"}
: ${INITIAL_DELAY:=0}
: ${FOLLOWUP_DELAY:=25}
: ${LOGIN_FAILURE_DETECTION_ENABLED:="no"} # New setting for login failure detection
: ${LOCATION_ENABLED:="yes"}
: ${LOCATION_METHOD:="corelocation_cli"} # Default method: corelocation_cli or apple_shortcuts
: ${NETWORK_INFO_ENABLED:="yes"} # Default for network information
: ${WEBCAM_ENABLED:="yes"}
: ${SCREENSHOT_ENABLED:="yes"}
: ${FOLLOWUP_SCREENSHOT_ENABLED:="yes"} # New setting for followup screenshot
: ${CUSTOM_SCHEDULE_ENABLED:="no"}
: ${ACTIVE_DAYS:="Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday"}
: ${SCHEDULE_ACTIVE_WINDOWS:=""}
: ${AUTO_DELETE_ENABLED:="no"}
: ${AUTO_DELETE_DAYS:=7}
: ${HTML_EMAIL_ENABLED:="yes"} # New setting for HTML email format

# Print key configuration settings for debugging
echo "Key configuration settings:"
echo "- EMAIL_ENABLED: $EMAIL_ENABLED"
echo "- LOCATION_ENABLED: $LOCATION_ENABLED"
echo "- LOCATION_METHOD: $LOCATION_METHOD"
echo "- NETWORK_INFO_ENABLED: $NETWORK_INFO_ENABLED"
echo "- WEBCAM_ENABLED: $WEBCAM_ENABLED"
echo "- SCREENSHOT_ENABLED: $SCREENSHOT_ENABLED"
echo "- FOLLOWUP_SCREENSHOT_ENABLED: $FOLLOWUP_SCREENSHOT_ENABLED"
echo "- LOGIN_DETECTION_ENABLED: $LOGIN_FAILURE_DETECTION_ENABLED"

# Directory setup
YEAR=$(date +"%Y")
MONTH=$(date +"%B")
DAY_WITH_DATE=$(date +"%d-%b-%Y-(%A)")
AMPM=$(date +%p)
HOUR=$(date +"%I" | sed 's/^0*//')  # remove any leading zero using 12-hour format
MINUTE=$(date +"%M")
SECOND=$(date +"%S")
# Fix: Strip leading zeros for arithmetic operations
MINUTE_NUM=${MINUTE#0}
SECOND_NUM=${SECOND#0}

# Fixed printf command - explicitly converting arguments to numbers
TIME=$(printf "(%s)-%02d.%02d.%02d" "$AMPM" "$HOUR" $MINUTE_NUM $SECOND_NUM)

TARGET_DIR="$BASE_DIR/$YEAR/$MONTH/$DAY_WITH_DATE/$TIME"
mkdir -p "$TARGET_DIR"

MAIL_QUEUE_DIR="$TARGET_DIR/mail_queue"
mkdir -p "$MAIL_QUEUE_DIR"

LOG_FILE="$TARGET_DIR/monitor.log"
exec > >(tee -a "$LOG_FILE") 2>&1

UTC_TIME=$(date -u "+%Y-%m-%d %H:%M:%S")
LOCAL_TIME=$(date "+%Y-%m-%d %H:%M:%S")
HR_TIME=$(date '+%I:%M:%S %p')
CURRENT_DAY=$(date +"%A")
CURRENT_USER=$(whoami)
echo "Script started at ${UTC_TIME} UTC (${LOCAL_TIME}) (${HR_TIME})"
echo "Current user: ${CURRENT_USER}"
echo "Current day: ${CURRENT_DAY}"

initial_email_sent=false

# Add this near the beginning of the script, after the directory setup section
# Generate a unique session ID
SESSION_ID=$(date +"%Y%m%d%H%M%S")_$$
echo "Session ID: $SESSION_ID"

# Create attachments directory
ATTACHMENTS_DIR="$TARGET_DIR/attachments"
mkdir -p "$ATTACHMENTS_DIR"

#############################
# Helper Functions for HTML Email
#############################
generate_html_initial_email() {
    local username="$1"
    local photo_time="$2"
    local shot_time="$3"
    local first_initial=$(echo "${username:0:1}" | tr '[:lower:]' '[:upper:]')
    local current_time=$(date '+%I:%M:%S %p')

    # Extract location data
    local locality="Not available"
    local sublocality="Not available"
    local admin_area="Not available"
    local postal_code="Not available"
    local country="Not available"
    local latitude="Not available"
    local longitude="Not available"
    local local_time="Not available"
    local timezone="Not available"
    local wifi_ssid="Not available"
    local local_ip="Not available"
    local public_ip="Not available"

    # Parse location data from file if available
    if [ "$LOCATION_ENABLED" = "yes" ] && [ -f "$TARGET_DIR/location_output.txt" ]; then
        while IFS= read -r line; do
            if [[ "$line" == *"Locality:"* ]]; then
                locality=$(echo "$line" | sed 's/Locality: *//')
            elif [[ "$line" == *"Sub-locality:"* ]]; then
                sublocality=$(echo "$line" | sed 's/Sub-locality: *//')
            elif [[ "$line" == *"Administrative Area:"* ]]; then
                admin_area=$(echo "$line" | sed 's/Administrative Area: *//')
            elif [[ "$line" == *"Postal Code:"* ]]; then
                postal_code=$(echo "$line" | sed 's/Postal Code: *//')
            elif [[ "$line" == *"Country:"* ]]; then
                country=$(echo "$line" | sed 's/Country: *//')
            elif [[ "$line" == *"Latitude:"* ]]; then
                latitude=$(echo "$line" | sed 's/Latitude: *//')
            elif [[ "$line" == *"Longitude:"* ]]; then
                longitude=$(echo "$line" | sed 's/Longitude: *//')
            elif [[ "$line" == *"Local Time:"* ]]; then
                local_time=$(echo "$line" | sed 's/Local Time: *//')
            elif [[ "$line" == *"Time Zone:"* ]]; then
                timezone=$(echo "$line" | sed 's/Time Zone: *//')
            elif [[ "$line" == *"WiFi SSID:"* ]]; then
                wifi_ssid=$(echo "$line" | sed 's/WiFi SSID: *//')
            elif [[ "$line" == *"Local IP Address:"* ]]; then
                local_ip=$(echo "$line" | sed 's/Local IP Address: *//')
            elif [[ "$line" == *"Public IP Address:"* ]]; then
                public_ip=$(echo "$line" | sed 's/Public IP Address: *//')
            fi
        done < "$TARGET_DIR/location_output.txt"
    else
        locality="Disabled"
        sublocality="Disabled"
        admin_area="Disabled"
        postal_code="Disabled"
        country="Disabled"
        latitude="Disabled"
        longitude="Disabled"
        local_time="Disabled"
        timezone="Disabled"
    fi
    
    # Set network info as disabled if not enabled
    if [ "$NETWORK_INFO_ENABLED" != "yes" ]; then
        wifi_ssid="Disabled"
        local_ip="Disabled"
        public_ip="Disabled"
    fi
    
    # Set webcam and screenshot status
    local photo_status="$photo_time"
    local shot_status="$shot_time"
    
    if [ "$WEBCAM_ENABLED" != "yes" ]; then
        photo_status="Disabled"
    fi
    
    if [ "$SCREENSHOT_ENABLED" != "yes" ]; then
        shot_status="Disabled"
    fi
    
    # Create map link
    local map_link="https://maps.apple.com/?q=${latitude},${longitude}&ll=${latitude},${longitude}"
    
    # Generate HTML email template
    cat <<EOF
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html dir="ltr" lang="en">
  <head>
    <meta content="text/html; charset=UTF-8" http-equiv="Content-Type" />
    <meta name="x-apple-disable-message-reformatting" />
    <title>Mac Watcher Alert</title>
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
                <td class="force-bg-card" style="border-radius:20px 20px 0 0 !important; padding: 16px 24px;" bgcolor="#ffffff">
                  <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" class="force-bg-header" style="border-radius:16px !important;" bgcolor="#eaf1fa">
                    <tr>
                      <td style="padding:15px 16px;">
                        <span style="font-size:18px; font-weight:bold; color:#007aff;">Mac Watcher Alert</span>
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
                        <span style="font-size:24px; font-weight:bold; color:#007aff;">${first_initial}</span>
                      </td>
                      <td width="15" style="width:15px; font-size:1px; line-height:1px;"> </td>
                      <td valign="middle">
                        <div style="font-size:24px; font-weight:bold; color:#222222; margin-bottom:5px;">${username}</div>
                        <div style="font-size:13px; color:#86868b;">Last activity: ${current_time}</div>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
              
              <!-- Timestamp Info Section -->
              <tr>
                <td style="padding:24px 24px 16px 24px;">
                  <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="min-width: 432px !important; border-radius:16px !important;" bgcolor="#f1f1f3">
                    <tr>
                      <td style="padding:16px;">
                        <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0">
                          <tr>
                            <td style="padding-bottom:8px; width:60%; font-size:13px; color:#86868b;">Photo Timestamp</td>
                            <td align="right" style="padding-bottom:8px; width:40%; font-size:13px; color:#222222;">${photo_status}</td>
                          </tr>
                          <tr>
                            <td colspan="2" style="padding-bottom:8px;">
                              <div style="height:1px; background-color:#e0e0e3;"></div>
                            </td>
                          </tr>
                          <tr>
                            <td style="width:60%; font-size:13px; color:#86868b;">Screenshot Timestamp</td>
                            <td align="right" style="width:40%; font-size:13px; color:#222222;">${shot_status}</td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
              
              <!-- Location Info Section -->
              <tr>
                <td style="padding:0 24px 16px 24px;">
                  <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="border-radius:16px !important;" bgcolor="#f1f1f3">
                    <tr>
                      <td style="padding:16px;">
                        <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0">
                          <tr>
                            <td style="padding-bottom:8px; width:40%; font-size:13px; color:#86868b;">Locality</td>
                            <td align="right" style="padding-bottom:8px; width:60%; font-size:13px; color:#222222;">${locality}</td>
                          </tr>
                          <tr>
                            <td colspan="2" style="padding-bottom:8px;">
                              <div style="height:1px; background-color:#e0e0e3;"></div>
                            </td>
                          </tr>
                          <tr>
                            <td style="padding-bottom:8px; width:40%; font-size:13px; color:#86868b;">Sub-locality</td>
                            <td align="right" style="padding-bottom:8px; width:60%; font-size:13px; color:#222222;">${sublocality}</td>
                          </tr>
                          <tr>
                            <td colspan="2" style="padding-bottom:8px;">
                              <div style="height:1px; background-color:#e0e0e3;"></div>
                            </td>
                          </tr>
                          <tr>
                            <td style="padding-bottom:8px; width:40%; font-size:13px; color:#86868b;">Administrative Area</td>
                            <td align="right" style="padding-bottom:8px; width:60%; font-size:13px; color:#222222;">${admin_area}</td>
                          </tr>
                          <tr>
                            <td colspan="2" style="padding-bottom:8px;">
                              <div style="height:1px; background-color:#e0e0e3;"></div>
                            </td>
                          </tr>
                          <tr>
                            <td style="padding-bottom:8px; width:40%; font-size:13px; color:#86868b;">Postal Code</td>
                            <td align="right" style="padding-bottom:8px; width:60%; font-size:13px; color:#222222;">${postal_code}</td>
                          </tr>
                          <tr>
                            <td colspan="2" style="padding-bottom:8px;">
                              <div style="height:1px; background-color:#e0e0e3;"></div>
                            </td>
                          </tr>
                          <tr>
                            <td style="padding-bottom:8px; width:40%; font-size:13px; color:#86868b;">Country</td>
                            <td align="right" style="padding-bottom:8px; width:60%; font-size:13px; color:#222222;">${country}</td>
                          </tr>
                          <tr>
                            <td colspan="2" style="padding-bottom:8px;">
                              <div style="height:1px; background-color:#e0e0e3;"></div>
                            </td>
                          </tr>
                          <tr>
                            <td style="padding-bottom:8px; width:40%; font-size:13px; color:#86868b;">Latitude</td>
                            <td align="right" style="padding-bottom:8px; width:60%; font-size:13px; color:#222222;">${latitude}</td>
                          </tr>
                          <tr>
                            <td colspan="2" style="padding-bottom:8px;">
                              <div style="height:1px; background-color:#e0e0e3;"></div>
                            </td>
                          </tr>
                          <tr>
                            <td style="padding-bottom:8px; width:40%; font-size:13px; color:#86868b;">Longitude</td>
                            <td align="right" style="padding-bottom:8px; width:60%; font-size:13px; color:#222222;">${longitude}</td>
                          </tr>
                          <tr>
                            <td colspan="2" style="padding-bottom:8px;">
                              <div style="height:1px; background-color:#e0e0e3;"></div>
                            </td>
                          </tr>
                          <tr>
                            <td style="padding-bottom:8px; width:40%; font-size:13px; color:#86868b;">Local Time</td>
                            <td align="right" style="padding-bottom:8px; width:60%; font-size:13px; color:#222222;">${local_time}</td>
                          </tr>
                          <tr>
                            <td colspan="2" style="padding-bottom:8px;">
                              <div style="height:1px; background-color:#e0e0e3;"></div>
                            </td>
                          </tr>
                          <tr>
                            <td style="width:40%; font-size:13px; color:#86868b;">Time Zone</td>
                            <td align="right" style="width:60%; font-size:13px; color:#222222;">${timezone}</td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
              
              <!-- Map Link Section -->
              <tr>
                <td style="padding:0 24px 16px 24px;">
                  <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="min-width: 432px !important; border-radius:16px !important;" bgcolor="#f1f1f3">
                    <tr>
                      <td align="center" style="padding:16px;">
                        $(if [ "$LOCATION_ENABLED" = "yes" ]; then
                          echo "<a href=\"${map_link}\" target=\"_blank\" style=\"text-decoration:none; display:block; width:100%; font-size:13px; color:#007aff;\">View in Apple Maps</a>"
                        else
                          echo "<span style=\"display:block; width:100%; font-size:13px; color:#86868b;\">Location tracking Disabled</span>"
                        fi)
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
              
              <!-- Network Info Section -->
              <tr>
                <td style="padding:0 24px 24px 24px;">
                  <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="min-width: 432px !important; border-radius:16px !important;" bgcolor="#f1f1f3">
                    <tr>
                      <td style="padding:16px;">
                        <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0">
                          <tr>
                            <td style="padding-bottom:8px; width:50%; font-size:13px; color:#86868b;">WiFi SSID</td>
                            <td align="right" style="padding-bottom:8px; width:50%; font-size:13px; color:#222222;">${wifi_ssid}</td>
                          </tr>
                          <tr>
                            <td colspan="2" style="padding-bottom:8px;">
                              <div style="height:1px; background-color:#e0e0e3;"></div>
                            </td>
                          </tr>
                          <tr>
                            <td style="padding-bottom:8px; width:50%; font-size:13px; color:#86868b;">Local IP Address</td>
                            <td align="right" style="padding-bottom:8px; width:50%; font-size:13px; color:#222222;">${local_ip}</td>
                          </tr>
                          <tr>
                            <td colspan="2" style="padding-bottom:8px;">
                              <div style="height:1px; background-color:#e0e0e3;"></div>
                            </td>
                          </tr>
                          <tr>
                            <td style="width:50%; font-size:13px; color:#86868b;">Public IP Address</td>
                            <td align="right" style="width:50%; font-size:13px; color:#222222;">${public_ip}</td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
              
              <!-- Footer -->
              <tr>
                <td style="padding:0 24px 24px 24px;">
                  <p style="font-size:11px; color:#86868b; text-align:center; margin:0; line-height:24px;">This is an automated security alert from your Mac device.</p>
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
}

generate_html_followup_email() {
    local username="$1"
    local shot_time="$2"
    local first_initial=$(echo "${username:0:1}" | tr '[:lower:]' '[:upper:]')
    local current_time=$(date '+%I:%M:%S %p')
    
    # Extract location data
    local locality="Not available"
    local sublocality="Not available"
    local admin_area="Not available"
    local postal_code="Not available"
    local country="Not available"
    local latitude="Not available"
    local longitude="Not available"
    local local_time="Not available"
    local timezone="Not available"
    local wifi_ssid="Not available"
    local local_ip="Not available"
    local public_ip="Not available"
    
    # Parse location data from file if available
    if [ "$LOCATION_ENABLED" = "yes" ] && [ -f "$TARGET_DIR/location_output.txt" ]; then
        while IFS= read -r line; do
            if [[ "$line" == *"Locality:"* ]]; then
                locality=$(echo "$line" | sed 's/Locality: *//')
            elif [[ "$line" == *"Sub-locality:"* ]]; then
                sublocality=$(echo "$line" | sed 's/Sub-locality: *//')
            elif [[ "$line" == *"Administrative Area:"* ]]; then
                admin_area=$(echo "$line" | sed 's/Administrative Area: *//')
            elif [[ "$line" == *"Postal Code:"* ]]; then
                postal_code=$(echo "$line" | sed 's/Postal Code: *//')
            elif [[ "$line" == *"Country:"* ]]; then
                country=$(echo "$line" | sed 's/Country: *//')
            elif [[ "$line" == *"Latitude:"* ]]; then
                latitude=$(echo "$line" | sed 's/Latitude: *//')
            elif [[ "$line" == *"Longitude:"* ]]; then
                longitude=$(echo "$line" | sed 's/Longitude: *//')
            elif [[ "$line" == *"Local Time:"* ]]; then
                local_time=$(echo "$line" | sed 's/Local Time: *//')
            elif [[ "$line" == *"Time Zone:"* ]]; then
                timezone=$(echo "$line" | sed 's/Time Zone: *//')
            elif [[ "$line" == *"WiFi SSID:"* ]]; then
                wifi_ssid=$(echo "$line" | sed 's/WiFi SSID: *//')
            elif [[ "$line" == *"Local IP Address:"* ]]; then
                local_ip=$(echo "$line" | sed 's/Local IP Address: *//')
            elif [[ "$line" == *"Public IP Address:"* ]]; then
                public_ip=$(echo "$line" | sed 's/Public IP Address: *//')
            fi
        done < "$TARGET_DIR/location_output.txt"
    else
        locality="Disabled"
        sublocality="Disabled"
        admin_area="Disabled"
        postal_code="Disabled"
        country="Disabled"
        latitude="Disabled"
        longitude="Disabled"
        local_time="Disabled"
        timezone="Disabled"
    fi
    
    # Set network info as disabled if not enabled
    if [ "$NETWORK_INFO_ENABLED" != "yes" ]; then
        wifi_ssid="Disabled"
        local_ip="Disabled"
        public_ip="Disabled"
    fi
    
    # Set screenshot status
    local shot_status="$shot_time"
    
    if [ "$SCREENSHOT_ENABLED" != "yes" ] || [ "$FOLLOWUP_SCREENSHOT_ENABLED" != "yes" ]; then
        shot_status="Disabled"
    fi
    
    # Create map link
    local map_link="https://maps.apple.com/?q=${latitude},${longitude}&ll=${latitude},${longitude}"
    
    # Generate HTML email template
    cat <<EOF
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html dir="ltr" lang="en">
  <head>
    <meta content="text/html; charset=UTF-8" http-equiv="Content-Type" />
    <meta name="x-apple-disable-message-reformatting" />
    <title>Mac Watcher Alert - Follow-up</title>
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
                        <span style="font-size:18px; font-weight:bold; color:#007aff;">Mac Watcher Alert - Follow-up</span>
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
                        <span style="font-size:24px; font-weight:bold; color:#007aff;">${first_initial}</span>
                      </td>
                      <td width="15" style="width:15px; font-size:1px; line-height:1px;"> </td>
                      <td valign="middle">
                        <div style="font-size:24px; font-weight:bold; color:#222222; margin-bottom:5px;">${username}</div>
                        <div style="font-size:13px; color:#86868b;">Follow-up at: ${current_time}</div>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>

              <!-- Timestamp Info Section -->
              <tr>
                <td style="padding:24px 24px 16px 24px;">
                  <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0" style="min-width: 432px !important; border-radius:16px !important;" bgcolor="#f1f1f3">
                    <tr>
                      <td style="padding:16px;">
                        <table role="presentation" width="100%" border="0" cellpadding="0" cellspacing="0">
                          <tr>
                            <td style="width:60%; font-size:13px; color:#86868b;">Follow-up Screenshot Timestamp</td>
                            <td align="right" style="width:40%; font-size:13px; color:#222222;">${shot_status}</td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
              <!-- footer -->
              <tr>
                <td style="padding:0 24px 24px 24px;">
                  <p style="font-size:11px; color:#86868b; text-align:center; margin:0; line-height:24px;">This is an automated security alert from your Mac device.</p>
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
}

#############################
# Helper Function: Validate Email Configuration
#############################
validate_email_config() {
    # Check if all required email parameters are set
    if [ -z "$EMAIL_TO" ] || [ "$EMAIL_TO" == "" ]; then
        echo "Email recipient (EMAIL_TO) is not configured. Skipping email."
        return 1
    fi
    
    if [ -z "$EMAIL_FROM" ] || [ "$EMAIL_FROM" == "" ]; then
        echo "Sender email (EMAIL_FROM) is not configured. Skipping email."
        return 1
    fi
    
    if [ -z "$RESEND_API_KEY" ] || [ "$RESEND_API_KEY" == "" ]; then
        echo "Resend API key (RESEND_API_KEY) is not configured. Skipping email."
        return 1
    fi
    
    return 0
}

#############################
# Schedule Checking Functions
#############################

# Check if current day is in active days
is_active_day() {
    if [ "$CUSTOM_SCHEDULE_ENABLED" = "no" ]; then
        return 0
    fi
    
    IFS=',' read -ra DAYS <<< "$ACTIVE_DAYS"
    for day in "${DAYS[@]}"; do
        if [ "$day" = "$CURRENT_DAY" ]; then
            return 0
        fi
    done
    return 1
}

# Check if email should be sent based on day restriction
is_email_day_allowed() {
    if [ "$EMAIL_DAY_RESTRICTION_ENABLED" = "no" ]; then
        return 0
    fi
    
    IFS=',' read -ra DAYS <<< "$EMAIL_ACTIVE_DAYS"
    for day in "${DAYS[@]}"; do
        if [ "$day" = "$CURRENT_DAY" ]; then
            return 0
        fi
    done
    return 1
}

# Check if current time is in any active window
is_active_time() {
    if [ "$CUSTOM_SCHEDULE_ENABLED" = "no" ] || [ -z "$SCHEDULE_ACTIVE_WINDOWS" ]; then
        return 0
    fi
    
    local current_hour=$(date +"%I")
    local current_minute=$(date +"%M")
    local current_ampm=$(date +"%p")
    
    # Fix: Strip leading zeros for arithmetic
    current_hour=${current_hour#0}
    current_minute=${current_minute#0}
    
    # Convert current time to minutes since midnight
    local current_time_minutes
    if [ "$current_ampm" = "AM" ] && [ "$current_hour" -eq 12 ]; then
        current_time_minutes=0
    elif [ "$current_ampm" = "AM" ]; then
        current_time_minutes=$((current_hour * 60 + current_minute))
    elif [ "$current_ampm" = "PM" ] && [ "$current_hour" -eq 12 ]; then
        current_time_minutes=$((12 * 60 + current_minute))
    else
        current_time_minutes=$(((current_hour + 12) * 60 + current_minute))
    fi
    
    IFS=',' read -ra WINDOWS <<< "$SCHEDULE_ACTIVE_WINDOWS"
    for window in "${WINDOWS[@]}"; do
        # Parse start time
        local start_hour=$(echo "$window" | sed -E 's/([0-9]+):([0-9]+)(AM|PM)-([0-9]+):([0-9]+)(AM|PM)/\1/')
        local start_minute=$(echo "$window" | sed -E 's/([0-9]+):([0-9]+)(AM|PM)-([0-9]+):([0-9]+)(AM|PM)/\2/')
        local start_ampm=$(echo "$window" | sed -E 's/([0-9]+):([0-9]+)(AM|PM)-([0-9]+):([0-9]+)(AM|PM)/\3/')
        
        # Parse end time
        local end_hour=$(echo "$window" | sed -E 's/([0-9]+):([0-9]+)(AM|PM)-([0-9]+):([0-9]+)(AM|PM)/\4/')
        local end_minute=$(echo "$window" | sed -E 's/([0-9]+):([0-9]+)(AM|PM)-([0-9]+):([0-9]+)(AM|PM)/\5/')
        local end_ampm=$(echo "$window" | sed -E 's/([0-9]+):([0-9]+)(AM|PM)-([0-9]+):([0-9]+)(AM|PM)/\6/')
        
        # Convert start time to minutes
        local start_time_minutes
        if [ "$start_ampm" = "AM" ] && [ "$start_hour" -eq 12 ]; then
            start_time_minutes=0
        elif [ "$start_ampm" = "AM" ]; then
            start_time_minutes=$((start_hour * 60 + start_minute))
        elif [ "$start_ampm" = "PM" ] && [ "$start_hour" -eq 12 ]; then
            start_time_minutes=$((12 * 60 + start_minute))
        else
            start_time_minutes=$(((start_hour + 12) * 60 + start_minute))
        fi
        
        # Convert end time to minutes
        local end_time_minutes
        if [ "$end_ampm" = "AM" ] && [ "$end_hour" -eq 12 ]; then
            end_time_minutes=0
        elif [ "$end_ampm" = "AM" ]; then
            end_time_minutes=$((end_hour * 60 + end_minute))
        elif [ "$end_ampm" = "PM" ] && [ "$end_hour" -eq 12 ]; then
            end_time_minutes=$((12 * 60 + end_minute))
        else
            end_time_minutes=$(((end_hour + 12) * 60 + end_minute))
        fi
        
        # Check if current time is within this window
        if [ "$current_time_minutes" -ge "$start_time_minutes" ] && [ "$current_time_minutes" -le "$end_time_minutes" ]; then
            return 0
        fi
    done
    
    return 1
}

# Check if email time restriction allows sending now
is_email_time_allowed() {
    if [ "$EMAIL_TIME_RESTRICTION_ENABLED" = "no" ] || [ -z "$EMAIL_ACTIVE_WINDOWS" ]; then
        return 0
    fi
    
    local current_hour=$(date +"%I")
    local current_minute=$(date +"%M")
    local current_ampm=$(date +"%p")
    
    # Fix: Strip leading zeros for arithmetic
    current_hour=${current_hour#0}
    current_minute=${current_minute#0}
    
    # Convert current time to minutes since midnight
    local current_time_minutes
    if [ "$current_ampm" = "AM" ] && [ "$current_hour" -eq 12 ]; then
        current_time_minutes=0
    elif [ "$current_ampm" = "AM" ]; then
        current_time_minutes=$((current_hour * 60 + current_minute))
    elif [ "$current_ampm" = "PM" ] && [ "$current_hour" -eq 12 ]; then
        current_time_minutes=$((12 * 60 + current_minute))
    else
        current_time_minutes=$(((current_hour + 12) * 60 + current_minute))
    fi
    
    IFS=',' read -ra WINDOWS <<< "$EMAIL_ACTIVE_WINDOWS"
    for window in "${WINDOWS[@]}"; do
        # Parse start time
        local start_hour=$(echo "$window" | sed -E 's/([0-9]+):([0-9]+)(AM|PM)-([0-9]+):([0-9]+)(AM|PM)/\1/')
        local start_minute=$(echo "$window" | sed -E 's/([0-9]+):([0-9]+)(AM|PM)-([0-9]+):([0-9]+)(AM|PM)/\2/')
        local start_ampm=$(echo "$window" | sed -E 's/([0-9]+):([0-9]+)(AM|PM)-([0-9]+):([0-9]+)(AM|PM)/\3/')
        
        # Parse end time
        local end_hour=$(echo "$window" | sed -E 's/([0-9]+):([0-9]+)(AM|PM)-([0-9]+):([0-9]+)(AM|PM)/\4/')
        local end_minute=$(echo "$window" | sed -E 's/([0-9]+):([0-9]+)(AM|PM)-([0-9]+):([0-9]+)(AM|PM)/\5/')
        local end_ampm=$(echo "$window" | sed -E 's/([0-9]+):([0-9]+)(AM|PM)-([0-9]+):([0-9]+)(AM|PM)/\6/')
        
        # Convert start time to minutes
        local start_time_minutes
        if [ "$start_ampm" = "AM" ] && [ "$start_hour" -eq 12 ]; then
            start_time_minutes=0
        elif [ "$start_ampm" = "AM" ]; then
            start_time_minutes=$((start_hour * 60 + start_minute))
        elif [ "$start_ampm" = "PM" ] && [ "$start_hour" -eq 12 ]; then
            start_time_minutes=$((12 * 60 + start_minute))
        else
            start_time_minutes=$(((start_hour + 12) * 60 + start_minute))
        fi
        
        # Convert end time to minutes
        local end_time_minutes
        if [ "$end_ampm" = "AM" ] && [ "$end_hour" -eq 12 ]; then
            end_time_minutes=0
        elif [ "$end_ampm" = "AM" ]; then
            end_time_minutes=$((end_hour * 60 + end_minute))
        elif [ "$end_ampm" = "PM" ] && [ "$end_hour" -eq 12 ]; then
            end_time_minutes=$((12 * 60 + end_minute))
        else
            end_time_minutes=$(((end_hour + 12) * 60 + end_minute))
        fi
        
        # Check if current time is within this window
        if [ "$current_time_minutes" -ge "$start_time_minutes" ] && [ "$current_time_minutes" -le "$end_time_minutes" ]; then
            return 0
        fi
    done
    
    return 1
}

#############################
# Helper Function: Check Internet Connectivity
#############################
check_internet() {
    echo "Checking internet connectivity..." >&2
    if ping -c 1 -W 3 api.resend.com > /dev/null 2>&1; then
        echo "Internet connection available (ping to api.resend.com successful)" >&2
        return 0
    else
        echo "No internet connection available (ping to api.resend.com failed)" >&2
        
        # Try alternate method with curl to Google
        if command -v curl >/dev/null 2>&1; then
            echo "Trying alternate connectivity check with curl..." >&2
            if curl -s --connect-timeout 3 -I https://api.resend.com >/dev/null 2>&1; then
                echo "Internet connection available (curl to api.resend.com successful)" >&2
                return 0
            else
                echo "No internet connection available (curl to api.resend.com failed)" >&2
            fi
        fi
        
        return 1
    fi
}

#############################
# Helper Function: JSON Escape (remove newlines and escape quotes)
#############################
json_escape() {
    # Improved version that handles empty or null values better
    if [ -z "$1" ]; then
        echo "Not available"
    else
        echo "$1" | tr '\n' ' ' | sed 's/"/\\"/g'
    fi
}

#############################
# Helper Function: Format Location for Email
#############################
format_location_for_email() {
    local location_file="$1"
    
    if [ ! -f "$location_file" ] || [ ! -s "$location_file" ]; then
        echo "Location data unavailable"
        return
    fi
    
    # Simply output the file contents, preserving newlines for HTML email
    cat "$location_file"
}

#############################
# Helper Function: Save JSON for debugging
#############################
save_json_debug() {
    local json_file="$1"
    local debug_file="$2"
    
    # Make a copy of the JSON for debugging
    cp "$json_file" "$debug_file"
    echo "Debug JSON saved to $debug_file"
}

#############################
# Helper Function: Collect Network Information
#############################
collect_network_info() {
    if [ "$NETWORK_INFO_ENABLED" != "yes" ]; then
        echo "Network info collection function called but NETWORK_INFO_ENABLED is not 'yes'" >&2
        return 1
    fi
    
    # Initialize variables with default values
    local wifi_ssid="Not available"
    local local_ip="Not available"
    local public_ip="Not available"
    
    # Get WiFi SSID
    if command -v ipconfig >/dev/null 2>&1; then
        echo "Getting WiFi SSID using ipconfig..." >&2
        local ssid_output=$(ipconfig getsummary en0 2>/dev/null | awk '/ SSID/ {print $NF}')
        if [ -n "$ssid_output" ]; then
            wifi_ssid="$ssid_output"
            echo "Found WiFi SSID: $wifi_ssid" >&2
        else
            echo "Failed to get WiFi SSID" >&2
        fi
    else
        echo "ipconfig command not available for SSID detection" >&2
    fi
    
    # Get local IP address
    if command -v ipconfig >/dev/null 2>&1; then
        echo "Getting local IP address using ipconfig..." >&2
        local ip_output=$(ipconfig getifaddr en0 2>/dev/null)
        if [ -n "$ip_output" ]; then
            local_ip="$ip_output"
            echo "Found local IP: $local_ip" >&2
        else
            echo "Failed to get local IP address from en0" >&2
            # Try alternate interface
            ip_output=$(ipconfig getifaddr en1 2>/dev/null)
            if [ -n "$ip_output" ]; then
                local_ip="$ip_output"
                echo "Found local IP from en1: $local_ip" >&2
            else
                echo "Failed to get local IP address from en1 as well" >&2
            fi
        fi
    else
        echo "ipconfig command not available for IP detection" >&2
    fi
    
    # Get public IP address (only if internet is available)
    if check_internet; then
        echo "Internet connection available, getting public IP..." >&2
        if command -v curl >/dev/null 2>&1; then
            local public_ip_output=$(curl -s ipinfo.io/ip 2>/dev/null)
            if [ -n "$public_ip_output" ]; then
                public_ip="$public_ip_output"
                echo "Found public IP: $public_ip" >&2
            else
                echo "Failed to get public IP from ipinfo.io" >&2
            fi
        else
            echo "curl command not available for public IP detection" >&2
        fi
    else
        echo "No internet connection available, skipping public IP detection" >&2
    fi
    
    # Return the formatted network information
    cat <<EOF


Network Information

WiFi SSID: $wifi_ssid
Local IP Address: $local_ip
Public IP Address: $public_ip
EOF
}

#############################
# Auto-Delete Old Files
#############################
run_auto_delete() {
    if [ "$AUTO_DELETE_ENABLED" = "yes" ] && [ "$AUTO_DELETE_DAYS" -gt 0 ]; then
        echo "Checking for files older than $AUTO_DELETE_DAYS days to delete..."
        find "$BASE_DIR" -type f -mtime +$AUTO_DELETE_DAYS -exec rm -f {} \; 2>/dev/null
        find "$BASE_DIR" -type d -empty -delete 2>/dev/null
        echo "Auto-delete process completed."
    fi
}

#############################
# Function: Capture Location Using CoreLocationCLI
#############################
capture_location_cli() {
    if [ "$LOCATION_ENABLED" != "yes" ]; then
        echo "Location capture disabled in configuration."
        return 1
    fi
    
    # Initialize variable to store complete output
    local formatted_output=""
    
    # Collect network information first if enabled
    if [ "$NETWORK_INFO_ENABLED" = "yes" ]; then
        echo "NETWORK_INFO_ENABLED is yes, collecting network information first..."
        local network_info=$(collect_network_info)
        formatted_output+="$network_info"
        echo "Network information collected successfully"
    else
        echo "NETWORK_INFO_ENABLED is not enabled, skipping network information collection"
    fi
    
    # Now try to capture location data
    echo "Capturing location data using CoreLocationCLI..."
    
    # Check if CoreLocationCLI is available
    if ! command -v CoreLocationCLI &> /dev/null; then
        echo "Error: CoreLocationCLI command not found. Cannot capture location."
        
        # If we already have network info, save it
        if [ -n "$formatted_output" ]; then
            echo "Location data unavailable - CoreLocationCLI not installed" > "$TARGET_DIR/location_output.txt"
            echo "$formatted_output" >> "$TARGET_DIR/location_output.txt"
            echo "Saved network information without location data"
            return 0
        else
            echo "Location data unavailable - CoreLocationCLI not installed" > "$TARGET_DIR/location_output.txt"
            return 1
        fi
    fi
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo "Error: jq command not found. Cannot parse location data."
        
        # If we already have network info, save it
        if [ -n "$formatted_output" ]; then
            echo "Location data unavailable - jq not installed" > "$TARGET_DIR/location_output.txt"
            echo "$formatted_output" >> "$TARGET_DIR/location_output.txt"
            echo "Saved network information without location data"
            return 0
        else
            echo "Location data unavailable - jq not installed" > "$TARGET_DIR/location_output.txt"
            return 1
        fi
    fi
    
    # Get location data using CoreLocationCLI
    local LOCATION_JSON
    LOCATION_JSON=$(CoreLocationCLI --json 2>/dev/null)
    
    # Check if we got valid JSON
    if [ -z "$LOCATION_JSON" ] || ! echo "$LOCATION_JSON" | jq . &>/dev/null; then
        echo "Error: Failed to obtain valid location data from CoreLocationCLI."
        
        # If we already have network info, save it
        if [ -n "$formatted_output" ]; then
            echo "Location data unavailable - CoreLocationCLI failed" > "$TARGET_DIR/location_output.txt"
            echo "$formatted_output" >> "$TARGET_DIR/location_output.txt"
            echo "Saved network information without location data"
            return 0
        else
            echo "Location data unavailable - CoreLocationCLI failed" > "$TARGET_DIR/location_output.txt"
            return 1
        fi
    fi
    
    # Extract values using jq
    local LAT LON LOCALITY SUBLOCALITY ADMIN_AREA POSTAL_CODE COUNTRY TIME_LOCAL TIMEZONE
    LAT=$(echo "$LOCATION_JSON" | jq -r '.latitude')
    LON=$(echo "$LOCATION_JSON" | jq -r '.longitude')
    LOCALITY=$(echo "$LOCATION_JSON" | jq -r '.locality // "N/A"')
    SUBLOCALITY=$(echo "$LOCATION_JSON" | jq -r '.subLocality // "N/A"')
    ADMIN_AREA=$(echo "$LOCATION_JSON" | jq -r '.administrativeArea // "N/A"')
    POSTAL_CODE=$(echo "$LOCATION_JSON" | jq -r '.postalCode // "N/A"')
    COUNTRY=$(echo "$LOCATION_JSON" | jq -r '.country // "N/A"')
    TIME_LOCAL=$(echo "$LOCATION_JSON" | jq -r '.time_local // "N/A"')
    TIMEZONE=$(echo "$LOCATION_JSON" | jq -r '.timeZone // "N/A"')
    
    # Generate Apple Maps link
    local MAP_LINK="https://maps.apple.com/?q=$LAT,$LON&ll=$LAT,$LON"
    
    # Format the location information
    local location_info
    location_info=$(cat <<EOF
Location Details

Locality: $LOCALITY
Sub-locality: $SUBLOCALITY
Administrative Area: $ADMIN_AREA
Postal Code: $POSTAL_CODE
Country: $COUNTRY

Coordinates

Latitude: $LAT
Longitude: $LON

Time

Local Time: $TIME_LOCAL
Time Zone: $TIMEZONE

Apple Maps Link
$MAP_LINK
EOF
)
    
    # Prepend the location information to our output
    formatted_output="$location_info$formatted_output"
    
    # Save the formatted location data to a file
    echo "$formatted_output" > "$TARGET_DIR/location_output.txt"
    
    # Save raw JSON data for debugging
    echo "$LOCATION_JSON" > "$TARGET_DIR/location_raw.json"
    
    echo "Location data captured and saved successfully."
    return 0
}

#############################
# Function: Capture Location Using Apple Shortcuts
#############################
capture_location_shortcuts() {
    if [ "$LOCATION_ENABLED" != "yes" ]; then
        echo "Location capture disabled in configuration."
        return 1
    fi
    
    # Initialize variable to store complete output
    local formatted_output=""
    
    # Collect network information first if enabled
    if [ "$NETWORK_INFO_ENABLED" = "yes" ]; then
        echo "NETWORK_INFO_ENABLED is yes, collecting network information first..."
        local network_info=$(collect_network_info)
        formatted_output+="$network_info"
        echo "Network information collected successfully"
    else
        echo "NETWORK_INFO_ENABLED is not enabled, skipping network information collection"
    fi
    
    # Now try to capture location data
    echo "Capturing location data using Apple Shortcuts..."
    
    # Run the location shortcut and save raw output
    local TEMP_OUTPUT="$TARGET_DIR/location_raw.txt"
    shortcuts run "Location" > "$TEMP_OUTPUT" 2>&1
    local SHORTCUT_EXIT_CODE=$?
    
    # Initialize location data variables
    local LAT=""
    local LON=""
    local LOCALITY="Unknown"
    local ADMIN_AREA="Unknown"
    local POSTAL_CODE="Unknown"
    local COUNTRY="Unknown" 
    local SUBLOCALITY="Unknown"
    local LOCATION_STATUS="Location data unavailable"
    
    # Try to extract location data if shortcut succeeded
    if [ $SHORTCUT_EXIT_CODE -eq 0 ]; then
        echo "Location shortcut executed successfully, extracting data..."
        # Simplified extraction approach using grep and sed
        LAT=$(grep -o '"latitude":"[^"]*"' "$TEMP_OUTPUT" | sed 's/"latitude":"//;s/"//g' | tr -d '\n\r' | xargs)
        LON=$(grep -o '"longitude":"[^"]*"' "$TEMP_OUTPUT" | sed 's/"longitude":"//;s/"//g' | tr -d '\n\r' | xargs)
        LOCALITY=$(grep -o '"locality":[[:space:]]*"[^"]*"' "$TEMP_OUTPUT" | sed 's/"locality":[[:space:]]*"//;s/"//g' | tr -d '\n\r' | xargs)
        ADMIN_AREA=$(grep -o '"administrativeArea":[[:space:]]*"[^"]*"' "$TEMP_OUTPUT" | sed 's/"administrativeArea":[[:space:]]*"//;s/"//g' | tr -d '\n\r' | xargs)
        POSTAL_CODE=$(grep -o '"postalCode":[[:space:]]*"[^"]*"' "$TEMP_OUTPUT" | sed 's/"postalCode":[[:space:]]*"//;s/"//g' | tr -d '\n\r' | xargs)
        COUNTRY=$(grep -o '"country":[[:space:]]*"[^"]*"' "$TEMP_OUTPUT" | sed 's/"country":[[:space:]]*"//;s/"//g' | tr -d '\n\r' | xargs)
        
        echo "Extracted data - LAT: ${LAT:-none}, LON: ${LON:-none}, LOCALITY: ${LOCALITY:-none}, ADMIN_AREA: ${ADMIN_AREA:-none}"
        
        # Special handling for subLocality - extract the first line/word
        local SUB_LOC_LINE=$(grep -n '"subLocality":' "$TEMP_OUTPUT" | cut -d':' -f1)
        if [ -n "$SUB_LOC_LINE" ]; then
            # Get the line and extract just the first word after the opening quote
            SUBLOCALITY=$(sed -n "${SUB_LOC_LINE}p" "$TEMP_OUTPUT" | sed -E 's/.*"subLocality":[[:space:]]*"([^[:space:]^"]+).*/\1/')
            echo "Extracted sublocality: ${SUBLOCALITY:-none}"
        else
            echo "No subLocality found in location data"
        fi
        
        # Set defaults for any missing fields
        : ${LOCALITY:="Unknown"}
        : ${ADMIN_AREA:="Unknown"}
        : ${POSTAL_CODE:="Unknown"} 
        : ${COUNTRY:="Unknown"}
        : ${SUBLOCALITY:="Unknown"}
        
        if [ -n "$LAT" ] && [ -n "$LON" ]; then
            LOCATION_STATUS="Location data available"
            echo "Successfully extracted coordinates: $LAT, $LON"
        else
            echo "Warning: Could not extract location coordinates from shortcut output."
            echo "Raw output first 100 chars: $(head -c 100 "$TEMP_OUTPUT")"
            LOCATION_STATUS="Location coordinates unavailable"
        fi
    else
        echo "Error: Location shortcut failed with exit code $SHORTCUT_EXIT_CODE"
        LOCATION_STATUS="Location shortcut failed"
        
        # If shortcut failed but we have network info, save it and return success
        if [ -n "$formatted_output" ]; then
            echo "Location data unavailable - Shortcut failed" > "$TARGET_DIR/location_output.txt"
            echo "$formatted_output" >> "$TARGET_DIR/location_output.txt"
            echo "Saved network information without location data"
            return 0
        fi
    fi
    
    # Prepare location output based on if we have coordinates
    local location_info=""
    if [ -n "$LAT" ] && [ -n "$LON" ]; then
        # Generate Apple Maps link
        local MAP_LINK="https://maps.apple.com/?q=$LAT,$LON&ll=$LAT,$LON"
        
        # Format the location information
        location_info=$(cat <<EOF
Location Details

Locality: $LOCALITY
Sub-locality: $SUBLOCALITY
Administrative Area: $ADMIN_AREA
Postal Code: $POSTAL_CODE
Country: $COUNTRY

Coordinates

Latitude: $LAT
Longitude: $LON

Time

Local Time: $(date "+%Y-%m-%d %H:%M:%S %z")
Time Zone: $(date +%Z)

Apple Maps Link
$MAP_LINK
EOF
)
    else
        # Basic location status if no coordinates
        location_info=$(cat <<EOF
Location Details

Status: $LOCATION_STATUS

Time

Local Time: $(date "+%Y-%m-%d %H:%M:%S %z")
Time Zone: $(date +%Z)
EOF
)
    fi
    
    # Prepend location info to our output
    formatted_output="${location_info}${formatted_output}"
    
    # Save the combined information
    echo "$formatted_output" > "$TARGET_DIR/location_output.txt"

    # Return success unless both location and network info failed
    if [ -n "$LAT" ] || [ -n "$formatted_output" ]; then
        echo "Data capture completed successfully."
        return 0
    else
        echo "Both location and network data capture failed."
        return 1
    fi
}

#############################
# Function: Capture Location (Router Function)
#############################
capture_location() {
    if [ "$LOCATION_ENABLED" != "yes" ]; then
        echo "Location capture disabled in configuration."
        return 1
    fi
    
    # Route to the appropriate location capture method based on configuration
    if [ "$LOCATION_METHOD" = "corelocation_cli" ]; then
        capture_location_cli
        return $?
    elif [ "$LOCATION_METHOD" = "apple_shortcuts" ]; then
        capture_location_shortcuts
        return $?
    else
        echo "Unknown location method: $LOCATION_METHOD. Defaulting to CoreLocationCLI."
        capture_location_cli
        return $?
    fi
}

#############################
# NEW Function: Capture Location If Email Disabled
#############################
capture_location_if_email_disabled() {
    if [ "$EMAIL_ENABLED" != "yes" ] && [ "$LOCATION_ENABLED" = "yes" ]; then
        echo "Email disabled but location tracking enabled. Capturing location data independently..."
        # Wait a few seconds to allow network to reconnect if needed
        sleep 3
        
        if check_internet; then
            capture_location
        else
            echo "Cannot capture location: No internet connection available."
            echo "Location data unavailable - no internet connection" > "$TARGET_DIR/location_output.txt"
        fi
    fi
}

#############################
# NEW Function: Ensure Network Info Is Available
#############################
ensure_network_info() {
    if [ "$NETWORK_INFO_ENABLED" = "yes" ]; then
        # Check if network info is already in location_output.txt
        if [ -f "$TARGET_DIR/location_output.txt" ] && grep -q "Network Information" "$TARGET_DIR/location_output.txt"; then
            echo "Network information already exists in location data" >&2
            return 0
        fi
        
        echo "Collecting network information separately..." >&2
        local network_info=$(collect_network_info)
        
        # If location file exists, append network info
        if [ -f "$TARGET_DIR/location_output.txt" ]; then
            echo "Appending network information to existing location data" >&2
            echo "$network_info" >> "$TARGET_DIR/location_output.txt"
        else
            # Create a minimal location file with just network info
            echo "Creating new location data file with network information" >&2
            cat > "$TARGET_DIR/location_output.txt" << EOF
Location Details

Status: Location data unavailable

Time

Local Time: $(date "+%Y-%m-%d %H:%M:%S %z")
Time Zone: $(date +%Z)
$network_info
EOF
        fi
        return 0
    fi
    return 1
}

#############################
# Utility Functions: Queue Emails
#############################
queue_initial_email() {
    local photo="$1"
    local screenshot="$2"
    local photo_utc="$3"
    local photo_local="$4"
    local shot_utc="$5"
    local shot_local="$6"
    
    # Copy files to attachments directory with session ID
    local photo_copy="$ATTACHMENTS_DIR/photo_${SESSION_ID}.jpg"
    local screenshot_copy="$ATTACHMENTS_DIR/screenshot_${SESSION_ID}.jpg"
    
    # Only copy if files exist and have content
    if [ -f "$photo" ] && [ -s "$photo" ]; then
        cp "$photo" "$photo_copy"
        echo "Copied photo to $photo_copy" >&2
    else
        photo_copy=""
    fi
    
    if [ -f "$screenshot" ] && [ -s "$screenshot" ]; then
        cp "$screenshot" "$screenshot_copy"
        echo "Copied screenshot to $screenshot_copy" >&2
    else
        screenshot_copy=""
    fi
    
    local filename="$MAIL_QUEUE_DIR/initial_${SESSION_ID}_$$.mail"
    echo "initial|$photo_copy|$screenshot_copy|$photo_utc|$photo_local|$shot_utc|$shot_local" > "$filename"
    echo "Queued initial email: $filename"
}

queue_followup_email() {
    # Check if follow-up email was already sent
    if [ -f "$TARGET_DIR/.followup_email_sent" ]; then
        echo "Follow-up email was already sent. Not queuing another one."
        return 1
    fi
    
    local screenshot="$1"
    local shot_utc="$2"
    local shot_local="$3"
    
    # Copy file to attachments directory with session ID
    local screenshot_copy="$ATTACHMENTS_DIR/followup_screenshot_${SESSION_ID}.jpg"
    
    # Only copy if file exists and has content
    if [ -f "$screenshot" ] && [ -s "$screenshot" ]; then
        cp "$screenshot" "$screenshot_copy"
        echo "Copied follow-up screenshot to $screenshot_copy" >&2
    else
        screenshot_copy=""
    fi
    
    local filename="$MAIL_QUEUE_DIR/followup_${SESSION_ID}_$$.mail"
    echo "followup|$screenshot_copy|$shot_utc|$shot_local" > "$filename"
    echo "Queued follow-up email: $filename"
}

#############################
# Functions: Sending Emails from Queue
#############################
send_initial_email_from_queue() {
    if [ "$EMAIL_ENABLED" != "yes" ]; then
        echo "Email notifications disabled in configuration."
        return 1
    fi
    
    if [ "$INITIAL_EMAIL_ENABLED" != "yes" ]; then
        echo "Initial email notifications disabled in configuration."
        return 1
    fi
    
    # Add validation check for email configuration
    if ! validate_email_config; then
        return 1
    fi
    
    if ! is_email_day_allowed; then
        echo "Email not allowed on $CURRENT_DAY per day restriction settings."
        return 1
    fi
    
    if ! is_email_time_allowed; then
        echo "Email not allowed at current time per time restriction settings."
        return 1
    fi
    
    local photo="$1"
    local screenshot="$2"
    local photo_utc="$3"
    local photo_local="$4"
    local shot_utc="$5"
    local shot_local="$6"

    local photo_has_failed=false
    local screenshot_has_failed=false
    
    if [ ! -f "$photo" ] || [ ! -s "$photo" ]; then
        photo_has_failed=true
    fi
    
    if [ ! -f "$screenshot" ] || [ ! -s "$screenshot" ]; then
        screenshot_has_failed=true
    fi

    # With internet connectivity available (queue processor), capture fresh location
    if [ "$LOCATION_ENABLED" = "yes" ]; then
        capture_location
    fi
    
    # Always ensure network info is available if enabled
    if [ "$NETWORK_INFO_ENABLED" = "yes" ]; then
        ensure_network_info
    fi

    local current_time=$(date '+%I:%M:%S %p')
    local email_subject="Mac Watcher Alert - ${CURRENT_USER} at ${HR_TIME}"
    
    local temp_json="$TARGET_DIR/.temp_email.json"
    
    # Determine if we should use HTML email
    if [ "$HTML_EMAIL_ENABLED" = "yes" ]; then
        # Generate HTML email content
        local email_html=$(generate_html_initial_email "$CURRENT_USER" "$photo_local" "$shot_local")
        
        # Create JSON with HTML content
        cat > "$temp_json" << EOF
{
  "from": "Mac Watcher <${EMAIL_FROM}>",
  "to": "${EMAIL_TO}",
  "subject": "${email_subject}",
  "reply_to": "${EMAIL_FROM}",
  "html": $(printf '%s' "$email_html" | jq -Rs .)
EOF
    else
        # Get location information for plain text email
        local location_info="Location tracking Disabled"
        if [ "$LOCATION_ENABLED" = "yes" ] && [ -f "$TARGET_DIR/location_output.txt" ] && [ -s "$TARGET_DIR/location_output.txt" ]; then
            location_info=$(cat "$TARGET_DIR/location_output.txt")
        else
            location_info="Location data unavailable"
        fi

        # Build email body with plain text format
        local email_body="Mac Watcher Alert

User Information
User: ${CURRENT_USER}

Media Status
"
        
        # Display photo timestamp (or Not available)
        if [ "$WEBCAM_ENABLED" != "yes" ]; then
            email_body+="Photo timestamp: Disabled
"
        elif [ "$photo_has_failed" = true ]; then
            email_body+="Photo timestamp: Not available
"
        else
            email_body+="Photo timestamp: ${photo_local} (Local) / ${photo_utc} (UTC)
"
        fi
        
        # Display screenshot timestamp (or Not available)
        if [ "$SCREENSHOT_ENABLED" != "yes" ]; then
            email_body+="Screenshot timestamp: Disabled
"
        elif [ "$screenshot_has_failed" = true ]; then
            email_body+="Screenshot timestamp: Not available
"
        else
            email_body+="Screenshot timestamp: ${shot_local} (Local) / ${shot_utc} (UTC)
"
        fi
        
        # Add location information
        email_body+="
Location Information
${location_info}"

        # Add network information status
        if [ "$NETWORK_INFO_ENABLED" != "yes" ]; then
            email_body+="

Network Information
WiFi SSID: Disabled
Local IP Address: Disabled
Public IP Address: Disabled"
        fi
        
        # Create email JSON with proper escaping
        local escaped_body=$(echo "$email_body" | sed 's/"/\\"/g' | sed 's/$/\\n/g' | tr -d '\n')
        
        # Setup JSON with plain text content
        cat > "$temp_json" << EOF
{
  "from": "Mac Watcher <${EMAIL_FROM}>",
  "to": "${EMAIL_TO}",
  "subject": "${email_subject}",
  "reply_to": "${EMAIL_FROM}",
  "text": "${escaped_body}"
EOF
    fi

    # Add attachments only if available (same for both HTML and plain text)
    if ([ "$WEBCAM_ENABLED" = "yes" ] && [ -f "$photo" ] && [ -s "$photo" ]) || ([ "$SCREENSHOT_ENABLED" = "yes" ] && [ -f "$screenshot" ] && [ -s "$screenshot" ]); then
        echo "," >> "$temp_json"
        echo "  \"attachments\": [" >> "$temp_json"
        
        local attachment_count=0
        
        if [ "$WEBCAM_ENABLED" = "yes" ] && [ -f "$photo" ] && [ -s "$photo" ]; then
            local photo_data
            photo_data=$(base64 < "$photo" | tr -d '\n')
            echo "    {" >> "$temp_json"
            echo "      \"filename\": \"webcam.jpg\"," >> "$temp_json"
            echo "      \"content\": \"${photo_data}\"" >> "$temp_json"
            echo "    }" >> "$temp_json"
            attachment_count=$((attachment_count + 1))
        fi
        
        if [ "$SCREENSHOT_ENABLED" = "yes" ] && [ -f "$screenshot" ] && [ -s "$screenshot" ]; then
            if [ $attachment_count -gt 0 ]; then
                echo "    ," >> "$temp_json"
            fi
            local screenshot_data
            screenshot_data=$(base64 < "$screenshot" | tr -d '\n')
            echo "    {" >> "$temp_json"
            echo "      \"filename\": \"screen.jpg\"," >> "$temp_json"
            echo "      \"content\": \"${screenshot_data}\"" >> "$temp_json"
            echo "    }" >> "$temp_json"
        fi
        
        echo "  ]" >> "$temp_json"
    fi
    
    echo "}" >> "$temp_json"
    
    # Save JSON for debugging
    save_json_debug "$temp_json" "$TARGET_DIR/debug_initial_email.json"

    echo "Sending initial email to ${EMAIL_TO} from ${EMAIL_FROM}..."
    local response
    response=$(curl -s -w "%{http_code}" -X POST \
       -H "Authorization: Bearer ${RESEND_API_KEY}" \
       -H "Content-Type: application/json" \
       --data-binary "@$temp_json" \
       "https://api.resend.com/emails")
    rm -f "$temp_json"

    local http_code=${response: -3}
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        echo "Initial email sent successfully. HTTP code: $http_code"
        echo "$email_subject" > "$TARGET_DIR/.subject"
        initial_email_sent=true
        # Create a flag file to indicate initial email was sent
        touch "$TARGET_DIR/.initial_email_sent"
        return 0
    else
        echo "Failed to send initial email. Status code: $http_code"
        echo "Response: ${response%???}"
        echo "Check your Resend API key and email configuration"
        return 1
    fi
}

send_followup_email_from_queue() {
    if [ "$EMAIL_ENABLED" != "yes" ] || [ "$FOLLOWUP_EMAIL_ENABLED" != "yes" ]; then
        echo "Email notifications or follow-up emails disabled in configuration."
        return 1
    fi
    
    # Check if follow-up email was already sent by looking for the flag file
    if [ -f "$TARGET_DIR/.followup_email_sent" ]; then
        echo "Follow-up email was already sent. Skipping duplicate."
        return 1
    fi
    
    # Add validation check for email configuration
    if ! validate_email_config; then
        return 1
    fi
    
    # Check if initial email was sent by looking for the flag file
    if [ ! -f "$TARGET_DIR/.initial_email_sent" ] && [ "$initial_email_sent" != "true" ]; then
        echo "Initial email was not sent. Skipping follow-up email."
        return 1
    fi
    
    if ! is_email_day_allowed; then
        echo "Email not allowed on $CURRENT_DAY per day restriction settings."
        return 1
    fi
    
    if ! is_email_time_allowed; then
        echo "Email not allowed at current time per time restriction settings."
        return 1
    fi
    
    local screenshot="$1"
    local shot_utc="$2"
    local shot_local="$3"
    
    # Always ensure network info is available if enabled
    if [ "$NETWORK_INFO_ENABLED" = "yes" ]; then
        ensure_network_info
    fi
    
    local original_subject=""
    if [ -f "$TARGET_DIR/.subject" ]; then
        original_subject=$(cat "$TARGET_DIR/.subject")
    else
        original_subject="Mac Watcher Alert - ${CURRENT_USER}"
    fi

    local screenshot_has_failed=false
    if [ ! -f "$screenshot" ] || [ ! -s "$screenshot" ]; then
        screenshot_has_failed=true
    fi

    local temp_json="$TARGET_DIR/.temp_followup.json"
    
    # Determine if we should use HTML email
    if [ "$HTML_EMAIL_ENABLED" = "yes" ]; then
        # Generate HTML email content
        local email_html=$(generate_html_followup_email "$CURRENT_USER" "$shot_local")
        
        # Create JSON with HTML content
        cat > "$temp_json" << EOF
{
  "from": "Mac Watcher <${EMAIL_FROM}>",
  "to": "${EMAIL_TO}",
  "subject": "Re: ${original_subject}",
  "reply_to": "${EMAIL_FROM}",
  "html": $(printf '%s' "$email_html" | jq -Rs .)
EOF
    else
        # Get location information for plain text
        local location_info="Location tracking Disabled"
        if [ "$LOCATION_ENABLED" = "yes" ] && [ -f "$TARGET_DIR/location_output.txt" ] && [ -s "$TARGET_DIR/location_output.txt" ]; then
            location_info=$(cat "$TARGET_DIR/location_output.txt")
        else
            location_info="Location data unavailable"
        fi
        
        # Build email body with plain text
        local email_body="Follow-up Screenshot

User Information
User: ${CURRENT_USER}

Media Status
"
        
        # Display screenshot timestamp (or Not available)
        if [ "$SCREENSHOT_ENABLED" != "yes" ] || [ "$FOLLOWUP_SCREENSHOT_ENABLED" != "yes" ]; then
            email_body+="Follow-up Screenshot timestamp: Disabled
"
        elif [ "$screenshot_has_failed" = true ]; then
            email_body+="Follow-up Screenshot timestamp: Not available
"
        else
            email_body+="Follow-up Screenshot timestamp: ${shot_local} (Local) / ${shot_utc} (UTC)
"
        fi
        
        # Add location information
        email_body+="
Location Information
${location_info}"

        # Add network information status
        if [ "$NETWORK_INFO_ENABLED" != "yes" ]; then
            email_body+="

Network Information
WiFi SSID: Disabled
Local IP Address: Disabled
Public IP Address: Disabled"
        fi
        
        # Create email JSON with proper escaping
        local escaped_body=$(echo "$email_body" | sed 's/"/\\"/g' | sed 's/$/\\n/g' | tr -d '\n')
        
        # Create the base JSON structure
        cat > "$temp_json" << EOF
{
  "from": "Mac Watcher <${EMAIL_FROM}>",
  "to": "${EMAIL_TO}",
  "subject": "Re: ${original_subject}",
  "reply_to": "${EMAIL_FROM}",
  "text": "${escaped_body}"
EOF
    fi
    
    # Only add screenshot if available and enabled in config
    if [ "$SCREENSHOT_ENABLED" = "yes" ] && [ -f "$screenshot" ] && [ -s "$screenshot" ]; then
        local screenshot_data
        screenshot_data=$(base64 < "$screenshot" | tr -d '\n')
        echo "," >> "$temp_json"
        cat >> "$temp_json" << EOF
  "attachments": [
    {
      "filename": "follow_up_screen.jpg",
      "content": "${screenshot_data}"
    }
  ]
EOF
    fi
    
    # Close the JSON object
    echo "}" >> "$temp_json"
    
    # Save JSON for debugging
    save_json_debug "$temp_json" "$TARGET_DIR/debug_followup_email.json"

    echo "Sending follow-up email"
    local response
    response=$(curl -s -w "%{http_code}" -X POST \
      -H "Authorization: Bearer ${RESEND_API_KEY}" \
      -H "Content-Type: application/json" \
      --data-binary "@$temp_json" \
      "https://api.resend.com/emails")
    rm -f "$temp_json"

    local http_code=${response: -3}
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        echo "Follow-up email sent successfully. HTTP code: $http_code"
        # Create a flag file to indicate follow-up email was sent
        touch "$TARGET_DIR/.followup_email_sent"
        return 0
    else
        echo "Failed to send follow-up email. Status code: $http_code"
        echo "Response: ${response%???}"
        echo "Check your Resend API key and email configuration"
        return 1
    fi
}

process_mail_queue() {
    echo "Starting mail queue processor..."
    
    # Check if email is disabled - if so, clear the queue and exit
    if [ "$EMAIL_ENABLED" != "yes" ]; then
        echo "Email notifications are disabled. Clearing mail queue..."
        rm -f "$MAIL_QUEUE_DIR"/*
        echo "Mail queue cleared."
        return 0
    fi
    
    # Add validation check for email configuration
    if ! validate_email_config; then
        echo "Email configuration is incomplete. Skipping mail queue processing."
        return 1
    fi
    
    local max_queue_attempts=30
    local attempts=0
    
    while [ $attempts -lt $max_queue_attempts ]; do
        if check_internet; then
            # First process any initial emails
            for mail_file in $(ls "$MAIL_QUEUE_DIR"/initial_* 2>/dev/null | sort); do
                fullpath="$mail_file"
                IFS='|' read -r mail_type rest <<< "$(cat "$fullpath")"
                if [ "$mail_type" = "initial" ]; then
                    IFS='|' read -r _ photo screenshot photo_utc photo_local shot_utc shot_local < "$fullpath"
                    echo "Attempting queued initial email from $mail_file"
                    
                    # Check if initial emails are enabled before sending
                    if [ "$INITIAL_EMAIL_ENABLED" = "yes" ]; then
                        if send_initial_email_from_queue "$photo" "$screenshot" "$photo_utc" "$photo_local" "$shot_utc" "$shot_local"; then
                            echo "Queued initial email sent successfully: $mail_file"
                            rm -f "$fullpath"
                            initial_email_sent=true
                        else
                            echo "Failed to send queued initial email: $mail_file"
                        fi
                    else
                        echo "Initial emails are disabled in configuration. Removing from queue: $mail_file"
                        rm -f "$fullpath"
                    fi
                fi
            done
            
            # Only process follow-up emails if initial email was sent (based on flag file)
            if [ -f "$TARGET_DIR/.initial_email_sent" ] || [ "$initial_email_sent" = "true" ]; then
                for mail_file in $(ls "$MAIL_QUEUE_DIR"/followup_* 2>/dev/null | sort); do
                    fullpath="$mail_file"
                    IFS='|' read -r mail_type rest <<< "$(cat "$fullpath")"
                    if [ "$mail_type" = "followup" ]; then
                        IFS='|' read -r _ screenshot shot_utc shot_local < "$fullpath"
                        echo "Attempting queued follow-up email from $mail_file"
                        if send_followup_email_from_queue "$screenshot" "$shot_utc" "$shot_local"; then
                            echo "Queued follow-up email sent successfully: $mail_file"
                            rm -f "$fullpath"
                        else
                            echo "Failed to send queued follow-up email: $mail_file"
                        fi
                    fi
                done
            else
                echo "Initial email not sent yet. Skipping follow-up email processing."
            fi
        fi
        
        # Exit loop if queue is empty
        if [ -z "$(ls "$MAIL_QUEUE_DIR" 2>/dev/null)" ]; then
            break
        fi
        
        attempts=$((attempts + 1))
        if [ $attempts -ge $max_queue_attempts ]; then
            echo "Reached maximum queue processing attempts ($max_queue_attempts). Some emails may remain in queue."
            break
        fi
        
        sleep 10
    done
    echo "Mail queue processor finished."
}

#############################
# Capture Functions: Media Capture
#############################
cleanup_camera() {
    if pgrep imagesnap > /dev/null; then
        pkill -9 imagesnap 2>/dev/null || true
        sleep 1
    fi
}

check_camera() {
    if system_profiler SPCameraDataType 2>&1 | grep -q "No Camera Found"; then
        return 1
    fi
    return 0
}

capture_photo() {
    if [ "$WEBCAM_ENABLED" != "yes" ]; then
        echo "Webcam capture disabled in configuration."
        return 1
    fi
    
    local photo_path="$1"
    local max_retries=3
    local retry_count=0
    
    echo "Checking for active camera processes..."
    cleanup_camera
    
    while [ $retry_count -lt $max_retries ]; do
        if check_camera; then
            echo "Camera detected, attempting to capture photo (attempt $((retry_count + 1))/$max_retries)..."
            if timeout 10 imagesnap -w 2 "$photo_path" && [ -s "$photo_path" ]; then
                PHOTO_UTC_CAPTURE=$(date -u '+%Y-%m-%d %H:%M:%S')
                PHOTO_LOCAL_CAPTURE=$(date '+%I:%M:%S %p')
                echo "Photo captured successfully at ${PHOTO_UTC_CAPTURE} UTC (${PHOTO_LOCAL_CAPTURE})"
                echo "Photo saved to: $photo_path ($(du -h "$photo_path" | cut -f1) bytes)"
                cleanup_camera
                return 0
            else
                echo "Photo capture attempt $((retry_count + 1)) failed"
            fi
        else
            echo "No camera detected on attempt $((retry_count + 1))"
        fi
        
        echo "Cleaning up camera and waiting before retry..."
        cleanup_camera
        sleep 2
        retry_count=$((retry_count + 1))
    done
    
    echo "Failed to capture photo after ${max_retries} attempts" >&2
    echo "Please check if camera is connected and permissions are granted"
    # Set default timestamp even when capture fails
    PHOTO_UTC_CAPTURE=$(date -u '+%Y-%m-%d %H:%M:%S')
    PHOTO_LOCAL_CAPTURE="Not available (capture failed)"
    return 1
}

capture_screenshot() {
    if [ "$SCREENSHOT_ENABLED" != "yes" ]; then
        echo "Screenshot capture disabled in configuration."
        return 1
    fi
    
    local screenshot_path="$1"
    local temp_path="${screenshot_path}.temp.png"
    
    echo "Attempting to capture screenshot..."
    if screencapture -x "$temp_path"; then
        echo "Raw screenshot captured, processing image..."
        if sips -s format jpeg "$temp_path" --out "$screenshot_path" >/dev/null 2>&1 &&
           sips -Z 1024 "$screenshot_path" >/dev/null 2>&1; then
            echo "Screenshot processed and resized successfully"
            echo "Screenshot saved to: $screenshot_path ($(du -h "$screenshot_path" | cut -f1) bytes)"
            rm -f "$temp_path"
            SCREENSHOT_UTC_CAPTURE=$(date -u '+%Y-%m-%d %H:%M:%S')
            SCREENSHOT_LOCAL_CAPTURE=$(date '+%I:%M:%S %p')
            echo "Screenshot captured successfully at ${SCREENSHOT_UTC_CAPTURE} UTC (${SCREENSHOT_LOCAL_CAPTURE})"
            return 0
        else
            echo "Failed to process screenshot with sips" >&2
            echo "Check if sips is available and has proper permissions"
        fi
    else
        echo "Failed to capture screenshot with screencapture command" >&2
        echo "Check if screencapture is available and has proper permissions"
    fi
    
    echo "Failed to capture or process screenshot" >&2
    # Set default timestamp even when capture fails
    SCREENSHOT_UTC_CAPTURE=$(date -u '+%Y-%m-%d %H:%M:%S')
    SCREENSHOT_LOCAL_CAPTURE="Not available (capture failed)"
    return 1
}

#############################
# Functions: Sending Immediate Emails
#############################
send_initial_email() {
    if [ "$EMAIL_ENABLED" != "yes" ]; then
        echo "Email notifications disabled in configuration."
        return 1
    fi
    
    if [ "$INITIAL_EMAIL_ENABLED" != "yes" ]; then
        echo "Initial email notifications disabled in configuration."
        return 1
    fi
    
    # Add validation check for email configuration
    if ! validate_email_config; then
        return 1
    fi
    
    if ! is_email_day_allowed; then
        echo "Email not allowed on $CURRENT_DAY per day restriction settings."
        return 1
    fi
    
    if ! is_email_time_allowed; then
        echo "Email not allowed at current time per time restriction settings."
        return 1
    fi
    
    local photo="$1"
    local screenshot="$2"
    
    # Check internet connectivity before sending email.
    if check_internet; then
        # Run the location capture since internet is available.
        if [ "$LOCATION_ENABLED" = "yes" ]; then
            capture_location
        fi
        
        # Always ensure network info is available if enabled
        if [ "$NETWORK_INFO_ENABLED" = "yes" ]; then
            ensure_network_info
        fi
    fi
    
    local photo_has_failed=false
    local screenshot_has_failed=false
    
    if [ ! -f "$photo" ] || [ ! -s "$photo" ]; then
        photo_has_failed=true
    fi
    
    if [ ! -f "$screenshot" ] || [ ! -s "$screenshot" ]; then
        screenshot_has_failed=true
    fi

    local current_time=$(date '+%I:%M:%S %p')
    local email_subject="Mac Watcher Alert - ${CURRENT_USER} at ${HR_TIME}"
    
    local temp_json="$TARGET_DIR/.temp_email.json"
    
    # Determine if we should use HTML email
    if [ "$HTML_EMAIL_ENABLED" = "yes" ]; then
        # Generate HTML email content
        local email_html=$(generate_html_initial_email "$CURRENT_USER" "$PHOTO_LOCAL_CAPTURE" "$SCREENSHOT_LOCAL_CAPTURE")
        
        # Create JSON with HTML content
        cat > "$temp_json" << EOF
{
  "from": "Mac Watcher <${EMAIL_FROM}>",
  "to": "${EMAIL_TO}",
  "subject": "${email_subject}",
  "reply_to": "${EMAIL_FROM}",
  "html": $(printf '%s' "$email_html" | jq -Rs .)
EOF
    else
        # Get location information for plain text
        local location_info="Location tracking Disabled"
        if [ "$LOCATION_ENABLED" = "yes" ]; then
            if check_internet; then
                if [ -f "$TARGET_DIR/location_output.txt" ] && [ -s "$TARGET_DIR/location_output.txt" ]; then
                    location_info=$(cat "$TARGET_DIR/location_output.txt")
                else
                    location_info="Location data unavailable"
                fi
            else
                location_info="Location data unavailable - no internet connection"
            fi
        fi

        # Build email body with plain text format
        local email_body="Mac Watcher Alert

User Information
User: ${CURRENT_USER}

Media Status
"
        
        # Display photo timestamp (or Not available)
        if [ "$WEBCAM_ENABLED" != "yes" ]; then
            email_body+="Photo timestamp: Disabled
"
        elif [ "$photo_has_failed" = true ]; then
            email_body+="Photo timestamp: Not available
"
        else
            email_body+="Photo timestamp: ${PHOTO_LOCAL_CAPTURE} (Local) / ${PHOTO_UTC_CAPTURE} (UTC)
"
        fi
        
        # Display screenshot timestamp (or Not available)
        if [ "$SCREENSHOT_ENABLED" != "yes" ]; then
            email_body+="Screenshot timestamp: Disabled
"
        elif [ "$screenshot_has_failed" = true ]; then
            email_body+="Screenshot timestamp: Not available
"
        else
            email_body+="Screenshot timestamp: ${SCREENSHOT_LOCAL_CAPTURE} (Local) / ${SCREENSHOT_UTC_CAPTURE} (UTC)
"
        fi
        
        # Add location information
        email_body+="
Location Information
${location_info}"

        # Add network information status
        if [ "$NETWORK_INFO_ENABLED" != "yes" ]; then
            email_body+="

Network Information
WiFi SSID: Disabled
Local IP Address: Disabled
Public IP Address: Disabled"
        fi

        # Create email JSON with proper escaping
        local escaped_body=$(echo "$email_body" | sed 's/"/\\"/g' | sed 's/$/\\n/g' | tr -d '\n')
        
        # Setup JSON with plain text content
        cat > "$temp_json" << EOF
{
  "from": "Mac Watcher <${EMAIL_FROM}>",
  "to": "${EMAIL_TO}",
  "subject": "${email_subject}",
  "reply_to": "${EMAIL_FROM}",
  "text": "${escaped_body}"
EOF
    fi

    # Add attachments only if available (same for both HTML and plain text)
    if ([ "$WEBCAM_ENABLED" = "yes" ] && [ -f "$photo" ] && [ -s "$photo" ]) || ([ "$SCREENSHOT_ENABLED" = "yes" ] && [ -f "$screenshot" ] && [ -s "$screenshot" ]); then
        echo "," >> "$temp_json"
        echo "  \"attachments\": [" >> "$temp_json"
        
        local attachment_count=0
        
        if [ "$WEBCAM_ENABLED" = "yes" ] && [ -f "$photo" ] && [ -s "$photo" ]; then
            local photo_data
            photo_data=$(base64 < "$photo" | tr -d '\n')
            echo "    {" >> "$temp_json"
            echo "      \"filename\": \"webcam.jpg\"," >> "$temp_json"
            echo "      \"content\": \"${photo_data}\"" >> "$temp_json"
            echo "    }" >> "$temp_json"
            attachment_count=$((attachment_count + 1))
        fi
        
        if [ "$SCREENSHOT_ENABLED" = "yes" ] && [ -f "$screenshot" ] && [ -s "$screenshot" ]; then
            if [ $attachment_count -gt 0 ]; then
                echo "    ," >> "$temp_json"
            fi
            local screenshot_data
            screenshot_data=$(base64 < "$screenshot" | tr -d '\n')
            echo "    {" >> "$temp_json"
            echo "      \"filename\": \"screen.jpg\"," >> "$temp_json"
            echo "      \"content\": \"${screenshot_data}\"" >> "$temp_json"
            echo "    }" >> "$temp_json"
        fi
        
        echo "  ]" >> "$temp_json"
    fi
    
    echo "}" >> "$temp_json"
    
    # Save JSON for debugging
    save_json_debug "$temp_json" "$TARGET_DIR/debug_initial_email.json"

    echo "Sending initial email"
    local response
    response=$(curl -s -w "%{http_code}" -X POST \
       -H "Authorization: Bearer ${RESEND_API_KEY}" \
       -H "Content-Type: application/json" \
       --data-binary "@$temp_json" \
       "https://api.resend.com/emails")
    rm -f "$temp_json"

    local http_code=${response: -3}
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        echo "Initial email sent successfully. HTTP code: $http_code"
        echo "$email_subject" > "$TARGET_DIR/.subject"
        initial_email_sent=true
        # Create a flag file to indicate initial email was sent
        touch "$TARGET_DIR/.initial_email_sent"
        return 0
    else
        echo "Failed to send initial email. Status code: $http_code"
        echo "Response: ${response%???}"
        echo "Check your Resend API key and email configuration"
        return 1
    fi
}

send_followup_email() {
    if [ "$EMAIL_ENABLED" != "yes" ] || [ "$FOLLOWUP_EMAIL_ENABLED" != "yes" ]; then
        echo "Email notifications or follow-up emails disabled in configuration."
        return 1
    fi
    
    # Check if follow-up email was already sent by looking for the flag file
    if [ -f "$TARGET_DIR/.followup_email_sent" ]; then
        echo "Follow-up email was already sent. Skipping duplicate."
        return 1
    fi
    
    # Add validation check for email configuration
    if ! validate_email_config; then
        return 1
    fi
    
    # Check if initial email was sent by looking for the flag file
    if [ ! -f "$TARGET_DIR/.initial_email_sent" ] && [ "$initial_email_sent" != "true" ]; then
        echo "Initial email was not sent. Skipping follow-up email."
        return 1
    fi
    
    if ! is_email_day_allowed; then
        echo "Email not allowed on $CURRENT_DAY per day restriction settings."
        return 1
    fi
    
    if ! is_email_time_allowed; then
        echo "Email not allowed at current time per time restriction settings."
        return 1
    fi
    
    local screenshot="$1"
    
    # Always ensure network info is available if enabled
    if [ "$NETWORK_INFO_ENABLED" = "yes" ] && check_internet; then
        ensure_network_info
    fi
    
    local original_subject=""
    if [ -f "$TARGET_DIR/.subject" ]; then
        original_subject=$(cat "$TARGET_DIR/.subject")
    else
        original_subject="Mac Watcher Alert - ${CURRENT_USER}"
    fi
    
    local screenshot_has_failed=false
    if [ ! -f "$screenshot" ] || [ ! -s "$screenshot" ]; then
        screenshot_has_failed=true
    fi
    
    local temp_json="$TARGET_DIR/.temp_followup.json"
    
    # Determine if we should use HTML email
    if [ "$HTML_EMAIL_ENABLED" = "yes" ]; then
        # Generate HTML email content
        local email_html=$(generate_html_followup_email "$CURRENT_USER" "$SCREENSHOT_LOCAL_CAPTURE")
        
        # Create JSON with HTML content
        cat > "$temp_json" << EOF
{
  "from": "Mac Watcher <${EMAIL_FROM}>",
  "to": "${EMAIL_TO}",
  "subject": "Re: ${original_subject}",
  "reply_to": "${EMAIL_FROM}",
  "html": $(printf '%s' "$email_html" | jq -Rs .)
EOF
    else
        # Get location information for plain text
        local location_info="Location tracking Disabled"
        if [ "$LOCATION_ENABLED" = "yes" ] && [ -f "$TARGET_DIR/location_output.txt" ] && [ -s "$TARGET_DIR/location_output.txt" ]; then
            location_info=$(cat "$TARGET_DIR/location_output.txt")
        else
            location_info="Location data unavailable"
        fi
        
        # Build email body with plain text
        local email_body="Follow-up Screenshot

User Information
User: ${CURRENT_USER}

Media Status
"
        
        # Display screenshot timestamp (or Not available)
        if [ "$SCREENSHOT_ENABLED" != "yes" ] || [ "$FOLLOWUP_SCREENSHOT_ENABLED" != "yes" ]; then
            email_body+="Follow-up Screenshot timestamp: Disabled
"
        elif [ "$screenshot_has_failed" = true ]; then
            email_body+="Follow-up Screenshot timestamp: Not available
"
        else
            email_body+="Follow-up Screenshot timestamp: ${SCREENSHOT_LOCAL_CAPTURE} (Local) / ${SCREENSHOT_UTC_CAPTURE} (UTC)
"
        fi
        
        # Add location information
        email_body+="
Location Information
${location_info}"

        # Add network information status
        if [ "$NETWORK_INFO_ENABLED" != "yes" ]; then
            email_body+="

Network Information
WiFi SSID: Disabled
Local IP Address: Disabled
Public IP Address: Disabled"
        fi
        
        # Create email JSON with proper escaping
        local escaped_body=$(echo "$email_body" | sed 's/"/\\"/g' | sed 's/$/\\n/g' | tr -d '\n')
        
        # Create base JSON structure
        cat > "$temp_json" << EOF
{
  "from": "Mac Watcher <${EMAIL_FROM}>",
  "to": "${EMAIL_TO}",
  "subject": "Re: ${original_subject}",
  "reply_to": "${EMAIL_FROM}",
  "text": "${escaped_body}"
EOF
    fi
    
    # Only add screenshot if available and enabled in config
    if [ "$SCREENSHOT_ENABLED" = "yes" ] && [ -f "$screenshot" ] && [ -s "$screenshot" ]; then
        local screenshot_data
        screenshot_data=$(base64 < "$screenshot" | tr -d '\n')
        echo "," >> "$temp_json"
        cat >> "$temp_json" << EOF
  "attachments": [
    {
      "filename": "follow_up_screen.jpg",
      "content": "${screenshot_data}"
    }
  ]
EOF
    fi
    
    # Close the JSON object
    echo "}" >> "$temp_json"
    
    # Save JSON for debugging
    save_json_debug "$temp_json" "$TARGET_DIR/debug_followup_email.json"

    echo "Sending follow-up email to ${EMAIL_TO} from ${EMAIL_FROM}..."
    local response
    response=$(curl -s -w "%{http_code}" -X POST \
       -H "Authorization: Bearer ${RESEND_API_KEY}" \
       -H "Content-Type: application/json" \
       --data-binary "@$temp_json" \
       "https://api.resend.com/emails")
    rm -f "$temp_json"

    local http_code=${response: -3}
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        echo "Follow-up email sent successfully. HTTP code: $http_code"
        # Create a flag file to indicate follow-up email was sent
        touch "$TARGET_DIR/.followup_email_sent"
        return 0
    else
        echo "Failed to send follow-up email. Status code: $http_code"
        echo "Response: ${response%???}"
        echo "Check your Resend API key and email configuration"
        return 1
    fi
}

#############################
# Schedule Check
#############################
# Check if we should run based on schedule
if [ "$CUSTOM_SCHEDULE_ENABLED" = "yes" ]; then
    if ! is_active_day; then
        echo "Today ($CURRENT_DAY) is not in active days schedule. Exiting."
        exit 0
    fi
    
    if ! is_active_time; then
        echo "Current time is not within any active time window. Exiting."
        exit 0
    fi
    
    echo "Schedule check passed. Continuing execution..."
fi

#############################
# Auto-Delete Old Files (Run before capturing new ones)
#############################
run_auto_delete

#############################
# Initial Delay
#############################
if [ "$INITIAL_DELAY" -gt 0 ]; then
    echo "Waiting for initial delay of $INITIAL_DELAY seconds..."
    sleep $INITIAL_DELAY
fi

#############################
# Login Detection
#############################
if [ "$LOGIN_FAILURE_DETECTION_ENABLED" = "yes" ]; then
    echo "Login detection enabled. Monitoring for login attempts..."
    
    # Set a timeout for the detection (in seconds)
    DETECTION_TIMEOUT=60
    
    # Variables for tracking login attempts
    success_count=0
    failed_count=0
    fingerprint_count=0
    password_count=0
    time_threshold=1
    last_success_time=0
    last_failed_time=0
    ACTUAL_USER=$(whoami)
    
    # Flag to track detection status
    login_detected=false
    login_success=false

    current_time_seconds() {
        date +%s
    }

    detect_auth_method() {
        local line="$1"
        local username="$2"

        if [[ "$username" == "admin" ]]; then
            echo "fingerprint/touch ID"
        elif [[ "$username" == "$ACTUAL_USER" ]]; then
            echo "password"
        elif [[ "$line" == *"_authSuccessUsingPassword"* || "$line" == *"with password"* || "$line" == *"password is CORRECT"* ]]; then
            echo "password"
        elif [[ "$line" == *"Screen saver unlocked by"* && "$line" != *"_authSuccessUsingPassword"* ]]; then
            echo "fingerprint/touch ID"
        elif [[ "$line" == *"biometric"* || "$line" == *"Touch ID"* ]]; then
            echo "fingerprint/touch ID"
        else
            echo "unknown method"
        fi
    }
    
    # Use process substitution to avoid creating a subshell that would lose variable changes
    # This technique allows us to read from log stream while maintaining variables in the main shell
    exec 3< <(log stream --predicate 'eventMessage CONTAINS "authSuccess" OR eventMessage CONTAINS "Failed to authenticate user" OR eventMessage CONTAINS "biometryFailed" OR eventMessage CONTAINS "Touch ID" OR eventMessage CONTAINS "LocalAuthentication" OR eventMessage CONTAINS "Authentication cancelled" OR eventMessage CONTAINS "unlock attempts"' --style syslog 2>/dev/null)
    
    # Create a temp file for timeout notification
    TIMEOUT_FILE=$(mktemp)
    
    # Start a timeout in background without using signals (no termination message)
    (
        sleep $DETECTION_TIMEOUT
        # Signal timeout by writing to a file instead of sending a signal
        echo "TIMEOUT" > "$TIMEOUT_FILE"
    ) >/dev/null 2>&1 &
    # Store timeout process ID
    timeout_pid=$!
    # Immediately disown it to prevent termination messages
    disown $timeout_pid
    
    echo "Waiting for login events (timeout: ${DETECTION_TIMEOUT} seconds)..."
    
    # Read log stream with timeout check
    while IFS= read -r line <&3 || [[ -n "$line" ]]; do
        # Check for timeout
        if [[ -s "$TIMEOUT_FILE" ]]; then
            # Timeout occurred
            echo "Detection timeout reached. No login events detected within $DETECTION_TIMEOUT seconds."
            timeout_triggered=true
            break
        fi
        
        # Skip filtering messages
        [[ "$line" == *"Filtering the log data"* ]] && continue
        
        current_time=$(current_time_seconds)
        log_timestamp=$(echo "$line" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" | head -1)
        [[ -z "$log_timestamp" ]] && log_timestamp=$(date "+%Y-%m-%d %H:%M:%S")
        
        if [[ "$line" == *"authSuccess"* ]]; then
            # Determine if this is a primary successful event
            if [[ "$line" == *"Screen saver unlocked by"* || "$line" == *"setting session authenticated flag"* || "$line" == *"Unlock succeeded"* || ( "$line" == *"password is CORRECT"* && "$line" != *"calling defaultScreenLockHandleUnlockResult"* ) ]]; then
                if (( current_time - last_success_time > time_threshold )); then
                    last_success_time=$current_time
                    username=$(echo "$line" | grep -oE "unlocked by [a-zA-Z0-9_-]+" | awk '{print $3}')
                    [[ -z "$username" ]] && username=$(whoami)
                    auth_method=$(detect_auth_method "$line" "$username")
                    if [[ "$auth_method" == "fingerprint/touch ID" ]]; then
                        ((fingerprint_count++))
                    elif [[ "$auth_method" == "password" ]]; then
                        ((password_count++))
                    fi
                    ((success_count++))
                    echo "[$log_timestamp] ✅ SUCCESS ($success_count): Login by $username using $auth_method"
                    
                    # Set flags and break the loop
                    login_detected=true
                    login_success=true
                    break
                fi
            fi
        elif [[ "$line" == *"Failed to authenticate user"* || "$line" == *"biometryFailed"* || "$line" == *"LocalAuthentication failed"* || "$line" == *"Touch ID authentication failed"* || ( "$line" == *"unlock attempts"* && "$line" != *"unlock attempts: 0"* ) || "$line" == *"Authentication cancelled"* ]]; then
            if (( current_time - last_failed_time > time_threshold )); then
                last_failed_time=$current_time
                auth_method="unknown method"
                [[ "$line" == *"Touch ID"* || "$line" == *"biometry"* ]] && auth_method="fingerprint/touch ID"
                [[ "$line" == *"password"* ]] && auth_method="password"
                ((failed_count++))
                echo "[$log_timestamp] ❌ FAILED ($failed_count): Authentication attempt failed ($auth_method)"
                
                # Set flag and break the loop
                login_detected=true
                login_success=false
                break
            fi
        fi
    done
    
    # Clean up
    exec 3<&-  # Close file descriptor

    # Remove timeout process without using kill (prevents termination message)
    timeout_triggered=false
    if [[ -s "$TIMEOUT_FILE" ]]; then
        timeout_triggered=true
    fi

    # Clean up the temp file
    rm -f "$TIMEOUT_FILE"

    # Check detection status and take appropriate action
    if $login_detected; then
        if $login_success; then
            echo "Successful login detected. Exiting as no security action needed."
            exit 0
        else
            echo "Failed login detected. Continuing with security monitoring actions..."
        fi
    else
        if $timeout_triggered; then
            echo "No login events detected within timeout period."
        else
            echo "Login detection completed without any events."
        fi
        echo "No login failures detected. Exiting script as per configuration."
        exit 0
    fi
fi

#############################
# Main Execution: Immediate Media Capture and Emailing
#############################
FILE_TIME_FORMAT=$(date +"_%a_%d_%b_%I-%M-%S_%p")
PHOTO_PATH="$TARGET_DIR/photo$FILE_TIME_FORMAT.jpg"
SCREENSHOT_PATH="$TARGET_DIR/screenshot$FILE_TIME_FORMAT.jpg"

echo "Starting photo capture..."
if capture_photo "$PHOTO_PATH"; then
    PHOTO_CAPTURED=true
else
    echo "Warning: Failed to capture initial photo"
    PHOTO_CAPTURED=false
fi

echo "Starting screenshot capture..."
if capture_screenshot "$SCREENSHOT_PATH"; then
    SCREENSHOT_CAPTURED=true
else
    echo "Warning: Failed to capture initial screenshot"
    SCREENSHOT_CAPTURED=false
fi

# Handle initial email if enabled - now works even with partial media
if [ "$EMAIL_ENABLED" = "yes" ] && [ "$INITIAL_EMAIL_ENABLED" = "yes" ]; then
    # Validate email configuration before trying to send or queue
    if validate_email_config; then
        # We now send email regardless of what media was captured
        if check_internet; then
            if send_initial_email "$PHOTO_PATH" "$SCREENSHOT_PATH"; then
                initial_email_sent=true
            else
                echo "Initial email failed; queuing for later."
                queue_initial_email "$PHOTO_PATH" "$SCREENSHOT_PATH" "$PHOTO_UTC_CAPTURE" "$PHOTO_LOCAL_CAPTURE" "$SCREENSHOT_UTC_CAPTURE" "$SCREENSHOT_LOCAL_CAPTURE"
            fi
        else
            echo "No internet available; queuing initial email."
            queue_initial_email "$PHOTO_PATH" "$SCREENSHOT_PATH" "$PHOTO_UTC_CAPTURE" "$PHOTO_LOCAL_CAPTURE" "$SCREENSHOT_UTC_CAPTURE" "$SCREENSHOT_LOCAL_CAPTURE"
        fi
    else
        echo "Email configuration is incomplete. Skipping initial email."
    fi
else
    if [ "$EMAIL_ENABLED" != "yes" ]; then
        echo "Email notifications disabled in configuration."
    else
        echo "Initial email notifications disabled in configuration."
    fi
    # Call new function to capture location if email is disabled
    capture_location_if_email_disabled
fi

#############################
# Follow-up Delay and Screenshot
#############################
# Only proceed with follow-up if either FOLLOWUP_EMAIL_ENABLED or FOLLOWUP_SCREENSHOT_ENABLED is yes
if ([ "$EMAIL_ENABLED" = "yes" ] && [ "$FOLLOWUP_EMAIL_ENABLED" = "yes" ]) || [ "$FOLLOWUP_SCREENSHOT_ENABLED" = "yes" ]; then
    echo "Waiting for follow-up delay of $FOLLOWUP_DELAY seconds..."
    sleep $FOLLOWUP_DELAY
    
    # Only capture followup screenshot if enabled
    if [ "$SCREENSHOT_ENABLED" = "yes" ] && [ "$FOLLOWUP_SCREENSHOT_ENABLED" = "yes" ]; then
        FILE_TIME_FORMAT=$(date +"_%a_%d_%b_%I-%M-%S_%p")
        SECOND_SCREENSHOT="$TARGET_DIR/screenshot$FILE_TIME_FORMAT.jpg"
        
        if capture_screenshot "$SECOND_SCREENSHOT"; then
            echo "Follow-up screenshot captured successfully."
            
            # Only handle email if emailing is enabled and config is valid
            if [ "$EMAIL_ENABLED" = "yes" ] && [ "$FOLLOWUP_EMAIL_ENABLED" = "yes" ]; then
                if validate_email_config; then
                    # Check if initial email was sent
                    if [ -f "$TARGET_DIR/.initial_email_sent" ] || [ "$initial_email_sent" = "true" ]; then
                        if check_internet; then
                            # Send follow-up email
                            send_followup_email "$SECOND_SCREENSHOT" || {
                                echo "Follow-up email failed; queuing for later."
                                queue_followup_email "$SECOND_SCREENSHOT" "$SCREENSHOT_UTC_CAPTURE" "$SCREENSHOT_LOCAL_CAPTURE"
                            }
                        else
                            echo "No internet available at follow-up time; queuing follow-up email."
                            queue_followup_email "$SECOND_SCREENSHOT" "$SCREENSHOT_UTC_CAPTURE" "$SCREENSHOT_LOCAL_CAPTURE"
                        fi
                    else
                        echo "Initial email was not sent. Skipping follow-up email."
                        # Queue the follow-up email anyway, it will only be sent if initial email gets sent
                        queue_followup_email "$SECOND_SCREENSHOT" "$SCREENSHOT_UTC_CAPTURE" "$SCREENSHOT_LOCAL_CAPTURE"
                        echo "Follow-up email queued but will only be sent after initial email."
                    fi
                else
                    echo "Email configuration is incomplete. Skipping follow-up email."
                fi
            else
                if [ "$EMAIL_ENABLED" != "yes" ]; then
                    echo "Follow-up email not sent because email notifications are disabled."
                elif [ "$FOLLOWUP_EMAIL_ENABLED" != "yes" ]; then
                    echo "Follow-up email disabled in configuration."
                fi
            fi
        else
            echo "Warning: Failed to capture follow-up screenshot."
        fi
    else
        echo "Follow-up screenshot disabled in configuration. Skipping."
    fi
else
    echo "Follow-up capture and email disabled. Skipping follow-up process."
fi

#############################
# Process Mail Queue
#############################
# Only process mail queue if emailing is enabled, config is valid, and there are files to process
if [ "$EMAIL_ENABLED" = "yes" ] && validate_email_config && [ -n "$(ls "$MAIL_QUEUE_DIR" 2>/dev/null)" ]; then
    process_mail_queue &
    echo "Mail queue processor started in background."
elif [ "$EMAIL_ENABLED" != "yes" ] && [ -n "$(ls "$MAIL_QUEUE_DIR" 2>/dev/null)" ]; then
    echo "Email notifications disabled. Clearing mail queue..."
    rm -f "$MAIL_QUEUE_DIR"/*
    echo "Mail queue cleared."
elif [ "$EMAIL_ENABLED" = "yes" ] && ! validate_email_config && [ -n "$(ls "$MAIL_QUEUE_DIR" 2>/dev/null)" ]; then
    echo "Email configuration is incomplete. Keeping mail queue for potential future processing."
else
    echo "No emails in queue, skipping queue processor."
fi

# Current user and time reporting
echo "Run by user: ${CURRENT_USER} at ${UTC_TIME} UTC"

UTC_COMPLETED=$(date -u '+%Y-%m-%d %H:%M:%S')
LOCAL_COMPLETED=$(date '+%Y-%m-%d %H:%M:%S')
echo "Script completed at ${UTC_COMPLETED} UTC (${LOCAL_COMPLETED})"

exit 0