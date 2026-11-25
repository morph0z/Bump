#!/bin/bash

VERSION=1.0
CREATOR='Jamal Awojide'
TIME=$(date +"%H:%M")

shopt -s extglob

PAUSED=false

#Check if playlists folder doesn't exists.
if [[ ! -d playlists ]]; then
    mkdir playlists
fi

SONG_ARG_CHOOSE=$1

if [[ ! -z $SONG_ARG_CHOOSE ]]; then
    if [ -z "$(ls -A playlists)" ]; then
        SONG_ARG_CHOOSE='playlists/'$1
    else 
        SONG_ARG_CHOOSE='playlists/*/'$1
    fi
fi

declare -i SONG_VOLUME=$2
declare -i SFX_ENABLED

if [[ -e saves/settings.txt ]]; then
    SONG_VOLUME=$(sed -n "1p" saves/settings.txt)
    SFX_ENABLED=$(sed -n "2p" saves/settings.txt)
else
    SFX_ENABLED=1
    if [[ $SONG_VOLUME -eq 0 ]]; then
        SONG_VOLUME=50
    fi

    if [[ $SONG_VOLUME -ge 100 ]]; then
        SONG_VOLUME=100
    elif [[ $SONG_VOLUME -le 0 ]]; then
        SONG_VOLUME=0
    fi
fi

#start sound
if [[ $SFX_ENABLED == 1 ]]; then
    ffplay "sfx/StartSnd.mp3" -loglevel quiet -nostats -nodisp -autoexit -volume $SONG_VOLUME &
fi

#https://unix.stackexchange.com/users/alexkli Alexander Klimetschek you a reall one.
# Renders a text based list of options that can be selected by the
# user using up, down and enter keys and returns the chosen option.
#
#   Arguments   : list of options, maximum of 256
#                 "opt1" "opt2" ...
#   Return value: selected index (0 for opt1, 1 for opt2 ...)
function select_option {

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "   $1 "; }
    print_selected()   { printf "  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    key_input()        { read -s -n3 key 2>/dev/null >&2
                         if [[ $key = $ESC[A ]]; then echo up;    fi
                         if [[ $key = $ESC[B ]]; then echo down;  fi
                         if [[ $key = ""     ]]; then echo enter; fi; }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt; do printf "\n"; done

    # determine current screen position for overwriting the options
    local lastrow=`get_cursor_row`
    local startrow=$(($lastrow - $#))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local selected=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for opt; do
            cursor_to $(($startrow + $idx))
            if [ $idx -eq $selected ]; then
                print_selected "$opt"
            else
                print_option "$opt"
            fi
            ((idx++))
        done

        if [[ -n $SONG_ARG_CHOOSE ]]; then
            break
        fi

        # user key control
        case `key_input` in
            enter) break;;
            up)    ((selected--));
                   if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
            down)  ((selected++));
                   if [ $selected -ge $# ]; then selected=0; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $selected
}

#https://stackoverflow.com/users/ken-bertelson ken is a life saver! (he saved my baby!)
containsElement () {
    declare -a first=("${!1}")

    declare -a second=("${!2}")

    for element1 in "${first[@]}"; do
        for element2 in "${second[@]}"; do
            if [[ "$element1" == "$element2" ]]; then
                return 0
            fi
        done
    done
    return 1
}

function song_selection {
    clear

    echo " "
    echo "-----------------------------------"
    echo "Select song..."
    
    if [[ -z $SONG_ARG_CHOOSE ]]; then
        if [[ ${#FILES_LOCAL_TO_BUMP[@]} == 0 ]]; then
            echo "File not found!"
        else
            options=( "${FILES_LOCAL_TO_BUMP[@]}" )
        fi
    else
        if [[ ${#found_song[@]} == 0 ]]; then
            echo "File not found!"
        else
            options=("${found_song[@]}")
        fi
    fi

    select_option "${options[@]}"
    choice=$?

    echo "PLAYING: ${options[$choice]}"
    echo " "
    echo "main menu: q"
    echo "pause/play song: p"
    echo "play new song: n"
    echo "-----------------------------------"

    ffplay "${options[$choice]}" -loglevel quiet -nostats -nodisp -autoexit -volume $SONG_VOLUME &
    song_pid=$!

}


function playlist_selection_play {
    playing=${playlist_songs[$inc]}
    ffplay "${playlist_songs[$inc]}" -loglevel quiet -nostats -nodisp -autoexit -volume $SONG_VOLUME &
    song_pid=$!  

    while true; do
        read -sn 1 keybinds
        case "$keybinds" in
            'n')
                kill -15 $song_pid
                playlist_selection
                ;;
            'p') 
                if [[ "$PAUSED" == false ]]; then
                    kill -20 "$song_pid"
                    PAUSED=true
                elif [[ "$PAUSED" == true ]]; then
                    kill -18 "$song_pid"
                    PAUSED=false
                fi
                ;;
            'q') 
                if [[ $inc -eq $((${#playlist_songs}-1)) ]]; then
                    inc=0
                fi
                echo ' skip song' 
                kill -15 $song_pid



                break
                ;;
        esac
    done 
}

function playlist_selection {
    clear

    echo " "
    echo "-----------------------------------"
    echo "Select playlist..."
    

    if [[ ${#PLAYLISTS_LOCAL_TO_BUMP[@]} == 0 ]]; then
        echo "Playlists not found!"
    else
        options=("${PLAYLISTS_LOCAL_TO_BUMP[@]}")
    fi

    select_option "${options[@]}"
    choice=$?

    playlist_songs=(${options[$choice]}/*)
    num_playlist_songs=



    echo "PLAYING: $playing"
    echo " "
    echo "main menu: q"
    echo "pause/play song: p"
    echo "play new song: n"
    echo "-----------------------------------"

    declare -i inc=0
    for (( i=0; i<${#playlist_songs[@]}; i++ )); do
        playlist_selection_play
        inc+=1
        #wait $song_pid
    done


}

#LINE 1: volume setting
#LINE 2: sfx enable setting
function save_settings {
    if [[ ! -e saves/settings.txt ]]; then
        mkdir saves
        touch saves/settings.txt
    fi
    
    if [[ -e saves/settings.txt ]]; then
        echo $SONG_VOLUME > saves/settings.txt
        echo $SFX_ENABLED >> saves/settings.txt
    fi
}

while true; do

    FILES_LOCAL_TO_BUMP=( playlists/*/*.@(mp3|mp4|wav|ogg|flac|opus) )
    PLAYLISTS_LOCAL_TO_BUMP=( playlists/* )

    clear

    shopt -s nullglob
    files=( * )

    fuzzy_result=()
    fuzzy_chars=''
    if [[ "${#SONG_ARG_CHOOSE[@]}" -ne 0 ]]; then

        for ((i=0; i<${#SONG_ARG_CHOOSE}; i++)) do
            if [[ i -eq 0 ]]; then
                fuzzy_chars+='*@('
            fi
            #NOT AI CODE: i just did smth dumb and im to scared to touch it
            if [[ i -ne ${#SONG_ARG_CHOOSE}-1 ]]; then
                fuzzy_chars+=""${SONG_ARG_CHOOSE:i:1}""
                fuzzy_chars+='|'
            elif [[ i -eq ${#SONG_ARG_CHOOSE}-1 ]]; then
                fuzzy_chars+=""${SONG_ARG_CHOOSE:i:1}""
                fuzzy_chars+=')*.@(mp3|mp4|wav|ogg|flac|opus)'
            fi
            
        done 
        fuzzy_result=( $fuzzy_chars )
    fi

    shopt -s nocaseglob

    auto_comp_result=()

    auto_comp_seach='*'
    auto_comp_seach+=$SONG_ARG_CHOOSE
    auto_comp_seach+='*.@(mp3|mp4|wav|ogg|flac|opus)'

    auto_comp_result=( $auto_comp_seach  )

    shopt -u nocaseglob


    found_song=()
    if containsElement fuzzy_result[@] auto_comp_result[@] ; then
        found_song=( "${auto_comp_result[@]}" )
    else
        found_song=( "${fuzzy_result[@]}" )
    fi

    echo '^-------------BUMP-------------^
|
| ~Time: '$TIME'
| ~Version: '$VERSION'        
| ~By: '$CREATOR' 
|
| [1] Play Single Song
| [2] Play Playlist
| [3] Settings
| [4] Exit
\_______________________________'

    
    if [[ -n $SONG_ARG_CHOOSE ]]; then option=1
    else read -p "Select an option: " option; fi
    

    if [[ "$option" == '1' ]]; then
        #play single song

        song_selection


        #Playback controls
        while true; do

            read -sn 1 keybinds
            case "$keybinds" in
                'n')
                    kill -15 $song_pid
                    SONG_ARG_CHOOSE=''
                    song_selection
                    ;;
                'p') 
                    if [[ "$PAUSED" == false ]]; then
                        kill -20 "$song_pid"
                        PAUSED=true
                    elif [[ "$PAUSED" == true ]]; then
                        kill -18 "$song_pid"
                        PAUSED=false
                    fi
                    ;;
                'q') 
                    option=0
                    echo ' quit' 
                    kill -15 $song_pid
                    SONG_ARG_CHOOSE=''
                    break
                    ;;
            esac
        done 
    fi


    if [[ "$option" == '2' ]]; then
        #play playlist
        echo "Select playlist..."
        
        playlist_selection

#        while true; do
            

 #       done
    fi


    if [[ "$option" == '3' ]]; then
        #edit settings

        sfx_enabled_visual='true'

        while true; do
            clear

            if [[ $SONG_VOLUME -ge 100 ]]; then
                SONG_VOLUME=100
            elif [[ $SONG_VOLUME -le 0 ]]; then
                SONG_VOLUME=0
            fi

            if [[ $SFX_ENABLED == 0 ]]; then
                sfx_enabled_visual='false'
            elif [[ $SFX_ENABLED == 1 ]]; then
                sfx_enabled_visual='true'
            fi


            echo "-----------------------------------"
            echo "Settings"
            echo $SONG_VOLUME
            echo "VOLUME: [$SONG_VOLUME]"
            echo "SFX: [$sfx_enabled_visual]"
            echo ''
            echo " [1] Increase Volume"
            echo " [2] Decrease Volume"
            echo " [3] Enable SFX"
            echo " [4] Exit"

            read -sn 1 keybinds
            case "$keybinds" in
                '1')
                    SONG_VOLUME+=10
                    ffplay "sfx/VolumeSnd.mp3" -loglevel quiet -nostats -nodisp -autoexit -volume $SONG_VOLUME &
                    ;;
                '2')
                    SONG_VOLUME=$SONG_VOLUME-10
                    ffplay "sfx/VolumeSnd.mp3" -loglevel quiet -nostats -nodisp -autoexit -volume $SONG_VOLUME &
                    ;;
                '3')
                    SFX_ENABLED=$((SFX_ENABLED + 1))
                    SFX_ENABLED=$((SFX_ENABLED % 2))
                    ;;
                '4')
                    break
                    ;;
            esac
        done
    fi

    if [[ "$option" == '4' ]]; then
        if [[ $SFX_ENABLED == 1 ]]; then
            ffplay "sfx/CloseSnd.mp3" -loglevel quiet -nostats -nodisp -autoexit -volume $SONG_VOLUME &
        fi
        save_settings
        
        echo "Closing bump..."
        break
    fi
done
