#!/bin/bash

################################################################################
# C3PT.sh                                                   # Usage: ./C3PT.sh #
#                                                           ####################
# Sets up a multi-platform C++ project structure with brew,                    #
# CMake, and ninja and configures specifically for the MacOSX Terminal target. #
#                                                                              #
#==============================================================================#
# I. STRUCTURE                                                                 #
#                                                                              #
# The resulting project tree is as follows, where '.' represents the current   #
# working directory in which this script was ran. See below for files created. #
#                                                                              #
#           Tree           |             Subdirectory Description              #
#--------------------------|---------------------------------------------------#
# ./                       |    CWD                                            #
#  |--<$PROJECT_NAME>/     |      Top level                                    #
#    |--assets/            |          For raw asset data                       #
#    |--src/               |          For C++ headers and sources              #
#    |--3rdParty/          |          For static or dynamic libraries          #
#    |--mac/               |          MacOSX Terminal Target                   #
#      |--bin/             |                 For executable and asset links    #
#      |--build/           |                 For CMake internals               #
#                                                                              #
# The purpose of the directory tree's design is to promote the implementation  #
# of modular builds for other targets (e.g., Windows, Web Browser, Android).   #
# Each one would get a subdirectory, at the same level as [mac], filled with   #
# platform specific scripts. However, all of the eventual executables would    #
# still be sourced from the common C++ codebase in the [src] subdirectory.     #
#                                                                              #
# II. FILES                                                                    #
#                                                                              #
# There are only 2 total files generated explicitly by this script, both of    #
# which can be found in the [mac] subdirectory:                                #
#     1) build.sh                                                              #
#     2) CMakeLists.txt                                                        #
#                                                                              #
# The former has 3 main responsibilities:                                      # 
#     1) Asset linkage                  -- via system link in [bin] directory  #
#     2) CMake configuration            -- via [CMakeLists.txt]                #
#     3) Code compilation               -- via Ninja                           #
#                                                                              #
# The created CMake project and executable are also called $PROJECT_NAME.      #
#                                                                              #
# III. INPUTS                                                                  #
#                                                                              #
# The script will prompt the user for various settings about the project and   #
# desired compiler configuration flags, which are detailed here:               #
#                                                                              #
#     Setting     |     Internal ID        |     Description                   #
#-----------------|------------------------|-----------------------------------#
# Project Title / | $PROJECT_NAME          | Overall name of the top-level,    #
# Executable Name |                        | CMake, and executable; string.    #
#-----------------|------------------------|-----------------------------------#
# C++ Standard    | $CPP_STD_VER           | Compiler Flag proxy.              #
# Version         |                        | Input one of ['14', 17', '20'].   #
#-----------------|------------------------|-----------------------------------#
# Enable          | $CPP_USE_EXCEPT        | Compiler Flag proxy.              #
# Exceptions      |                        | Input one of ['y', 'n'].          #
#-----------------|------------------------|-----------------------------------#
#                                                                              #
# IV. USAGE                                                                    #
#                                                                              #
# [brew] is the only dependency for this setup tool, and must be available     #
# somewhere along the current value of $PATH. Assuming that [brew] is usable,  #
# then the following non-code dependencies are queried for and installed if    #
# not found:                                                                   #
#     - wget                                                                   #
#     - cmake (>=3.4.1)                                                        #
#     - ninja                                                                  #
#                                                                              #
# Once these tools are available, the user is prompted for information. After, #
# the directory tree and files are created. To develop the project further,    #
# populate the [src] directory with appropriate code, navigate to the [mac]    #
# subdirectory, and run [build.sh]. If all succeeds, the executable can be     #
# found in the [bin] subdirectory.                                             #
#                                                                              #
#==============================================================================#
#                                                                              #
# Author: Alexander Gibbons (@alex)                                            #
# Date: 28 October 2022                                                        #
#                                                                              #
# Changelog:                                                                   #
#     @alex (10/28/22) - Initial creation.                                     #
#                        Specification writeup.                                #
#     @alex (10/29/22) - Wrote [echop], [check_brew], and [ensure_available].  #
#                        Greeting and dependency checks (step 1) complete.     #
#                        Wrote and tested [read_*_*] subroutines.              #
#     @alex (10/30/22) - Wrote [q_mkdir] and [build_tree].                     #
#                        User input (step 2) and tree creation (step 3) done.  #
#     @alex (11/02/22) - Wrote initial version of [write_build_script].        #
#                        Wrote [g], [gen_spaces], [ge].                        #
#                        Implemented beginning of comment header with heredoc. #
#     @alex (11/03/22) - Refactored with [printf] to remove [g] and [ge].      #
#                        Changed [gen_spaces] to [gs] for brevity.             #
#                        Moved comment strings into [prep_*_strings].          #
#                        Finshed comment header via heredoc for build script.  #
#     @alex (11/04/22) - Wrote [write_comment_header], [write_script_funcs].   #
#                        Wrote [write_fheader] and [write_ensure_assets].      #
#     @alex (01/01/24) - Wrote [write_cfg_cmake] and [cfg_cmake].              #
#                        Wrote [write_run_ninja] and [run_ninja].              #
#                        Finished [write_build_script]; scripts (step 4) done. #
#    @alex (01/24/24)  - Wrote [write_cmake_comment] and [write_cmake_cmds].   #
#                      - Finished [write_cmake_lists]; cmake (step 5) done.    #
#                      - C3PT Version 1.0 finished.                            #
#                                                                              #
# Bugs:                                                                        #
#     sh_ucar#0000  : <<Unintended Consequence>> in [echop]                    #
#                     Special operands -n, -e show up as literals.             #
#                                                                              #
################################################################################

#### SUBROUTINES ####

#
# [echop $@]
#
# Lets the user know what print statements come from 
# this script by prefixing '[bash] ' onto ideally 
# non-empty [echo] calls.
#
# Parameters:
#     $@ = Variadic list of passable strings to 
#          [echo].
#
# Preconditions:              Consequences:
#     $@ expands validly          Premature return
#
function echop() {                                   #
    builtin echo -n -e "[bash] $@"                   # <<sh_ucar#0000>>
}                                                    #

#
# [check_brew]
#
# Check if brew is available on the current $PATH.
# If not, terminate the script with error code [1].
#
function check_brew() {                              #
    echop "Querying dependency 'brew'... "           # --version needed for
    brew --version >/dev/null 2>/dev/null            # querying this way
    local brewFlg=$?                                 # 
    if [ $brewFlg == 0 ]; then                       # 0 iff brew on $PATH
        echo  "Found."                               #
    elif [ $brewFlg == 127 ]; then                   # brew not available
        echo -e "Missing."                           #
        echop "brew is required for this tool.\n"    # Notify user that this
        echop "Install separately and try again.\n"  # is unrecoverable and
        echop "\nSetup Failed.\n"                    # quit the tool.
        exit 1                                       #
    fi                                               #
}                                                    #

#
# [ensure_available $1]
#
# Checks to see if dependency [$1] is already 
# installed via [brew].
#
# If not, then [$1] is attempted to be installed. 
# Failure to do successfully will terminate the 
# script with error code [2].
# 
# Parameters:
#     $1 = The desired dependency name as registered 
#          with [brew] (string).
#
# Preconditions:              Consequences:
#     $1 non-empty                Undefined Behavior
#
function ensure_available() {                        #
    echop "Querying dependency '$1'... "             # See if installed
    brew ls --versions "$1" >/dev/null               # by peeking at $?
    if [ $? == 0 ]; then                             #
        echo "Found."                                # Great; no work
    else                                             # 
        echo  "Missing."                             #
        echop "$1 will be installed via brew.\n"     # Try to install
        brew install "$1"                            # with brew
        if [ $? == 0 ]; then                         #
            echo                                     #
            echop "Dependency '$1' installed.\n"     # Done; now available
        else                                         #
            echo                                     # Unable to ensure
            echop "$1 failed to install properly.\n" # dependency working
            echop "Unable to configure project.\n\n" #
            echop "Setup Failed.\n"                  # Quit tool
            exit 2                                   # with error code 2
        fi                                           #
    fi                                               #
}                                                    #

#
# [read_project_name]
#
# Prompts the user for the name of the C++ project
# and reads the response into $PROJECT_NAME. If EOF
# is entered, then the user is asked to repeat.
#
# Given that the name can be any string, the only
# erroneous input is EOF, an empty (newline only) 
# buffer, or a keyboard interrupt, which would 
# probably exit this script anyway.
#
function read_project_name() {                       #
    echop "Project Name: "                           # Prompt and read
    read PROJECT_NAME                                # 
    if [ $? == 1 ]; then                             # EOF?
        echo                                         # Force break before print
    elif [[ -z $PROJECT_NAME ]]; then                # Empty?
        :                                            # nop to break out
    else                                             #
        return                                       # Valid name; leave
    fi                                               #
    echop "Invalid string.\n"                        # Garbage value
    read_project_name                                # User retry
}                                                    #

#
# [read_cpp_version]
#
# Prompts the user for the version of C++ standard
# to compile the project against. If values aside
# from '14', '17', or '20' are entered, the user
# must retry.
#
function read_cpp_version() {                        #
    echop "C++ Standard: "                           # Prompt and read value
    read CPP_STD_VER                                 # (@alex): Maybe more info
    case $CPP_STD_VER in                             # about what is valid here
    98 | 03 | 11)                                    #
        echop "This C++ version is not supported.\n" # C++14 is minimum
        read_cpp_version                             # User Retry
    ;;                                               # 
    14 | 17)                                         # C++14 and C++17
        :                                            # are acceptable
    ;;                                               #
    20)                                              # Clang's incomplete C++20
        readonly CPP_STD_VER="2a"                    # implementation is "2a"
    ;;                                               # 
    *)                                               #
        if [ $? == 1 ]; then                         # If EOF is given, add
            echo                                     # break before next print
        fi                                           #
        echop "Unrecognized C++ version.\n"          # Random useless input
        read_cpp_version                             # User Retry
    ;;                                               #
    esac                                             #
}                                                    #

#
# [read_exception_flag]
#
# Prompts the user if exceptions should be enabled
# for the project and stores the corresponding flag
# for clang in $CPP_USE_EXCEPT. 
#
# If values besides some form of yes/no are entered, 
# the user must retry.
#
function read_exception_flag() {                     #
    echop "Exceptions (y/n): "                       # Prompt and read
    read CPP_USE_EXCEPT                              # (@alex): Probably need
    case $CPP_USE_EXCEPT in                          # to expand 'y/n' prompt
    y | Y | yes | YES | Yes):                        #
        readonly CPP_USE_EXCEPT="-fexceptions"       # yes => -fexceptions
    ;;                                               #
    n | N | no | NO | No):                           #
        readonly CPP_USE_EXCEPT="-fno-exceptions"    # no => -fno-exceptions
    ;;                                               #
    *)                                               #
        if [ $? == 1 ]; then                         # If EOF given, force
            echo                                     # break before next print
        fi                                           #
        echop "Invalid response.\n"                  # Garbage value
        read_exception_flag                          # User retry
    ;;                                               #
    esac                                             #
}                                                    #

#
# [q_mkdir $1]
#
# Attempts to create the directory [$1] in the 
# current working one; however, if creation fails
# for whatever reason, then the script will exit 
# with error code [3].
#
# Parameters:
#     $1 = Name of the directory to create (string);
#          Enclosing folders need not exist.
# 
# Preconditions:              Consequences:
#     $1 is a valid name          Exit with code [3]
#
function q_mkdir() {                                 #
    echop "Creating $1... "                          # Attempt at
    if ! mkdir -p "$1" ; then                        # creating folder
        echop "Cannot create directory $1.\n"        #
        echop "ERROR\n\n"                            # Display error status
        echop "Setup Failed.\n"                      # and quit with code [3].
        exit 3                                       #
    fi                                               # This point marks
    echo "Done"                                      # successful creation.
}                                                    # 

#
# [build_tree]
#
# Creates the directory tree as seen in the 
# specfication found above. If directories cannot
# be made for whatever reason, the script exits with
# error code [3].
#
function build_tree() {                              # ./
    q_mkdir $PROJECT_NAME                            #  |--Top-Level/
    q_mkdir $PROJECT_NAME/assets                     #    |--assets/
    q_mkdir $PROJECT_NAME/src                        #    |--src/
    q_mkdir $PROJECT_NAME/3rdParty                   #    |--3rdParty/
    q_mkdir $PROJECT_NAME/mac                        #    |--mac/
    q_mkdir $PROJECT_NAME/mac/bin                    #      |--bin/
    q_mkdir $PROJECT_NAME/mac/build                  #      |--build/
}                                                    #

#
# [gs $1]
#
# Shorthand for "Generate Spaces".
#
# Utility subroutine for writing the build 
# script's comment header.
#
# Meant to be used for printing at the end of a 
# line of text in the header, and followed up by 
# a hash. Doing so will cause a nice vertical line
# of hashes along column 80.
#
# Parameters:
#     $1 = Number of characters, including spaces,
#          to the left of where space should be 
#          placed on the current line. (int)
# 
# Preconditions:              Consequences:
#     0 < $1 <= 79                Undefined Behavior
#
function gs() {                                      #
    printf " %.0s" $(seq "$((79-$1))")               # Fill gap to column 80
}                                                    #

#
# [prep_hash_strings]
#
# Initializes global variables with string
# values for helping with the styling of the
# build script's comment header.
# 
# The following are set as such:
# 1) $H          - #
# 2) $H_20       - ###<...n=14...>###
# 3) $HASH_LINE  - ###<...n=74...>###
# 4) $BLANK_LINE - #  <...n=74...>  #
# 5) $EQUAL_LINE - #==<...n=74...>==#
#
# Remarks:
#     @alex (11/04/22) - $H is not strictly needed,
#                        as [cat] will interpret # 
#                        literally; however, $H will
#                        prevent all text being gray.
#
function prep_hash_strings() {                          #
    readonly H="#"                                      # 
    readonly HASH_LINE="$(printf '#%.0s' $(seq 80))"    # Outer border
    readonly H_20="$(printf '#%.0s' $(seq 20))"         # "Usage" styling
    readonly BLANK_LINE="$H$(gs 1)$H"                   # 
    readonly EQUAL_LINE="#$(printf '=%.0s' $(seq 78))#" # Section break
}                                                       #

#
# [prep_date_strings]
#
# Initializes global variables with string 
# values for helping in writing portions of 
# the build script's comment header.
#
# All date values are relative to the time 
# at invocation of this subroutine.
# 
# The following are set as such:
# 1) $DATE_SHORT - <Month (2dgts)>/<Day (2dgts)>
# 2) $DATE_LINE  - # Date: <Day> <Month> <Year><...>#
#
function prep_date_strings() {                               #
    readonly DATE_SHORT=$(date +"%m/%d")                     # E.g., 11/23
    local MONTH="$(date +'%B')"                              # Account for month
    local DATE_SPACES=$((16 + ${#MONTH}))                    # length for spaces
    local TODAY="$(date +'%d %B %Y')"                        # 
    readonly DATE_LINE="$H Date: $TODAY$(gs $DATE_SPACES)$H" # Goes below author
}                                                            # line

#
# [write_comment_header]
# 
# Appends a pregenerated comment header to the
# beginning of the build script.
#
# The same style as this script is used, except
# for an empty specification and additional section
# describing how the build script is autogenerated 
# but freely modifiable.
# 
# The script should already contain a shebang.
#
function write_comment_header() {
    cat << EOF >> $PROJECT_NAME/mac/build.sh         # Append
$HASH_LINE
$H build.sh$(gs 30)$H Usage: ./build.sh $H
$H$(gs 21)$H_20$H
$H Preps and compiles the C++ codebase found in ../src/,$(gs 55)$H
$H targeting the MacOSX Terminal. Ensures ../assets/ is available$(gs 64)$H
$H in bin/ via a syslink. The existence of bin/ and build/ is assumed.$(gs 69)$H
$BLANK_LINE
$EQUAL_LINE
$BLANK_LINE
$H THIS FILE WAS PRODUCED BY THE C++ PROJECT SETUP TOOL.$(gs 55)$H
$H FEEL FREE TO EDIT THIS TO SUIT PROJECT NEEDS.$(gs 47)$H
$BLANK_LINE
$EQUAL_LINE
$BLANK_LINE
$H Author: Alexander Gibbons (@alex)$(gs 35)$H
$DATE_LINE
$BLANK_LINE
$H Changelog:$(gs 12)$H
$H     @CPP_PROJECT_TOOL ($DATE_SHORT) - Generated build script.$(gs 57)$H
$BLANK_LINE
$H Bugs:$(gs 7)$H
$H     N/A$(gs 9)$H
$BLANK_LINE
$HASH_LINE

EOF
}                                                    #

#
# [write_fheader]
#
# Appends a comment header block to the build script
# appropriate for a function with no parameters and
# returning nothing. The style is the same as is
# used here, generalized as such with arguments:
# 
# # [$1]
# #
# # $2
# #
# 
# Parameters:
#     $1 = Name of the function (string)
#     $2 = Description of the function (string)
#
# Preconditions:                Consequences:
#  [prep_hash_strings] called    Premature return
#
function write_fheader() {                          #
    cat << EOF >> $PROJECT_NAME/mac/build.sh        # Append
#
# [$1]
#
# $(echo -e $2)
#
EOF
}                                                   #

#
# [write_ensure_assets]
#
# Writes the function [ensure_assets] to the build
# script, which checks for a syslink in bin/, and 
# if not, tries to create one. The script will exit 
# with code [4] on failure to do so.
#
# Remarks:
#     @alex (11/04/22) - \$ is one character in the 
#                        script but here takes up 
#                        two, so the # is just 
#                        visually thrown off.
#
function write_ensure_assets() {                     #
    write_fheader "ensure_assets" "Checks if there 
    exists a syslink in bin/ to\n# ../assets/; if
    not, one is created. Should that\n# fail, the\
    script exits with code [4]."                     #
    cat << EOF >> $PROJECT_NAME/mac/build.sh         # Append
function ensure_assets() {                           #
    pushd bin/ >/dev/null                            # Quietly change directory
        echo -n "Querying assets... "                #
        if [ ! -d "assets" ]; then                   # ! syslink exist?
            ln -s ../../assets/ assets               # Extra .. since in bin/
            if [ \$? == 0 ]; then                     #
                echo "Link created"                  # Successful link
            else                                     #
                echo -e "Error\n\nBuild Failed"      # Notify and
                exit 4                               # abort build
            fi                                       #
        else                                         #
            echo "Found"                             # Link exists
        fi                                           #
    popd >/dev/null                                  # Quietly go back
}                                                    #

EOF
}                                                    #

#
# [write_cfg_cmake]
#
# Writes the function [cfg_cmake] to the build
# script, which sets up [cmake] to use [ninja] and
# configure using the CMakeLists.txt file located
# in the mac/ subdirectory. If any error occurs
# during this setup process, written function will
# exit with error code [5].
#
# Remarks:
#     @alex (01/01/24) - \$ is one character in the 
#                        script but here takes up 
#                        two, so the # is just 
#                        visually thrown off. 
#
function write_cfg_cmake() {                         #
    write_fheader "cfg_cmake" "Sets up [cmake] to use
    [ninja] and the\n# CMakeLists.txt file located at
    ../; if any error\n# occurs, the script exits 
    with error code [5]."                            # 
    cat << EOF >> $PROJECT_NAME/mac/build.sh         # Append
function cfg_cmake() {                               #
    pushd build/ >/dev/null                          # Quietly change directory
        cmake -G Ninja ..                            # Configure [cmake]
        if [[ \$? -ne 0 ]]; then                      #
            echo -e "ERROR\n\nBuild Failed"          #
            exit 5                                   # Bad setup
        else                                         #
            echo -e "CMake configured."              # Good setup
        fi                                           #
    popd >/dev/null                                  # Quietly go back
}                                                    #

EOF
}                                                    #

#
# [write_run_ninja]
#
# Writes the function [run_ninja] to the build
# script, which attempts to execute [ninja] using
# the current CMake configuration. The return code
# is checked to determine success; upon failure, the
# the function will exit the script with error code
# [6].
# 
# Remarks:
#     @alex (01/01/24) - \$ is one character in the 
#                        script but here takes up 
#                        two, so the # is just 
#                        visually thrown off. 
#
function write_run_ninja() {                         #
    write_fheader "run_ninja" "Attempts to execute
    [ninja] using the current\n# [cmake] 
    configuration. The return code is checked\n# to 
    determine success; upon failure, the script\n#
    exits with error code [6]."                      #
    cat << EOF >> $PROJECT_NAME/mac/build.sh         # Append
function run_ninja() {                               #
    pushd build/ >/dev/null                          # Quietly change directory
        ninja                                        # Try [ninja]
        if [[ \$? -ne 0 ]]; then                      #
            echo -e "ERROR\n\nBuild Failed."         #
            exit 6                                   # Error compiling
        else                                         #
            echo -e "OK\n\nBuild Succeeded."         # Good to run
        fi                                           #
    popd >/dev/null                                  # Quitely go back
}                                                    #

EOF
}                                                    #

#
# [write_script_funcs]
#
# Populates the build script by calling each needed
# function's corresponding [write_*] subroutine,
# which places the executable code in the build
# script after the header. Finally, these functions
# are called in order at the end of the build script:
#   1) [ensure_assets]
#   2) [cfg_cmake]
#   3) [run_ninja]
#
function write_script_funcs() {                   # 
    write_ensure_assets                              # Subroutine definitions
    write_cfg_cmake                                  #
    write_run_ninja                                  #
    cat << EOF >> $PROJECT_NAME/mac/build.sh         # Append after header
ensure_assets                                        # 
cfg_cmake                                            # Script body
run_ninja                                            #
EOF
}                                                    #

#
# [write_build_script]
#
# Opens a new / rewrites the file at [mac/build.sh] 
# and populates it (roughly) as below. The resulting 
# script at that location is then given appropriate
# permissions to be executable.
#
# #!/bin/bash
# 
# ####################################################
# # File Header                                      #
# # ...                                              #
# ####################################################
#
# function ensure_assets() { ... }
# function cfg_cmake()     { ... }
# function run_ninja()     { ... }
#
# ensure_assets
# cfg_cmake
# run_ninja
#
#
function write_build_script() {                      #
    local DST_FILE=$PROJECT_NAME/mac/build.sh        # For readability
    echop "Writing $DST_FILE... "                    #
    cat << EOF > $DST_FILE                           # > to force rewrite
#!/bin/bash

EOF
    write_comment_header                             # These will consecutively
    write_script_funcs                               # append to the file. 
    chmod +x $DST_FILE                               # Allow execution 
    echo "Done"                                      #
}                                                    #

#
# [write_cmake_comment]
#
# Adds a comment block to [mac/CMakeLists.txt] with
# the following style:
#
# #[[
#  CMakeLists.txt
#  
#  <AUTO-GENERATED NOTICE>
#
#  <AUTHOR>
#  <DATE>
#
#  <CHANGELOG>
# ]]
#
function write_cmake_comment() {
    local DST_FILE=$PROJECT_NAME/mac/CMakeLists.txt  # ../ relative to build.sh
    cat << EOF >> $DST_FILE
#[[
CMakeLists.txt

Sets up CMake for the MacOS command-line target.

===============================================================================

THIS FILE WAS PRODUCED BY THE C++ PROJECT SETUP TOOL.                        
FEEL FREE TO EDIT THIS TO SUIT PROJECT NEEDS.                                  

===============================================================================

Author: Alexander Gibbons (@alex)
Date: $TODAY

Changelog:
    @CPP_PROJECT_TOOL ($DATE_SHORT) - Generated file.
]]
EOF
}

#
# [write_cmake_cmds]
#
# Adds three sections of commands
# within [mac/CMakeLists.txt]:
#
#    1) CMake Verification & Project Name Setup
#           - Oldest acceptable version: 
#                 3.4.1
#           - CMake Project Name: 
#                 [$PROJECT_NAME]
#    2) CMake Flag Setup
#           - Compiler Flags: 
#                 [$CPP_STD_VER; $CPP_USE_EXCEPT]
#           - Output Directory: 
#                 [$PROJECT_NAME/mac/bin/]
#    3) Executable Setup
#           - Search [$PROJECT_NAME/src/] 
#                 for extensions: [.h; .cpp]
#           - Create corresponding 
#                 executable called [$PROJECT_NAME]
#
function write_cmake_cmds() {
    local DST_FILE=$PROJECT_NAME/mac/CMakeLists.txt  # ../ relative to build.sh
    cat << EOF > $DST_FILE
cmake_minimum_required(VERSION 3.4.1)
project("$PROJECT_NAME")
set(CMAKE_CXX_FLAGS "\${CMAKE_CXX_FLAGS} -std=c++$CPP_STD_VER $CPP_USE_EXCEPT")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY \${CMAKE_CURRENT_SOURCE_DIR}/bin/)
set(SRC_DIR "../src/")
file(GLOB_RECURSE CPP_HEADERS \${SRC_DIR}/*.h)
file(GLOB_RECURSE CPP_SOURCES \${SRC_DIR}/*.cpp)
add_executable($PROJECT_NAME \${CPP_HEADERS} \${CPP_SOURCES})
EOF
}

#
# [write_cmake_lists]
#
# Creates and/or clears the file 
# at [mac/CMakeLists.txt] and then populates it.
# 
# A header comment block is prepended to commands 
# for setting up the CMake project; 
# see [write_cmake_comment] and [write_cmake_cmds] 
# respectively for what is added specifically.
#
function write_cmake_lists() {
    local DST_FILE=$PROJECT_NAME/mac/CMakeLists.txt  # ../ relative to build.sh
    echop "Writing $DST_FILE... "                    #
    cat << EOF > $DST_FILE                           # > forces rewrite
EOF
    write_cmake_comment                              # Add comment header
    write_cmake_cmds                                 # Populate with parameters
    echo "Done"
}                                                    #

#### SCRIPT ####

#
# Print the greeting as well as legal and licensing 
# information.
#
echop "C++ Project Setup Tool\n"
echop "Alexander Gibbons (C) 2022\n\n"

#
# Dependency checks
#
echop "Dependency Checks (Step 1/5)\n"
check_brew
ensure_available "wget"
ensure_available "cmake"
ensure_available "ninja"
echop "OK\n\n"

#
# Get inputs
#
echop "User Settings (Step 2/5)\n"
echop "Please enter the following information.\n"
read_project_name
read_cpp_version
read_exception_flag
echop "OK\n\n"

#
# Make directory tree
# 
echop "Directory Tree (Step 3/5)\n"
build_tree
echop "OK\n\n"

#
# Write scripts
#
echop "Scripts (Step 4/5)\n"
prep_hash_strings
prep_date_strings
write_build_script
echop "OK\n\n"

#
# Write CMakeLists.txt
#
echop "CMake (Step 5/5)\n"
write_cmake_lists
echop "OK\n\n"

#
# Print status before exit.
#
echop "Setup Successful.\n"
exit 0
