/*#info 

    # Author
        Paul White (https://sqlperformance.com/2016/05/sql-performance/the-internals-of-with-encryption)

    # Descrição 
        Criar as funções no banco master para auxiliar no processo de decrypt de procs.
        O blog acima explica muito bem como funciona esse processo.
        Você deve criar esse script antes de usar o DecryptProcs.sql
*/

USE master 
GO

-- thanks to: 
IF OBJECT_ID(N'dbo.sp_fnEncDecRc4', N'FN') IS NOT NULL
    DROP FUNCTION dbo.sp_fnEncDecRc4;
GO
IF OBJECT_ID(N'dbo.sp_fnInitRc4', N'TF') IS NOT NULL
    DROP FUNCTION dbo.sp_fnInitRc4;
GO
CREATE FUNCTION dbo.sp_fnInitRc4
    (@Pwd varbinary(256))
RETURNS @Box table
    (
        i tinyint PRIMARY KEY, 
        v tinyint NOT NULL
    )
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @Key table
    (
        i tinyint PRIMARY KEY,
        v tinyint NOT NULL
    );
 
    DECLARE
        @Index smallint = 0,
        @PwdLen tinyint = DATALENGTH(@Pwd);
 
    WHILE @Index <= 255
    BEGIN
        INSERT @Key
            (i, v)
        VALUES
            (@Index, CONVERT(tinyint, SUBSTRING(@Pwd, @Index % @PwdLen + 1, 1)));
 
        INSERT @Box (i, v)
        VALUES (@Index, @Index);
 
        SET @Index += 1;
    END;
 
    DECLARE
        @t tinyint = NULL,
        @b smallint = 0;
 
    SET @Index = 0;
 
    WHILE @Index <= 255
    BEGIN
        SELECT @b = (@b + b.v + k.v) % 256
        FROM @Box AS b
        JOIN @Key AS k
            ON k.i = b.i
        WHERE b.i = @Index;
 
        SELECT @t = b.v
        FROM @Box AS b
        WHERE b.i = @Index;
 
        UPDATE b1
        SET b1.v = (SELECT b2.v FROM @Box AS b2 WHERE b2.i = @b)
        FROM @Box AS b1
        WHERE b1.i = @Index;
 
        UPDATE @Box
        SET v = @t
        WHERE i = @b;
 
        SET @Index += 1;
    END;
 
    RETURN;
END;
GO
CREATE FUNCTION dbo.sp_fnEncDecRc4
(
    @Pwd varbinary(256),
    @Text varbinary(MAX)
)
RETURNS varbinary(MAX)
WITH 
    SCHEMABINDING, 
    RETURNS NULL ON NULL INPUT
AS
BEGIN
    DECLARE @Box AS table 
    (
        i tinyint PRIMARY KEY, 
        v tinyint NOT NULL
    );
 
    INSERT @Box
        (i, v)
    SELECT
        FIR.i, FIR.v
    FROM dbo.sp_fnInitRc4(@Pwd) AS FIR;
 
    DECLARE
        @Index integer = 1,
        @i smallint = 0,
        @j smallint = 0,
        @t tinyint = NULL,
        @k smallint = NULL,
        @CipherBy tinyint = NULL,
        @Cipher varbinary(MAX) = 0x;
 
    WHILE @Index <= DATALENGTH(@Text)
    BEGIN
        SET @i = (@i + 1) % 256;
 
        SELECT
            @j = (@j + b.v) % 256,
            @t = b.v
        FROM @Box AS b
        WHERE b.i = @i;
 
        UPDATE b
        SET b.v = (SELECT w.v FROM @Box AS w WHERE w.i = @j)
        FROM @Box AS b
        WHERE b.i = @i;
 
        UPDATE @Box
        SET v = @t
        WHERE i = @j;
 
        SELECT @k = b.v
        FROM @Box AS b
        WHERE b.i = @i;
 
        SELECT @k = (@k + b.v) % 256
        FROM @Box AS b
        WHERE b.i = @j;
 
        SELECT @k = b.v
        FROM @Box AS b
        WHERE b.i = @k;
 
        SELECT
            @CipherBy = CONVERT(tinyint, SUBSTRING(@Text, @Index, 1)) ^ @k,
            @Cipher = @Cipher + CONVERT(binary(1), @CipherBy);
 
        SET @Index += 1;
    END;
 
    RETURN @Cipher;
END;
GO

