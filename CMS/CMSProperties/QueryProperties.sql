-- Esta parte da query irá gerar uma linha para cada membro da hierarquia de um server. Isso nos vai permitir obter todas as descrições da qual
-- um server herda tags!
;WITH ServersParents AS
(
	SELECT
		S.server_id
		,S.server_group_id  parentGroup
		,CONVERT(bigint,1) as Priori
	FROM
		msdb..sysmanagement_shared_registered_servers S

	UNION ALL

	SELECT
		SP.server_id
		,SG.parent_id
		,CONVERT(bigint,SP.Priori+1) as Priori
	FROM
		ServersParents SP
		INNER JOIN
		msdb..sysmanagement_shared_server_groups SG
			ON SG.server_group_id = SP.parentGroup
	WHERE
		SG.parent_id IS NOT NULL
)
SELECT
	 F.server_id
	,F.propName
	,F.propValue
FROM
(
	SELECT
		 S.server_id
		,S.description
		,CP.propName
		,RTRIM(LTRIM(SUBSTRING(S.description,CP.PropPos+1,CP.ExprEnd-CP.PropPos-1))) as propValue
		,ROW_NUMBER() OVER(PARTITION BY S.server_id,CP.PropName ORDER BY S.Priori) as Priority
	FROM
		(
			SELECT
				S.server_id
				,S.description
				,0 as Priori
			FROM
				msdb..sysmanagement_shared_registered_servers S
			UNION ALL
			SELECT
				SP.server_id
				,SG.description
				,SP.Priori
			FROM
				msdb..sysmanagement_shared_server_groups SG
				INNER JOIN
				ServersParents SP
					ON SP.parentGroup = SG.server_group_id
		) S
		CROSS APPLY
		(
			SELECT
				*
				,CHARINDEX(':',S.description,F.ExprtStart) as PropPos
				,CHARINDEX(']',S.description,F.ExprtStart) as ExprEnd
			FROM
				(
					SELECT
						*
						,NULLIF(PATINDEX(CONVERT(varchar(100),'%[[]'+propName+':%'),S.description),0) as ExprtStart
					FROM
						dbo.CMSProperties P		
				) F
			WHERE
				F.ExprtStart IS NOT NULL
		) CP
) F
WHERE
	F.Priority = 1
OPTION(MAXRECURSION 0)