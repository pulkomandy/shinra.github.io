10 MODE 2
20 DEFINT u-z
30 CMD=&FE81:DAT=&FE80
40 ' Initialize and detect the controller -------------------------------------
50 OUT cmd,&5:FOR i = 0 TO 5:FRAME:NEXT
60 OUT cmd,6:OUT dat,&55:ret = INP(dat) ' Check device available
70 IF ret = &AA THEN OUT cmd,1:PRINT "CH376 detected, version";INP(dat)-&40:ELSE PRINT "CH376 not detected"
80 OUT cmd,&15:OUT dat,7:v=INP(dat)
90 OUT cmd,&15:OUT dat,6:v=INP(dat) ' USB HOST mode
100 DEVCOUNT=0
110 GOSUB 190 ' List the root device
120 IF CLASS=9 THEN GOTO 720
130 END
140 ' Wait for command to complete and detect errors --------------------------
150 sta=INP(cmd):IF sta > 127 THEN GOTO 150
160 OUT CMD,&22
170 STATUS=INP(dat):IF STATUS<>&14 AND status<>&1D THEN PRINT"IT STAT:",HEX$(STATUS)
180 RETURN
190 ' LIST USB DEVICES --------------------------------------------------------
200 OUT CMD,&13:OUT DAT,0 ' TALK TO THE NEXT UNCONFIGURED DEVICE
210 PRINT "Set USB address"
220 DEVCOUNT=DEVCOUNT+1
230 OUT cmd,&45:OUT dat,DEVCOUNT:v=INP(dat) ' USB address
240 GOSUB 140
250 OUT cmd,&13:OUT dat,DEVCOUNT
260 PRINT"Get device descriptor
270 OUT cmd,&46:OUT dat,1:GOSUB 140 ' Get device descriptor
280 OUT cmd,&27:ln=INP(dat):IF ln<>18 THEN PRINT"Invalid device descriptor length ";ln
290 'CMD27 allows us to read the descriptor data, let's print the info we find
300 length=INP(dat):IF LENGTH<>18 THEN PRINT"INVALID DEscriptor length: ";length
310 type=INP(dat):IF TYPE<>1 THEN PRINT"INVALID Descriptor type: ";type
320 lo=INP(dat):hi=INP(dat):PRINT"USB Version ";hi;".";lo
330 class=INP(dat):subclass=INP(dat):protocol=INP(dat):PRINT"Device class: ";class;" subclass: ";subclass;" protocol: ";protocol 
340 pktsize=INP(dat):PRINT"Packet size: ";pktsize
350 lov=INP(dat):hiv=INP(dat):lod=INP(dat):hid=INP(dat):PRINT"Vendor: ";HEX$(hiv,2);HEX$(lov,2);" Device: ";HEX$(hid,2);HEX$(lod,2)
360 lor=INP(dat):hir=INP(dat):PRINT"Device revision ";HEX$(hir);".";HEX$(lor)
370 man=INP(dat):prod=INP(dat):ser=INP(dat):PRINT "string descriptors: manufacturer ";man;" product ";prod;" serial ";ser
380 numconf=INP(dat):PRINT numconf;" configurations"
390 PRINT"Select configuration 1
400 OUT cmd,&49:OUT dat,1 'Select config 1
410 GOSUB 140
411 PRINT "Press Return to continue":INPUT x
420 RETURN ' END OF DEVICE DESCRIPTOR LISTING
430 ' HID MOUSE TEST (for reference) ------------------------------------------
440 OUT cmd,&2C:OUT dat,&8 ' Write an 8 byte command to the device 
450 OUT dat, &21:OUT dat,&B ' SET PROTOCOL command   
460 OUT dat, &0 ' Use BOOT protocol
470 OUT dat,&0:OUT dat,&0:OUT dat,&0:OUT dat,&0:OUT dat,&0    
480 OUT cmd,&4E:OUT dat,&80:OUT dat,&D
490 GOSUB 140
500 token =0
510 OUT cmd, &4E:OUT dat,token:OUT dat,&19:token = token XOR &80 ' Get HID data
520 GOSUB 140
530 IF status = &23 THEN GOTO 660
540 IF STATUS<>&14 THEN PRINT HEX$(STATUS);:GOTO 510
550 OUT cmd,&27
560 Ln = INP(dat)
570 btn = INP(dat)
580 PLOT x,y,0
590 xd=INP(dat):yd=INP(dat):w=0'INP(dat)
600 IF xd>127 THEN xd=xd-256
610 IF yd>127 THEN yd=yd-256
620 IF w>127 THEN w=w-256
630 x=x+xd:y=y-yd:PLOT x,y,1
640 BORDER btn
650 GOTO 510
660 ' CLEAR STALL
670 PRINT "S";
680 OUT cmd,&41 ' CMD_CLEAR_STALL
690 OUT DAT,&81 ' Endpoint 1, IN
700 GOSUB 140:IF STATUS<>&14 THEN PRINT HEX$(STATUS);
710 GOTO 500
720 'HUB HANDLING CODE --------------------------------------------------------
730 PRINT"DEVICE ";DEVCOUNT;" IS A HUB, ENUMERATING IT"
740 ' TODO read the configuration descriptor to get port count
750 portcount = 4:token=0
760 FOR i=1 TO portcount
770 'power on each port
780 OUT cmd,&2C:OUT dat,&8 ' Send data to the CH376 for the request, requests are always 8 bytes
790 OUT dat,&23 ' bmRequesType = SET PORT FEATURE
800 OUT DAT,3 ' bRequest = SET FEATURE
810 OUT dat,8:OUT dat,0 ' wValue = PORT_POWER
820 OUT dat,i:OUT dat, 0 ' wIndex = port index (1 to 4 for a 4 port hub)
830 OUT dat,0:OUT dat,0 ' wLength = 0 (no data)
840 OUT cmd,&4E:OUT dat,token:OUT dat,&D ' Do a control transfer
850 token = token XOR &80 ' prepare for next transaction
860 GOSUB 140 ' Wait for operation to complete
870 NEXT i
880 ' Ok, now all port are powered up and we should start getting notifications for new connected devices
890 OUT cmd,&4E:OUT dat,token:OUT dat,&19 ' Read transaction on endpoint 1 (interrupt endpoint)
900 GOSUB 140
910 OUT cmd,&27 ' Read the result
920 ln=INP(dat):'PRINT"Received ";ln;" bytes"
930 ' The reply is a bitfield where bit 0 is the global status and bits 1 to N are the status for each port. Each set bit is a port with a device connected
940 hubstatus=INP(dat):port = 0
950 PRINT "Initial value: ";HEX$(hubstatus, 2)
960 hubstatus = hubstatus AND &FE
970 hubstatus=UNT(hubstatus/2):port = port + 1
980 PRINT "Scanning port ";port;" hubstatus ";HEX$(hubstatus,2)
990 IF hubstatus AND 1 THEN PRINT "Device found on port ";port:GOSUB 1030
1000 hubstatus = hubstatus AND &FE
1010 IF hubstatus <> 0 THEN GOTO 970
1020 END
1030 ' Reset the port then enumerate the device --------------------------------
1040 OUT cmd,&2C:OUT dat,&8 ' Prepare a control transfer
1050 OUT dat,&23 ' bmRequestType = Set Port Feature
1060 OUT dat,&3 ' Set feature
1070 OUT dat,&4:OUT dat,&0 ' Port reset
1080 OUT dat,port:OUT dat,0 ' Port index
1090 OUT dat,0: OUT dat, 0 ' No data
1091 OUT cmd,&4E:OUT dat,token:OUT dat,&D
1100 token=token XOR &80:GOSUB 140
1110 FRAME:FRAME:FRAME:FRAME:FRAME ' Wait a bit for port reset
1111 ' TODO do a "get port status" and check at least the lowspeed/highseed bits, if either is set, we need to do a "set device speed" to go to usb1 speeds?
1112 'Get Port status: request type A3, GET FEATURE, value 0, index=port, wLength=4
1120 GOSUB 190 ' Now we can enumerate the device
1130 RETURN
