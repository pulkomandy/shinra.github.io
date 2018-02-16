10 REM Albireo HID Mouse - 2016.12.02
20 REM V1.0.0 PulkoMandy
30 REM V1.0.1 TFM
40 REM
50 DEFINT a-z:MODE 2
60 CMD=&FE81 : DAT=&FE80 :' CH376 IO ports
70 x=320:y=200:PLOT x,y
80 :' Device initialization
90 :' First we reset the device (mode 7), then we enter normal host mode (6).
100 OUT CMD,&15:OUT DAT,&7 :' Initialize device in usb HOST mode, reset USB bus
110 OUT CMD,&15:OUT DAT,&6 :' Initialize device in usb HOST mode, produce SOF
120 OUT CMD,&B:OUT DAT,&17:OUT DAT,&D8 :' Set USB device speed?
130 OUT CMD,&45:OUT DAT,&1:v =INP(dat) :' Set device address
140 GOSUB 510
150 OUT CMD,&13:OUT DAT,&1 :' Set CH376 address
160 :' We can now select configuration 1. In a mouse, this is (usually?) the only available configuration.
170 OUT CMD,&49:OUT DAT,&1 :' Select configuration 1
180 GOSUB 510
190 :' And here is our main loop.
200 :' We will poll the mouse for data.
210 :' We use command &4E which is the lowest level command available.
220 TOKEN = &0 :' TOKEN selects DATA0 or DATA1 packet. They must alternate!
230 OUT CMD,&4E
240 :' First parameter is the "sync token", bit 7 means "host endpoint synchronous trigger" (whatever...)
250 OUT DAT,TOKEN
260 :' Second byte is the operation descriptor.
270 :' High 4 bits define the endpoint
280 :' (here we use endpoint 1, which is the interrpt endpoint of the mouse)
290 :' low 4 bits define the operation (9 is a READ).
300 OUT DAT,&19 :' Read from endpoint 0
310 :' The mouse only sends reports when something actually changes (move or button state). If you want periodic reports, the HID "set idle" command can be used to configure it so.
320 TOKEN = TOKEN XOR &80 :'Alternate DATA0 - DATA1 packets
330 GOSUB 510
340 OUT CMD,&27 :' Get data from command RD_USB_DATA0
350 :' We use command &27 as usual to get the data
360 :' The first byte is the length of the report.
370 Ln = INP(dat)
380 IF Ln = 0 THEN GOTO 230 :' No data, try again?
390 :' First byte of report has button states (lowest bit is button 1)
400 BTN=INP(dat)
410 xd=INP(dat):yd=INP(dat):w=INP(dat) :' Next are X-delta, Y-delta, and wheel-delta
420 LOCATE 1,3:PRINT"dX: &";HEX$(xd,2);"   dY: &";HEX$(yd,2);"   Wheel: &";HEX$(w,2);"   Buttons: &";HEX$(BTN,2);
430 :' Now perform some fixes for BASIC compatibility
440 IF xd > 127 THEN xd = xd - 256 :' Convert to signed
450 yd = yd XOR &FF:IF yd > 127 THEN yd = yd - 256
460 IF w > 127 THEN w = w - 256
470 :' And just plot a pixel at the current mouse position
480 x=x+xd:y=y+yd:DRAW x,y :' Move and draw cursor
490 GOTO 230
500 :' Wait for command to complete and read error code
510 LOCATE 1,24:sta = INP(CMD):PRINT"Status: &";HEX$(sta,2);:IF sta > 127 THEN GOTO 510
520 :' GET_STATUS
530 OUT CMD,&22
540 STATUS=INP(DAT):LOCATE 1,1:PRINT"Interrupt status (&14,&1D=OK) = ";HEX$(STATUS,2);
550 RETURN
