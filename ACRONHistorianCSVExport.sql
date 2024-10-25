-- Aktiver xp_cmdshell hvis ikke allerede aktivert
-- EXEC sp_configure 'xp_cmdshell', 1;
-- RECONFIGURE;

--EXECUTE AS USER = '1CJA02GZ004\ACRON'
--REVERT;

use	DevTestDB

-- Input parmaterere:
DECLARE @Starttime varchar(30) = '2010-01-01 00:00:00'
DECLARE @Endtime varchar(30) = '2025-01-01 00:00:00' --'2024-04-15 14:45:00'
DECLARE @TimeInterval INT = 10; -- Minutter med data som skal hentes ut per fil
DECLARE @dir VARCHAR(50) = 'C:\ACRON_Export\CSVFiles'; -- csv filer
DECLARE @Header1 NVARCHAR(20) = '[Data]'
DECLARE @Header2 NVARCHAR(200) = 'Tagname,TimeStamp,Value'

-- Variable
DECLARE @time_start DATETIME;
DECLARE @time_end DATETIME;
DECLARE @var VARCHAR(255);
DECLARE @tempVar VARCHAR(200);
DECLARE @sql NVARCHAR(MAX);
DECLARE @fileName NVARCHAR(255);
DECLARE @cmd VARCHAR(8000);
DECLARE @cnt BIGINT;

-- Hindrer ekstra resultat som spiser opp minnet.
SET NOCOUNT ON; 

set @cnt = 0 -- Fortsette der det stoppet sist

-- Sette rett encoding ANSI før skriving til filer
SET @cmd = 'chcp 1252';
EXEC master..xp_cmdshell @cmd, NO_OUTPUT;

-- Slett headers og data csv filer for å ikke få duplikate headers
SET @cmd = 'DEL "' + @dir + '\headers.csv" ' + @dir + '\data.csv"';
EXEC master..xp_cmdshell @cmd, NO_OUTPUT;

-- Lager en fil med custom headers for hver av datafilene
SET @cmd = 'echo ' + @Header1 + '>"' + @dir + '\headers.csv"';
EXEC master..xp_cmdshell @cmd, NO_OUTPUT;
  
SET @cmd = 'echo ' + @Header2 + '>>"' + @dir + '\headers.csv"';
EXEC master..xp_cmdshell @cmd, NO_OUTPUT;

-- Setter starttid på variabel
SET @time_start = @Starttime;

-- Opprett en cursor basert på tidsintervall, start og sluttid
WHILE @time_start < @Endtime
BEGIN
     
  -- Juster sluttidspunkt for dette intervallet
  SET @time_end = DATEADD(MINUTE, @TimeInterval, @time_start);

  -- Tilbakestill CSV-data
  TRUNCATE TABLE dbo.csvData;

  -- Bygg dynamisk SQL-spørring for å hente data basert på variabel
  SET @sql = N'
  INSERT INTO dbo.csvData
  SELECT
    D.timestamp,
    REPLACE(SUBSTRING(ac.formula, 9, LEN(ac.formula) - 10), ''/'', ''\'') AS variable,
    D.numdata
  FROM openquery (ACRONODBC, 
    ''SELECT timestamp, PVShortname, NumData 
      FROM fastprocess 
      WHERE timestamp > {ts '''''+ CONVERT(VARCHAR, @time_start, 120) +'''''} 
      AND timestamp < {ts ''''' + CONVERT(VARCHAR, @time_end, 120) + '''''}'') D
  JOIN dbo.AcronTags ac ON AC.var = D.PVShortName
	  AND Forexport = 1';

     -- Utfør dynamisk SQL-spørring og lagre resultat i dbo.csvData
  EXEC sp_executesql @sql;

  -- Formater CSV-data
   SET @fileName = 'dataset_' + FORMAT(@cnt, 'D8') + '.csv'; -- Format with leading zeros

  SET @cmd = 'bcp "SELECT variable, timestamp, numdata FROM DevTestDB.dbo.csvData" queryout "' + @dir + '\data.csv" -c -T -t , -S ' + @@servername;
  EXEC master..xp_cmdshell @cmd, NO_OUTPUT;

  SET @cmd = 'TYPE "' + @dir + '\headers.csv" > "' + @dir + '\' + @fileName + '"';
  EXEC master..xp_cmdshell @cmd, NO_OUTPUT;

  SET @cmd = 'TYPE "' + @dir + '\data.csv" >> "' +  @dir + '\' + @fileName + '"';
  EXEC master..xp_cmdshell @cmd, NO_OUTPUT;

  -- Setter tidspunkt for neste intervall
  SET @time_start = @time_end;

  -- teller
  set @cnt = @cnt + 1;

  -- Release memory to prevent crash
  DBCC DROPCLEANBUFFERS;
  --WAITFOR DELAY '00:00:01'

  --BREAK; -- One cycle test
END


