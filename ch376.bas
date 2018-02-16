10 MODE 2
20 CMD=&FE81 : DAT=&FE80 ' CH376 IO ports
30 ' Initialisation du CH376
40 OUT CMD,&5:FOR I=0 TO 5:FRAME:NEXT
50 OUT CMD,&6:OUT DAT,&55:ret = INP(DAT) ' Detection du CH376
60 IF ret = &AA THEN OUT CMD,&1:PRINT "CH376 detected (rev. ";INP(DAT)-&40;")":ELSE PRINT "CH376 not detected!"
70 PRINT " --- ALBIREO TEST PROGRAM --- "
80 PRINT "1 - Select USB drive":PRINT "2 - Select SD Card":PRINT "3 - Get drive info (USB only)":PRINT "4 - Get capacity":PRINT "5 - List files"
90 INPUT choice
100 ON choice GOSUB 120, 150, 180, 280, 370
110 GOTO 70

120 ' Selection de l'USB
130 OUT CMD,&15: OUT DAT,&6: v=INP(DAT)
140 RETURN

150 ' Selection de la carte SD
160 OUT CMD,&15: OUT DAT,&3: v=INP(DAT)
170 RETURN

180 ' Info sur le disque USB
190 OUT CMD,&31
200 GOSUB 470
210 OUT CMD,&27
220 Ln=INP(DAT)
230 FOR i = 0 TO Ln
240 v=INP(DAT): IF v > 31 THEN PEN 1:PAPER 0:PRINT CHR$(v);:ELSE PEN 0:PAPER 1:PRINT " ";HEX$(v);
250 NEXT
260 PEN 1:PAPER 0:PRINT
270 RETURN

280 ' Taille du volume et espace libre
290 OUT CMD,&3F:GOSUB 470
300 OUT CMD,&27
310 Ln = INP(DAT):t0=INP(dat):t1 = INP(DAT):t2=INP(dat):t3=INP(dat)
320 f0=INP(dat):f1 = INP(DAT):f2=INP(dat):f3=INP(dat)
330 t=((t3*256+t2)*256+t1)*256+t0:PRINT "Sectors: ",t," / MB:",t/2048
340 f=((f3*256+f2)*256+f1)*256+f0:PRINT "   Free: ",f," / MB:",f/2048
350 Ln = INP(DAT) ' FS type information
360 RETURN

370 ' List files in root directory
380 OUT CMD,&2F:OUT DAT,&2A:OUT DAT,0 ' open "*" (list all files in current dir)
390 OUT CMD,&32:GOSUB 470
400 OUT CMD,&27:Ln=INP(DAT)
410 FOR i = 0 TO Ln:v=INP(DAT): IF v > 31 THEN PEN 1:PAPER 0:PRINT CHR$(v);:ELSE PEN 0:PAPER 1:PRINT " ";HEX$(v);
420 NEXT i
430 PEN 1:PAPER 0:PRINT
440 OUT CMD,&33:GOSUB 470 ' Get next chunk of list
450 IF status = &1D THEN GOTO 400
460 RETURN

470 ' Wait for command to complete and read error code
480 sta = INP(CMD):IF sta > 127 THEN GOTO 480
490 OUT CMD,&22
500 STATUS=INP(DAT):IF STATUS<>&14 AND STATUS <> &1D THEN PRINT "ERROR: interrupt status = ";HEX$(STATUS)
510 RETURN
