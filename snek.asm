left equ 0
top equ 2
row equ 15
col equ 40
right equ left+col
bottom equ top+row

; The full block character is ASCII 219 (0DBh)
SOLID_BLOCK equ 0DBh

.model small
.data          
    msg db "Welcome to the snake game!!",0
    instructions db 0AH,0DH,"Use a, s, d and w to control your snake",0AH,0DH,"Use q anytime to quit",0DH,0AH, "Press any key to continue$"
    quitmsg db "Thanks for playing! hope you enjoyed",0
    gameovermsg db "OOPS!! your snake died! :P ", 0
    scoremsg db "Score: ",0
    
    ; --- ADDED CODE: Play Again Message ---
    playagainmsg db 0AH,0DH,"Play again? (Y/N)$" 
    
    head db '^',10,10
    body db SOLID_BLOCK,10,11, 3*15 DUP(0) ; <--- CHANGE 1: Initial body character is now SOLID_BLOCK
    segmentcount db 1
    fruitactive db 1
    fruitx db 8
    fruity db 8
    gameover db 0
    quit db 0   
    delaytime db 5


.stack
    dw   128  dup(0)


.code

main proc far
    mov ax, @data
    mov ds, ax 
    
    mov ax, 0b800H
    mov es, ax
    
    ; Set text mode (3) and clear screen
    mov ax, 0003H
    int 10H
    
    lea bx, msg
    mov dx,00
    call writestringat
    
    lea dx, instructions
    mov ah, 09H
    int 21h
    
    ; Wait for any key press
    mov ah, 07h
    int 21h
    
    ; Reset screen and draw box for game
    mov ax, 0003H
    int 10H
    call printbox      
    
    ; --- ADDED CODE: Reset game state for potential restart ---
    mov segmentcount, 1
    mov fruitactive, 1
    mov gameover, 0
    mov quit, 0
    mov delaytime, 5
    mov head, '^'
    mov byte ptr body, SOLID_BLOCK
    mov byte ptr body+3, 0 ; Clear second segment data
    
    ; Reset initial snake position
    mov byte ptr head+1, 10
    mov byte ptr head+2, 10
    mov byte ptr body+1, 10
    mov byte ptr body+2, 11
    ; --- END ADDED CODE ---

mainloop:       
    call delay             
    lea bx, msg
    mov dx, 00
    call writestringat
    call shiftsnake
    cmp gameover,1
    je gameover_mainloop
    
    call keyboardfunctions
    cmp quit, 1
    je quitpressed_mainloop
    call fruitgeneration
    call draw
    
    jmp mainloop
    
gameover_mainloop: 
    mov ax, 0003H
    int 10H
    mov delaytime, 100
    mov dx, 0000H
    lea bx, gameovermsg
    call writestringat
    call delay    
    
    ; --- START ADDED CODE: Play Again Logic ---
    ; Print "Play Again?" message
    lea dx, playagainmsg
    mov ah, 09h
    int 21h
    
    ; Read user input (only AL contains character)
    mov ah, 00h
    int 16h
    
    cmp al, 'y'
    je restart_game
    cmp al, 'Y'
    je restart_game
    
    ; If not 'y' or 'Y', fall through to quit
    jmp quit_mainloop    
    
restart_game:
    jmp main ; Jumps to the start of the main procedure to re-initialize the game
    ; --- END ADDED CODE ---
    
quitpressed_mainloop:
    mov ax, 0003H
    int 10H    
    mov delaytime, 100
    mov dx, 0000H
    lea bx, quitmsg
    call writestringat
    call delay    
    jmp quit_mainloop    

quit_mainloop:
;first clear screen
mov ax, 0003H
int 10h    
mov ax, 4c00h
int 21h  

delay proc 
    
    mov ah, 00
    int 1Ah
    mov bx, dx
    
jmp_delay:
    int 1Ah
    sub dx, bx

    cmp dl, delaytime                                                      
    jl jmp_delay    
    ret
    
delay endp
   
fruitgeneration proc
    mov ch, fruity
    mov cl, fruitx
regenerate:
    
    cmp fruitactive, 1
    je ret_fruitactive
    mov ah, 00
    int 1Ah

    push dx
    mov ax, dx
    xor dx, dx
    xor bh, bh
    mov bl, row
    dec bl
    div bx
    mov fruity, dl
    inc fruity
    
    pop ax
    mov bl, col
    dec dl
    xor bh, bh
    xor dx, dx
    div bx
    mov fruitx, dl
    inc fruitx
    
    cmp fruitx, cl
    jne nevermind
    cmp fruity, ch
    jne nevermind
    jmp regenerate             
nevermind:
    mov al, fruitx
    ror al,1
    jc regenerate
    
    add fruity, top
    add fruitx, left 
    
    mov dh, fruity
    mov dl, fruitx
    call readcharat
    cmp bl, SOLID_BLOCK ; <--- CHANGE 2: Collision check now uses SOLID_BLOCK
    je regenerate
    cmp bl, '^'
    je regenerate
    cmp bl, '<'
    je regenerate
    cmp bl, '>'
    je regenerate
    cmp bl, 'v'
    je regenerate    
    
ret_fruitactive:
    ret
fruitgeneration endp

dispdigit proc
    add dl, '0'
    mov ah, 02H
    int 21H
    ret
dispdigit endp   
   
dispnum proc    
    test ax,ax
    jz retz
    xor dx, dx

    mov bx,10
    div bx

    push dx
    call dispnum  
    pop dx
    call dispdigit
    ret
retz:
    mov ah, 02  
    ret    
dispnum endp   

setcursorpos proc
    mov ah, 02H
    push bx
    mov bh,0
    int 10h
    pop bx
    ret
setcursorpos endp

draw proc
    lea bx, scoremsg
    mov dx, 0109
    call writestringat
    
    
    add dx, 7
    call setcursorpos
    mov al, segmentcount
    dec al
    xor ah, ah
    call dispnum
        
    lea si, head
draw_loop:
    mov bl, ds:[si]
    test bl, bl
    jz out_draw
    mov dx, ds:[si+1]
    call writecharat
    add si,3   
    jmp draw_loop 

out_draw:
    mov bl, 'X'
    mov dh, fruity
    mov dl, fruitx
    call writecharat
    mov fruitactive, 1
    
    ret

draw endp

readchar proc
    mov ah, 01H
    int 16H
    jnz keybdpressed
    xor dl, dl
    ret
keybdpressed:
    mov ah, 00H
    int 16H
    mov dl,al
    ret
readchar endp                    

keyboardfunctions proc
    
    call readchar
    cmp dl, 0
    je next_14
    
    cmp dl, 'w'
    jne next_11
    cmp head, 'v'
    je next_14
    mov head, '^'
    ret
next_11:
    cmp dl, 's'
    jne next_12
    cmp head, '^'
    je next_14
    mov head, 'v'
    ret
next_12:
    cmp dl, 'a'
    jne next_13
    cmp head, '>'
    je next_14
    mov head, '<'
    ret
next_13:
    cmp dl, 'd'
    jne next_14
    cmp head, '<'
    je next_14
    mov head,'>'
next_14:    
    cmp dl, 'q'
    je quit_keyboardfunctions
    ret    
quit_keyboardfunctions:   
    inc quit
    ret
    
keyboardfunctions endp
                    
shiftsnake proc     
    mov bx, offset head
    
    xor ax, ax
    mov al, [bx]
    push ax
    inc bx
    mov ax, [bx]
    inc bx    
    inc bx
    xor cx, cx
l:      
    mov si, [bx]
    test si, [bx]
    jz outside
    inc cx     
    inc bx
    mov dx,[bx]
    mov [bx], ax
    mov ax,dx
    inc bx
    inc bx
    jmp l
    
outside:    
    
    pop ax
    
    push dx
    
    lea bx, head
    inc bx
    mov dx, [bx]
    
    cmp al, '<'
    jne next_1
    dec dl
    dec dl
    jmp done_checking_the_head
next_1:
    cmp al, '>'
    jne next_2                
    inc dl 
    inc dl
    jmp done_checking_the_head
    
next_2:
    cmp al, '^'
    jne next_3 
    dec dh               
    
    jmp done_checking_the_head
    
next_3:
    inc dh
    
done_checking_the_head:    
    mov [bx],dx
    call readcharat 
    
    cmp bl, 'X'
    je i_ate_fruit
    
    mov cx, dx
    pop dx 
    cmp bl, SOLID_BLOCK   ; <--- CHANGE 3: Collision check now uses SOLID_BLOCK
    je game_over
    mov bl, 0
    call writecharat
    mov dx, cx
    
    cmp dh, top
    je game_over
    cmp dh, bottom
    je game_over
    cmp dl,left
    je game_over
    cmp dl, right
    je game_over
    
    ret
game_over:
    inc gameover
    ret
i_ate_fruit:    

    mov al, segmentcount
    xor ah, ah
    
    
    lea bx, body
    mov cx, 3
    mul cx
    
    pop dx
    add bx, ax
    mov byte ptr ds:[bx], SOLID_BLOCK  ; <--- CHANGE 4: New segment character is now SOLID_BLOCK
    mov [bx+1], dx
    inc segmentcount 
    mov dh, fruity
    mov dl, fruitx
    mov bl, 0
    call writecharat
    mov fruitactive, 0
    
    ; --- START OF ADDED CODE FOR SPEED INCREASE ---
    
    ; Decrease delaytime by 1 to make the game faster
    mov al, delaytime
    cmp al, 2       ; Check if delaytime is already at the minimum of 2
    jle skip_speed_change 
    
    dec delaytime   ; Decrease the delay
    
skip_speed_change:
    ; --- END OF ADDED CODE FOR SPEED INCREASE ---
    
    ret 
shiftsnake endp
   
printbox proc
    mov dh, top
    mov dl, left
    mov cx, col
    mov bl, '*'
l1:                 
    call writecharat
    inc dl
    loop l1
    
    mov cx, row
l2:
    call writecharat
    inc dh
    loop l2
    
    mov cx, col
l3:
    call writecharat
    dec dl
    loop l3

    mov cx, row     
l4:
    call writecharat    
    dec dh 
    loop l4    
    
    ret
printbox endp
              
writecharat proc
    ;80x25
    push dx
    mov ax, dx
    and ax, 0FF00H
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    
    
    push bx
    mov bh, 160
    mul bh 
    pop bx
    and dx, 0FFH
    shl dx,1
    add ax, dx
    mov di, ax
    mov es:[di], bl
    pop dx
    ret    
writecharat endp
            
readcharat proc
    push dx
    mov ax, dx
    and ax, 0FF00H
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1    
    push bx
    mov bh, 160
    mul bh 
    pop bx
    and dx, 0FFH
    shl dx,1
    add ax, dx
    mov di, ax
    mov bl,es:[di]
    pop dx
    ret
readcharat endp        

writestringat proc
    push dx
    mov ax, dx
    and ax, 0FF00H
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    
    push bx
    mov bh, 160
    mul bh
    
    pop bx
    and dx, 0FFH
    shl dx,1
    add ax, dx
    mov di, ax
loop_writestringat:
    
    mov al, [bx]
    test al, al
    jz exit_writestringat
    mov es:[di], al
    inc di
    inc di
    inc bx
    jmp loop_writestringat
    
    
exit_writestringat:
    pop dx
    ret
writestringat endp
     
main endp
          
end main