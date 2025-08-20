#!/bin/bash

# Snake para Git Bash (Windows 8.1)
# - SCORE | FPS | TIMER centralizados uma linha acima da borda
# - Fim: mostra mensagem central e permite R (reiniciar) / S (sair)
# - Loop único (sem processos em background)
# - Cores com tput setaf (compatível)
# - Setas e teclas vi (h j k l)

############# Configurações da caixa e jogo #############

SNAKECHAR="@"
WALLCHAR="X"
APPLECHAR="o"

SNAKESIZE=3
DELAY=0.08              # menor = mais rápido
FIRSTROW=3
FIRSTCOL=1
LASTCOL=60              # pode ajustar a largura do campo
LASTROW=22              # pode ajustar a altura do campo

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
    # borda superior e inferior
    tput setaf 6
    for ((x=FIRSTCOL; x<=LASTCOL; x++)); do
        tput cup $FIRSTROW $x; printf "%s" "$WALLCHAR"
        tput cup $LASTROW $x; printf "%s" "$WALLCHAR"
    done
    # laterais
    for ((y=FIRSTROW; y<=LASTROW; y++)); do
        tput cup $y $FIRSTCOL; printf "%s" "$WALLCHAR"
        tput cup $y $LASTCOL; printf "%s" "$WALLCHAR"
    done
    tput sgr0
}

center_in_box() {
    # $1: texto
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
    # escolhe posição que não colida com a cobra
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
    # cresce em 3 segmentos duplicando a cabeça antiga
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

    # colisão com parede
    if (( POSX <= FIRSTCOL || POSX >= LASTCOL || POSY <= FIRSTROW || POSY >= LASTROW )); then
        LOSE_MSG="GAME OVER! Você bateu na parede!"
        RUNNING=0
        return
    fi

    # colisão com o próprio corpo
    for ((i=1; i<${#LASTPOSX[@]}; i++)); do
        if [[ $POSX -eq ${LASTPOSX[i]} && $POSY -eq ${LASTPOSY[i]} ]]; then
            LOSE_MSG="GAME OVER! Você se mordeu!"
            RUNNING=0
            return
        fi
    done

    # apaga cauda
    tput cup ${LASTPOSY[0]} ${LASTPOSX[0]}; printf " "

    # atualiza histórico
    LASTPOSX=( "${LASTPOSX[@]:1}" "$POSX" )
    LASTPOSY=( "${LASTPOSY[@]:1}" "$POSY" )

    # desenha cabeça
    tput setaf 2
    tput cup $POSY $POSX
    printf "%s" "$SNAKECHAR"
    tput sgr0

    # maçã
    if (( POSX == APPLEX && POSY == APPLEY )); then
        grow_snake
        SCORE=$((SCORE+10))
    fi
}

read_input_nonblock() {
    # lê 1 char com timeout DELAY
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
                # possível seta
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
        # 1 segundo se passou
        LAST_SEC=$now
        FPS=$FRAMES
        FRAMES=0
        # Timer regressivo
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

end_menu() {
    # mostra mensagem e espera R ou S
    tput sgr0
    local title="" hint="Aperte R para reiniciar e S para sair"
    if (( VICTORY )); then
        title="Você venceu!"
    else
        title="$LOSE_MSG"
    fi

    # limpa área interna e redesenha borda pra servir de fundo
    for ((y=AREAMINY; y<=AREAMAXY; y++)); do
        tput cup "$y" $((FIRSTCOL+1))
        printf "%*s" $((LASTCOL - FIRSTCOL - 1)) " "
    done
    draw_border
    center_message_in_box "$title" "$hint"

    while true; do
        IFS= read -rsn1 key
        case "$key" in
            [Rr]) return 0 ;;   # reiniciar
            [Ss]) return 1 ;;   # sair
        esac
    done
}

init_game() {
    clear
    stty -echo
    tput civis
    tput sgr0

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
        # R: reiniciar (loop continua)
        continue
    else
        # S: sair
        tput cnorm
        stty echo
        tput sgr0
        tput cup $((LASTROW+2)) 0
        exit 0
    fi
done
