IF OBJECT_ID('cmsprops.cpFullInstanceProperties') IS NOT NULL
	EXEC('DROP VIEW cmsprops.cpFullInstanceProperties');
GO

CREATE VIEW
	[cmsprops].[cpFullInstanceProperties]
AS
	SELECT
		I.serverId
		,I.connectionName
		,I.displayName
		,CP.propName
		,IP.propValue
	FROM
		cmsprops.cpInstances I
		CROSS JOIN
		cmsprops.CMSProperties CP
		LEFT JOIN
		cmsprops.cpInstanceProperties IP
			ON IP.server_id = I.serverId
			AND IP.propName = CP.propName


GO


