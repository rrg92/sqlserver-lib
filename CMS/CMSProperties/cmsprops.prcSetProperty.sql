IF OBJECT_ID('cmsprops.prcSetProperty') IS NULL
	EXEC('CREATE PROCEDURE cmsprops.prcSetProperty AS SELECT ''VersãoTemporária. Será Substuída.'' as VersaoTemp ')
GO

ALTER PROCEDURE cmsprops.prcSetProperty
(
	@Prop varchar(300)
	,@Description nvarchar(max)
)
AS
	IF NOT EXISTS( 
		SELECT * FROM cmsprops.CMSProperties P WHERE P.propName = @Prop
	)
	BEGIN
		INSERT INTO cmsprops.CMSProperties(propName,propDescription) VALUES(@Prop,@Description);
		return;
	END

	UPDATE
		cmsprops.CMSProperties
	SET
		propDescription = ISNULL(NULLIF(@Description,''),propDescription)
	WHERE
		propName = @Prop