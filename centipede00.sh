#!/bin/bash

# Centipede para Git Bash (Windows 8.1)
# - SCORE | FPS | TIMER centralizados uma linha acima da borda
# - Fim: mostra mensagem central e permite R (reiniciar) / S (sair)
# - Menu de dificuldade dentro do frame (sempre aparece ao iniciar/reiniciar)
# - Cores com tput setaf (compatível)
# - Setas e teclas vi (h j k l)

############# Configurações da caixa e jogo #############

SNAKECHAR="@"
WALLCHAR="X"
APPLECHAR="o"

SNAKESIZE=3
BASE_DELAY=0.08         # velocidade base
DELAY=$BASE_DELAY
FIRSTROW=3
FIRSTCOL=1
LASTCOL=60
LASTROW=22

AREAMAXX=$(( LASTCOL - 1 ))
AREAMINX=$(( FIRSTCOL + 1 ))
AREAMAXY=$(( LASTROW - 1 ))
AREAMINY=$(( FIRSTROW + 1 ))

############# Variáveis globais de estado #############

POSX=0
POSY=0
APPLEX=0
APPLEY=0

SCORE=0
FPS=0
FRAMES=0
LAST_SEC=$(date +%s)

SECONDS_REMAIN=$((5*60))  # 5 minutos
DIRECTION="r"
RUNNING=1
VICTORY=0
LOSE_MSG=""

LASTPOSX=()
LASTPOSY=()

############# Funções utilitárias #############

draw_border() {
    tput setaf 6
    for ((x=FIRSTCOL; x<=LASTCOL; x++)); do
        tput cup $FIRSTROW $x; printf "%s" "$WALLCHAR"
        tput cup $LASTROW $x; printf "%s" "$WALLCHAR"
    done
    for ((y=FIRSTROW; y<=LASTROW; y++)); do
        tput cup $y $FIRSTCOL; printf "%s" "$WALLCHAR"
        tput cup $y $LASTCOL; printf "%s" "$WALLCHAR"
    done
    tput sgr0
}

clear_inside() {
    for ((y=AREAMINY; y<=AREAMAXY; y++)); do
        tput cup "$y" $((FIRSTCOL+1))
        printf "%*s" $((LASTCOL - FIRSTCOL - 1)) " "
    done
}

center_in_box() {
    local text="$1"
    local box_width=$((LASTCOL - FIRSTCOL + 1))
    local col=$(( FIRSTCOL + (box_width - ${#text}) / 2 ))
    (( col < 0 )) && col=0
    echo -n "$col"
}

draw_status() {
    local mm=$(printf "%02d" $((SECONDS_REMAIN/60)))
    local ss=$(printf "%02d" $((SECONDS_REMAIN%60)))
    local status="SCORE: $SCORE   FPS: $FPS   TIMER: ${mm}:${ss}"
    local col=$(center_in_box "$status")
    tput cup $((FIRSTROW-1)) $col
    printf "%s" "$status"
}

rand_apple_coords() {
    APPLEX=$(( (RANDOM % (AREAMAXX - AREAMINX + 1)) + AREAMINX ))
    APPLEY=$(( (RANDOM % (AREAMAXY - AREAMINY + 1)) + AREAMINY ))
}

draw_apple() {
    local valid=0
    while (( !valid )); do
        valid=1
        rand_apple_coords
        for ((i=0; i<${#LASTPOSX[@]}; i++)); do
            if [[ $APPLEX -eq ${LASTPOSX[i]} && $APPLEY -eq ${LASTPOSY[i]} ]]; then
                valid=0; break
            fi
        done
    done
    tput setaf 1
    tput cup $APPLEY $APPLEX
    printf "%s" "$APPLECHAR"
    tput sgr0
}

grow_snake() {
    for _ in {1..3}; do
        LASTPOSX=( "${LASTPOSX[0]}" "${LASTPOSX[@]}" )
        LASTPOSY=( "${LASTPOSY[0]}" "${LASTPOSY[@]}" )
    done
    draw_apple
}

move_snake() {
    case "$DIRECTION" in
        u) ((POSY--));;
        d) ((POSY++));;
        l) ((POSX--));;
        r) ((POSX++));;
    esac

    if (( POSX <= FIRSTCOL || POSX >= LASTCOL || POSY <= FIRSTROW || POSY >= LASTROW )); then
        LOSE_MSG="GAME OVER! Você bateu na parede!"
        RUNNING=0
        return
    fi

    for ((i=1; i<${#LASTPOSX[@]}; i++)); do
        if [[ $POSX -eq ${LASTPOSX[i]} && $POSY -eq ${LASTPOSY[i]} ]]; then
            LOSE_MSG="GAME OVER! Você se mordeu!"
            RUNNING=0
            return
        fi
    done

    tput cup ${LASTPOSY[0]} ${LASTPOSX[0]}; printf " "

    LASTPOSX=( "${LASTPOSX[@]:1}" "$POSX" )
    LASTPOSY=( "${LASTPOSY[@]:1}" "$POSY" )

    tput setaf 2
    tput cup $POSY $POSX
    printf "%s" "$SNAKECHAR"
    tput sgr0

    if (( POSX == APPLEX && POSY == APPLEY )); then
        grow_snake
        SCORE=$((SCORE+10))
    fi
}

read_input_nonblock() {
    local key
    IFS= read -rsn1 -t "$DELAY" key
    if [[ -n "$key" ]]; then
        case "$key" in
            k) DIRECTION="u";;
            j) DIRECTION="d";;
            h) DIRECTION="l";;
            l) DIRECTION="r";;
            x) LOSE_MSG="Saindo..."; RUNNING=0;;
            $'\x1b')
                IFS= read -rsn2 -t 0.001 key2
                case "$key2" in
                    "[A") DIRECTION="u";;
                    "[B") DIRECTION="d";;
                    "[D") DIRECTION="l";;
                    "[C") DIRECTION="r";;
                esac
                ;;
        esac
    fi
}

update_time_and_fps_per_second() {
    local now=$(date +%s)
    if (( now != LAST_SEC )); then
        LAST_SEC=$now
        FPS=$FRAMES
        FRAMES=0
        if (( SECONDS_REMAIN > 0 )); then
            SECONDS_REMAIN=$((SECONDS_REMAIN-1))
        else
            VICTORY=1
            RUNNING=0
            return
        fi
    fi
    FRAMES=$((FRAMES+1))
}

difficulty_menu() {
    clear
    draw_border

    local l1="Escolha o modo:"
    local l2="1 - Fácil  (Velocidade Normal)"
    local l3="2 - Médio  (8x mais rápido)"
    local l4="3 - Difícil (16x mais rápido)"

    local max=${#l1}
    (( ${#l2} > max )) && max=${#l2}
    (( ${#l3} > max )) && max=${#l3}
    (( ${#l4} > max )) && max=${#l4}

    local box_w=$((LASTCOL - FIRSTCOL + 1))
    local col=$(( FIRSTCOL + (box_w - max) / 2 ))
    local start_y=$(( (FIRSTROW + LASTROW) / 2 - 2 ))

    tput cup "$start_y"     "$col"; printf "%s" "$l1"
    tput cup $((start_y+1)) "$col"; printf "%s" "$l2"
    tput cup $((start_y+2)) "$col"; printf "%s" "$l3"
    tput cup $((start_y+3)) "$col"; printf "%s" "$l4"

    local choice
    while true; do
        IFS= read -rsn1 choice
        case "$choice" in
            1) DELAY=$BASE_DELAY; break;;
            2) DELAY=$(echo "$BASE_DELAY/8"  | bc -l); break;;
            3) DELAY=$(echo "$BASE_DELAY/16" | bc -l); break;;
        esac
    done

    clear_inside
    draw_border
}

center_message_in_box() {
    local line1="$1"
    local line2="$2"
    local cy=$(( (FIRSTROW + LASTROW) / 2 ))
    local box_w=$((LASTCOL - FIRSTCOL + 1))
    local col1=$(( FIRSTCOL + (box_w - ${#line1}) / 2  ))
    local col2=$(( FIRSTCOL + (box_w - ${#line2}) / 2  ))
    tput cup "$cy" "$col1"; printf "%s" "$line1"
    tput cup $((cy+1)) "$col2"; printf "%s" "$line2"
}

welcome_screen() {
    clear
    draw_border
    local msg="Bem-vindo ao Centipede!"
    local sub="Pressione qualquer tecla para continuar..."
    center_message_in_box "$msg" "$sub"
    IFS= read -rsn1
    clear_inside
    draw_border
}

end_menu() {
    tput sgr0
    local title="" hint="Aperte R para reiniciar e S para sair"
    if (( VICTORY )); then
        title="Você venceu!"
    else
        title="$LOSE_MSG"
    fi
    clear_inside
    draw_border
    center_message_in_box "$title" "$hint"

    while true; do
        IFS= read -rsn1 key
        case "$key" in
            [Rr]) return 0 ;;
            [Ss]) return 1 ;;
        esac
    done
}

init_game() {
    clear
    stty -echo
    tput civis
    tput sgr0

    welcome_screen
    difficulty_menu

    POSX=$(( (FIRSTCOL + LASTCOL) / 2 ))
    POSY=$(( (FIRSTROW + LASTROW) / 2 ))

    SCORE=0
    FPS=0
    FRAMES=0
    LAST_SEC=$(date +%s)
    SECONDS_REMAIN=$((5*60))
    VICTORY=0
    LOSE_MSG=""
    DIRECTION="r"

    LASTPOSX=()
    LASTPOSY=()
    for ((i=0; i<SNAKESIZE; i++)); do
        LASTPOSX+=("$POSX")
        LASTPOSY+=("$POSY")
    done

    draw_border
    draw_status
    draw_apple

    RUNNING=1
}

game_loop() {
    while (( RUNNING )); do
        read_input_nonblock
        move_snake
        update_time_and_fps_per_second
        draw_status
    done
}

############# Execução #############

while true; do
    init_game
    game_loop
    if end_menu; then
        continue
    else
        tput cnorm
        stty echo
        tput sgr0
        tput cup $((LASTROW+2)) 0
        exit 0
    fi
done
