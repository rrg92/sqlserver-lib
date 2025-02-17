/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 

	# Detalhes 
		Rapaz... esse é um script que nunca terminei (ou devo ter feito algum outro).
		O objetivo desse era responder: Meus backups estão sendo feitos no scheduel esperado?

		PRa fazer isso, eu iria ter que consultar a sysschedules, e fazer uns cálculos...
		Nao lembro realmente se desistir no meio do caminhjopela complexidade ou comecei algium outro...

		Mas deixei aqui,  para ou alguém pegar e terminar ou eu mesmo, no futuro, resolver andar com isso!

		A maior diversão desse script é brincar com a msdb..sysschedules, que é onde o sql guarda as info dos schedules dos sql agent
*/


DECLARE @testDate datetime
SET @testDate =CURRENT_TIMESTAMP;

SET DATEFIRST 7; -- Sunday is the first day of month...

DECLARE @WeekDaysMappings TABLE(weekDay smallint, freqIntervalNumber int);
INSERT INTO @WeekDaysMappings VALUES(1,1);
INSERT INTO @WeekDaysMappings VALUES(2,2);
INSERT INTO @WeekDaysMappings VALUES(3,4);
INSERT INTO @WeekDaysMappings VALUES(4,8);
INSERT INTO @WeekDaysMappings VALUES(5,16);
INSERT INTO @WeekDaysMappings VALUES(6,32);
INSERT INTO @WeekDaysMappings VALUES(7,64);

SELECT
	S.name
	,@testDate [testdate]
	,CONVERT(datetime,CONVERT(varchar(10),S.active_start_date)) as StartDate
	,S.freq_type
	,S.freq_interval
	,S.freq_recurrence_factor

	,-- day is elegible?
	(
		SELECT 
			ISNULl((SELECT 'BYDAILY' WHERE DATEDIFF(DAY,convert(VARCHAR(10),S.active_start_date),@testDate)%NULLIF(S.freq_interval,0) = 0),'')
		+
			ISNULL((SELECT 'BYWEEKDAY' FROM @WeekDaysMappings WDM WHERE WDM.weekDay = DATEPART(WEEKDAY,@testDate) AND WDM.freqIntervalNumber & S.freq_interval = WDM.freqIntervalNumber 
						AND DATEDIFF(WEEK,convert(VARCHAR(10),S.active_start_date),@testDate)%NULLIF(S.freq_recurrence_factor,0) = 0
						),'')
	) AS DayEligibleReason
	,DATEDIFF(WEEK,convert(VARCHAR(10),S.active_start_date),@testDate) PasssedTime
	,DATEADD(WEEK,S.freq_recurrence_factor,convert(VARCHAR(10),S.active_start_date))
FROM
	msdb..sysschedules S

/*
	64						1
	0	0	0	0	0	0	0
*/

select dateadd(week,20,'20150824')