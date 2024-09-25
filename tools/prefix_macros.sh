#!/bin/bash

# Prefix that will be added to all required macro/struct/module names
PREFIX="css_mcu0_"
# Path to directory where common_defines.vh, el2_param.vh, el2_pdef.vh, and pd_defines.vh reside
DEFINES_PATH="/home/ws/caliptra/pateln/veer_el2_core_ws2_0924/snapshots/default"
# Path to directory hierarchy where RTL sources reside
DESIGN_DIR="/home/ws/caliptra/pateln/veer_el2_core_ws2_0924/design"

COMMON_DEFINES="$DEFINES_PATH/common_defines.vh"
EL2_PARAM="$DEFINES_PATH/el2_param.vh"
EL2_PDEF="$DEFINES_PATH/el2_pdef.vh"
PD_DEFINES="$DEFINES_PATH/pd_defines.vh"
EL2_DEF="$DESIGN_DIR/include/el2_def.sv"
EL2_IFU_IC_MEM="$DESIGN_DIR/ifu/el2_ifu_ic_mem.sv"

echo "Starting script with PREFIX=$PREFIX"
echo "DEFINES_PATH=$DEFINES_PATH"
echo "DESIGN_DIR=$DESIGN_DIR"

# Define regex patterns for matching defines
DEFINES_REGEX="s/((\`define)|(\`ifndef)|(\`undef)) ([A-Z0-9_]+).*/\5/p"
DEFINES_REPLACE_REGEX="s/((\`define)|(\`ifndef)|(\`undef)) ([A-Z0-9_]+)/\1 $PREFIX\5/"
echo "DEFINES_REGEX=$DEFINES_REGEX"
echo "DEFINES_REPLACE_REGEX=$DEFINES_REPLACE_REGEX"

# Extract unique defines
DEFINES="$(sed -nr "$DEFINES_REGEX" "$COMMON_DEFINES" "$PD_DEFINES" "$EL2_IFU_IC_MEM" | sort -ur)"
echo "DEFINES=$DEFINES"

# Skip certain design files
SKIP_DESIGN_FILES="el2_param.vh\|el2_pdef.vh\|common_defines.vh\|pd_defines.vh"
DESIGN_FILES="$(find "$DESIGN_DIR" \( -name "*.sv" -o -name "*.vh" -o -name "*.v" \) | grep -v -E "$SKIP_DESIGN_FILES")"
echo "DESIGN_FILES=$DESIGN_FILES"

# Add prefix to macro names
echo "Adding prefix to macro names in $COMMON_DEFINES and $PD_DEFINES"
sed -E "$DEFINES_REPLACE_REGEX" "$COMMON_DEFINES" > "$DEFINES_PATH/${PREFIX}common_defines.vh"
sed -E "$DEFINES_REPLACE_REGEX" "$PD_DEFINES" > "$DEFINES_PATH/${PREFIX}pd_defines.vh"

# Replace renamed macros in RTL sources
echo "Replacing renamed macros in RTL sources"
for DEFINE in $DEFINES; do
    echo "Processing DEFINE=$DEFINE"
    # Quoting the file list for sed to handle spaces or special characters
    sed -i "s/\`$DEFINE/\`$PREFIX$DEFINE/g" $DESIGN_FILES
done

# Add prefix to VeeR config struct
STRUCT_SED="s/el2_param_t/${PREFIX}el2_param_t/g"
echo "Adding prefix to VeeR config struct with STRUCT_SED=$STRUCT_SED"
sed "$STRUCT_SED" "$EL2_PARAM" > "$DEFINES_PATH/${PREFIX}el2_param.vh"
sed "$STRUCT_SED" "$EL2_PDEF" > "$DEFINES_PATH/${PREFIX}el2_pdef.vh"
sed -i "$STRUCT_SED" $DESIGN_FILES

# Replace include names in RTL sources
echo "Replacing include names in RTL sources"
sed -i "s/include \"el2_param.vh\"/include \"${PREFIX}el2_param.vh\"/g" $DESIGN_FILES
sed -i "s/include \"el2_pdef.vh\"/include \"${PREFIX}el2_pdef.vh\"/g" $DESIGN_FILES

# Replace package name and its imports in RTL sources
echo "Replacing package name and its imports in RTL sources"
sed -i "s/import el2_pkg/import ${PREFIX}el2_pkg/g" $DESIGN_FILES
sed -i "s/package el2_pkg/package ${PREFIX}el2_pkg/g" "$EL2_DEF"

# Extract unique module names
MODULES_REGEX="s/^module ([\`A-Za-z0-9_]+).*/\1/p"
MODULES="$(sed -nr "$MODULES_REGEX" $DESIGN_FILES | sort -ur)"
echo "MODULES=$MODULES"

# Add prefix to all module names
echo "Adding prefix to all module names"
sed -i -E "s/module ([\`A-Za-z0-9_]+)/module ${PREFIX}\1/g" $DESIGN_FILES

# Add prefix to all module instantiations
echo "Adding prefix to all module instantiations"
for MODULE in $MODULES; do
    echo "Processing MODULE=$MODULE"
    sed -i -E "s/(^|[^A-Za-z0-9_])$MODULE([^A-Za-z0-9_])/\1$PREFIX$MODULE\2/g" $DESIGN_FILES
done

# Remove old header files to avoid redefining their contents during elaboration
echo "Removing old header files"
# Using -f to avoid errors if files are already missing
rm -f "$COMMON_DEFINES" "$EL2_PARAM" "$EL2_PDEF" "$PD_DEFINES"

# Add prefix to el2_mem_if interface
echo "Adding prefix to el2_mem_if interface"
sed -i -E "s/el2_mem_if/${PREFIX}el2_mem_if/g" $DESIGN_FILES

# Prefix memory macro names in el2_ifu_ic_mem.sv
echo "Prefixing memory macro names in $EL2_IFU_IC_MEM"
sed -i "s/EL2_IC_TAG_PACKED_SRAM/${PREFIX}EL2_IC_TAG_PACKED_SRAM/g" "$EL2_IFU_IC_MEM"
sed -i "s/EL2_IC_TAG_SRAM/${PREFIX}EL2_IC_TAG_SRAM/g" "$EL2_IFU_IC_MEM"
sed -i "s/EL2_PACKED_IC_DATA_SRAM/${PREFIX}EL2_PACKED_IC_DATA_SRAM/g" "$EL2_IFU_IC_MEM"
sed -i "s/EL2_IC_DATA_SRAM/${PREFIX}EL2_IC_DATA_SRAM/g" "$EL2_IFU_IC_MEM"

echo "Script finished successfully"

