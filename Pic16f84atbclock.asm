
; Aydin T. Bakir
; 8 MHz XTAL
; 
; 8.000.000 / 4 = 2.000.000
; Prescaler = 128
; 2.000.000 / 128 = 15625 ticks a second (reminds me PAL TV 625*25 = 125*125)

	LIST   P=PIC16F84
;	#define __16F84
	#include "p16f84.inc"
	
	__CONFIG _PWRTE_ON & _XT_OSC & _WDT_ON & _CP_OFF

	; registers
 
msec	equ	0x0c		; tens of milliseconds
second	equ	0x0d		; seconds
minute	equ	0x0e		; minutes second digit
hour	equ	0x0f		; hours
timef	equ	0x10		; register for time flags
safe_w	equ	0x11		; save for ACCU
safe_s	equ	0x12		; save for FLAGS
ticksl	equ	0x13		; count of ticks low
ticksh	equ	0x14		; count of ticks high
dirty	equ	0x15		; display values changed
temp1	equ	0x16		; temporary register
temp2	equ	0x17		; temporary register
temp3	equ	0x18		; temporary register
temp4	equ	0x19		; temporary register
		 
	org	0
	goto	_main

        org	0x04		; interrupt
_interrupt                      ; 
	; save flags
	movwf	safe_w		;   
	swapf	STATUS,w	;   swap status, w
	movwf	safe_s		;   save status(nibble swap, remember)
	;

	btfss	INTCON,T0IF	; test timer zero interrupt flag
	goto	_interrupt_exit

	movlw	0xff
	movwf	dirty

	; restore before leaving the interrupt
	; 8Mhz / 4 / 128 = 15625
	; 15625 / '125' = 125
	; 256 - 125 = 131 = 0x83
	movlw	0x83
	movwf	TMR0

; count
	incfsz	ticksl, F
	goto	_interrupt_exit

; overflow

	movlw	0x83
	movwf	ticksl

	clrf	dirty

; seconds

	incf	second, F
	movf	second, W
	sublw	0x3c
	btfss	STATUS, Z
	goto	_interrupt_exit

; increase minute

	clrf	second
	incf	minute, F
	movf	minute, W
	sublw	0x3c
	btfss	STATUS, Z
	goto	_interrupt_exit

; increase hour
	
	clrf	minute
	incf	hour, F
	movf	hour, W
	sublw	0x18
	btfss	STATUS, Z
	goto	_interrupt_exit

; hour is 24:00
	clrf	hour

	goto _interrupt_exit
_interrupt_exit
	
	btfss	dirty, 0
	call	_display_calculate

	swapf	safe_s, W
	movwf	STATUS
	swapf	safe_w, F
	swapf	safe_w, W
	bcf     INTCON, T0IF
	retfie

_initialize
	bsf	STATUS,RP0	; bank 1
	clrf    TRISB^80H	; port B all outputs
        clrf    TRISA^80h	; port A all outputs
	bcf	STATUS,RP0	; bank 0

; interrupt init

	bsf	STATUS,RP0	; bank 1
	movlw   b'10000110'	; timer0 prescale 64:1
	movwf   OPTION_REG^80H	;     
	bcf	STATUS,RP0	; bank 0
	movlw	b'10100000'
	movwf	INTCON

	; 15625/2 times a second
	clrf	hour
	clrf	minute
	clrf	second
	clrf	temp1
	clrf	temp2
	clrf	temp3
	clrf	temp4

;	movlw	0x00
;	movwf	sec
;	movlw	0x83
;	movwf	ticksl

	retlw	0
	
_main
	call	_initialize
loop	
	
	movfw	temp1
	movwf	PORTB

	movfw	temp2
	movwf	PORTB

	movfw	temp3
	movwf	PORTB

	movfw	temp4
	movwf	PORTB

	goto	loop

_display_calculate
	movfw	hour
	call	_modulus_hour

	movfw	minute
	call	_modulus_minutes
	; how will i put these values to portb?
	call	_mark_for_out

	return

_mark_for_out
	bsf	temp1, 4
	bsf	temp2, 5
	bsf	temp3, 6
	bsf	temp4, 7
	return

_modulus_hour
	movfw	hour
	sublw	0x14
	btfss	STATUS, C
	goto	_mod_hour_big20
	movfw	hour
	sublw	0xA
	btfss	STATUS, C
	goto	_mod_hour_big10
	
	btfsc	STATUS, Z
	goto	_mod_hour_A
	movfw	hour
	movwf	temp2
	movlw	0x0
	movwf	temp1
	return
_mod_hour_A
	movlw	0x0
	movwf	temp2
	movlw	0x1
	movwf	temp1

	return
_mod_hour_big20
	sublw	0x0
	movwf	temp2
	movlw	0x2
	movwf	temp1
	return
_mod_hour_big10
	sublw	0x0
	movwf	temp2
	movlw	0x1
	movwf	temp1

	return

_modulus_minutes
	movfw	minute
	sublw	0x32
	btfss	STATUS, C
	goto	_mod_min_big50

	movfw	minute
	sublw	0x28
	btfss	STATUS, C
	goto	_mod_min_big40

	movfw	minute
	sublw	0x1e
	btfss	STATUS, C
	goto	_mod_min_big30

	movfw	minute
	sublw	0x14
	btfss	STATUS, C
	goto	_mod_min_big20

	movfw	minute
	sublw	0xA
	btfss	STATUS, C
	goto	_mod_min_big10

	btfsc	STATUS, Z
	goto	_mod_min_A

	movfw	minute
	movwf	temp4
	movlw	0x0
	movwf	temp3
	return

_mod_min_A
	movlw	0x0
	movwf	temp4
	movlw	0x1
	movwf	temp3
	return

_mod_min_big50
	sublw	0x0
	movwf	temp4
	movlw	0x5
	movwf	temp3
	return

_mod_min_big40
	sublw	0x0
	movwf	temp4
	movlw	0x4
	movwf	temp3
	return

_mod_min_big30
	sublw	0x0
	movwf	temp4
	movlw	0x3
	movwf	temp3
	return

_mod_min_big20
	sublw	0x0
	movwf	temp4
	movlw	0x2
	movwf	temp3
	return

_mod_min_big10
	sublw	0x0
	movwf	temp4
	movlw	0x1
	movwf	temp3
	return


	END


