IF OBJECT_ID('cmsprops.prcGetInstance') IS NULL
	EXEC('CREATE PROCEDURE [cmsprops].[prcGetInstance] AS SELECT 1 as StubVersion')
GO


ALTER PROCEDURE 
	[cmsprops].[prcGetInstance](@FilterExpression nvarchar(3000) = NULL)
AS	
	DECLARE
		@PropNames varchar(200)
		,@tsql nvarchar(max)

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

GO


