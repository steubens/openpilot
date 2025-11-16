#!/bin/bash
# Custom opParams Default Override Script
#
# This script sets custom default values for opParams without modifying the code.
# It creates parameter files in /data/openpilot/community/params/ before OpenPilot
# initializes, so your custom values are used from first boot.
#
# The original defaults remain in common/op_params.py, so:
# - Code stays clean for updates/merges
# - Original values are still visible for reference
# - opParams CLI shows your values as "changed" with (C) marker
#
# To reapply or modify:
# 1. Edit the parameter values below
# 2. Increment the version number in MARKER variable (e.g., v1 -> v2)
# 3. Reboot the device
#

PARAMS_DIR="/data/openpilot/community/params"
MARKER="$PARAMS_DIR/.custom_defaults_v1"

# Only run once per version (increment version to re-apply)
if [ -f "$MARKER" ]; then
    exit 0
fi

# Create params directory if needed
mkdir -p "$PARAMS_DIR"

echo "Applying custom opParams defaults..."

# ============================================================================
# CUSTOM PARAMETER VALUES
# ============================================================================

# Misc Settings
echo '10' > "$PARAMS_DIR/MISC_offroad_shutdown_time_hr"
echo '12.0' > "$PARAMS_DIR/MISC_car_12v_pause_charging_v"

# Following Profile
echo '2.0' > "$PARAMS_DIR/FP_stop_distance_offset_m"

# Lane Change
echo '35.0' > "$PARAMS_DIR/LC_minimum_speed_mph"

# MADS One-Pedal Settings
echo '[-1.2, -1.1]' > "$PARAMS_DIR/MADS_OP_decel_ms2"
echo '1.75' > "$PARAMS_DIR/MADS_OP_regen_paddle_decel_factor"
echo '1.0' > "$PARAMS_DIR/MADS_OP_one_time_stop_decel_factor"
echo '1.0' > "$PARAMS_DIR/MADS_OP_rate_ramp_up"

# Lane Position
echo '0.5' > "$PARAMS_DIR/LP_offset_maximum_m"

# Extended Radar - Traffic Detection
echo '190.0' > "$PARAMS_DIR/XR_TD_oncoming_timeout_s"
echo '10.0' > "$PARAMS_DIR/XR_TD_ongoing_timeout_s"
echo '15.0' > "$PARAMS_DIR/XR_TD_min_traffic_moving_speed_mph"

# Lateral Tuning
echo 'true' > "$PARAMS_DIR/TUNE_LAT_do_override"
echo '0.25' > "$PARAMS_DIR/TUNE_LAT_steer_actuator_delay_s"
echo 'true' > "$PARAMS_DIR/TUNE_LAT_TRX_use_NN_FF"
echo '1.5' > "$PARAMS_DIR/TUNE_LAT_TRX_kf"

# ============================================================================
# END OF CUSTOM PARAMETERS
# ============================================================================

# Mark as applied
touch "$MARKER"
echo "Custom defaults applied on $(date)" >> "$MARKER"
echo "Custom opParams defaults applied successfully!"
echo "Parameters set:"
echo "  - MISC_offroad_shutdown_time_hr = 10"
echo "  - MISC_car_12v_pause_charging_v = 12.0"
echo "  - FP_stop_distance_offset_m = 2.0"
echo "  - LC_minimum_speed_mph = 35.0"
echo "  - MADS_OP_decel_ms2 = [-1.2, -1.1]"
echo "  - MADS_OP_regen_paddle_decel_factor = 1.75"
echo "  - MADS_OP_one_time_stop_decel_factor = 1.0"
echo "  - MADS_OP_rate_ramp_up = 1.0"
echo "  - LP_offset_maximum_m = 0.5"
echo "  - XR_TD_oncoming_timeout_s = 190.0"
echo "  - XR_TD_ongoing_timeout_s = 10.0"
echo "  - XR_TD_min_traffic_moving_speed_mph = 15.0"
echo "  - TUNE_LAT_do_override = true"
echo "  - TUNE_LAT_steer_actuator_delay_s = 0.25"
echo "  - TUNE_LAT_TRX_use_NN_FF = true"
echo "  - TUNE_LAT_TRX_kf = 1.5"

exit 0
