DECLARE @StartTime DateTime = null
DECLARE @EndTime DateTime = null
DECLARE @ExportHours SMALLINT = 1

-- Finn siste eksporttid fra AvevaExportLog
SELECT @EndTime = MIN(L.StartTime)
FROM VianodeCustomDB.dbo.AvevaExportLog L
WHERE ExportType = 'AvevaHistorianDataToCsv'

-- Hvis det ikke finnes noen tidligere eksport, sett start og end til nåværende tid
IF @EndTime IS NULL
      BEGIN
    SET @EndTime = DATEADD(HOUR, 0, GETDATE())
      SET @StartTime = DATEADD(HOUR, -@ExportHours, GETDATE())
      END
ELSE
    SET @StartTime = DATEADD(HOUR, -@ExportHours, @EndTime)

-- Clear and populate export table
TRUNCATE TABLE VianodeCustomDB.dbo.ExportData

select @StartTime, @EndTime

INSERT INTO VianodeCustomDB.dbo.ExportData(DateTime, vValue, TagName)
SELECT DateTime, h.vValue, h.TagName
FROM VianodeCustomDB.dbo.TagsForAvevaPI l
INNER REMOTE JOIN Runtime.dbo.History h
    ON h.TagName = l.TagName
WHERE DateTime >= @StartTime
    AND DateTime < @EndTime
    AND wwRetrievalMode = 'DELTA'
ORDER BY h.Tagname, h.DateTime

-- Export data to CSV
DECLARE @FileName varchar(8000)
SET @FileName = CONCAT('E:\Export\ExportData_', FORMAT(@EndTime, 'yyyyMMddHHmmss'), '.csv')

DECLARE @BCPCommand varchar(8000)
SET @BCPCommand = 'bcp "SELECT DateTime, vValue, TagName FROM VianodeCustomDB.dbo.ExportData" queryout "'
                  + @FileName + '" -c -T -t, -S ' + 'OT-KRS-AGGRAS'

PRINT @BCPCommand
EXEC master..xp_cmdshell @BCPCommand

-- Log the export interval
INSERT INTO VianodeCustomDB.dbo.AvevaExportLog (ExportType, StartTime, EndTime)
VALUES ('AvevaHistorianDataToCsv', @StartTime, @EndTime)
