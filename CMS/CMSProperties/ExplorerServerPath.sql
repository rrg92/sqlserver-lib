
WITH ServersParents AS
(
	SELECT
		S.server_id
	    ,S.server_group_id as parentGroup
		,CONVERT(varchar(max),S.name) as ServerPath
		,CONVERT(bigint,1) as HierarchyLevel
	FROM
		msdb..sysmanagement_shared_registered_servers S
		JOIN
		msdb..sysmanagement_shared_server_groups SG
			ON SG.server_group_id = S.server_group_id

	UNION ALL

	SELECT
		SP.server_id
		,SG.parent_id
		,CONVERT(varchar(max),SG.name+'/'+SP.ServerPath) as ServerPath
		,SP.HierarchyLevel+1 as HierarchyLevel
	FROM
		ServersParents SP
		INNER JOIN
		msdb..sysmanagement_shared_server_groups SG
			ON SG.server_group_id = SP.parentGroup
	WHERE
		SG.parent_id IS NOT NULL
)
SELECT
	S.server_id
	,S.ServerPath
FROM
	(
		SELECT
			*
			,ROW_NUMBER() OVER(PARTITION BY SP.server_id ORDER BY SP.HierarchyLevel DESC) Lastency
		FROM
			ServersParents SP
	) S
WHERE
	S.Lastency = 1