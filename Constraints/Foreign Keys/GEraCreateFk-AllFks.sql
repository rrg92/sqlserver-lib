/*#info 
	# Autor 
		Rodrigo Ribeiro Gomes 

	# Detalhes 
		Gera o create/drop de todas as fks do banco atual!
		Eu usei muito isso para quando eu queria copiar tabelas entre bancos usando Import/Export wizard...
		como pode ir em qualquer ordem, a ideia era fazer assim:
			1. usa esse script apra gerar o script de todas as fks do banco 
			2. salva o resultado em um excel ou txt (amabas as colunas)
			3. Drop as fks (usando o codigo da coluna Drops)
			4. Importa os dados 
			5. Recria as fks

		MUITO IMPORTANTE só dropar depois de copiar!
*/

;WITH FKs AS
(
SELECT 
	 fk.object_id							fkID
	,fk.name								NomeDaFK
	,FK.parent_object_id
	,object_name(fk.parent_object_id)		ObjetoQReferencia
	,object_name(fk.referenced_object_id)	ObjetoReferenciado
	,fk.is_not_trusted
	,CASE delete_referential_action
		WHEN 0 THEN 'NO ACTION'
		WHEN 1 THEN 'CASCADE'
		WHEN 2 THEN 'SET NULL'
		WHEN 3 THEN 'SET DEFAULT'
	END										OnDelete
	,CASE update_referential_action
		WHEN 0 THEN 'NO ACTION'
		WHEN 1 THEN 'CASCADE'
		WHEN 2 THEN 'SET NULL'
		WHEN 3 THEN 'SET DEFAULT'
	END										OnUpdate
	,CASE is_not_for_replication
		WHEN 1 THEN 'NOT FOR REPLICATION'
		ELSE ''
	 END									NotForReplication
FROM 
	 sys.foreign_keys			fk
)

SELECT
	AddConstraint = 'ALTER TABLE '+ObjetoQReferencia+
			CASE
				WHEN is_not_trusted = 1 THEN ' WITH NOCHECK '
				ELSE ' WITH CHECK '
			END
			+' ADD CONSTRAINT '+NomeDaFK	

	+ ' FOREIGN KEY(' +STUFF(CO.x,1,1,'')+')'+ 

	' REFERENCES '+ObjetoReferenciado+'(' +STUFF(CD.x,1,1,'')+')'+  
	
	' ON DELETE '+OnDelete+' ON UPDATE '+OnUpdate+' '+NotForReplication 
	
	,DropContains = 'ALTER TABLE '+ObjetoQReferencia+' DROP CONSTRAINT '+NomeDaFK+''
FROM
	FKs F
	cross apply
	(
		SELECT
			','+C.name as 'data()'
		FROM
			sys.foreign_key_columns	FCK
			JOIN
			sys.columns C
				ON C.column_id		= FCK.parent_column_id
				and	c.object_id		= FCK.parent_object_id
		WHERE
			FCK.constraint_object_id = F.fkID
		ORDER BY	
			FCK.constraint_object_id
		FOR XML PATH('')
	) CO(x)
	cross apply
	(
		SELECT
			','+C.name as 'data()'
		FROM
			sys.foreign_key_columns	FCK
			JOIN
			sys.columns C
				ON C.column_id		= FCK.referenced_column_id
				and	c.object_id		= FCK.referenced_object_id
		WHERE
			FCK.constraint_object_id = F.fkID
		ORDER BY	
			FCK.constraint_object_id
		FOR XML PATH('')
	) CD(x)
ORDER BY
	ObjetoQReferencia
	
