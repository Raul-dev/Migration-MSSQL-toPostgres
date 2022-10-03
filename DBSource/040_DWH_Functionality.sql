CREATE OR REPLACE PROCEDURE dbo.sp_filldimdate(IN par_fromdate TIMESTAMP WITHOUT TIME ZONE DEFAULT NULL, IN par_todate TIMESTAMP WITHOUT TIME ZONE DEFAULT NULL)
AS 
$BODY$
/* EXEC [dbo].[sp_FillDimDate] @FromDate = '20180101', @ToDate = '20251231', @Culture = 'ru-ru', @TableName = '#Result_Test1', @IsOutput = 1 */
/* EXEC [dbo].[sp_FillDimDate] @FromDate = '20180101', @ToDate = '20251231', @Culture = 'ru-ru', @IsOutput = 1 */
/* SET LANGUAGE English --  Russian */

DECLARE
    var_RowCount INTEGER;
    var_Days INTEGER;
BEGIN
    par_fromdate := COALESCE(par_fromdate, '20200101'::DATE);
    par_todate := COALESCE(par_todate, NOW());
    var_Days := DATE_PART('day', par_todate - par_fromdate);
	--RAISE NOTICE '% , %, %', var_Days, par_fromdate, par_todate;
    DROP TABLE IF EXISTS t$newdate;
    CREATE TEMPORARY TABLE t$newdate AS
    SELECT TO_CHAR(datum, 'yyyymmdd')::INT AS DateID, 
        TO_CHAR(datum, 'yyyy-mm-dd')::DATE AS FullDateAlternateKey,
        EXTRACT(DOY FROM datum) AS DayNumberOfYear,
        EXTRACT(DAY FROM datum) AS DayNumberOfMonth,
        datum - DATE_TRUNC('quarter', datum)::DATE + 1 AS DayNumberOfQuarter,
        EXTRACT(MONTH FROM datum) AS MonthNumberOfYear,
        ((3+EXTRACT(MONTH FROM datum)) - EXTRACT(QUARTER FROM datum)*3) MonthNumberOfQuarter,
        EXTRACT(QUARTER FROM datum) AS CalendarQuarter,
        EXTRACT(YEAR FROM datum) AS CalendarYear,
        TO_CHAR(datum, 'D')::VARCHAR AS DayName,
        TO_CHAR(datum, 'TMMonth') AS MonthName,
        (DATE_TRUNC('MONTH', datum) + INTERVAL '1 MONTH - 1 day')::DATE AS LastOfMonth,
        DATE_TRUNC('quarter', datum)::DATE AS FirstOfQuarter,	
        (DATE_TRUNC('quarter', datum) + INTERVAL '3 MONTH - 1 day')::DATE AS LastOfQuarter
    FROM (SELECT par_fromdate::DATE + SEQUENCE.DAY AS datum
        FROM GENERATE_SERIES(0, var_Days) AS SEQUENCE (DAY)
        GROUP BY SEQUENCE.DAY) DQ
    ORDER BY 1;


    INSERT INTO dbo.dimdate (dateid, fulldatealternatekey, daynumberofyear, daynumberofmonth, daynumberofquarter, monthnumberofyear, monthnumberofquarter, calendarquarter, calendaryear, dayname, monthname, lastofmonth, firstofquarter, lastofquarter)
    SELECT
        new.dateid, new.fulldatealternatekey, new.daynumberofyear, new.daynumberofmonth, new.daynumberofquarter, new.monthnumberofyear, new.monthnumberofquarter, new.calendarquarter, new.calendaryear, new.dayname, new.monthname, new.lastofmonth, new.firstofquarter, new.lastofquarter
        FROM t$newdate AS new
        LEFT OUTER JOIN dbo.dimdate AS d
            ON new.dateid = d.dateid
        WHERE d.dateid IS NULL;
    DROP TABLE IF EXISTS t$newdate;
END;
$BODY$
LANGUAGE plpgsql;



create or replace function dbo.text_to_ucs2be(input_in_utf8 text)
  returns bytea
  immutable
  strict
  language sql
as $$
  select decode(string_agg(case
           when code_point < 65536
           then lpad(to_hex(code_point), 4, '0')
         end, ''), 'hex')
  from   regexp_split_to_table(input_in_utf8, '') chr,
         ascii(chr) code_point
$$;

create or replace function dbo.text_to_ucs2le(input_in_utf8 text)
  returns bytea
  immutable
  strict
  language sql
as $$
  select decode(string_agg(case
           when code_point < 65536
           then lpad(to_hex(code_point & 255), 2, '0')
             || lpad(to_hex(code_point >> 8), 2, '0')
         end, ''), 'hex')
  from   regexp_split_to_table(input_in_utf8, '') chr,
         ascii(chr) code_point
$$;


CREATE OR REPLACE PROCEDURE dbo.sp_runbatch(INOUT par_errmessage VARCHAR DEFAULT NULL, INOUT return_code int DEFAULT 0)
AS 
$BODY$
/*
Example:
[dbo].[sp_RunBatch]
TRUNCATE TABLE [audit].[LogProcedures]
SELECT * FROM [audit].[LogProcedures]
SELECT 'ExcelFileIncomeBookCmd',''
INSERT [meta].[ConfigApp] (Parameter, StrValue) VALUES( 'ExcelFileIncomeBook','E:\Work\SQL\IndividualEntrepreneur\IncomeBook.xlsx')
UPDATE [meta].[ConfigApp] SET StrValue = 'E:\Work\SQL\IndividualEntrepreneur\Declaration.xlsm'
WHERE Parameter = 'ExcelFileIncomeBook'
	EXEC [dbo].[sp_RunBatch]
	EXEC [dbo].[sp_RunTransform]
	EXEC [dbo].[sp_FillFactIncome]
*/
DECLARE
    var_SPName VARCHAR(510);
    var_SPParams TEXT;
    var_SPInfo TEXT;
    var_LogID INTEGER;
    var_RowCount INTEGER;
    var_Trancnt INTEGER;
    var_AuditMessage TEXT;
    var_ExecStr TEXT;
    var_OverridePrintEnabling NUMERIC(1, 0);
    var_Res INTEGER;
    var_BatchID INTEGER;
    var_FromDate INTEGER;
    var_ToDate INTEGER;
    var_CreateDate TIMESTAMP WITHOUT TIME ZONE;
    var_StartDate INTEGER;
    var_ID INTEGER;
    var_EndDate INTEGER;
    var_Start TIMESTAMP WITHOUT TIME ZONE;
    var_End TIMESTAMP WITHOUT TIME ZONE;
    error_catch$ERROR_NUMBER TEXT;
    error_catch$ERROR_SEVERITY TEXT;
    error_catch$ERROR_STATE TEXT;
    error_catch$ERROR_LINE TEXT;
    error_catch$ERROR_PROCEDURE TEXT;
    error_catch$ERROR_MESSAGE TEXT;
    sp_auditstart$ReturnCode INTEGER;
    sp_print$ReturnCode INTEGER;
    sp_auditfinish$ReturnCode INTEGER;
    cur_local cursor FOR SELECT * FROM t$tmp2;
    rec_local record;
    var_ErrMessage VARCHAR;
BEGIN

    var_OverridePrintEnabling := 0;
    var_AuditMessage := '[dbo].[sp_RunBatch]; start';
    CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);

    BEGIN

        SELECT
            NOW(), TO_CHAR(NOW(), 'yyyymmdd')::INT
            INTO var_CreateDate, var_StartDate;

        INSERT INTO dbo.dimbatch (dateid, createdate)
        SELECT
            var_StartDate, var_CreateDate;

        TRUNCATE TABLE upload.incomebook;

        CALL upload.upl_incomebook(par_ErrMessage => par_ErrMessage, return_code => var_Res);

        IF var_Res != 0 THEN
            RAISE 'Error %, severity %, state % was raised. Message: %. Argument: %', '50000', 16, 1, 'Error: [%]', par_ErrMessage USING ERRCODE = '50000';
        END IF;
        SELECT
            MIN(dateid), MAX(dateid)
            INTO var_FromDate, var_ToDate
            FROM upload.incomebook AS i
            INNER JOIN dbo.dimdate AS d
                ON i.date = d.fulldatealternatekey;

        IF EXISTS (SELECT
            *
            FROM dbo.dimdate AS d
            LEFT OUTER JOIN upload.incomebook AS i
                ON i.date = d.fulldatealternatekey
            WHERE i.date IS NULL AND (dateid >= var_FromDate OR dateid <= var_ToDate)) THEN
            TRUNCATE TABLE upload.currencyperiod;
            TRUNCATE TABLE upload.cbrusdrate;
            SELECT
                MIN(dateid), MAX(dateid)
                INTO var_FromDate, var_ToDate
                FROM upload.incomebook AS i
                INNER JOIN dbo.dimdate AS d
                    ON i.date = d.fulldatealternatekey;
            SELECT
                MAX(batchid)
                INTO var_BatchID
                FROM dbo.dimbatch;
			DROP TABLE IF EXISTS t$tmp1;
            CREATE TEMPORARY TABLE t$tmp1
            AS
            SELECT
                d.dateid, fulldatealternatekey, lead(d.dateid, 1, 0) OVER (ORDER BY d.dateid) AS idlead, lead(d.fulldatealternatekey) OVER (ORDER BY d.dateid) AS dlead, lag(d.fulldatealternatekey) OVER (ORDER BY d.dateid) AS dlag, aws_sqlserver_ext.datediff('day', d.fulldatealternatekey::TIMESTAMP, lead(d.fulldatealternatekey) OVER (ORDER BY d.dateid)::TIMESTAMP) AS ddiff
                FROM dbo.dimdate AS d
                LEFT OUTER JOIN dbo.dimexchrateusd AS i
                    ON i.dateid = d.dateid
                WHERE i.dateid IS NULL AND (d.dateid >= var_FromDate AND d.dateid <= var_ToDate);

        DROP TABLE IF EXISTS t$tmp2;
        CREATE TEMPORARY TABLE t$tmp2
        AS
        SELECT
    			r.ID,
    			s.FullDateAlternateKey AS StartDate,
    			e.FullDateAlternateKey + (1 * interval '1 month') AS EndDate
    		FROM (		
    		SELECT sr.ID,
    				(CAST(sr.DateID / 100 AS int) * 100 + 1) AS StartDate,
    				(CAST(ed.DateID / 100 AS int) * 100 + 1) AS EndDate
    			FROM (
    				SELECT ROW_NUMBER() OVER (ORDER BY DateID) AS ID,
    				    CASE WHEN dLag is Null THEN DateID
    					ELSE (
    						CASE WHEN (dDiff<> 1 OR dDiff IS NULL) THEN idLead
    						ELSE NULL
    						END
    					)
    					END AS DateID
    			FROM t$tmp1  
    			WHERE dLag is Null or (dDiff<> 1 AND NOT dDiff IS NULL)
    			) sr INNER JOIN (
    				SELECT ROW_NUMBER() OVER (ORDER BY DateID) AS ID, DateID
    				FROM t$tmp1  
    				WHERE (dDiff<> 1 OR dDiff IS NULL) 
    				) ed ON sr.ID = ed.ID
    			) r INNER JOIN dbo.DimDate s ON s.DateID = r.StartDate
    			INNER JOIN dbo.DimDate e ON e.DateID = r.EndDate
    		ORDER BY ID;
			

	OPEN cur_local; 
   LOOP
      fetch cur_local into rec_local;
      exit when not found;

      RAISE NOTICE '%', rec_local;
        INSERT INTO upload.currencyperiod (batchid, dateid_start, dateid_end, createdate)
                SELECT
                    var_BatchID, CAST (aws_sqlserver_ext.conv_datetime_to_string('VARCHAR(25)', 'DATETIME', rec_local.StartDate, 112) AS INTEGER), CAST (aws_sqlserver_ext.conv_datetime_to_string('VARCHAR(25)', 'DATETIME', rec_local.EndDate, 112) AS INTEGER), var_CreateDate;
                CALL upload.upl_cbrusdrate(par_FromDate := rec_local.StartDate, par_ToDate := rec_local.EndDate, par_ErrMessage => par_ErrMessage, return_code => var_Res);

        IF var_Res != 0 THEN
                    /*
                    [7774 - Severity CRITICAL - AWS SCT can't convert arithmetic operations with mixed types of operands. Revise your code to use cast operands to the expected type, and try again.]
                    CLOSE PeriodsTable
                    */
                    
                    RAISE 'Error %, severity %, state % was raised. Message: %. Argument: %', '50000', 16, 1, 'Error: [%]', par_ErrMessage USING ERRCODE = '50000';
                END IF;
   END LOOP;
  
   -- close the cursor
   CLOSE cur_local;
          
        END IF;

        var_AuditMessage := '[dbo].[sp_RunBatch]; finish';
        CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);
        --CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);
        EXCEPTION
            WHEN OTHERS THEN
                error_catch$ERROR_NUMBER := '0';
                error_catch$ERROR_SEVERITY := '0';
                error_catch$ERROR_LINE := '0';
                error_catch$ERROR_PROCEDURE := 'SP_RUNBATCH';
                GET STACKED DIAGNOSTICS error_catch$ERROR_STATE = RETURNED_SQLSTATE,
                    error_catch$ERROR_MESSAGE = MESSAGE_TEXT;
            SELECT
                error_catch$ERROR_MESSAGE
                INTO par_ErrMessage;


            var_AuditMessage := '[dbo].[sp_RunBatch]; error=''' || par_ErrMessage || '''';
            CALL audit.sp_print(var_AuditMessage, 2, return_code => sp_print$ReturnCode);
            return_code := - 1;
            RETURN;
    END;

END;
$BODY$
LANGUAGE plpgsql;



CREATE OR REPLACE PROCEDURE dbo.sp_runtransform(INOUT par_errmessage VARCHAR DEFAULT NULL, INOUT return_code int DEFAULT 0)
AS 
$BODY$

DECLARE
    var_SPName VARCHAR(510);
    var_SPParams TEXT;
    var_SPInfo TEXT;
    var_LogID INTEGER;
    var_RowCount INTEGER;
    var_Trancnt INTEGER;
    var_AuditMessage TEXT;
    var_ExecStr TEXT;
    var_OverridePrintEnabling NUMERIC(1, 0);
    var_Res INTEGER;
    var_BatchID INTEGER;
    var_FromDate INTEGER;
    var_ToDate INTEGER;
    var_CreateDate TIMESTAMP WITHOUT TIME ZONE;
    var_StartDate INTEGER;
    error_catch$ERROR_NUMBER TEXT;
    error_catch$ERROR_SEVERITY TEXT;
    error_catch$ERROR_STATE TEXT;
    error_catch$ERROR_LINE TEXT;
    error_catch$ERROR_PROCEDURE TEXT;
    error_catch$ERROR_MESSAGE TEXT;
    sp_auditstart$ReturnCode INTEGER;
    sp_print$ReturnCode INTEGER;
    sp_auditfinish$ReturnCode INTEGER;
BEGIN

    var_OverridePrintEnabling := 0;
    var_AuditMessage := '[dbo].[sp_RunTransform]; start';
    CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);


        SELECT
            NOW(), TO_CHAR(NOW(), 'yyyymmdd')::INT
            INTO var_CreateDate, var_StartDate;            
        SELECT
            MAX(batchid)
            INTO var_BatchID
            FROM dbo.dimbatch;
BEGIN
        IF EXISTS (SELECT
            *
            FROM upload.cbrusdrate) THEN
            
			INSERT INTO dbo.dimexchrateusd (DateID, BatchID, ExchangeRates, CreateDate, IsCopy)
            SELECT dd.DateID, der.BatchID, der.ExchangeRates, der.CreateDate, (CASE WHEN dd.FullDateAlternateKey = der.Date THEN false ELSE true END) AS IsCopy
                FROM dbo.DimDate dd  
                INNER JOIN upload.CurrencyPeriod c ON dd.DateID >= c.DateID_Start AND  dd.DateID < c.DateID_End
                LEFT JOIN
                    (SELECT Date, var_BatchID as BatchID, ExchangeRates, var_CreateDate CreateDate, LEAD(Date) OVER(ORDER BY Date) NextDate  
                    , 1 AS IsCoppy
                        FROM upload.CbrUsdRate 
                    ) der ON  dd.FullDateAlternateKey BETWEEN der.Date AND COALESCE((der.NextDate - interval '1 day'), der.Date)
            WHERE NOT der.Date IS NULL
            ON CONFLICT (DateID) DO UPDATE SET BatchID = excluded.BatchID, ExchangeRates = excluded.ExchangeRates, CreateDate = excluded.CreateDate, IsCopy = excluded.IsCopy;
			GET DIAGNOSTICS var_RowCount = ROW_COUNT;

            var_AuditMessage := '[dbo].[sp_RunTransform]; Merge DimExchRateUSD @RowCount= ' || LTRIM(to_char(var_RowCount::DOUBLE PRECISION, '9999999999')) || ' ';
            CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);
        END IF;
    
        TRUNCATE TABLE staging.factincomehistory;
         
        INSERT INTO staging.FactIncomeHistory(DateID, BatchID, IncomeUSD, NaturalKey, VersionKey, ExchangeDateID, ExchangeValue, ExchangeRate, LotOrder)
        SELECT 
            d.DateID,
            var_BatchID AS BatchID,
            IncomeUSD,
            CAST(md5(dbo.text_to_ucs2le(
                CAST(d.DateID as varchar) || '|' || ROW_NUMBER() OVER(PARTITION BY d.DateID ORDER BY i.ID  )
                )) AS UUID) AS  NaturalKey,
            CAST(md5(dbo.text_to_ucs2le(
                CAST(d.DateID as varchar) || '|' || ROW_NUMBER() OVER(PARTITION BY d.DateID ORDER BY i.ID  ) || '|' || 
                    CAST(IncomeUSD as varchar(30)) || '|' || 
                    coalesce(cast(d2.DateID as varchar) ,'null')  || '|' ||
                    coalesce(cast(ExchangeValue as varchar(30)) ,'null') || '|' ||
                    coalesce(cast(ExchangeRate as varchar(30)) ,'null') 
                    )) AS UUID) AS  VersionKey,
            d2.DateID AS ExchangeDateID,
            i.ExchangeValue,
        	i.ExchangeRate,
            ROW_NUMBER() OVER(PARTITION BY d.DateID ORDER BY i.ID  ) as LotOrder
        FROM upload.IncomeBook i INNER JOIN dbo.DimDate d ON  CAST(i.Date as date) = d.FullDateAlternateKey
            LEFT JOIN dbo.DimDate d2 ON  CAST(i.ExchangeDate as date) = d2.FullDateAlternateKey;
        GET DIAGNOSTICS var_RowCount = ROW_COUNT;
        var_AuditMessage := '[dbo].[sp_RunTransform]; Insert staging.FactIncomeHistory @RowCount= ' || LTRIM(to_char(var_RowCount::DOUBLE PRECISION, '9999999999')) || ' ';
        CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);

        SELECT
            MIN(dateid), MAX(dateid)
            INTO var_FromDate, var_ToDate
            FROM staging.factincomehistory;
        /* Fix deleted */
        INSERT INTO staging.factincomehistory (id, dateid, batchid, incomeusd, naturalkey, versionkey, exchangedateid, exchangevalue, exchangerate, endbatchid)
        SELECT
            source.id, source.dateid, source.batchid, source.incomeusd, source.naturalkey, source.versionkey, source.exchangedateid, source.exchangevalue, source.exchangerate, var_BatchID
            FROM dbo.factincomehistory AS source
            WHERE source.endbatchid IS NULL AND NOT EXISTS (SELECT
                1
                FROM staging.factincomehistory AS target
                WHERE source.naturalkey = target.naturalkey) AND (source.dateid >= var_FromDate OR source.dateid <= var_ToDate);
        GET DIAGNOSTICS var_RowCount = ROW_COUNT;

        DELETE FROM staging.FactIncomeHistory as target
        USING dbo.FactIncomeHistory as source
        WHERE source.NaturalKey = target.NaturalKey AND source.VersionKey = target.VersionKey
            AND source.EndBatchID is NULL AND target.ID is NULL;
            
        INSERT INTO staging.factincomehistory (id, dateid, batchid, incomeusd, naturalkey, versionkey, exchangedateid, exchangevalue, exchangerate, endbatchid)
        SELECT
            source.id, source.dateid, source.batchid, source.incomeusd, source.naturalkey, source.versionkey, source.exchangedateid, source.exchangevalue, source.exchangerate, var_BatchID
            FROM dbo.factincomehistory AS source
            WHERE source.endbatchid IS NULL AND EXISTS (SELECT
                1
                FROM staging.factincomehistory AS target
                WHERE source.naturalkey = target.naturalkey AND target.id IS NULL);
        
		INSERT INTO dbo.FactIncomeHistory ( DateID, BatchID, IncomeUSD, NaturalKey, VersionKey, ExchangeDateID, ExchangeValue, ExchangeRate, LotOrder, EndBatchID, CreateDate)
        SELECT DateID, BatchID, IncomeUSD, NaturalKey, VersionKey, ExchangeDateID, ExchangeValue, ExchangeRate, LotOrder, EndBatchID, NOW() AS CreateDate FROM staging.FactIncomeHistory;
        
		UPDATE dbo.FactIncomeHistory f SET DateID = sf.DateID, BatchID = sf.BatchID, IncomeUSD = sf.IncomeUSD, NaturalKey = sf.NaturalKey, VersionKey = sf.VersionKey, ExchangeDateID = sf.ExchangeDateID, ExchangeValue = sf.ExchangeValue, ExchangeRate = sf.ExchangeRate, LotOrder = sf.LotOrder, EndBatchID = sf.EndBatchID, CreateDate = NOW()
		FROM staging.FactIncomeHistory sf 
		WHERE f.ID = sf.ID;
        GET DIAGNOSTICS var_RowCount = ROW_COUNT;
        var_AuditMessage := '[dbo].[sp_RunTransform]; Update FactIncomeHistory @RowCount= ' || LTRIM(to_char(var_RowCount::DOUBLE PRECISION, '9999999999')) || '; finish';
        CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);
                
        --CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);
        EXCEPTION
            WHEN OTHERS THEN
                error_catch$ERROR_NUMBER := '0';
                error_catch$ERROR_SEVERITY := '0';
                error_catch$ERROR_LINE := '0';
                error_catch$ERROR_PROCEDURE := 'SP_RUNTRANSFORM';
                GET STACKED DIAGNOSTICS error_catch$ERROR_STATE = RETURNED_SQLSTATE,
                    error_catch$ERROR_MESSAGE = MESSAGE_TEXT;
            var_AuditMessage := '[dbo].[sp_RunTransform]; error=''' || par_ErrMessage || '''';
            CALL audit.sp_print(var_AuditMessage, 2, return_code => sp_print$ReturnCode);
        return_code := - 1;
        RETURN;
    END;

END;
$BODY$
LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE dbo.sp_fillfactincome(INOUT par_errmessage VARCHAR DEFAULT NULL, INOUT return_code int DEFAULT 0)
AS 
$BODY$
/*
Example:
[dbo].[sp_FillFactIncome]
*/
DECLARE
    var_SPName VARCHAR(510);
    var_SPParams TEXT;
    var_SPInfo TEXT;
    var_LogID INTEGER;
    var_RowCount INTEGER;
    var_Trancnt INTEGER;
    var_AuditMessage TEXT;
    var_ExecStr TEXT;
    var_OverridePrintEnabling NUMERIC(1, 0);
    var_Res INTEGER;
    var_RowCounttmp INTEGER;
    error_catch$ERROR_NUMBER TEXT;
    error_catch$ERROR_SEVERITY TEXT;
    error_catch$ERROR_STATE TEXT;
    error_catch$ERROR_LINE TEXT;
    error_catch$ERROR_PROCEDURE TEXT;
    error_catch$ERROR_MESSAGE TEXT;
    sp_auditstart$ReturnCode INTEGER;
    sp_print$ReturnCode INTEGER;
    sp_auditfinish$ReturnCode INTEGER;
BEGIN

    var_OverridePrintEnabling := 0;
    var_AuditMessage := '[dbo].[sp_FillFactIncome]; start';
    CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);

    BEGIN
       
        TRUNCATE TABLE dbo.factincome;
        INSERT INTO dbo.factincome (dateid, batchid, incomevalue, createdate)
        SELECT
            fih.dateid, fih.batchid, (fih.incomeusd) * der.exchangerates AS incomevalue, clock_timestamp() AS createdate
            FROM dbo.factincomehistory AS fih
            INNER JOIN dbo.dimexchrateusd AS der
                ON fih.dateid = der.dateid
            WHERE fih.endbatchid IS NULL;
        GET DIAGNOSTICS var_RowCount = ROW_COUNT;
        INSERT INTO dbo.factincome (dateid, batchid, incomevalue, createdate)
        SELECT
            dateid, ex.batchid, ex.incomevalue - base.incomevalue AS incomevalue, clock_timestamp() AS createdate
            FROM (SELECT
                fih.id, fih.dateid, (fih.exchangevalue) * der.exchangerates AS incomevalue, der.exchangerates AS der_exchangerates
                FROM dbo.factincomehistory AS fih
                INNER JOIN dbo.dimexchrateusd AS der
                    ON fih.dateid = der.dateid
                WHERE fih.endbatchid IS NULL) AS base
            INNER JOIN (SELECT
                fih.id, fih.exchangedateid, fih.batchid, (fih.exchangevalue) * der.exchangerates AS incomevalue, der.exchangerates AS der_exchangerates
                FROM dbo.factincomehistory AS fih
                LEFT OUTER JOIN dbo.dimexchrateusd AS der
                    ON fih.exchangedateid = der.dateid
                WHERE fih.endbatchid IS NULL AND NOT fih.exchangevalue IS NULL) AS ex
                ON base.id = ex.id
            WHERE base.incomevalue < ex.incomevalue;
        GET DIAGNOSTICS var_RowCounttmp = ROW_COUNT;
        var_RowCount := var_RowCount + var_RowCounttmp;


        var_AuditMessage := '[dbo].[sp_FillFactIncome] Inserted FactIncome @RowCount= ' || LTRIM(to_char(var_RowCount::DOUBLE PRECISION, '9999999999')) || ' finish';
        CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);
        --CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);
        EXCEPTION
            WHEN OTHERS THEN
                error_catch$ERROR_NUMBER := '0';
                error_catch$ERROR_SEVERITY := '0';
                error_catch$ERROR_LINE := '0';
                error_catch$ERROR_PROCEDURE := 'SP_FILLFACTINCOME';
                GET STACKED DIAGNOSTICS error_catch$ERROR_STATE = RETURNED_SQLSTATE,
                    error_catch$ERROR_MESSAGE = MESSAGE_TEXT;
                SELECT
                    error_catch$ERROR_MESSAGE
                    INTO par_ErrMessage;


                var_AuditMessage := '[dbo].[sp_FillFactIncome]; error=''' || par_ErrMessage || '''';
                CALL audit.sp_print(var_AuditMessage, 2, return_code => sp_print$ReturnCode);
                --CALL audit.sp_auditerror(par_LogID := var_LogID, par_ErrorMessage := par_ErrMessage);

                --CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);
                return_code := - 1;
                RETURN;
    END;

END;
$BODY$
LANGUAGE plpgsql;
