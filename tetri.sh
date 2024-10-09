#!/usr/bin/env bash

set -eo pipefail

# check if script is executed with bash, version >= 4.0
if [[ -z $BASH_VERSION ]]; then
		echo 'Execute this script with bash, version >= 4.0'
		exit 1
fi

VERSION_ABOVE_OR_EQUAL_4_REGEX='^[^0-3]\..*\|^[0-9][0-9][0-9]*\..*'
echo $BASH_VERSION | grep $VERSION_ABOVE_OR_EQUAL_4_REGEX
if [[ $? -ne 0 ]]; then
	echo "Execute this script with bash, version >= 4.0. Your current version=$BASH_VERSION"
	exit 1
fi

# remove highlighted terminal cursor
tput civis
# reset to normal on exit
trap 'tput cnorm;' EXIT
# reset to normal on exit and clean screen
trap 'tput cnorm; clear; exit;' SIGINT 

# declare default options
declare -i cols=12
declare -i rows=24
declare -i next_piece_view_cols=4
declare -i next_piece_view_rows=4
REFRESH_TIME=0.02

# holds a screen matrix in an associative array
declare -A screen
declare -A next_piece_view
  
declare -i score=0 
declare -i level=1 
declare -i lines_cleared=0 
declare -i piece_id 
declare -i next_piece_offset_cols
declare -i next_piece_id=0 

declare -i piece_col
declare -i piece_row

# key input from user
key=""

# constants
declare -r BLOCK_ICON="X"
declare -r EMPTY=" "
declare -r ARROW_UP="A"
declare -r ARROW_DOWN="B"
declare -r ARROW_RIGHT="C"
declare -r ARROW_LEFT="D"
declare -r X="x"
declare -r Z="z"
declare -r HORIZONTAL_BAR="-"
declare -r VERTICAL_BAR="|"
declare -r CORNER_ICON="+"

# Tetrimino shapes as arrays of coordinates
pieces=(
    "0 0 1 0 2 0 3 0" # I vertical 
    "0 0 0 1 0 2 0 3" # I horizontal
    "0 0 0 1 1 0 1 1" # square
    "0 0 1 0 2 0 2 1" # L
    "0 0 0 1 0 2 1 0" # L 1 rot to right
    "0 0 0 1 1 1 2 1" # L 2 rot to right
    "0 2 1 0 1 1 1 2" # L 3 rot to right
    "0 0 0 1 1 1 1 2" # Z
    "0 1 1 0 1 1 2 0" # Z 1 rot to right
    "0 1 0 2 1 0 1 1" # inverse Z
    "0 0 1 0 1 1 2 1" # inverse Z 1 rot to right
    "0 1 1 1 2 0 2 1" # mirror L
    "0 0 1 0 1 1 1 2" # mirror L 1 rot to right
    "0 0 0 1 1 0 2 0" # mirror L 2 rot to right
    "0 0 0 1 0 2 1 2" # mirror L 3 rot to right
    "0 1 1 0 1 1 1 2" # T
    "0 0 1 0 1 1 2 0" # T 1 rot to right
    "0 0 0 1 0 2 1 1" # T 2 rot to right
    "0 1 1 0 1 1 2 1" # T 3 rot to right
)

pieces_next_piece_rot_right=(
    1 # I vertical 
    0 # I horizontal
    2 # square
    4 # L
    5 # L 1 rot to right
    6 # L 2 rot to right
    3 # L 3 rot to right
    8 # Z
    7 # Z 1 rot to right
    10 # inverse Z
    9 # inverse Z 1 rot to right
    12 # mirror L
    13 # mirror L 1 rot to right
    14 # mirror L 2 rot to right
    11 # mirror L 3 rot to right
    16 # T
    17 # T 1 rot to right
    18 # T 2 rot to right
    15 # T 3 rot to right
)

pieces_next_piece_rot_left=(
    1 # I vertical 
    0 # I horizontal
    2 # square
    6 # L
    3 # L 1 rot to right
    4 # L 2 rot to right
    5 # L 3 rot to right
    8 # Z
    7 # Z 1 rot to right
    10 # inverse Z
    9 # inverse Z 1 rot to right
    14 # mirror L
    11 # mirror L 1 rot to right
    12 # mirror L 2 rot to right
    13 # mirror L 3 rot to right
    18 # T
    15 # T 1 rot to right
    16 # T 2 rot to right
    17 # T 3 rot to right
)

pieces_vertical_check_pixels=(
    "3 0" # bottom pixel of I vertical 
    "0 0 0 1 0 2 0 3" # all pixels of I horizontal
    "1 0 1 1" # bottom pixels square
    "2 0 2 1" # L
    "0 1 0 2 1 0" # L 1 rot to right
    "0 0 2 1" # L 2 rot to right
    "1 0 1 1 1 2" # L 3 rot to right
    "0 0 1 1 1 2" # Z
    "1 1 2 0" # Z 1 rot to right
    "0 2 1 0 1 1" # inverse Z
    "1 0 2 1" # inverse Z 1 rot to right
    "2 0 2 1" # mirror L
    "1 0 1 1 1 2" # mirror L 1 rot to right
    "0 1 2 0" # mirror L 2 rot to right
    "0 0 0 1 1 2" # mirror L 3 rot to right
    "1 0 1 1 1 2" # T
    "1 1 2 0" # T 1 rot to right
    "0 0 0 2 1 1" # T 2 rot to right
    "1 0 2 1" # T 3 rot to right
)

pieces_horizontal_left_check_pixels=(
    "0 0 1 0 2 0 3 0" # all pixels of I vertical 
    "0 0" # left pixel of I horizontal 
    "0 0 1 0" # left pixels of square 
    "0 0 1 0 2 0" # L
    "0 0 1 0" # L 1 rot to right
    "0 0 1 1 2 1" # L 2 rot to right
    "0 2 1 0" # L 3 rot to right
    "0 0 1 1" # Z
    "0 1 1 0 2 0" # Z 1 rot to right
    "0 1 1 0" # inverse Z
    "0 0 1 0 2 1" # inverse Z 1 rot to right
    "0 1 1 1 2 0" # mirror L
    "0 0 1 0" # mirror L 1 rot to right
    "0 0 1 0 2 0" # mirror L 2 rot to right
    "0 0 1 2" # mirror L 3 rot to right
    "0 1 1 0" # T
    "0 0 1 0 2 0" # T 1 rot to right
    "0 0 1 1" # T 2 rot to right
    "0 1 1 0 2 1" # T 3 rot to right
)

pieces_horizontal_right_check_pixels=(
    "0 0 1 0 2 0 3 0" # all pixels of I vertical 
    "0 3" # right pixel of I horizontal 
    "0 1 1 1" # right pixels of square
    "2 1" # L
    "0 2 1 0" # L 1 rot to right
    "0 1 1 1 2 1" # L 2 rot to right
    "0 2 1 2" # L 3 rot to right
    "0 1 1 2" # Z
    "0 1 1 1 2 0" # Z 1 rot to right
    "0 2 1 1" # inverse Z
    "0 0 1 1 2 1" # inverse Z 1 rot to right
    "0 1 1 1 2 1" # mirror L
    "0 0 1 2" # mirror L 1 rot to right
    "0 1 1 0 2 0" # mirror L 2 rot to right
    "0 2 1 2" # mirror L 3 rot to right
    "0 1 1 2" # T
    "0 0 1 1 2 0" # T 1 rot to right
    "0 2 1 1" # T 2 rot to right
    "0 1 1 1 2 1" # T 3 rot to right
)

pieces_starting_position=(0 2 3 7 9 11 15)

parse_args ()
{
	local OPTIND opt
	while getopts ":c:r:l:h" opt; do
		case ${opt} in
			c )
			cols=$OPTARG
			;;
			r )
			rows=$OPTARG
			;;
			l )
			set_start_level $OPTARG
			;;
			h )
			usage
			exit 0
			;;
			\? )
			usage
			exit 1
			;;
		esac
	done
}

set_start_level () 
{
	start_level=$1

    if [[ $start_level -gt 10 ]] || [[ $start_level -lt 1 ]]; then
		usage
		exit 1
    fi
    level=$start_level
}

usage ()
{
    echo "usage: $0 [-c cols ] [-r rows] [-l start level]"
    echo "controls: left, right and down arrows for movement, z and x for rotation"
    echo "  -h display help"
    echo "  -c cols specify game area cols. Make sure it's not higher then the actual terminal's width. "
    echo "  -r rows specify game area rows. Make sure it's not higher then the actual terminal's height."
    echo "  -l specify start level. Value from 1-10."
}

clear_game_area_screen ()
{
	for ((i=1;i<rows;i++)); do
		for ((j=1;j<cols;j++)); do
			screen[$i,$j]=$EMPTY
		done
	done
	draw_game_area_boundaries
    clear_next_piece
}

draw_game_area_boundaries()
{
	for i in 0 $rows; do
		for ((j=0;j<cols;j++)); do
			screen[$i,$j]=$HORIZONTAL_BAR
		done
	done
	for j in 0 $cols; do
		for ((i=0;i<rows+1;i++)); do
			screen[$i,$j]=$VERTICAL_BAR
		done
	done
	screen[0,0]=$CORNER_ICON
	screen[0,$cols]=$CORNER_ICON
	screen[$rows,$cols]=$CORNER_ICON
	screen[$rows,0]=$CORNER_ICON
}

print_screen ()
{
	tput cup 0 0
	for ((i=0;i<rows+1;i++)); do
		for ((j=0;j<cols+1;j++)); do
			printf "${screen[$i,$j]}"
		done
		printf "\n"
	done
    echo "Score: $score"
    echo "Level: $level"
    tput cup 0 $next_piece_offset_cols
    printf "Next: \n"
	for ((i=0;i<next_piece_view_rows;i++)); do
        tput cup $(($i + 1)) $next_piece_offset_cols
		for ((j=0;j<next_piece_view_cols;j++)); do
			printf "${next_piece_view[$i,$j]}"
		done
		printf "\n"
	done
}

print_empty_screen ()
{
	tput cup 1 1
	for ((i=1;i<rows;i++)); do
		for ((j=1;j<cols;j++)); do
			printf "${EMPTY}"
		done
		printf "\n"
	done
    printf "Score:                           \n"
    printf "Level:                           \n"
    printf "Next piece:                        \n"
	for ((i=0;i<next_piece_view_rows;i++)); do
		for ((j=0;j<next_piece_view_cols;j++)); do
			printf "${EMPTY}"
		done
		printf "\n"
	done
}

handle_input ()
{
	if [[ "$1" = "$ARROW_UP" ]]; then
        :
	elif [[ "$1" = "$ARROW_DOWN" ]]; then
        game
        #move_piece_down
	elif [[ "$1" = "$ARROW_RIGHT" ]]; then
        if check_piece_horizontal_right_collission; then
            clear_piece
            piece_col=$(( piece_col + 1 ))
            draw_piece
        fi
	elif [[ "$1" = "$ARROW_LEFT" ]]; then
        if check_piece_horizontal_left_collission; then
            clear_piece
            piece_col=$(( piece_col - 1 ))
            draw_piece
        fi
	elif [[ "$1" = "$X" ]]; then
        # try to rotate right
        local prev_piece=$piece_id
        local next_piece=${pieces_next_piece_rot_right[$prev_piece]}
        clear_piece
        if check_next_piece_collission $next_piece; then
            piece_id=$next_piece
        fi
        draw_piece
	elif [[ "$1" = "$Z" ]]; then
        # try to rotate left 
        local prev_piece=$piece_id
        local next_piece=${pieces_next_piece_rot_left[$prev_piece]}
        clear_piece
        if check_next_piece_collission $next_piece; then
            piece_id=$next_piece
        fi
        draw_piece
	else
		:
	fi
}

spawn_random_piece()
{
    local starting_piece_pos_id=$(( $RANDOM%( ${#pieces_starting_position[@]}) ))
    piece_id=${next_piece_id}
    next_piece_id=${pieces_starting_position[$starting_piece_pos_id]}
    piece_col=$(( cols/2 ))
    piece_row=1
    draw_piece
    clear_next_piece
    draw_next_piece
}

clear_piece()
{
    current_piece=(${pieces[$piece_id]})
    for ((i = 0; i < ${#current_piece[@]}; i+=2)); do
		local row=${current_piece[$i]}
		local col=${current_piece[$i+1]}
		screen[$((row + piece_row)),$((col + piece_col))]=$EMPTY
	done
}

draw_piece_at_pos()
{
    local pos_row=$1
    local pos_col=$2
    current_piece=(${pieces[$piece_id]})
    for ((i = 0; i < ${#current_piece[@]}; i+=2)); do
		local row=${current_piece[$i]}
		local col=${current_piece[$i+1]}
		screen[$((row + $pos_row)),$((col + $pos_col))]=$BLOCK_ICON
	done
}

draw_piece()
{
    draw_piece_at_pos $piece_row $piece_col
}

draw_next_piece()
{
    local pos_row=0
    local pos_col=0
    current_piece=(${pieces[$next_piece_id]})
    for ((i = 0; i < ${#current_piece[@]}; i+=2)); do
		local row=${current_piece[$i]}
		local col=${current_piece[$i+1]}
		next_piece_view[$((row + $pos_row)),$((col + $pos_col))]=$BLOCK_ICON
	done
}

clear_next_piece()
{
	for ((i=0;i<next_piece_view_rows;i++)); do
		for ((j=0;j<next_piece_view_cols;j++)); do
			next_piece_view[$i,$j]=$EMPTY
		done
	done
}

check_piece_vertical_collission() {
    local current_piece_vertical_check_pixels=(${pieces_vertical_check_pixels[$piece_id]})
    for ((i = 0; i < ${#current_piece_vertical_check_pixels[@]}; i+=2)); do
        local pixel_row=$(( piece_row + ${current_piece_vertical_check_pixels[$i]} ))
        local pixel_col=$(( piece_col + ${current_piece_vertical_check_pixels[$i+1]} ))
        local pixel_below_row=$(( pixel_row + 1 ))
        local pixel_below=${screen[$pixel_below_row,$pixel_col]}
        if [[ $pixel_below != $EMPTY ]]; then 
            return 1
        fi
	done
    return 0
}

check_piece_horizontal_left_collission() {
    local current_piece_horizontal_left_check_pixels=(${pieces_horizontal_left_check_pixels[$piece_id]})
    for ((i = 0; i < ${#current_piece_horizontal_left_check_pixels[@]}; i+=2)); do
        local pixel_row=$(( piece_row + ${current_piece_horizontal_left_check_pixels[$i]} ))
        local pixel_col=$(( piece_col + ${current_piece_horizontal_left_check_pixels[$i+1]} ))
        local pixel_left_col=$(( pixel_col - 1 ))
        local pixel_left=${screen[$pixel_row,$pixel_left_col]}
        if [[ $pixel_left != $EMPTY ]]; then 
            return 1
        fi
	done
    return 0
}

check_piece_horizontal_right_collission() {
    local current_piece_horizontal_right_check_pixels=(${pieces_horizontal_right_check_pixels[$piece_id]})
    for ((i = 0; i < ${#current_piece_horizontal_right_check_pixels[@]}; i+=2)); do
        local pixel_row=$(( piece_row + ${current_piece_horizontal_right_check_pixels[$i]} ))
        local pixel_col=$(( piece_col + ${current_piece_horizontal_right_check_pixels[$i+1]} ))
        local pixel_right_col=$(( pixel_col + 1 ))
        local pixel_right=${screen[$pixel_row,$pixel_right_col]}
        if [[ $pixel_right != $EMPTY ]]; then 
            return 1
        fi
	done
    return 0
}

check_next_piece_collission() {
    local next_piece=(${pieces[$1]})
    for ((i = 0; i < ${#next_piece[@]}; i+=2)); do
        local pixel_row=$(( piece_row + ${next_piece[$i]} ))
        local pixel_col=$(( piece_col + ${next_piece[$i+1]} ))
        local pixel=${screen[$pixel_row,$pixel_col]}
        if [[ $pixel != $EMPTY ]]; then 
            return 1
        fi
	done
    return 0
}

score_for_line_deletion=(0 100 300 500 800)

check_full_line() {
    local current_piece=(${pieces[$piece_id]})
    local rows_to_remove=()
    for ((i = 0; i < ${#current_piece[@]}; i+=2)); do
        local pixel_row=$(( piece_row + ${current_piece[$i]} ))
        local pixel_col=$(( piece_col + ${current_piece[$i+1]} ))
        local pixel=${screen[$pixel_row,$pixel_col]}
        local full_line=1
		for ((j=1;j<cols;j++)); do
			local pixel_to_check=${screen[$pixel_row,$j]};
            if [[ $pixel_to_check != $BLOCK_ICON ]]; then
                full_line=0 
            fi
		done
        if [[ $full_line -eq 1 ]]; then 
            rows_to_remove+=([${pixel_row}]=1)
        fi
	done
    score+=${score_for_line_deletion[${#rows_to_remove[@]}]}
    lines_cleared+=${#rows_to_remove[@]}
    level=$(( $start_level + $(( ${lines_cleared}/2 )) ))
    for row_to_delete in "${!rows_to_remove[@]}"
    do
        remove_row $row_to_delete
    done
    return 0
}

remove_row() {
	for ((i=$1;i>1;i--)); do
		for ((j=0;j<cols+1;j++)); do
            local row_above=$(( $i-1 ))
            screen[$i,$j]=${screen[$row_above,$j]}
		done
	done
}

move_piece_down() {
    for (( ; ; ))
    do
        clear_piece
        piece_row=$(( piece_row + 1))
        draw_piece
        if ! check_piece_vertical_collission; then
            # double piece score for quick down drop
            add_piece_score
            add_piece_score
            check_full_line
            spawn_random_piece
            return 0
        fi
    done
}

check_end_condition() {
	for ((j=1;j<cols;j++)); do
        local pixel=${screen[1,$j]};
        if [[ $pixel != $EMPTY ]]; then 
            return 1
        fi
    done
    return 0
}

add_piece_score () {
    local current_piece=(${pieces[$piece_id]})
    score+=$((${#current_piece[@]}/2))
}

game ()
{
    if ! check_piece_vertical_collission; then
        add_piece_score
        check_full_line
        spawn_random_piece
        if ! check_piece_vertical_collission; then
            if ! check_end_condition; then 
                print_screen
                tput cup $(( $rows+4 )) 0
                echo You lose!
                exit 0
            fi
        fi
    fi
	clear_piece
    piece_row=$(( piece_row + 1))
    draw_piece
}

set_pixel ()
{
	tput cup "$1" "$2"
	printf "%s" "$3"
}

set_cursor_below_game ()
{
	tput cup $(($rows+1)) 0
}

game_tick=0
# execute game loop, then sleep for REFRESH_TIME in a subshell and send SIGALRM to the current process
# thanks to the trap below it will trigger the game loop again
tick() {
    game_tick=$(( ${game_tick} + 1 ))
	tput cup 0 0
	handle_input "$key"
    key="unknown"
    game_tick_slowdown_factor=$((15 - $level))
    if [[ $game_tick_slowdown_factor -le 1 ]]; then
        game_tick_slowdown_factor=1
    fi 
    mod_tick=$(( ${game_tick}%${game_tick_slowdown_factor} ))
    if [[ $mod_tick -eq 0 ]]; then
	    game
    fi
    print_screen
	( sleep $REFRESH_TIME; kill -s ALRM $$ &> /dev/null )&
}
trap tick ALRM

parse_args "$@"
next_piece_offset_cols=$(( $cols + 3))
clear
# initialize game area
clear_game_area_screen
spawn_random_piece
clear_piece
spawn_random_piece
print_screen
# start game
tick
# poll for user input in loop
for (( ; ; ))
do
	read -rsn 1 key
done
