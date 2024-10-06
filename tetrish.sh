#!/usr/bin/env bash

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
trap 'tput cnorm; echo Exitting $0' EXIT

# declare default options
declare -i cols=12
declare -i rows=24
Y_TIME=0.14
REFRESH_TIME=$Y_TIME

# holds a screen matrix in an associative array
declare -A screen

declare -i piece_id 

declare -i piece_x
declare -i piece_y

# key input from user
key=""

# constants
declare -r BLOCK_ICON="X"
declare -r EMPTY=" "
declare -r ARROW_UP="A"
declare -r ARROW_DOWN="B"
declare -r ARROW_RIGHT="C"
declare -r ARROW_LEFT="D"
declare -r HORIZONTAL_BAR="-"
declare -r VERTICAL_BAR="|"
declare -r CORNER_ICON="+"

# Tetrimino shapes as arrays of coordinates
pieces=(
    "0 0 0 1 0 2 0 3" # I vertical 
    "0 0 1 0 2 0 3 0" # I horizontal 
    "0 0 0 1 1 1 1 0" # square
)

pieces_vertical_check_pixels=(
    "0 3" # I vertical 
    "0 0 1 0 2 0 3 0" # I horizontal 
    "0 1 1 1" # square
)

pieces_horizontal_left_check_pixels=(
    "0 0 0 1 0 2 0 3" # I vertical 
    "0 0" # I horizontal 
    "0 0 0 1" # square
)

pieces_horizontal_right_check_pixels=(
    "0 0 0 1 0 2 0 3" # I vertical 
    "3 0" # I horizontal 
    "1 0 1 1" # square
)

pieces_starting_position=(1 2)

parse_args ()
{
	local OPTIND opt
	while getopts ":c:r:s:h" opt; do
		case ${opt} in
			c )
			cols=$OPTARG
			;;
			r )
			rows=$OPTARG
			;;
			s )
			set_speed "$OPTARG"
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

set_speed () 
{
	local speed_level=$1

	case ${speed_level} in
		1)
		Y_TIME=1
		;;
		2)
		Y_TIME=0.8
		;;
		3)
		Y_TIME=0.6
		;;
		4)
		Y_TIME=0.4
		;;
		5)
		Y_TIME=0.2
		;;
		6)
		Y_TIME=0.16
		;;
		7)
		Y_TIME=0.12
		;;
		8)
		Y_TIME=0.08
		;;
		9)
		Y_TIME=0.04
		;;
		10)
		Y_TIME=0.02
		;;
		*)
		usage
		exit 1
		;;
	esac
	REFRESH_TIME=$Y_TIME
}

usage ()
{
    echo "usage: $0 [-c cols ] [-r rows] [-s speed]"
    echo "  -h display help"
    echo "  -c cols specify game area cols. Make sure it's not higher then the actual terminal's width. "
    echo "  -r rows specify game area rows. Make sure it's not higher then the actual terminal's height."
    echo "  -s speed specify snake speed. Value from 1-10."
}

clear_game_area_screen ()
{
	for ((i=1;i<rows;i++)); do
		for ((j=1;j<cols;j++)); do
			screen[$i,$j]=$EMPTY
		done
	done
	draw_game_area_boundaries
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
	for ((i=0;i<rows+1;i++)); do
		for ((j=0;j<cols+1;j++)); do
			printf "${screen[$i,$j]}"
		done
		printf "\n"
	done
}

handle_input ()
{
	if [[ "$1" = "$ARROW_UP" ]]; then
        test1=1
	elif [[ "$1" = "$ARROW_DOWN" ]]; then
        test1=1
	elif [[ "$1" = "$ARROW_RIGHT" ]]; then
        if check_piece_horizontal_collission; then
            clear_piece
            piece_x=$(( piece_x + 1 ))
            draw_piece
        fi
	elif [[ "$1" = "$ARROW_LEFT" ]]; then
        if check_piece_horizontal_collission; then
            clear_piece
            piece_x=$(( piece_x - 1 ))
            draw_piece
        fi
	else
		:
	fi
}

spawn_random_piece()
{
    local starting_piece_pos_id=$(( $RANDOM%2 ))
    piece_id=${pieces_starting_position[$starting_piece_pos_id]}
    piece_x=$(( cols/2 ))
    piece_y=1
    draw_piece
}

calc_new_snake_head_x () {
	local cur_head_x=$1
	local v_x=$2
	new_head_x=$(( cur_head_x+v_x ))
	if (( new_head_x == 0 )); then
		new_head_x=$(( cols-1 ))
	elif (( new_head_x == cols )); then
		new_head_x=1
	fi
}

calc_new_snake_head_y () {
	local cur_head_y=$1
	local v_y=$2
	new_head_y=$(( cur_head_y+v_y ))
	if (( new_head_y == 0 )); then
		new_head_y=$(( rows-1 ))
	elif (( new_head_y == rows )); then
		new_head_y=1
	fi
}

clear_piece()
{
    current_piece=(${pieces[$piece_id]})
    for ((i = 0; i < ${#current_piece[@]}; i+=2)); do
		local x=${current_piece[$i]}
		local y=${current_piece[$i+1]}
		screen[$((y + piece_y)),$((x + piece_x))]=$EMPTY
	done
}

draw_piece()
{
    current_piece=(${pieces[$piece_id]})
    for ((i = 0; i < ${#current_piece[@]}; i+=2)); do
		local x=${current_piece[$i]}
		local y=${current_piece[$i+1]}
		screen[$((y + piece_y)),$((x + piece_x))]=$BLOCK_ICON
	done
}

check_piece_vertical_collission() {
    current_piece_vertical_check_pixels=(${pieces_vertical_check_pixels[$piece_id]})
    for ((i = 0; i < ${#current_piece_vertical_check_pixels[@]}; i+=2)); do
        local pixel_x=$(( piece_x + ${current_piece_vertical_check_pixels[$i]} ))
        local pixel_y=$(( piece_y + ${current_piece_vertical_check_pixels[$i+1]} ))
        local pixel_below_y=$(( pixel_y + 1 ))
        local pixel_below=${screen[$pixel_below_y,$pixel_x]}
        #echo "pixel_below=${pixel_below}end"
        if [[ $pixel_below != $EMPTY ]]; then 
            return 1
        fi
	done
    return 0
}

check_piece_horizontal_collission() {
    local current_piece_horizontal_left_check_pixels=(${pieces_horizontal_left_check_pixels[$piece_id]})
    for ((i = 0; i < ${#current_piece[@]}; i+=2)); do
        local pixel_x=$(( piece_x + ${current_piece[$i]} ))
        local pixel_y=$(( piece_y + ${current_piece[$i+1]} ))
        local pixel_left_x=$(( pixel_x - 1 ))
        local pixel_left=${screen[$pixel_y,$pixel_left_x]}
        if [[ $pixel_left != $EMPTY ]]; then 
            return 1
        fi
	done
    local current_piece_horizontal_right_check_pixels=(${pieces_horizontal_right_check_pixels[$piece_id]})
    for ((i = 0; i < ${#current_piece[@]}; i+=2)); do
        local pixel_x=$(( piece_x + ${current_piece[$i]} ))
        local pixel_y=$(( piece_y + ${current_piece[$i+1]} ))
        local pixel_right_x=$(( pixel_x - 1 ))
        local pixel_right=${screen[$pixel_y,$pixel_right_x]}
        if [[ $pixel_right != $EMPTY ]]; then 
            return 1
        fi
	done
    return 0
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

game ()
{
    if ! check_piece_vertical_collission; then
        if ! check_end_condition; then 
            echo You lose!
            exit 0
        fi
    fi
	clear_piece
    piece_y=$(( piece_y + 1))
    draw_piece
    if ! check_piece_vertical_collission; then
        spawn_random_piece
    fi
    
	# local head_x=${snakebod_x[0]}
	# local head_y=${snakebod_y[0]}
	# declare -i new_head_x
	# declare -i new_head_y
	# calc_new_snake_head_x $head_x $vel_x
	# calc_new_snake_head_y $head_y $vel_y
	# local snake_length=${#snakebod_x[@]}

	# # check if new head positions is not inside snake
	# for ((i=0;i<snake_length-1;i++));
	# do
	# 	if [[ ${snakebod_y[i]} -eq $new_head_y ]] && [[ ${snakebod_x[i]} -eq $new_head_x ]]; then
	# 		set_cursor_below_game
	# 		echo Snake ate itself. You lose!
	# 		exit 0
	# 	fi
	# done

	# # if head is were food is, do not remove the last element of snake body and set new food position
	# if (( new_head_x == food_x )) && (( new_head_y == food_y )); then
	# 	snakebod_x=($new_head_x ${snakebod_x[@]:0:${#snakebod_x[@]}})
	# 	snakebod_y=($new_head_y ${snakebod_y[@]:0:${#snakebod_y[@]}})
	# 	draw_snake
	# 	check_win_cond
	# 	set_food
	# else
	# 	snakebod_x=($new_head_x ${snakebod_x[@]:0:${#snakebod_x[@]}-1})
	# 	snakebod_y=($new_head_y ${snakebod_y[@]:0:${#snakebod_y[@]}-1})
	# 	draw_snake
	# fi
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

# execute game loop, then sleep for REFRESH_TIME in a subshell and send SIGALRM to the current process
# thanks to the trap below it will trigger the game loop again
tick() {
	tput cup 0 0
	handle_input "$key"
    key="unknown"
    clear
	game
    print_screen
	( sleep $REFRESH_TIME; kill -s ALRM $$ &> /dev/null )&
}
trap tick ALRM

parse_args "$@"
# initialize game area
clear_game_area_screen
print_screen
spawn_random_piece
# start game
tick
# poll for user input in loop
for (( ; ; ))
do
	read -rsn 1 key
done
