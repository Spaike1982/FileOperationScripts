------------------------------------------------------------------
-- PARAMETRE
------------------------------------------------------------------
DECLARE @StartTime DATETIME = '2026-06-24 17:00'
DECLARE @EndTime   DATETIME = '2026-06-24 19:00'
DECLARE @ExportHours INT = 1

DECLARE @CurrentStart DATETIME = @StartTime
DECLARE @CurrentEnd   DATETIME

------------------------------------------------------------------
-- LOOP gjennom hele perioden (1 time per gang)
------------------------------------------------------------------
WHILE (@CurrentStart < @EndTime)
BEGIN
    SET @CurrentEnd = DATEADD(HOUR, @ExportHours, @CurrentStart)

    IF (@CurrentEnd > @EndTime)
        SET @CurrentEnd = @EndTime

    ------------------------------------------------------------------
    -- Skip hvis allerede eksportert
    ------------------------------------------------------------------
    IF NOT EXISTS (
        SELECT 1
        FROM VianodeCustomDB.dbo.AvevaExportLog L
        WHERE L.ExportType = 'AvevaHistorianDataToCsv'
          AND L.StartTime <= @CurrentStart
          AND L.EndTime   >= @CurrentEnd
    )
    BEGIN
        PRINT CONCAT('Eksporterer: ', @CurrentStart, ' -> ', @CurrentEnd)

        ------------------------------------------------------------------
        -- Klargjør staging
        ------------------------------------------------------------------
        TRUNCATE TABLE VianodeCustomDB.dbo.ExportData

        ------------------------------------------------------------------
        -- Lag tag-liste (½50 tags per batch)
        ------------------------------------------------------------------
        IF OBJECT_ID('tempdb..#Tags') IS NOT NULL DROP TABLE #Tags

        SELECT 
            HistorianTagName,
            ROW_NUMBER() OVER (ORDER BY HistorianTagName) AS rn
        INTO #Tags
        FROM VianodeCustomDB.dbo.TagsForAvevaPI

        DECLARE @BatchSize INT = 50
        DECLARE @MaxRow INT = (SELECT MAX(rn) FROM #Tags)
        DECLARE @i INT = 1

        ------------------------------------------------------------------
        -- Hent data i batcher (HIGH PERFORMANCE)
        ------------------------------------------------------------------
        WHILE @i <= @MaxRow
        BEGIN
            DECLARE @TagList NVARCHAR(MAX)

            SELECT @TagList =
                STRING_AGG(
                    CAST(QUOTENAME(HistorianTagName, '''') AS NVARCHAR(MAX)),
                    ','
                )
            FROM #Tags
            WHERE rn BETWEEN @i AND (@i + @BatchSize - 1)

            IF @TagList IS NOT NULL
            BEGIN
                DECLARE @SQL NVARCHAR(MAX)

                SET @SQL = '
                INSERT INTO VianodeCustomDB.dbo.ExportData(DateTime, vValue, TagName)
                SELECT 
                    DateTime,
                    TRY_CAST(vValue AS FLOAT),
                    TagName
                FROM Runtime.dbo.History
                WHERE DateTime >= ''' + CONVERT(VARCHAR(23), @CurrentStart, 121) + '''
                  AND DateTime <  ''' + CONVERT(VARCHAR(23), @CurrentEnd, 121) + '''
                  AND wwRetrievalMode = ''DELTA''
                  AND TagName IN (' + @TagList + ')
                '

                EXEC(@SQL)
            END

            SET @i = @i + @BatchSize
        END

        ------------------------------------------------------------------
        -- Eksporter til CSV
        ------------------------------------------------------------------
        DECLARE @FileName VARCHAR(8000)

        SET @FileName = CONCAT(
            'D:\HistorianCSVExport\ExportData_',
            FORMAT(@CurrentStart, 'yyyyMMddHHmmss'),
            '_',
            FORMAT(@CurrentEnd, 'yyyyMMddHHmmss'),
            '.csv'
        )

        DECLARE @BCPCommand VARCHAR(8000)

        SET @BCPCommand =
        'bcp "SELECT DateTime, vValue, TagName FROM VianodeCustomDB.dbo.ExportData" queryout "'
        + @FileName + '" -c -T -t, -S localhost'

        PRINT @BCPCommand
        EXEC master..xp_cmdshell @BCPCommand

        ------------------------------------------------------------------
        -- Logg
        ------------------------------------------------------------------
        INSERT INTO VianodeCustomDB.dbo.AvevaExportLog (ExportType, StartTime, EndTime)
        VALUES ('AvevaHistorianDataToCsv', @CurrentStart, @CurrentEnd)

        PRINT 'Ferdig time ✅'
    END
    ELSE
    BEGIN
        PRINT CONCAT('Hopper over: ', @CurrentStart, ' -> ', @CurrentEnd)
    END

    ------------------------------------------------------------------
    -- Neste time
    ------------------------------------------------------------------
    SET @CurrentStart = @CurrentEnd
END

PRINT 'ALLE FERDIG ✅'
