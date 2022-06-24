	INCLUDE "P16F877A.INC"
	__CONFIG(0x3FF9)
;*********************************************************************************
; User-defined variables
	CBLOCK	0x20
			WTemp			; Must be reserved in all banks
			StatusTemp		; reserved in bank0 only
			FLOOR0
			FLOOR1
			TEMP
			tens
			units  
			tens0           ; the ten bit of convert result
			units0         	; the ones bit of convert result
			tens1           ; the ten bit of convert result
			units1         	; the ones bit of convert result
			WREG
			SEC_CALC
;			FLASHING
;			TIMER_ON
	ENDC
;******************************************************************************************************
; Macro Assignment
pop	   		MACRO
	BANKSEL	StatusTemp		; point to StatusTemp bank
	SWAPF	StatusTemp,W	; unswap STATUS nibbles into W	
	MOVWF	STATUS			; restore STATUS (which points to where W was stored)
	SWAPF	WTemp,F			; unswap W nibbles
	SWAPF	WTemp,W			; restore W without affecting STATUS
	ENDM

push		MACRO
	MOVWF	WTemp			; WTemp must be reserved in all banks
	SWAPF	STATUS,W		; store in W without affecting status bits
	BANKSEL	StatusTemp		; select StatusTemp bank
	MOVWF	StatusTemp		; save STATUS
	ENDM
;*********************************************************************************
;CODE START HERE
	ORG		0x00			; Reset Vector
	GOTO	MAIN
	ORG		0x04			; Interrupt Vector	
	GOTO	ISR

;*********************************************************************************
; Main function
MAIN
	CALL 	INITIAL
LOOP  
	

D0
	BANKSEL	FLOOR0
	MOVF	FLOOR0,W            
	MOVWF   TEMP 			; keep Result in temporary register
	CALL    CHANGE_To_BCD   ; call result convert subroutine
	MOVF	tens,W 
	MOVWF	tens0
	MOVF	units,W
	MOVWF 	units0
	CALL    DELAY 
	CALL    DISPLAY0        ; call display subroutine
	CALL   	DELAY 
     

D1
	BANKSEL	FLOOR1
	MOVF	FLOOR1,W            
	MOVWF   TEMP 			; keep Result in temporary register
	CALL    CHANGE_To_BCD   ; call result convert subroutine
	MOVF	tens,W
	MOVWF	tens1
	MOVF	units,W
	MOVWF 	units1
	CALL    DELAY 
	CALL    DISPLAY1        ; call display subroutine
	CALL   	DELAY 

	GOTO 	LOOP

;*********************************************************************************
; Interrupt Service Routine
ISR
	push
	BTFSC	PIR1, RCIF		; Check for RX interrupt
	CALL	RX_Receive
	pop
	
	RETFIE

RX_Receive
	BCF		PIR1, RCIF		; Save the value of RCREG to FLOOR0 OR FLOOR1
	BANKSEL	RCREG
	MOVF	RCREG, W
	MOVWF	WREG
	BTFSS	WREG,5 
	GOTO	SAVE_VALUE0
	GOTO	SAVE_VALUE1	
FINISH_RC  
	RETURN
;*********************************************************************************
; saving the received number to floor 0 or floor1
SAVE_VALUE0
	MOVWF 	FLOOR0
	GOTO 	FINISH_RC

SAVE_VALUE1
	MOVWF 	FLOOR1
	MOVLW 	0x0F
	ANDWF 	FLOOR1,F
	GOTO	FINISH_RC
;*********************************************************************************
; convert the number to a 2-digit
CHANGE_To_BCD
	CLRF	tens
	CLRF	units
gen_tens
	BANKSEL	TEMP
	MOVLW   .10             ; sub 10,result keep in W
	SUBWF   TEMP,0          
	BTFSS   STATUS,C        ; judge if the result biger than 10
	GOTO    gen_ones        ; no,get the Entries bit result
  	MOVWF   TEMP            ; yes,result keep in TEMP
  	INCF    tens,1          ; ten bit add 1
  	GOTO    gen_tens        ; turn  to continue get ten bit
gen_ones
  	MOVF    TEMP,W
  	MOVWF   units           ; the value of Entries bit
 	RETURN

;*********************************************************************************
; Display subroutine for floor 0
DISPLAY0
	BANKSEL	PORTB
	BCF	 	PORTB,0
	BCF	 	PORTB,1
	MOVF 	tens0,W 		; display Tens bit
	CALL 	DISPLAY_TABLE
 	MOVWF 	PORTD
 	BSF 	PORTB,2
 	CALL 	DELAY
 	CALL 	DELAY
 	BCF 	PORTB,2
 
	MOVF 	units0,W 		; display Units bit
	CALL 	DISPLAY_TABLE
	MOVWF 	PORTD
	BSF 	PORTB,3
	CALL 	DELAY
	CALL 	DELAY
	BCF 	PORTB,3
 	RETURN
;*********************************************************************************
; Display subroutine for floor 1
DISPLAY1
	BANKSEL	PORTB
	BCF	 	PORTB,2
	BCF	 	PORTB,3
	MOVF 	tens1,W 		; display Tens bit
	CALL 	DISPLAY_TABLE
 	MOVWF 	PORTD
 	BSF 	PORTB,0
 	CALL 	DELAY
 	CALL 	DELAY
 	BCF 	PORTB,0
 
	MOVF 	units1,W 		; display Units bit
	CALL 	DISPLAY_TABLE
	MOVWF 	PORTD
	BSF 	PORTB,1
	CALL 	DELAY
	CALL 	DELAY
	BCF 	PORTB,1
 	RETURN
;*********************************************************************************
; Look-up table for 7-segment
DISPLAY_TABLE
	ADDWF 	PCL , 1
	RETLW 	B'11000000' 	;’0’
	RETLW 	B'11111001' 	;’1’
	RETLW 	B'10100100' 	;’2’
	RETLW 	B'10110000' 	;’3’
	RETLW 	B'10011001' 	;’4’
	RETLW 	B'10010010' 	;’5’
	RETLW 	B'10000010' 	;’6’
	RETLW 	B'11111000' 	;’7’
	RETLW 	B'10000000' 	;’8’
	RETLW 	B'10010000' 	;’9’
;*********************************************************************************
; DELAY to display numbers
DELAY
	MOVLW 	0xFF
	MOVWF 	TEMP
L1 
	DECFSZ 	TEMP,1
 	GOTO 	L1
 	RETURN	
;*********************************************************************************
; Initializing the ports 
INITIAL
	MOVLW	D'2'			; This sets the baud rate to 19200
	BANKSEL	SPBRG			; assuming BRGH=0 and Fosc = 4.000 MHz
	MOVWF	SPBRG	

	BANKSEL	RCSTA		
	BSF		RCSTA, SPEN		; Enable serial port	
	BSF		RCSTA, CREN		; Enable Receiver

	BANKSEL	TXSTA
	BCF		TXSTA, SYNC		; Set up the port for Asynchronous operation
	BCF		TXSTA, BRGH		; LOW baud rate used

	BANKSEL	PIE1
	BSF		PIE1,RCIE		; Enable Receiver Interrupt

	BANKSEL	INTCON		
	BSF		INTCON, GIE		; Enable global and peripheral interrupts	
	BSF		INTCON, PEIE

	BANKSEL TRISD			
	CLRF	TRISD			; PORTD is used to display the received number 
	CLRF 	TRISB			; PORTB is used to choose the digit to display			
	BSF		TRISC, 7		; Configuring RC7 pin as i/p for serial communication
	
	
	BANKSEL	PORTD
	CLRF	PORTD			; clear PORTD and PORTB
	CLRF 	PORTB

	BANKSEL FLOOR0
	CLRF 	FLOOR0			; Initializing FLOOR0 and FLOOR1 with 0 value
	CLRF	FLOOR1

	RETURN
;*********************************************************************************
; Code ends here
	END
