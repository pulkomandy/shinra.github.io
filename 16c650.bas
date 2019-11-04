10 RBR=&FEB0:THR=&FEB0:DLL=&FEB0:IER=&FEB1:DLM=&FEB1:FCR=&FEB2:EFR=&FEB2:IIR=&FEB2:LCR=&FEB3:MCR=&FEB4:LSR=&FEB5:MSR=&FEB6:SCR=&FEB7
20 PRINT "Albireo Serial Link test"
25 ' Detect the device
30 OUT SCR,42:a=INP(SCR):IF a <>42 THEN PRINT "Serial controller not detected":END
40 PRINT "Serial controller detected"
48 OUT FCR,7 ' Enable FIFO
49 'OUT FCR,6 ' Disable FIFO
50 OUT IER,0 ' Disable interrupts
51 OUT LCR,&BF ' Enter configuration mode
52 baudrate = 115200:divider = 1500000 / baudrate
53 OUT DLL,divider:OUT DLM,divider / 256
54 OUT EFR,&C0 ' Enable hardware flow control
55 OUT LCR,&03 ' Disable configuration mode
60 'OUT MCR,&10 ' For loopback mode
61 OUT MCR,0 ' For normal mode
65 PRINT "Test sending data"
70 FOR i = 0 TO 255 ' Loop on every possible value
80 OUT THR,i ' Send the value
100 NEXT
110 PRINT "Test receiving data"
120 r=INP(LSR):IF (r AND 1)=0 THEN 120 'Wait for incoming data
130 PRINT " ";HEX$(INP(RBR),2):GOTO 120 'Receive and print one byte
