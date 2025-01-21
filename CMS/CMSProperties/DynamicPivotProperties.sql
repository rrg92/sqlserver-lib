DECLARE
	@PropNames varchar(200)
	,@tsql nvarchar(max)
	,@FilterExpression nvarchar(4000)

IF OBJECT_ID('tempdb..#PropertiesPivoted') IS NOT NULL
	DROP TABLE #PropertiesPivoted;


SELECT
	@PropNames = ISNULL(@PropNames + ',','') + QUOTENAME(P.propName)
FROM
	cmsprops.CMSProperties P

IF @FilterExpression IS NULL
	SET @FilterExpression = '1 = 1';


SET @tsql = N'
	SELECT
		P.*
	FROM
		(
			SELECT
				*
			FROM
				cmsprops.cpFullInstanceProperties FIP
		) F
		PIVOT 
		(
			MAX(F.propValue) FOR F.propName IN ('+@PropNames+')
		) P
	WHERE
		(
			'+REPLACE(@FilterExpression,'"','''')+'
		)
'

EXEC sp_Executesql @tsql;