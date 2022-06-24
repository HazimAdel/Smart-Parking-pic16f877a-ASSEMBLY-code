	INCLUDE "P16F877A.INC"
	__CONFIG(0x3FF9)
;*********************************************************************************
; User-defined variables
	CBLOCK 0X20
			FLOOR0
			FLOOR1
			WTemp				; Must be reserved in all banks
			StatusTemp			; reserved in bank0 only	    
			TEMP1
			TEMP0
			TEMP
	ENDC
	CBLOCK	0X30
			Delay_reg 
			STATUSTEMP
			SEC_CALC			; used in calculating the elapse of one second
			START_STOP			; user defined flag which if filled with 1’s the stop watch 
			ITERATIONS			; counts, else halts
	ENDC
;*********************************************************************************
; Macro assignment
pop	   		MACRO
	BANKSEL	StatusTemp			; point to StatusTemp bank
	SWAPF	StatusTemp,W		; unswap STATUS nibbles into W	
	MOVWF	STATUS				; restore STATUS (which points to where W was stored)
	SWAPF	WTemp,F				; unswap W nibbles
	SWAPF	WTemp,W				; restore W without affecting STATUS
	ENDM

push		MACRO
	MOVWF	WTemp				; WTemp must be reserved in all banks
	SWAPF	STATUS,W			; store in W without affecting status bits
	BANKSEL	StatusTemp			; select StatusTemp bank
	MOVWF	StatusTemp			; save STATUS
	ENDM
;*********************************************************************************
; CODE START HERE
	ORG 0X000
	GOTO 	MAIN
	ORG 0X004
	GOTO	ISR
;*********************************************************************************
; Main function 
MAIN 
	CALL 	INITIAL

	CALL 	SEND0
	CALL	SEND1

LOOP
  	Banksel   ADCON0       	
  	MOVLW     41H
  	MOVWF     ADCON0           ;select CLOCK is fosc/8,A/D enabled
  	CALL      DELAY            ;call delay program,ensure enough time to sampling
  	BSF       ADCON0,GO        ;startup ADC divert
LDR
  	BTFSS     PIR1,ADIF        ;is the convert have finished?
  	GOTO      LDR            ;wait for the convert finished
  	bcf		  PIR1, ADIF       ; Clear the A/D flag

	BANKSEL	ADRESH
	BTFSC	ADRESH,1
	GOTO	ON_LIGHT1
	BTFSC	ADRESH,0
	GOTO	ON_LIGHT1
	BANKSEL	PORTD
	CLRF	PORTD
								; The initial numbers are sent, loop and wait				
	GOTO	LOOP				; for receiver interrupts or the other interrupts.
	
ON_LIGHT1
	BANKSEL	PORTD
	MOVLW 	0xFF
	MOVWF	PORTD
	GOTO	LOOP
;*********************************************************************************
; Sending the numbers  
SEND0	
	BANKSEL TXREG
	MOVF	FLOOR0, W
	MOVWF	TXREG
L0	
	BANKSEL	TXSTA				; Polling for the TRMT flag to check
	BTFSS	TXSTA, TRMT			; if TSR is empty or not
	GOTO	L0
	RETURN
	
SEND1	
	BANKSEL TXREG
	MOVF	FLOOR1, W
	MOVWF	TXREG
L1	
	BANKSEL	TXSTA				; Polling for the TRMT flag to check
	BTFSS	TXSTA, TRMT			; if TSR is empty or not
	GOTO	L1	
	RETURN

;*********************************************************************************
; interrupt Routine
ISR
	push
	BANKSEL INTCON
	BTFSC 	INTCON,RBIF 		; Test if the Sensors make an interrupt
	CALL 	SERVICE				; Service the Sensors
	BANKSEL INTCON
	BCF 	INTCON, RBIF		; Clear PORTB-Change Flag
	pop 
	BTFSC	INTCON, TMR0IF		; Test if Timer0 interrupt
	CALL	TMR0_CODE	
	RETFIE
;*********************************************************************************
; PORTB Change service
SERVICE
	BANKSEL PORTB				; Testing which sensors make the interrupt
	BTFSS 	PORTB,4				; ENTER FLOOR 0	sensor
	CALL  	INC0
	BTFSS 	PORTB,5 			; EXIT 	FLOOR 0 sensor
	CALL  	DEC0
	BTFSS 	PORTB,6 			; ENTER FLOOR 1 sensor
	CALL  	INC1	
	BTFSS 	PORTB,7 			; EXIT 	FLOOR 1 sensor
	CALL  	DEC1
	RETURN
INC0
	MOVLW 	.15					; Make sure FLOOR0 is not full yet
	SUBWF 	FLOOR0,W
	BTFSC 	STATUS,Z
	RETURN
	CALL 	START_LIGHT			; Turn on the Basement Lights if an car Enter the parking
	INCF 	FLOOR0,F			; Increase the cars counter by 1
	CALL	SEND0
	RETURN

DEC0
	DECF 	FLOOR0,F			; Decrease the cars counter by 1
	CALL 	SEND0
	RETURN

INC1
	MOVLW 	0x0F				; Mask the first 4 bits 
	ANDWF 	FLOOR1,W
	MOVWF 	TEMP1
	MOVLW 	.15 				; Make sure FLOOR1 is not full yet
	SUBWF 	TEMP1,W 			; TESTING THE FIRST 4 BITS JUST
	BTFSC 	STATUS,Z
	RETURN
	INCF 	FLOOR1,F			; Increase the cars counter by 1
	CALL	SEND1
	RETURN

DEC1
	DECF 	FLOOR1,F			; Decrease the cars counter by 1
	CALL	SEND1
	RETURN
;*********************************************************************************
; Start the lights in the Basement floor
START_LIGHT
	BANKSEL	INTCON
	BSF		INTCON,TMR0IE		; Enable TMR0 interrupt
	BCF		INTCON,TMR0IF		; Clear TMR0 flag
	CLRF	SEC_CALC			; Reinitialize the registers to start again from 0 Sec
	BANKSEL ITERATIONS
	MOVLW	.30
	MOVWF	ITERATIONS
	MOVLW	0x0F				; Turn on the Basement Light
	MOVWF	PORTE
	RETURN
;*********************************************************************************
; Timer0 code 
TMR0_CODE
	BANKSEL INTCON
	BCF		INTCON, TMR0IF		; Clear TMR0 Flag
	MOVLW	0X06				; Reinitialize TMR0
	MOVWF	TMR0
	INCF	SEC_CALC, F
	MOVLW	.250				; Assuming a clock of 4MHz, we need 
	SUBWF	SEC_CALC, W			; 250 * 32 * 250 = 2 Sec
	BTFSS	STATUS, Z
	GOTO	ENDTMR0				; Not 2 Sec yet
	DECFSZ	ITERATIONS, F		
	GOTO	ENDTMR0				; Not 60 Sec yet
	CALL	OFF_LIGHT0			; if 60 seconds passed, turn off the lights
ENDTMR0
	RETURN

OFF_LIGHT0
	BANKSEL	PORTE
	CLRF	PORTE				; Turn off the lights
	BANKSEL INTCON
	BCF		INTCON, TMR0IF		; Clear TMR0 Flag
	BCF		INTCON, TMR0IE		; Disable interrupt
	RETURN

;*********************************************************************************
; Initializing the ports 
INITIAL 
	MOVLW	D'2'				; This sets the baud rate to 19200
	BANKSEL	SPBRG				; assuming BRGH=0 and Fosc = 4.000 MHz
	MOVWF	SPBRG
	
	BANKSEL	RCSTA		
	BSF		RCSTA, SPEN			; Enable serial port
	
	BANKSEL	TXSTA
	BCF		TXSTA, SYNC			; Set up the port for Asynchronous operation
	BSF		TXSTA, TXEN			; Enable Transmitter
	BCF		TXSTA, BRGH			; LOW baud rate used

	BANKSEL	INTCON		
	BSF		INTCON, GIE			; Enable global peripheral PORTB-Change interrupts
	BSF		INTCON, PEIE	
	BSF		INTCON, RBIE
	BCF		INTCON, RBIF		; Clear PORTB-Change interrupt Flag
	
	BANKSEL	PIR1
	BCF		PIR1, ADIF			; Clear A/D converter flag

	BANKSEL	OPTION_REG
	MOVLW	0XD4				; PSA assigned to TMR0, Prescalar = 32, TMR0 clock source is the internal
	MOVWF	OPTION_REG			; instruction cycle clock, External interrupt is on the rising edge

	BANKSEL ADCON1
	MOVLW   0x8E                ; set RA0 as an Analog input pin
 	MOVWF   ADCON1              ; set the other pins in PORTA as general Digital I/O PORT
	
	BANKSEL ADCON0
	MOVLW 	0x41
	MOVWF	ADCON0    

	BANKSEL TRISD				; PORTD is used to control the Ground floor
	CLRF	TRISD
	CLRF	TRISE				; PORTE is used to control the Basement floor
	MOVLW 	0xFF
	MOVWF 	TRISB				; Configuring PORTB as an INPUT port for the IR sensors
	BCF		TRISC, 6			; Configuring pin RC6 as OUTPUT pin 
	BSF		TRISA, 0			; Configuring pin RA0 as INPUT  pin 
	
	BANKSEL	PORTD
	CLRF	PORTD
	CLRF	PORTE 
	
	BANKSEL	TMR0				; TMR0 to update 256 – 6 = 250
	MOVLW	0X06
	MOVWF	TMR0
	CLRF	SEC_CALC			; 0 ms has passed
	MOVLW 	.30
	MOVWF 	ITERATIONS			; Initialize it with 30 to make timer0 count 60s
	
	BANKSEL FLOOR0				; Initialize FLOOR0 and FLOOR1 with 0
	CLRF 	FLOOR0
	CLRF 	FLOOR1				; Make the 5th bit in FLOOR1 to distinguish
	BSF 	FLOOR1,5			; between FLOOR0 and FLOOR1
							
	RETURN 
;*********************************************************************************
; Delay subroutine
DELAY
  	MOVLW    0xFF
  	MOVWF    TEMP
LO1	DECFSZ   TEMP,1
  	GOTO     LO1
  	RETURN
;*********************************************************************************
; Code ends here 
	END
