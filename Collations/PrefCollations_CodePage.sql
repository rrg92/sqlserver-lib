/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 

	# Detalhes 
		Traz um collation de cada Code Page!

*/

SELECT
	CodePage
	,NAME
	,COLLATIONPROPERTY(name,'ComparisonStyle')
FROM
(
	SELECT  
		NAME
		,CodePage
		,ROW_NUMBER() OVER(PARTITION BY CodePage ORDER BY Name)  [Top]
	FROM
	(
		SELECT
			NAME
			,COLLATIONPROPERTY(Name,'CodePage') as CodePage
		FROM
		(
			select 
				NAME
				,PATINDEX('%[_]CP%[_]%',NAME) as CPStart
			from 
				fn_helpcollations() C
			WHERE
				C.name like '%pref%'
		) C
	) CINF
) CL
WHERE
	CL.[Top] = 1

	

