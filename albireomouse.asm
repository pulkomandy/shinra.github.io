; Register base address
ACE_ADDR	EQU 0xfeb0	; IO base address
ACE_ADDRh	EQU 0xfe  	; IO base address
ACE_ADDRl	EQU 0xb0  	; IO base address
ACE_CMDl        EQU #81
ACE_DATl        EQU #80
ACE_CMD         equ ACE_ADDRh * 256 + ACE_CMDl
ACE_DAT         equ ACE_ADDRh * 256 + ACE_DATl

ACE_SCR_OFF	EQU 7     	; Scratch register
ACE_SCR		EQU ACE_ADDR+ACE_SCR_OFF

; Any value will do, we just test that we can read/write a register
ACE_MAGIC_NUMBER    EQU #61


;Detects and initializes the Albireo.
;OUT:   Carry = 1 = OK. 0 if undetected or a problem occurred.
InitializeAlbireo:

        ; First, detect the card. We use the scratch register which has no effect but can be read
        ; and written to. Just make sure we can write something and read it back.
        ld bc,ACE_SCR                   ;SIO_DETECT_INTERFACE
        ld a,ACE_MAGIC_NUMBER
        out (c),a
        in a,(c)
        xor ACE_MAGIC_NUMBER            ;Clears carry flag.
        jr nz,.error  ; Not found!               

        ; Configure an USB device. We need to switch to USB mode 7 (this resets the USB bus),
        ; then mode 6 (USB host mode) which allows us to send USB commands to the mouse directly.
        ld a,#15 : call AlbireoCmd
        ld a,#7 : call AlbireoDat
        ld a,#15 : call AlbireoCmd
        ld a,#6 : call AlbireoDat
        ; Set the USB bus speed. #b is a "poke" command which allows to set some variables in the
        ; Albireo USB controller. Here it's used to set the USB speed at address #17.
        ; TODO: I'm not sure if this is required, and there is another command to set the speed
        ; in a simpler way
        ld a,#b : call AlbireoCmd
        ld a,#17 : call AlbireoDat
        ld a,#d8 : call AlbireoDat

        ; At this point, the USB bus is initialized. By default, all USB devices are assigned to
        ; address 0 which is a broadcast address. Only few USB commands can be sent to this port.
        ; In a normal USB setup, this is where we would setup USB hubs, discover all devices
        ; connected to them, etc. But assume we have just a mouse connected directly to Albireo
        ; for now.

        ; Command 45 tells the mouse (or whatever is connected to the USB port) to now reply only
        ; to commands sent to address 1
        ld a,#45 : call AlbireoCmd
        ld a,#1 : call AlbireoDat

        ; This command takes some time to run, so we wait for it to complete by checking the
        ; status register
        call AlbireoWaitForCommandEnd
        
        ; Now we need to tell Albireo itself that all following commands will be sent at address
        ; 1 (if you had multiple devices connected to a hub, you would switch between them using
        ; this command after you assigned a different address to each using command 45)
        ld a,#13 : call AlbireoCmd
        ld a,#1 : call AlbireoDat

        ; Phew! USB initialization is now complete, we can finally send and receive data from the
        ; mouse itself. We now need to configure the mouse to use the correct "configuration".
        ; Some USB devices can be used in different ways and have multiple configurations. We
        ; are only dealing with a simple mouse here, so we just pick the first configuration
        ld a,#49 : call AlbireoCmd
        ld a,#1 : call AlbireoDat
        ; Again this is a command that can take some time to complete...
        call AlbireoWaitForCommandEnd

        ; OK, all of the above was quite generic USB setup code. It would look similar for any
        ; other USB device. Now on to the mouse specific bits!


        ; This example uses the mouse in normal HID mode. In this mode, the mouse can send a
        ; "descriptor" telling the computer how the report is structured: how many buttons,
        ; wheels, axes, ...
        ; However, this is complicated to parse and most mouse use a similar layout anyway. So we
        ; just go ahead and read the report and assume something close to the usual thing.
        ; This may not work with very advanced mouses (more than 8 buttons, more than 1 mouse
        ; wheel, etc). But, we could switch the mouse to "boot mode" instead. In that case all
        ; mouses will use th same report format: 2 buttons and 2 axes. No 3rd button and no
        ; mousewheel, unfortunately. It's up to you, either universal but limited compatibility
        ; with all mouses, or support for wheels and extra buttons, but only the simpler mouses
        ; will work.
        ; Here is the sequence to switch to boot mode:
        ; OUT CMD,&2C ' For WRITE commands, you first send the data to Albireo, then trigger the transfer. It's symetrical to READ. 
        ; OUT DAT,8 ' Size of the data we're going to send
        ; The CH376 is now waiting for our 8 data bytes. We will now write the HID command to enter boot mode:
        ; OUT DAT,&21 ' (because all HID commands start with &21) 
        ; OUT DAT,&0B ' (this is the HID SET PROTOCOL command) 
        ; OUT DAT,&00:OUT DAT,&00 ' (protocol number 0 - on 16 bits - is the BOOT protocol) 
        ; OUT DAT,&00:OUT DAT,&00:OUT DAT,&00:OUT DAT,&00
        ; All USB commands must also include an index and a data length, 16 bits each. Both are set to 0 for the SET PROTOCOL command.
        ; The bytes are now loaded in the CH376. We can request it to perform the USB transaction:
        ; OUT CMD,&4E:OUT DAT,&80:OUT DAT,&0D ' The &80 here must match the "token" sequence as for the read commands
        ; call AlbireoWaitForCommandEnd


        ; The way an USB mouse works is that there is nothing to "read" from it as long as the
        ; mouse does not move or a button isn't clicked. Albireo takes care of watching for that,
        ; and will tell us when there is some data available. For this to work, we need to tell
        ; Albireo that we want to read data from the USB device. Starting a (read or write)
        ; transaction is done using command 4e. The first parameter is a "token" where bit 7 must
        ; change every time the command is used. This allows the device to know it did not miss
        ; a command. The second parameter configures the type of request, #19 is a read.

        ;Submit our first request to the mouse to get things started
        ld a,#4e : call AlbireoCmd
       
        ld a,0
        call AlbireoDat
        ld a,(Token + 1)
        xor #80
        ld (Token + 1),a
       
        ld a,#19 : call AlbireoDat

        ; And that's finally it, we're ready to go!
        scf
        ret
.error:
        or a
        ret


        
;Sends a byte to the DAT port.
;IN:    A = the byte to send.
AlbireoDat:
        ld bc,ACE_DAT
        out (c),a
        ret

; This is the method to call every frame (or as often or rarely as you want, really), or you can
; call it only when an interrupt occurs, if you're using interrupt-driven mode (then there is 0
; CPU use when the mouse is not moving!)

;Reads the mouse and updates the cursor X/Y accordingly.
;Screen limits are not tested here.
AlbireoManageMouse:
        ; First of all, check if the mouse has anything to say at the moment. We check this in
        ; bit 7 of the status register
        ld bc,ACE_CMD
        in a,(c)
        rla
        ; Nothing to do? Exit.
        ret c
        
        ; If we get here, there is data waiting for us, so we need to read it
        ; Command 27 is used to read the data.
        ld a,#27 : call AlbireoCmd
        
        ; The first byte returned is the size of the data to read. Since we know this is a mouse,
        ; we can ignore it, they all use the same layout:
        ; 1 byte with buttons
        ; 1 byte with signed delta X since last read
        ; 1 byte with signed delta Y since last read
        ; 1 byte with mousewheel delta since last read
        ; Fancy mouse with more than 8 buttons, or two wheels, ... would use a different layout.
        ; It's possible to ask the mouse for its HID report descriptor, but it's too complicated.
        ; Get a cheaper mouse for your CPC.
        ; Alternatively, for maximum compatibility, the mouse can be set to "boot mode" where ALL
        ; mouses will report only 2 buttons and deltaX/deltaY. But that means no mouse wheel.
        call AlbireoReadDat
        
        ;Reads Buttons.
        call AlbireoReadDat
        ld c,a
        and %00000001           ;Button 0.
        ld (MouseButton0),a
        ld a,c
        and %00000010           ;Button 1.
        ld (MouseButton1),a
        ld a,c
        and %00000100
        ld (MouseButton2),a     ;Button 2.
        ; ... and so on for extra buttons
        ;Reads deltaX.
        call AlbireoReadDat
        or a
        jr z,.endXMotion
        call SignedByteToWord
        call CursorMoveHorizontally
.endXMotion
        ;Reads deltaY.
        call AlbireoReadDat
        or a
        jr z,.endYMotion
        call SignedByteToWord
        call CursorMoveVertically
.endYMotion
        ;Reads Wheel.
        call AlbireoReadDat
        
        ; We now schedule a new read transfer so that there is more data to get next time the
        ; routine is called (if the mouse has moved until then). This is the same code as in
        ; the end of the initialization phase
ScheduleTransfer:    
        ld a,#4e : call AlbireoCmd
        
Token:  ld a,0
        call AlbireoDat
        ld a,(Token + 1)
        xor #80
        ld (Token + 1),a
        
        ld a,#19
        jp AlbireoDat
        

;Sends a byte to the CMD port.
;IN:    A = the byte to send.
AlbireoCmd
        ld bc,ACE_CMD
        out (c),a
        ret
        
;OUT:   A = the byte read from the DAT.
AlbireoReadDat:
        ld bc,ACE_DAT
        in a,(c)
        ret
        
; Waits for a command to end by polling the status register. There is no timeout.
; Alternatively you could use interrupts if you really want to do something else during that time.
AlbireoWaitForCommandEnd:
        ld bc,ACE_CMD
.waitLoop
        in a,(c)
        rla
        jr c,.waitLoop
        
        ld a,#22
        jp AlbireoCmd
