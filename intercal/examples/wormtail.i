	DO (1) NEXT

	PLEASE KNOW THAT THIS IS AN EXAMPLE OF A PROGRAM THAT USES EXTENSIONS
		TO INTERCAL FOR BINARY INPUT AND OUTPUT

	PLEASE CHOOSE EITHER PUKE BINARY I/O OR C-INTERCAL BINARY I/O
		BY REINSTATING (1) FOR PUKE BINARY I/O OR
		ABSTAINING FROM (1) FOR C-INTERCAL BINARY I/O

	PLEASE KNOW THAT NO OTHER EXTENSIONS TO INTERCAL ARE USED

	PLEASE NOTE .10 + .11 ARE LEFT CODE ARRAY
	PLEASE NOTE .12 + .13 ARE RIGHT CODE ARRAY
	PLEASE NOTE .14 + .15 ARE LEFT MEMORY ARRAY
	PLEASE NOTE .16 + .17 ARE RIGHT MEMORY ARRAY
	PLEASE NOTE .11 + .13 + .15 + .17 INDICATE END OF ARRAY WITH #1
	PLEASE NOTE .11 + .13 + .15 + .17 INDICATE ARRAY CONTINUES WITH #2

	PLEASE INITIALIZE
(1)	DO (2) NEXT
	DO REINSTATE (110)
	DO REINSTATE (111)
	DO REINSTATE (210)
	DO REINSTATE (211)
	DO ABSTAIN FROM (100)
	DO ABSTAIN FROM (101)
	DO ABSTAIN FROM (200)
	DO ABSTAIN FROM (201)
(2)	DO FORGET #2
	DO .11 <- #1
	DO .13 <- #1
	DO .15 <- #1
	DO .17 <- #1
	DO (100) NEXT
	DO (200) NEXT
	DO (300) NEXT
	DO (10) NEXT

	PLEASE START EXECUTION LOOP AND CHECK FOR ANGLE
(10)	DO FORGET #1
	DO (11) NEXT
	DO (20) NEXT
	PLEASE STOP
(11)	DO (12) NEXT
	DO FORGET #1
	DO (11001) NEXT
	DO (10) NEXT
	PLEASE STOP	
(12)	DO RESUME '∀"'#255~"'∀#60¢.12'~'#0¢#255'"'~#1"¢#1'~#3
	PLEASE CHECK FOR RIGHT ANGLE
(20)	DO FORGET #1
	DO (21) NEXT
	DO (30) NEXT
	PLEASE STOP
(21)	DO (22) NEXT
	DO FORGET #1
	DO (12001) NEXT
	DO (10) NEXT
	PLEASE STOP
(22)	DO RESUME '∀"'#255~"'∀#62¢.12'~'#0¢#255'"'~#1"¢#1'~#3
	PLEASE CHECK FOR INTERSECTION
(30)	DO FORGET #1
	DO (31) NEXT
	DO (40) NEXT
	PLEASE STOP
(31)	DO (32) NEXT
	DO FORGET #1
	DO (13001) NEXT
	DO (10) NEXT
	PLEASE STOP
(32)	DO RESUME '∀"'#255~"'∀#43¢.12'~'#0¢#255'"'~#1"¢#1'~#3
	PLEASE CHECK FOR WORM
(40)	DO FORGET #1
	DO (41) NEXT
	DO (50) NEXT
	PLEASE STOP
(41)	DO (42) NEXT
	DO FORGET #1
	DO (14001) NEXT
	DO (10) NEXT
	PLEASE STOP
(42)	DO RESUME '∀"'#255~"'∀#45¢.12'~'#0¢#255'"'~#1"¢#1'~#3
	PLEASE CHECK FOR SPOT
(50)	DO FORGET #1
	DO (51) NEXT
	DO (60) NEXT
	PLEASE STOP
(51)	DO (52) NEXT
	DO FORGET #1
	DO (15001) NEXT
	DO (10) NEXT
	PLEASE STOP
(52)	DO RESUME '∀"'#255~"'∀#46¢.12'~'#0¢#255'"'~#1"¢#1'~#3
	PLEASE CHECK FOR TAIL
(60)	DO FORGET #1
	DO (61) NEXT
	DO (70) NEXT
	PLEASE STOP
(61)	DO (62) NEXT
	DO FORGET #1
	DO (16001) NEXT
	DO (10) NEXT
	PLEASE STOP
(62)	DO RESUME '∀"'#255~"'∀#44¢.12'~'#0¢#255'"'~#1"¢#1'~#3
	PLEASE CHECK FOR U-TURN
(70)	DO FORGET #1
	DO (71) NEXT
	DO (80) NEXT
	PLEASE STOP
(71)	DO (72) NEXT
	DO FORGET #1
	DO (17001) NEXT
	DO (10) NEXT
	PLEASE STOP
(72)	DO RESUME '∀"'#255~"'∀#91¢.12'~'#0¢#255'"'~#1"¢#1'~#3
	PLEASE CHECK FOR U-TURN BACK
(80)	DO FORGET #1
	DO (81) NEXT
	DO (401) NEXT
	DO (10) NEXT
	PLEASE STOP
(81)	DO (82) NEXT
	DO FORGET #1
	DO (18001) NEXT
	DO (10) NEXT
	PLEASE STOP
(82)	DO RESUME '∀"'#255~"'∀#93¢.12'~'#0¢#255'"'~#1"¢#1'~#3
	PLEASE STOP

	PLEASE INPUT NEXT BYTE INTO .1
	PLEASE USE (100) FOR INITIALIZATION ENTRY POINT
	PLEASE USE (101) FOR MAIN ENTRY POINT
	PLEASE SELECT (20100) AND (20101) FOR PUKE BINARY INPUT
	PLEASE SELECT (21100) AND (21101) FOR C-INTERCAL BINARY INPUT
(100)	DO (20100) NEXT
(110)	DO NOT (21100) NEXT
	DO RESUME #1
	PLEASE STOP
(101)	DO (20101) NEXT
(111)	DO NOT (21101) NEXT
	DO RESUME #1
	PLEASE STOP

	PLEASE OUTPUT BYTE IN .1
	PLEASE USE (200) FOR INITIALIZATION ENTRY POINT
	PLEASE USE (201) FOR MAIN ENTRY POINT
	PLEASE SELECT (20200) AND (20201) FOR PUKE BINARY INPUT
	PLEASE SELECT (21200) AND (21201) FOR C-INTERCAL BINARY INPUT
(200)	DO (20200) NEXT
(210)	DO NOT (21200) NEXT
	DO RESUME #1
	PLEASE STOP
(201)	DO (20201) NEXT
(211)	DO NOT (21201) NEXT
	DO RESUME #1
	PLEASE STOP

	PLEASE INPUT CODE
(300)	DO (301) NEXT
	PLEASE ITERATE OVER INPUT
(301)	DO FORGET #1
	DO (101) NEXT
	DO (302) NEXT
	DO (304) NEXT
	DO STASH .10 + .11
	DO .10 <- .1
	DO .11 <- #2
	DO (301) NEXT
	PLEASE STOP
(302)	DO (303) NEXT
	DO FORGET #1
	DO (310) NEXT
	PLEASE STOP
(303)	DO RESUME "∀'"#255~.1"~#1'¢#1"~#3
	PLEASE STOP
(304)	DO (305) NEXT
	DO FORGET #1
	DO (310) NEXT
	PLEASE STOP
(305)	DO RESUME '∀"'#255~"'∀#33¢.1'~'#0¢#255'"'~#1"¢#1'~#3
	PLEASE REWIND CODE
(310)	DO FORGET #1
	DO (311) NEXT
	PLEASE STOP
(311)	DO FORGET #1
	DO (312) NEXT
	DO STASH .12 + .13
	DO .12 <- .10
	DO .13 <- #2
	DO RETRIEVE .10 + .11
	DO (311) NEXT
	PLEASE STOP
(312)	DO (313) NEXT
	DO RESUME #2
	PLEASE STOP
(313)	DO RESUME .11
	PLEASE STOP

	PLEASE ADVANCE INSTRUCTION POINTER BY ONE
(401)	DO STASH .10 + .11
	DO .10 <- .12
	DO .11 <- #2
	DO RETRIEVE .12 + .13
	DO (402) NEXT
	DO RESUME #1
	PLEASE STOP
(402)	DO (403) NEXT
	DO GIVE UP
	PLEASE STOP
(403)	DO RESUME .13
	PLEASE STOP

	PLEASE REWIND INSTRUCTION POINTER BY ONE
(501)	DO STASH .12 + .13
	DO .12 <- .10
	DO .13 <- #2
	DO RETRIEVE .10 + .11
	DO (502) NEXT
	DO RESUME #1
	PLEASE STOP
(502)	DO (503) NEXT
	DO GIVE UP
	PLEASE STOP
(503)	DO RESUME .11
	PLEASE STOP

	PLEASE ADVANCE INSTRUCTION POINTER PAST MATCHING U-TURN BACK
	PLEASE ASSUME THE CURRENT INSTRUCTION ON ENTRY IS U-TURN
(601)	DO STASH .1 + .2 + .3 + .601
	DO .601 <- #0
	DO (602) NEXT
	PLEASE STOP
(602)	DO FORGET #1
	DO (401) NEXT
	DO (603) NEXT
	DO (605) NEXT
	PLEASE STOP
(603)	DO (604) NEXT
	DO FORGET #1
	DO .1 <- .601
	DO (1020) NEXT
	DO .601 <- .1
	DO (602) NEXT
	PLEASE STOP
(604)	DO RESUME '∀"'#255~"'∀#91¢.12'~'#0¢#255'"'~#1"¢#1'~#3
	PLEASE STOP
(605)	DO FORGET #1
	DO (606) NEXT
	DO (602) NEXT
	PLEASE STOP
(606)	DO (607) NEXT
	DO FORGET #1
	DO (608) NEXT
	PLEASE STOP
(607)	DO RESUME '∀"'#255~"'∀#93¢.12'~'#0¢#255'"'~#1"¢#1'~#3
	PLEASE STOP
(608)	DO FORGET #1
	DO (609) NEXT
	DO .1 <- .601
	DO .2 <- #1
	DO (1010) NEXT
	DO .601 <- .3
	DO (602) NEXT
	PLEASE STOP
(609)	DO (610) NEXT
	DO FORGET #1
	DO RETRIEVE .1 + .2 + .3 + .601
	DO RESUME #1
	PLEASE STOP
(610)	DO RESUME '∀"'"#65535~.601"~#1'"¢#1'~#3
	PLEASE STOP

	PLEASE REWIND INSTRUCTION POINTER TO MATCHING U-TURN
	PLEASE ASSUME THE CURRENT INSTRUCTION ON ENTRY IS U-TURN BACK
(701)	DO STASH .1 + .2 + .3 + .701
	DO .701 <- #0
	DO (702) NEXT
	PLEASE STOP
(702)	DO FORGET #1
	DO (501) NEXT
	DO (703) NEXT
	DO (705) NEXT
	PLEASE STOP
(703)	DO (704) NEXT
	DO FORGET #1
	DO .1 <- .701
	DO (1020) NEXT
	DO .701 <- .1
	DO (702) NEXT
	PLEASE STOP
(704)	DO RESUME '∀"'#255~"'∀#93¢.12'~'#0¢#255'"'~#1"¢#1'~#3
	PLEASE STOP
(705)	DO FORGET #1
	DO (706) NEXT
	DO (702) NEXT
	PLEASE STOP
(706)	DO (707) NEXT
	DO FORGET #1
	DO (708) NEXT
	PLEASE STOP
(707)	DO RESUME '∀"'#255~"'∀#91¢.12'~'#0¢#255'"'~#1"¢#1'~#3
	PLEASE STOP
(708)	DO FORGET #1
	DO (709) NEXT
	DO .1 <- .701
	DO .2 <- #1
	DO (1010) NEXT
	DO .701 <- .3
	DO (702) NEXT
	PLEASE STOP
(709)	DO (710) NEXT
	DO FORGET #1
	DO RETRIEVE .1 + .2 + .3 + .701
	DO RESUME #1
	PLEASE STOP
(710)	DO RESUME '∀"'"#65535~.701"~#1'"¢#1'~#3
	PLEASE STOP

	PLEASE EXECUTE ANGLE
(11001)	DO STASH .14 + .15
	DO .14 <- .16
	DO .15 <- #2
	DO (11002) NEXT
	DO RETRIEVE .16 + .17
	DO (401) NEXT
	DO RESUME #1
	PLEASE STOP
(11002)	DO (11003) NEXT
	DO .16 <- #0
	DO (401) NEXT
	DO RESUME #2
	PLEASE STOP
(11003)	DO RESUME .17
	PLEASE STOP

	PLEASE EXECUTE RIGHT ANGLE
(12001)	DO STASH .16 + .17
	DO .16 <- .14
	DO .17 <- #2
	DO (12002) NEXT
	DO RETRIEVE .14 + .15
	DO (401) NEXT
	DO RESUME #1
	PLEASE STOP
(12002)	DO (12003) NEXT
	DO .14 <- #0
	DO (401) NEXT
	DO RESUME #2
	PLEASE STOP
(12003)	DO RESUME .15
	PLEASE STOP

	PLEASE EXECUTE INTERSECTION
(13001)	DO STASH .1
	DO .1 <- .16
	DO (1020) NEXT
	DO .16 <- .1~#255
	DO RETRIEVE .1
	DO (401) NEXT
	DO RESUME #1
	PLEASE STOP

	PLEASE EXECUTE WORM
(14001)	DO STASH .1 + .2 + .3
	DO .1 <- .16
	DO .2 <- #255
	DO (1000) NEXT
	DO .16 <- .3~#255
	DO RETRIEVE .1 + .2 + .3
	DO (401) NEXT
	DO RESUME #1
	PLEASE STOP

	PLEASE EXECUTE SPOT
(15001)	DO STASH .1
	DO .1 <- .16
	DO (201) NEXT
	DO RETRIEVE .1
	DO (401) NEXT
	DO RESUME #1
	PLEASE STOP

	PLEASE EXECUTE TAIL
(16001)	DO STASH .1
	DO (101) NEXT
	DO .16 <- .1
	DO RETRIEVE .1
	DO (401) NEXT
	DO RESUME #1
	PLEASE STOP

	PLEASE EXECUTE U-TURN
(17001)	DO (17002) NEXT
	DO (401) NEXT
	DO RESUME #1
	PLEASE STOP
(17002)	DO (17003) NEXT
	DO (601) NEXT
	DO RESUME #2
	PLEASE STOP
(17003)	DO RESUME '∀"'#255~.16'~#1"¢#1'~#3
	PLEASE STOP

	PLEASE EXECUTE U-TURN BACK
(18001)	DO (18002) NEXT
	DO (701) NEXT
	DO RESUME #1
	PLEASE STOP
(18002)	DO (18003) NEXT
	DO (401) NEXT
	DO RESUME #2
	PLEASE STOP
(18003)	DO RESUME '∀"'#255~.16'~#1"¢#1'~#3
	PLEASE STOP

	PLEASE INPUT NEXT BYTE INTO .1 USING PUKE BINARY INPUT EXTENSION
	PLEASE MAINTAIN ,20100 BETWEEN INVOCATIONS
	PLEASE USE (20100) FOR INITIALIZATION ENTRY POINT
	PLEASE USE (20101) FOR MAIN ENTRY POINT
(20100)	DO ,20100 <- #2
	DO RESUME #1
	PLEASE STOP
(20101)	DO STASH .2 + .3 + .20100 + .20101
	DO .20100 <- #1
	DO .20101 <- #0
	DO (20102) NEXT
	PLEASE STOP
(20102)	DO FORGET #1
	DO (20103) NEXT
	DO (20110) NEXT
	PLEASE STOP
(20103)	DO (20104) NEXT
	DO .1 <- .20101
	DO RETRIEVE .2 + .3 + .20100 + .20101
	DO RESUME #2
	PLEASE STOP
(20104)	DO RESUME "∀'"#255~!20100~#255'"~#1'¢#1"~#3
	PLEASE STOP
(20110)	DO FORGET #1
	DO (20111) NEXT
	DO .1 <- ,20100SUB#1
	DO .2 <- #1
	DO (1010) NEXT
	DO ,20100SUB#1 <- .3
	DO .20100 <- !20100¢#0'~'#32767¢#1'
	DO (20102) NEXT
	PLEASE STOP
(20111)	DO (20112) NEXT
	DO FORGET #1
	DO (20120) NEXT
	PLEASE STOP
(20112)	DO RESUME "∀'"#65535~,20100SUB#1"~#1'¢#1"~#3
	PLEASE STOP
(20120)	DO FORGET #1
	DO (20121) NEXT
	DO .1 <- ,20100SUB#2
	DO .2 <- #1
	DO (1010) NEXT
	DO ,20100SUB#2 <- .3
	DO .1 <- .20100
	DO .2 <- .20101
	DO (1000) NEXT
	DO .20100 <- !20100¢#0'~'#32767¢#1'
	DO .20101 <- .3
	DO (20102) NEXT
	PLEASE STOP
(20121)	DO (20122) NEXT
	DO FORGET #1
	DO (20130) NEXT
	PLEASE STOP
(20122)	DO RESUME "∀'"#65535~,20100SUB#2"~#1'¢#1"~#3
	PLEASE STOP
(20130)	DO FORGET #1
	DO WRITE IN ,20100
	DO (20131) NEXT
	DO (20102) NEXT
	PLEASE STOP
(20131)	DO (20132) NEXT
	DO .1 <- .20101
	DO RETRIEVE .2 + .3 + .20100 + .20101
	DO RESUME #2
	PLEASE STOP
(20132)	DO RESUME '∀"'"#65535¢#65535"~"',20100SUB#1'¢',20100SUB#2'"'~#1"¢#1'~#3
	PLEASE STOP

	PLEASE OUTPUT BYTE IN .1 USING PUKE BINARY OUTPUT EXTENSION
	PLEASE USE (20200) FOR INITIALIZATION ENTRY POINT
	PLEASE USE (20201) FOR MAIN ENTRY POINT
(20200)	DO RESUME #1
	PLEASE STOP
(20201)	DO STASH ,8
	DO ,8 <- #8
	DO ,8SUB#1 <- .1~#1
	DO ,8SUB#2 <- !1~#2'¢#0
	DO ,8SUB#3 <- !1~#4'¢!1~#4'
	DO ,8SUB#4 <- #0¢"!1~#8'¢#0"
	DO ,8SUB#5 <- #0¢"!1~#16'¢!1~#16'"
	DO ,8SUB#6 <- !1~#32'¢"!1~#32'¢#0"
	DO ,8SUB#7 <- !1~#64'¢"!1~#64'¢!1~#64'"
	DO ,8SUB#8 <- "!1~#128'¢#0"¢#0
	DO READ OUT ,8
	DO RETRIEVE ,8
	DO RESUME #1
	PLEASE STOP

	PLEASE INPUT NEXT BYTE INTO .1 USING C-INTERCAL BINARY INPUT EXTENSION
	PLEASE MAINTAIN .21100 BETWEEN INVOCATIONS
	PLEASE USE (21100) FOR INITIALIZATION ENTRY POINT
	PLEASE USE (21101) FOR MAIN ENTRY POINT
(21100)	DO .21100 <- #0
	DO RESUME #1
	PLEASE STOP
(21101) DO STASH .2 + .3 + ,21100
	DO ,21100 <- #1
	DO WRITE IN ,21100
	DO (21102) NEXT
	DO (21104) NEXT
	PLEASE STOP
(21102)	DO (21103) NEXT
	DO .1 <- #0
	DO RETRIEVE .2 + .3 + ,21100
	DO RESUME #2
	PLEASE STOP
(21103)	DO RESUME '∀"'#511~"'∀#256¢,21100SUB#1'~'#0¢#511'"'~#1"¢#1'~#3
	PLEASE STOP
(21104)	DO .1 <- ,21100SUB#1
	DO .2 <- .21100
	DO (1000) NEXT
	DO .1 <- .3~#255
	DO .21100 <- .1
	DO RETRIEVE .2 + .3 + ,21100
	DO RESUME #2
	PLEASE STOP

	PLEASE OUTPUT BYTE IN .1 USING C-INTERCAL BINARY OUTPUT EXTENSION
	PLEASE MAINTAIN .21200 BETWEEN INVOCATIONS
	PLEASE USE (21200) FOR INITIALIZATION ENTRY POINT
	PLEASE USE (21201) FOR MAIN ENTRY POINT
(21200)	DO .21200 <- #0
	DO RESUME #1
	PLEASE STOP
(21201)	DO STASH .1 + .2 + .3 + ,21200
	DO ,21200 <- #1
	DO .2 <- '"!1~#1'¢!1~#16'"¢"!1~#4'¢!1~#64'"'¢'"!1~#2'¢!1~#32'"¢"!1~#8'¢!1~#128'"'
	DO .1 <- .21200
	DO .21200 <- .2
	DO (1010) NEXT
	DO ,21200SUB#1 <- .3~#255
	DO READ OUT ,21200
	DO RETRIEVE .1 + .2 + .3 + ,21200
	DO RESUME #1
	PLEASE STOP
