/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 

	# Detalhes 
		O objetivo aqui acho que era brincar com o conceito de code page.
		Adicionado uma coluna com code page diferente, eu poderia usar novos símbolos...
		Por exemplo, para desenhar algo no resultset...

		Eu acho que ficou incompleto... mas vários insghts aqui!

*/

---------

DECLARE
	@Code varchar(100) = 'cp850'
;

----------
if objecT_id('tempdb..#Collate') is not null
	drop table #collate;

CREATE TABLE
	#Collate(code tinyint,bin AS CONVERT(binary(1),code))
;

;WITH Nums AS
(
	SELECT
		CONVERT(tinyint,0) as n
	UNION ALL
	SELECT
		CONVERT(tinyint,n+1)
	FROM
		Nums
	WHERE
		n < 255
)
INSERT INTO
	#Collate(code)
SELECT
	*
FROM
	Nums
OPTION(MAXRECURSION 256)


-- Add the cp850...
ALTER TABLE #Collate ADD cp850 char(1) COLLATE SQL_Latin1_General_CP850_BIN;
UPDATE #Collate SET cp850 = bin;

DECLARE
	@DrawSymbol TABLE(name varchar(100),symbol varchar(20),code tinyint)

INSERT INTO @DrawSymbol
	VALUES	('cp850','UL',201)
			,('cp850','UR',187)
			,('cp850','V',186)
			,('cp850','H',205)
			,('cp850','BL',200)
			,('cp850','BR',188)
			,('cp850','N',255)
DECLARE
	@_width	 int = 5
	,@_height int = 5

DECLARE
	@output sql_variant
	,@LineBreak char(2) = CHAR(13)+CHAR(10)


DECLARE
	@x int = 0
	,@y int = 0;

;WITH x AS (
	SELECT
		CONVERT(int,0) as Pos

	UNION ALL

	SELECT
		CONVERT(int,Pos+1)
	FROM
		X
	WHERE
		Pos < @_width
), y AS (
	SELECT
		CONVERT(int,0) as Pos

	UNION ALL

	SELECT
		CONVERT(int,Pos+1)
	FROM
		y
	WHERE
		Pos < @_height
), XY  AS (
	SELECT
		*
		,(SELECT cp850 FROM @DrawSymbol DS INNER JOIN #Collate C ON C.code = DS.code  WHERE name = @Code and symbol = xy.Value) as FinalSymbol
	FROM
	(
		SELECT
			X.Pos  as X
			,y.Pos AS Y
			,CASE 
				WHEN X.Pos = 0 AND Y.Pos = 0 THEN 'UL'
				WHEN X.Pos = @_width AND Y.Pos = 0 THEN 'UR'
				WHEN X.Pos = 0 AND Y.Pos = @_height THEN 'BL'
				WHEN X.Pos = @_width AND Y.Pos = @_height THEN 'BR'
				WHEN X.Pos > 0  AND Y.Pos IN (0,@_height) THEN 'H'
				WHEN X.Pos in (0,@_width)  AND Y.Pos > 0 THEN 'V'
				ELSE 'N' 
			END as Value
		FROM
			X
			CROSS JOIN
			Y
	) XY
)
SELECT
	string --+ convert(sql_variant,@LineBreak)
FROM
(
	SELECT
		Y as Line
	FROM
		XY y
	GROUP BY
		Y
) LINES
CROSS APPLY
(
		SELECT	
			FinalSymbol 'text()'
		FROM
			XY x
		WHERE
			X.Y = LINES.Line
		FOR XML PATH('')
) COLUMNS(string)
OPTION(MAXRECURSION 0)