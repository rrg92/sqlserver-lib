IF OBJECT_ID('cmsprops.cpInstances') IS NOT NULL
	EXEC('DROP VIEW [cmsprops].[cpInstances]');
GO

CREATE VIEW
	[cmsprops].[cpInstances]
AS
	SELECT
		S.server_id		AS serverId
		,S.name			AS displayName
		,S.server_name	AS connectionName
		,S.description	AS instanceDescription
	FROM
		msdb..sysmanagement_shared_registered_servers S
GO


