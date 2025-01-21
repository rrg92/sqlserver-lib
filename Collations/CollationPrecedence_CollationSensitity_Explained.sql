/*#info 
	# Autor 
		Rodrigo Ribeiro Gomes 

	# Detalhes 
		Uma pequena demo de como funciona o collation precedence!
		eu tenho uma palestra sobre isso, e vou ver de um dia deixar um vídeo gravado dela!
		É um assunto super interessante e acho que pouca gente sabe!

		Repare em como para mesmas operações, as mensagens mudam...
		PArece o mesmo erro , mas não é... O segredo? Tipo dado unicode vs nao unicode se comportam diferente!

		eu não lembro pq deixei comentado em inglês... acho que estava praticando na época...
		Mas creio que é tranquilo para ler... Se voc~e quiser traduzir, ou quiser q eu traduza, é so abrir um PR/issue!
*/
USE tempdb
GO

/*
CREATE TABLE wincollations(c1 char(1) COLLATE Latin1_General_CI_AS,c2 char(1) COLLATE Slovenian_CI_AS)
INSERT INTO wincollations VALUES(CONVERT(binary(1),140),CONVERT(binary(1),140))
CREATE TABLE wincollations_n(c1 nchar(1) COLLATE Latin1_General_CI_AS,c2 nchar(1) COLLATE Slovenian_CI_AS)
INSERT INTO wincollations_n VALUES(CONVERT(binary(1),140),CONVERT(binary(1),140))
*/

-- CONCATENATION OPERATOR:

	-- NON-UNICODE DATA, NO-COLLATION LABEL, CONCATENATION OPERATOR
	SELECT 
		c1+c2
	FROM 
		wincollations
		-- Error: Msg 457
		-- This procedure a error in the add operator and not in the column 1.
		--	Note the error is in the ADD operator.

	-- UNICODE DATA, NO-COLLATION LABEL, CONCATENATION OPERATOR
	SELECT 
		c1+c2
	FROM 
		wincollations_n
	GO
		-- Error: 451
		-- This produce error in SELECT statement, column 1, not in the concatenate operator.
		--	NOTE the error is not in the ADD operator, but in the column 1, the add operator pass!

	-- NON-UNICODE DATA, NO-COLLATION x EXPLICIT, CONCATENATION OPERATOR
	--	If error in the add operator for non-unicode, this query must be raise a error, because the error continue in the add operator!
	SELECT 
		(c1+c2) COLLATE Hungarian_CI_AI
	FROM 
		wincollations

		-- This raise the error 457 again!
		-- This is because the non-unicode concatenation operator is COLLATION SENSITIVE.


	-- UNICODE DATA, NO-COLLATION LABEL X EXPLICIT, CONCATENATION OPERATOR
		-- This must produce a valid resultset with the result as collation of explicit, because in this rules, the NO-COLLATION with EXPLICIT, results EXPLICIT.
	SELECT 
		(c1+c2) COLLATE Hungarian_CI_AI
	FROM 
		wincollations_n

		-- This procedure a valid resultset.
		-- This is because non unicode concatenation operator is COLLATION INSENSITIVE. Your expression procedure a non-collation.


-- THE UNION ALL OPERATOR:

	-- NON-UNICODE DATA, NO-COLLATION LABEL, UNION ALL OPERATOR
	SELECT c1 FROM wincollations UNION ALL SELECT c2 FROM wincollations

		-- This produce: 457. Error at UNION ALL.

	-- UNICODE DATA, NO-COLLATION LABEL, UNION ALL OPERATOR
	SELECT c1 FROM wincollations_n UNION ALL SELECT c2 FROM wincollations_n

		-- This produce: 451. Error at COLUMN 1, not in the UNION ALL operator.


	-- NON-UNICODE DATA, NO-COLLATION LABEL x EXPLICIT, UNION ALL OPERATOR
	SELECT R.colr COLLATE Hungarian_CI_AI FROM (SELECT c1 FROM wincollations UNION ALL SELECT c2 FROM wincollations) R(colr)

		-- This procedure the same error that above. This is because the non-unicode operator.

	-- UNICODE DATA, NO-COLLATION LABEL x EXPLICIT, UNION ALL OPERATOR
	SELECT R.colr COLLATE Hungarian_CI_AI FROM (SELECT c1 FROM wincollations_n UNION ALL SELECT c2 FROM wincollations_n) R(colr)

		-- This not procedure any errors.
		-- This is because the unicode union all operator is COLLATION INSENSITIVE

-- THE ASSINGMENT OPERATOR:

	-- NON-UNICODE DATA, NO-COLLATION LABEL, ASSINGMENT OPERATOR
	DECLARE
		@MyVar varchar(max)
	SELECT @MyVar = c1+c2 FROM  wincollations;

		-- This procedure error 457.
	GO

	-- UNICODE DATA, NO-COLLATION LABEL, ASSINGMENT OPERATOR
	DECLARE
		@MyVar nvarchar(max)
	SELECT @MyVar = c1+c2 FROM  wincollations_n;
	SELECT @MyVar;

		-- This not produce any errors... The collation of result expression is assigned to left.
		-- UNICODE ASSINGMENT OPERATOR is COLLATION INSENSITIVE.
	GO