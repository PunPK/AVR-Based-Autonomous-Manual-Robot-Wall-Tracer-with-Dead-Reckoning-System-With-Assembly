.INCLUDE "m328pdef.inc"   

; กำหนดชื่อสัญลักษณ์ตัวแปร
.DEF temp   = R16               ; Res ชั่วคราว ไว้เก็บค่าชั่วคราว
.DEF dist_L = R17               ; เก็บค่าระยะทาง Ultrasonic ไบต์ต่ำ
.DEF dist_H = R18               ; เก็บค่าระยะทาง Ultrasonic ไบต์สูง
.DEF param  = R19               ; เอาไว้ Input ค่าสำหรับ Subroutine ในค่า R19

; กำหนดรหัสคำสั่งมอเตอร์ PortD ขา 4 ถึง 7
.EQU CMD_FORWARD  = 0b01010000  ; กำหนดคำสั่งเดินหน้า (IN1=1, IN2=0, IN3=1, IN4=0)
.EQU CMD_TURN_R   = 0b01100000  ; กำหนดคำสั่งเลี้ยวขวา (IN1=1, IN2=0, IN3=0, IN4=1)
.EQU CMD_TURN_L   = 0b10010000  ; กำหนดคำสั่งเลี้ยวซ้าย (IN1=0, IN2=1, IN3=1, IN4=0)
.EQU CMD_BACK     = 0b10100000  ; กำหนดคำสั่งถอยหลัง (IN1=0, IN2=1, IN3=0, IN4=1)
.EQU MOTOR_MASK   = 0b11110000  ; กำหนด bit สำหรับเคลียร์ค่าเก่าทิ้ง

; กำหนด Interrupt
.ORG 0x0000						; เริ่มต้นโปรแกรมที่ตำแหน่ง 0x0000
    rjmp RESET                  ; กระโดดไปที่ Reset
.ORG 0x0002						; รูทีนบริการการขัดจังหวะของ INT0 เป็นตัวของ Sensor แสง LDR
    rjmp EXT_INT0_ISR           ; กระโดดไปยังรูทีน INT0
.ORG 0x0006
    rjmp PCINT0_ISR             ; รูทีนบริการการขัดจังหวะ PCINT0 Sensor IR
.ORG 0x0008
    rjmp PCINT1_ISR             ; รูทีนบริการการขัดจังหวะ PCINT1 Push Swicth ควบคุมมือ

RESET:
    ldi temp, high(RAMEND)		; โหลด High Byte ของ RAMEND (ขอบเขตตาราง) ไป 
temp
    out SPH, temp				; เก็บใน SPH
    ldi temp, low(RAMEND)		; โหลด Low Byte ของ RAMEND (ขอบเขตตาราง) ไป temp
    out SPL, temp				; เก็บใน SLH

    ; PORTD: PD3-PD7 Output Motor (L298n) และ Servo Motor, PD2 เป็น INT0
    ldi temp, 0b11111000		; bit 1 Output, bit 2 Input
    out DDRD, temp			; กำหนด Input Output bit นั้น
    ldi temp, 0x00
    out PORTD, temp

    ; PORTB: PB0 Output Trig, PB1-PB5 Input (Echo, Silde switch Mode, Sersor IR)
    ldi temp, 0b00000001		
    out DDRB, temp
    ldi temp, 0b00111100        ; เปิด Pull-up resistor ให้ PB2-PB5 ให้ Logic เป็น HIGH ตลอด
    out PORTB, temp

    ; PORTC: PC4,PC5=Output(LED), PC0-PC3=Input (ปุ่มกด)
    ldi temp, 0b00110000
    out DDRC, temp
    ldi temp, 0b00001111        ; เปิด Pull-up resistor ให้ปุ่มกด ให้ Logic เป็น HIGH เมื่อไม่มีการกดปุ่ม
    out PORTC, temp
    
    sbi PORTC, 4                ; ทำการ Set Bit  เพื่อสั่ง logic 1 ที่ PC4 มี logic เป็น 1 เปิด ไฟ LED สีเขียว (พร้อมใช้งาน)
    cbi PORTC, 5                ; ทำการ Clear Bit  เพื่อสั่ง logic 0 ที่ PC5 มี logic เป็น 0 (ปิด Buzzer)


    ; External Interrupt 
    ldi temp, 0b00000011        ; เปิด bit ISC01 และ ISC00 เป็น 1 และ 1 ทำให้เมื่อเกิดขอบขาขึ้นของสัญญาณ INT0 ตัวประมวลผลจะถือว่าเกิดการขัดจังหวะ
    ldi XL, low(EICRA)          ; เอาที่อยู่ byte low ของ EICRA ไปฝากไว้ที่ XL
    ldi XH, high(EICRA)         ; เอาที่อยู่ byte high ของ EICRA ไปฝากไว้ที่ XH
    st X, temp                  ; เอาค่าใน temp ไปใส่ในตำแหน่งที่ X ชี้อยู่ เป็น EICRA

    ldi temp, 0b00000001        ; กำหนดให้อนุญาต INT0 สามารถส่งสัญญาณขัดจังหวะได้ 
    out EIMSK, temp				

    ldi temp, 0b00000011        ; เปิด PCINT0 และ PCINT1
    ldi XL, low(PCICR)			; เอาที่อยู่ byte low ของ PCICR ไปฝากไว้ที่ XL
    ldi XH, high(PCICR)			; เอาที่อยู่ byte high ของ PCICR ไปฝากไว้ที่ XH
    st X, temp                  ; เอาค่าใน temp ไปใส่ในตำแหน่งที่ X ชี้อยู่ เป็น PCICR

    ldi temp, 0b00111100        ; เลือกขา PB2, PB3, PB4, PB5
    ldi XL, low(PCMSK0)			; เอาที่อยู่ byte low ของ PCMSK0 ไปฝากไว้ที่ XL
    ldi XH, high(PCMSK0)		; เอาที่อยู่ byte high ของ PCMSK0 ไปฝากไว้ที่ XH
    st X, temp                  ; เอาค่าใน temp ไปใส่ในตำแหน่งที่ X ชี้อยู่ เป็น PCMSK0
    
    ldi temp, 0b00001111        ; เลือกขา PC0, PC1, PC2, PC3
    ldi XL, low(PCMSK1)			; เอาที่อยู่ byte low ของ PCMSK1 ไปฝากไว้ที่ XL
    ldi XH, high(PCMSK1)		; เอาที่อยู่ byte high ของ PCMSK1 ไปฝากไว้ที่ XH
    st X, temp                  ; เอาค่าใน temp ไปใส่ในตำแหน่งที่ X ชี้อยู่ เป็น PCMSK1

    sei                         ; เปิด Interrupt




MAIN:
	; ตรวจสอบ slide switch Mode ในขา PB2
    sbis PINB, 2                ; Skip if Bit Set เป็น 1 คือถ้าที่ค่าที่ PB2 เป็น 1 อยู่ ไป AUTO MODE ถ้าเป็น 0 ไป MANUAL MODE
    rjmp MANUAL_MODE        
    rjmp AUTO_MODE            

MANUAL_MODE:
    ; ใน MANUAL MODE ผมให้โปรแกรมวนลูปเปล่า รอการขัดจังหวะจาก Push Switch PCINT1
    rjmp MAIN               

AUTO_MODE:
    rcall DELAY_10MS            ; หน่วงเวลา 10 มิลลิวินาที ให้การส่งคลื่นเสถียร

    ; เรียกซับรูทีนอ่านค่าระยะทางจาก ultrasonic sensor
    rcall READ_SONAR        
    
    ; เปรียบเทียบระยะทางกับค่า 20 ซม. (0x0910)
    ldi temp, 0x10              ; โหลด Byte low ค่า 20 ซม.
    cp dist_L, temp             ; เปรียบเทียบ Byte low
    ldi temp, 0x09              ; โหลด Byte High ค่า 20 ซม.
    cpc dist_H, temp            ; เปรียบเทียบ Byte High 
    brcs FOUND_OBSTACLE         ; ถ้าระยะทางน้อยกว่า 20 ซม. ทำการเช็คตามขั้นตอน

    ; กรณีไม่มีสิ่งกีดขวาง 
    ldi param, CMD_FORWARD      ; สั่งเดินหน้าเรื่อยๆ
    rcall SET_MOTOR
    rjmp MAIN                   ; วนซ้ำการทำงาน

FOUND_OBSTACLE:
    rcall MOTOR_STOP            ; หยุดรถ
    rcall SERVO_LEFT            ; สั่งหัน Servo ไปตรวจสอบด้านซ้าย
    rcall DELAY_250MS           ; หน่วงเวลารอให้ Servo หันจนสุด
    rcall READ_SONAR            ; อ่านค่าระยะทางจาก ultrasonic sensor ด้านซ้าย

    ; ตรวจสอบว่าด้านซ้ายมีสิ่งกีดขวางในระยะ 20 ซม. หรือไม่
    ldi temp, 0x10
    cp dist_L, temp
    ldi temp, 0x09
    cpc dist_H, temp
    brcs CHECK_RIGHT            ; หากซ้ายติดสิ่งกีดขวาง ให้กระโดดไปเช็คขวา

    ; กรณีด้านซ้ายโล่ง
    rcall SERVO_CENTER          ; หันหัวกลับมาตรง
    rcall DELAY_250MS           
    rcall TURN_LEFT_90_DEG      ; สั่งรถเลี้ยวซ้าย
    rjmp MAIN

CHECK_RIGHT:
    rcall SERVO_RIGHT           ; สั่งหัน Servo ไปตรวจสอบด้านขวา
    rcall DELAY_250MS           
    rcall READ_SONAR            ; อ่านค่าระยะทางด้านขวา

    ; ตรวจสอบว่าด้านขวามีสิ่งกีดขวางในระยะ 20 ซม. หรือไม่
    ldi temp, 0x10
    cp dist_L, temp
    ldi temp, 0x09
    cpc dist_H, temp
    brcs TURN_AROUND            ; หากขวาก็ติดสิ่งกีดขวาง ให้กระโดดไปกลับหลังหัน


    ; กรณีด้านขวาโล่ง
    rcall SERVO_CENTER          
    rcall DELAY_250MS
    rcall TURN_RIGHT_90_DEG     ; สั่งรถเลี้ยวขวา
    rjmp MAIN

TURN_AROUND:
    ; กรณีทางตันทั้ง 3 ด้าน
    rcall SERVO_CENTER          ; สั่งให้ Servo หันกลับมาตรงกลาง
    rcall DELAY_250MS
    rcall TURN_U_TURN           ; สั่งรถกลับหลังหัน 180 องศา
    rjmp MAIN

; รูทีนขัดจังหวะจาก Sensor แสง LDR ที่ต่อเปรียบเทียบแรงดันกับ Op-Amp
EXT_INT0_ISR:
    push temp                   ; เอา temp R16 ไปเก็บไว้ใน Stack  
    in temp, SREG               ; อ่านค่า Status Register ที่เป็น Flags ต่างๆ มาไว้ใน temp
    push temp                   ; เอา temp Flags ไปเก็บไว้ใน Stack

    rcall MOTOR_STOP            ; กระโดดไปทำซับรูทีนหยุดมอเตอร์ เพื่อตามที่กำหนด
    cbi PORTC, 4                ; ทำการ Clear Bit เพื่อสั่ง logic 0 ที่ PC4 มี logic เป็น 0 ซึ่งควบคุมให้ปิดไฟ LED สีเขียว ทำให้ LED สีแดงทำงาน (ไม่พร้อมทำงาน)

LOOP_ALARM:		  ; loop ตรวจจนกว่าไม่มีแสงสว่างตามที่กำหนด
    sbis PIND, 2                ; Skip if Bit เป็น 1 คือถ้าที่ค่าที่ PD2 เป็น 1 อยู่ แสดงว่าแสงยังสว่างมากอยู่ ไม่ให้ออกจาก loop นี้
			    ; แต่ถ้า PD2 เป็น 0 ก็ไม่ต้อง skip และออกจาก Loop นี้

    rjmp EXIT_EXT_INT0          ; กระโดดออกจากการทำงานของ Interrupt เมื่อแสงลดลงแล้ว

    ; ผมทำให้มันส่งเสียง Buzzer แบบกระพริบ
    sbi PORTC, 5                ; ทำการ Set Bit  เพื่อสั่ง logic 1 ที่ PC5 มี logic เป็น 1 (เปิด Buzzer)
    rcall DELAY_1MS             ; delay 1ms
    cbi PORTC, 5                ; ทำการ Clear Bit  เพื่อสั่ง logic 0 ที่ PC5 มี logic เป็น 0 (ปิด Buzzer)
    rcall DELAY_1MS             ; delay 1ms
    rjmp LOOP_ALARM             ; วนซ้ำไปเรื่อยๆใน LOOP_ALARM

EXIT_EXT_INT0:
    cbi PORTC, 5               ; ทำการ Clear Bit  เพื่อสั่ง logic 0 ที่ PC5 มี logic เป็น 0 (ปิด Buzzer)
    sbi PORTC, 4               ; ทำการ Set Bit  เพื่อสั่ง logic 1 ที่ PC4 มี logic เป็น 1 เปิด ไฟ LED สีเขียว (พร้อมใช้งานต่อ)
    
    pop temp                    ; เอาค่าที่ใส่ใน Stack ออกไป แบบ LIFO ออกมาใส่ temp
    out SREG, temp              ; คืนค่าจาก temp คืนกลับเข้าไปใน Status Register
    pop temp                    ; เอาค่าที่ใส่ใน Stack ออกไป แบบ LIFO ที่เก็บค่า temp เก่าเอาไว้ออกมาใส่ temp
    
    reti                        ; Return from Interrupt จบ INT0 

; Sensor IR กันตกหลุม และกันชนด้านหลัง
PCINT0_ISR:
    push temp		; ทำเหมือนที่ทำในรูทีนขัดจังหวะจาก Sensor แสง LDR
    in temp, SREG
    push temp
    push r24

    ; ตรวจสอบ IR ด้านหน้า (PB3) ถ้าเป็น logic 0 แสดงว่าชน
    sbis PINB, 3				; Skip if Bit Set เป็น 1 คือถ้าที่ค่าที่ PB3 เป็น 1 อยู่ แสดงว่า IR Sensor เช็คด้านหลัง ไม่เจอสิ่งกีดขว้าง
			; แต่ถ้า PB3 เป็น 0 แสดงว่า IR Sensor เช็คด้านหลัง เจอสิ่งกีดขว้าง
    rjmp BACK_HIT
    
    sbic PINB, 4                ; Skip if Bit Clear เป็น 0 คือถ้าที่ค่าที่ PB4 เป็น 0 อยู่ แสดงว่า IR Sensor เช็คด้านใต้ด้านหลัง ยังเจอพื้น ไม่ได้เจอหลุม
		; แต่ถ้า PB4 เป็น 1 แสดงว่า IR Sensor เช็คด้านใต้ด้านหลัง ไม่เจอพื้น เจอหลุม
    rjmp BACK_HIT               

    sbic PINB, 5                ; Skip if Bit Clear เป็น 0 คือถ้าที่ค่าที่ PB5 เป็น 0 อยู่ แสดงว่า IR Sensor เช็คด้านใต้ด้านหน้า ยังเจอพื้น ไม่ได้เจอหลุม
		; แต่ถ้า PB4 เป็น 1 แสดงว่า IR Sensor เช็คด้านใต้ด้านหน้า ไม่เจอพื้น เจอหลุม
    rjmp FRONT_HIT               
    
    rjmp EXIT_PCINT0            ; กันไม่มีอะไรเลย แล้วอยู่ดีๆเกิด Interrupt แบบเกิด Noise ขึ้น

FRONT_HIT:
    ldi param, CMD_BACK         ; ถ้าด้านหน้าเจอหลุดก็ให้ถอยหลังทันที
    rjmp RE_POSITION			

BACK_HIT:
    ldi param, CMD_FORWARD      ; ถ้าด้านหลังเจอหลุด หรือสิ่งกีดขวาง ก็ให้เดินหน้าทันที
    rjmp RE_POSITION          

RE_POSITION:
    rcall MOTOR_STOP            
    cbi PORTC, 4                ; ทำการ Clear Bit  เพื่อสั่ง logic 0 ที่ PC4 มี logic เป็น 0 (ปิด LED สีเขียว)
    sbi PORTC, 5	; ทำการ Set Bit  เพื่อสั่ง logic 1 ที่ PC5 มี logic เป็น 1 (เปิด Buzzer)
    
    rcall SET_MOTOR       ; สั่งมอเตอร์ (ทิศทางตาม FRONT_HIT หรือ BACK_HIT ที่ได้กำหนดไว้ใน Param)
    rcall DELAY_500MS           ; ตั้งให้สั่งการ Motor เคลื่อนที่แค่ 500Ms
    rcall MOTOR_STOP            ; หยุดการเคลื่อนที่ Motor

WAIT:	; หลักการทำงานคล้ายๆด้านบน แค่ไว้เช็คว่ายังมีอะไรที่ยังเป็น Interrupt เกิดขึ้นอยู่ไหม
    sbis PINB, 3               
    rjmp PCINT0_ISR         
    sbic PINB, 4                
    rjmp PCINT0_ISR    
    sbic PINB, 5               
    rjmp PCINT0_ISR

    ; ถ้ามันสามารถหลุดมาถึงตรงนี้ได้ ไม่มีอะไรแล้วสามารถเดินหน้าต่อและทำงานปกติแล้ว
    sbi PORTC, 4            ; ทำการ Set Bit  เพื่อสั่ง logic 1 ที่ PC4 มี logic เป็น 1 (เปิด LED สีเขียว)
    cbi PORTC, 5            ; ทำการ Clear Bit  เพื่อสั่ง logic 0 ที่ PC5 มี logic เป็น 0 (ปิด Buzzer)
    rcall TURN_U_TURN           ; สั่งรถกลับหลังหัน
    
EXIT_PCINT0:					; ออกจาก รูทีนนี้ไป
    pop r24					; pop ออกทุก Res
    pop temp
    out SREG, temp
    pop temp
    reti

; รูทีนขัดจังหวะจาก Mode ควบคุมมือ
PCINT1_ISR:
    push temp					; ทำเหมือนที่ผ่านมา ใส่ค่าต่างๆลงไปใน stack
    in temp, SREG
    push temp
    push param

    ; ตรวจสอบสวิตช์โหมด ถ้าเป็น AUTO MODE จะไม่รับคำสั่งปุ่มกด
    sbic PINB, 2				; Skip if Bit Clear เป็น 0 คือถ้าที่ค่าที่ PB2 เป็น 0 อยู่ แสดงว่า Mode เป็น ควบคุมมือ
					; แต่ถ้า PB2 เป็น 1 แสดงว่า Mode เป็น AUTO
    rjmp EXIT_PCINT1			; ไปยังที่สิ้นสุด รูทีนนี้

    ; ตรวจสอบสถานะ Push Switch แต่ละปุ่มแบบ Active Low โดยได้เปิด Pull UP ในแต่ละขาพวกนี้แล้ว งั้นที่กำหนดมาข้างต้น    
    sbis PINC, 0				; เช็คปุ่ม เดินหน้า ที่ PC0
    rjmp BTN_FWD
    sbis PINC, 1				; เช็คปุ่ม เลี้ยวซ้าย ที่ PC1
    rjmp BTN_LEFT
    sbis PINC, 2				; เช็คปุ่ม เลี้ยวขวา ที่ PC2
    rjmp BTN_RIGHT
    sbis PINC, 3				; เช็คปุ่ม ถอยหลัง ที่ PC3
    rjmp BTN_REV

    ; กรณีไม่มีการกดปุ่มใดๆ ให้หยุดรถ
    rcall MOTOR_STOP
    rjmp EXIT_PCINT1

BTN_FWD:
    ldi param, CMD_FORWARD		; ส่งค่าเดินหน้าตามที่ได้กำหนดไว้ ใส่ไปใน param
    rcall SET_MOTOR				; สั่งให้มอเตอร์ทำตามค่านั้นๆ
    rjmp EXIT_PCINT1
BTN_REV:
    ldi param, CMD_BACK			; ส่งค่าถอยหลังตามที่ได้กำหนดไว้ ใส่ไปใน param
    rcall SET_MOTOR				; สั่งให้มอเตอร์ทำตามค่านั้นๆ
    rjmp EXIT_PCINT1
BTN_LEFT:
    ldi param, CMD_TURN_L		; ส่งค่าเลี้ยวซ้ายตามที่ได้กำหนดไว้ ใส่ไปใน param
    rcall SET_MOTOR				; สั่งให้มอเตอร์ทำตามค่านั้นๆ
    rjmp EXIT_PCINT1
BTN_RIGHT:
    ldi param, CMD_TURN_R		; ส่งค่าเลี้ยวขวาตามที่ได้กำหนดไว้ ใส่ไปใน param
    rcall SET_MOTOR				; สั่งให้มอเตอร์ทำตามค่านั้นๆ
    rjmp EXIT_PCINT1

EXIT_PCINT1:
    pop param					; เมื่อใส่ res เข้าไปแล้วก็ต้อง pop res นั้นๆออกให้หมด
    pop temp
    out SREG, temp
    pop temp
    reti



; Subroutines  Motor
SET_MOTOR:
    push r24					; มีการเรียกใช้งาน Register ต้อง push ทุกครั้ง  
    in   r24, PORTD             ; เก็บค่าที่ PD เอาไว้ 
    cbr r24, MOTOR_MASK			; สั่งเคลียร์ bit มอเตอร์ให้เป็น 0 ทั้งหมด
    or   r24, param             ; ใช้ส่วนนี้ใช้ Res param ควบคุมทิศทางการเคลื่อนที่ โดยนำคำสั่งทิศทางใหม่มาใส่
    out  PORTD, r24             ; ส่งค่าออก  PORTD ขับ L298N
    pop  r24					; ใช้งาน Register เสร็จ ก็ต้องลบ โดย pop ทุกครั้ง  
    ret							; Return

; Subroutines หยุดมอเตอร์ ทำเหมือนข้างบน แค่ไม่เอาค่าใหม่มาใส่
MOTOR_STOP:
    push r24
    in   r24, PORTD
    cbr r24, MOTOR_MASK			; สั่งเคลียร์ bit มอเตอร์ให้เป็น 0 ทั้งหมด
    out  PORTD, r24
    pop  r24
    ret

; Subroutines เลี้ยวซ้าย 90 องศา
TURN_LEFT_90_DEG:
    push r24
    ldi param, CMD_TURN_L		; ใส่ค่าเลี้ยวซ้ายตามที่ได้กำหนดไว้ 
    rcall SET_MOTOR				; สั่งให้มอเตอร์ทำงาน
    ldi r24, 200                ; หน่วงเวลาเลี้ยว
LOOP_TL:						; loop รอมอเตอร์เลี้ยวซ้าย
    rcall DELAY_1MS
    dec r24						; ลดค่าลงทีละ 1
    brne LOOP_TL				; Branch if Not Equal to zero
    rcall MOTOR_STOP			; รอตามที่กำหนดแล้ว หยุดมอเตอร์
    pop r24
    ret

; Subroutines เลี้ยวขวา 90 องศา
TURN_RIGHT_90_DEG:
    push r24
    ldi param, CMD_TURN_R		; ใส่ค่าเลี้ยวขวาตามที่ได้กำหนดไว้ 
    rcall SET_MOTOR				; ด้านล่างทำตามเหมือนเลี้ยวซ้าย
    ldi r24, 200            
LOOP_TR:
    rcall DELAY_1MS
    dec r24
    brne LOOP_TR
    rcall MOTOR_STOP
    pop r24
    ret

; Subroutines กลับหลังหัน 180 องศา
TURN_U_TURN:
    push r24
    ldi param, CMD_TURN_R       ; ใส่ค่าเลี้ยวขวายาวเพื่อกลับรถตามที่ได้กำหนดไว้
    rcall SET_MOTOR		 ; ด้านล่างทำตามเหมือนเลี้ยวซ้าย แต่เพิ่มเวลาตอนเลี้ยวขึ้น 2 เท่า
    ldi r24, 250            
LOOP_UT1: 
    rcall DELAY_1MS
    dec r24
    brne LOOP_UT1
    ldi r24, 250            
LOOP_UT2: 
    rcall DELAY_1MS
    dec r24
    brne LOOP_UT2
    rcall MOTOR_STOP
    pop r24
    ret

; Subroutines อ่านค่า Ultrasonic
READ_SONAR:
    push r24                    ; เก็บค่าลง Stack
    push r25
    push r26

    sbi PORTB, 0                ; ส่งสัญญาณ Trig (HIGH)
    rcall DELAY_10US            ; ส่งคลื่นสัญญาณออกไประยะหนึ่ง
    cbi PORTB, 0                ; ปิดสัญญาณ Trig (LOW)
    
; รอให้คลื่อนเสียงที่ขา Echo ขึ้นเป็น HIGH 
    ldi r25, 255                ; รอคลื่นสัญญาณสะท้อนกลับมา
WAIT_ECHO_HIGH_OUT:
    ldi r24, 255                ; รอคลื่นสัญญาณสะท้อนกลับมา
WAIT_ECHO_HIGH_IN:
    sbic PINB, 1                ; Skip if Bit Clear ถ้าขา PB1 (Echo) เป็น 0
    rjmp START_TIMER            ; ถ้าเป็น 1 กระโดดไปจับค่าเวลามาประมวลผล
    
    ; ส่วนนับถอยหลัง Timeout
    dec r24                     ; ลดค่าตัวนับ loop ใน
    brne WAIT_ECHO_HIGH_IN		; วน loop ในจนกว่าจะครบ
    dec r25                     ; ลดค่าตัวนับ loop นอก
    brne WAIT_ECHO_HIGH_OUT		; วน loop นอกจนกว่าจะครบ
    rjmp SONAR_TIMEOUT          ; ถ้ารอจน loop หมดแล้ว Echo ยังไม่มา Timeout

START_TIMER:
    ldi temp, 0
    
    ldi ZL, low(TCNT1H)         ; โหลด byte low TCNT1H ใส่ ZL
    ldi ZH, high(TCNT1H)        ; โหลด byte high TCNT1H ใส่ ZH
    st Z, temp                  ; นำ 0 ใน temp ไปใส่ที่ TCNT1H ผ่านตัวชี้ Z

    ldi ZL, low(TCNT1L)         ; โหลด byte low TCNT1L ใส่ ZL
    ldi ZH, high(TCNT1L)        ; โหลด byte high TCNT1L ใส่ ZH
    st Z, temp                  ; นำ 0 ใน temp ไปใส่ที่ TCNT1L ผ่านตัวชี้ Z
    
    ldi temp, (1<<CS11)         ; ตั้งค่า Prescaler เป็น /8 (ความเร็วการนับ = 16MHz/8 = 2MHz หรือนับทุกๆ 0.5us)
    
    ldi ZL, low(TCCR1B)         ; โหลด byte low TCCR1B ใส่ ZL
    ldi ZH, high(TCCR1B)        ; โหลด byte high TCCR1B ใส่ ZH
    st Z, temp           ; นำ temp ไปใส่ที่ TCCR1B ผ่านตัวชี้ Z ควบคุม Timer1 เพื่อ เริ่มเดิน Timer

; รอให้ขา Echo ตกลงเป็น LOW (คลื่นสะท้อนกลับมาถึงแล้ว)
; ระยะเวลาที่ขา Echo ค้างเป็น HIGH คือระยะเวลาเดินทางไป-กลับของเสียง

    ldi r26, 10                 ; รอคลื่นสัญญาณสะท้อนกลับมา
WAIT_ECHO_LOW_SUPER:
    ldi r25, 255				; รอคลื่นสัญญาณสะท้อนกลับมา
WAIT_ECHO_LOW_OUTER:
    ldi r24, 255				; รอคลื่นสัญญาณสะท้อนกลับมา
WAIT_ECHO_LOW_INNER:
    sbis PINB, 1                ; Skip if Bit Set ถ้าขา PB1 (Echo) ยังเป็น 1 ยังเดินทางอยู่
    rjmp STOP_TIMER       ; ขา Echo เป็น LOW แล้ว กระโดดไปหยุดจับ Timer มาประมวลผลต่อไป
    
    ; ส่วนนับถอยหลัง Timeout ของขากลับ
    dec r24                     ; ลดค่าตัวนับ loop ต่างๆไปเรื่อย เหมือนที่เคยทำมา
    brne WAIT_ECHO_LOW_INNER
    dec r25
    brne WAIT_ECHO_LOW_OUTER
    dec r26
    brne WAIT_ECHO_LOW_SUPER
    rjmp STOP_TIMER             ; ถ้ารอจน Timeout

STOP_TIMER:
    ldi temp, 0
    
    ldi ZL, low(TCCR1B)			; โหลด byte low TCCR1B ใส่ ZL
    ldi ZH, high(TCCR1B)		; โหลด byte high TCCR1B ใส่ ZH
    st Z, temp                  ; นำ 0 ใน temp ไปใส่ที่ TCCR1B ผ่านตัวชี้ Z ควบคุม Timer1 เพื่อ หยุดเดิน Timer
    
    lds dist_L, TCNT1L          ; โหลด byte low TCNT1L ที่ได้ใส่ dist_L
    lds dist_H, TCNT1H          ; โหลด byte high TCNT1H ที่ได้ใส่ dist_H
    rjmp EXIT_SONAR             ; เก็บค่าระยะครบแล้วออกได้

; Timeout
SONAR_TIMEOUT:
    ldi dist_L, 0xFF            ; ใส่ค่า 255 ให้ byte low
    ldi dist_H, 0xFF            ; ยัดค่า 255 ให้ byte high บอกว่าไกลมากๆ

EXIT_SONAR:
    pop r26                     ; pop res ออก
    pop r25
    pop r24
    ret                         ; จบ

; Subroutines ควบคุม Servo ใช้ขาสัญญาณ PD3 ในการส่ง PWM
; โดย Servo จะส่งสัญญาณ PWM ให้ครบ 1 รอบ ในเวลา 20ms เสมอ เพร่าะ GEN_PWM ใช้เวลาหน่วงรอบละ 0.1ms จ
; r22 = จำนวนเวลา HIGH เป็นตัวกำหนดองศา หรือการหมุน
; r23 = จำนวนเวลา LOW  เป็นตัวชดเชยเวลาที่เหลือให้ครบ 20ms 
; โดย r22 + r23 ต้องรวมกันได้ 200
; เพราะ ถ้า T = 20ms จะได้ 50Hz ตามความถี่ที่ไว้ควบคุม Servo Motor

SERVO_LEFT:
    push r24
    push r22
    push r23
    ldi r24, 15
LOOP_SL:
    ldi r22, 24                 ; ใช้ Pulse HIGH 24 x 0.1ms = 2.4ms ใช้มันหมุนซ้ายไป
			    ; เวลามากกว่า 1.5ms Motor ให้บิดไปทางมุม 180 องศา
    ldi r23, 176                ; ใช้ Pulse LOW  176 x 0.1ms = 17.6ms 
    rcall GEN_PWM
    dec r24	             ; ลบค่า r24 ลงไปเรื่อยๆจนถึง 0 จึงจะหลุดไปได้ เพื่อรอให้ Servo หมุนให้ครบถ้วน
    brne LOOP_SL
    pop r23
    pop r22
    pop r24
    ret

SERVO_RIGHT:
    push r24
    push r22
    push r23
    ldi r24, 15
LOOP_SR:
    ldi r22, 6                  ; ใช้ Pulse HIGH 6 x 0.1ms = 0.6ms ใช้มันหมุนขวาไป
			    ; เวลาน้อยกว่า 1.5ms Motor ให้บิดไปทางมุม 0 องศา
    ldi r23, 194				; ใช้ Pulse LOW  194 x 0.1ms = 19.4ms
    rcall GEN_PWM
    dec r24	; ลบค่า r24 ลงไปเรื่อยๆจนถึง 0 จึงจะหลุดไปได้ เพื่อรอให้ Servo หมุนให้ครบถ้วน
    brne LOOP_SR
    pop r23
    pop r22
    pop r24
    ret

SERVO_CENTER:
    push r24
    push r22
    push r23
    ldi r24, 15                 ; รอให้ servo หันเสร็จก่อน
LOOP_SC:
    ldi r22, 15                 ; ใช้ Pulse HIGH 15 x 0.1ms = 1.5ms ให้มันอยู่ตรงกลางพอดี
    ldi r23, 185                ; ใช้ Pulse LOW  185 x 0.1ms = 18.5ms 
			; เวลารวม 1 รอบ = 1.5 + 18.5 = 20.0ms
    rcall GEN_PWM
    dec r24	; ลบค่า r24 ลงไปเรื่อยๆจนถึง 0 จึงจะหลุดไปได้ เพื่อรอให้ Servo หมุนให้ครบถ้วน
    brne LOOP_SC
    pop r23
    pop r22
    pop r24
    ret

; สร้างสัญญาณ PWM
; R22 (Logic High), R23 (Logic Low)
GEN_PWM:
    cli                         ; ปิด Interrupt ก่อนชั่วคราว เพื่อป้องกันเวลา PWM คลาดเคลื่อนเดียวมันมั่วครับ
    sbi PORTD, 3                ; ส่ง Set bit 1 ไปที่ Servo Motor ให้มันหมุน
PWM_HIGH_LOOP:
    rcall DELAY_100US
    dec r22			; ให้มันวนไปเรื่อยๆ ลบ 1 จนเป็น 0 ตามค่า r22 รอบละ 1ms
    brne PWM_HIGH_LOOP
    cbi PORTD, 3                ; ส่ง Clear bit 0 ไปที่ Servo Motor ให้มันหยุดหมุน
    sei                         ; เปิด Interrupt
PWM_LOW_LOOP:
    rcall DELAY_100US
    dec r23						; ให้มันวนไปเรื่อยๆ ลบ 1 จนเป็น 0 ตามค่า r23 รอบละ 1ms
    brne PWM_LOW_LOOP
    ret

; Delay
DELAY_1MS:
	push r20
	push r21
	ldi r20, 16
LOOP_1MS_OUTER:
	ldi r21, 250
LOOP_1MS_INNER:
	nop
	nop
	dec r21
	brne LOOP_1MS_INNER
	dec r20
	brne LOOP_1MS_OUTER
	pop r21
	pop r20
	ret

DELAY_10MS:
    push r26
    ldi r26, 10
LOOP_10MS:
    rcall DELAY_1MS
    dec r26
    brne LOOP_10MS
    pop r26
    ret

DELAY_250MS:
    push r27
    ldi r27, 25
LOOP_250MS:
    rcall DELAY_10MS
    dec r27
    brne LOOP_250MS
    pop r27
    ret

DELAY_500MS:
    push r27
    ldi r27, 50
LOOP_500MS:
    rcall DELAY_10MS
    dec r27
    brne LOOP_500MS
    pop r27
    ret

DELAY_100US:
    push r20
    ldi r20, 250
LOOP_100US:
    nop
    nop
    nop
    dec r20
    brne LOOP_100US
    pop r20
    ret

DELAY_10US:
    push temp
    ldi temp, 53
LOOP_10US:
    dec temp
    brne LOOP_10US
    pop temp
    ret
