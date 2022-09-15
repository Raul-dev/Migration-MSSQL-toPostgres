-- SELECT upload.upl_loadxmlfromfile 'http://www.cbr.ru/scripts/XML_dynamic.asp?date_req1=01.01.2020&date_req2=29.05.2020&VAL_NM_RQ=R01235', @xmlString output
--
 CREATE OR REPLACE FUNCTION upload.upl_loadxmlfromfile(p_url text)
 RETURNS text
 LANGUAGE plpython3u
AS $function$
    import requests, json
    try:
        r = requests.request(method='GET', url=p_url, data='', headers=json.loads('{"Content-Type": "application/json"}'))
    except Exception as e:
        return e
    else:
        return r.content.decode('utf-8')
$function$
;

 CREATE OR REPLACE FUNCTION public.py_pgrest(p_url text, p_method text DEFAULT 'GET'::text, p_data text DEFAULT ''::text, p_headers text DEFAULT '{"Content-Type": "application/json"}'::text)
 RETURNS text
 LANGUAGE plpython3u
AS $function$
    import requests, json
    try:
        r = requests.request(method=p_method, url=p_url, data=p_data, headers=json.loads(p_headers))
    except Exception as e:
        return e
    else:
        return r.content
$function$
;


CREATE OR REPLACE PROCEDURE upload.upl_cbrusdrate(IN par_fromdate TIMESTAMP WITHOUT TIME ZONE DEFAULT NULL, IN par_todate TIMESTAMP WITHOUT TIME ZONE DEFAULT NULL, INOUT par_errmessage TEXT DEFAULT NULL, INOUT return_code int DEFAULT 0)
AS 
$BODY$
/*
Example:
EXEC [upload].[upl_CbrUsdRate] '20200101', '20201231'
EXEC [upload].[upl_CbrUsdRate] '20200101', '20200102'
DECLARE @xmlString varchar(max)
EXEC [upload].[upl_LoadXMLFromFile] 'http://www.cbr.ru/scripts/XML_dynamic.asp?date_req1=01.01.2020&date_req2=29.05.2020&VAL_NM_RQ=R01235', @xmlString output
EXEC [audit].[sp_Print] @xmlString
INSERT [meta].[ConfigApp] (Parameter, StrValue) VALUES( 'ExcelFileIncomeBook','E:\Work\SQL\IndividualEntrepreneur\IncomeBook.xlsx')

SELECT * FROM [upload].[CbrUsdRate]
*/
DECLARE
    var_SPName VARCHAR(510);
    var_SPParams TEXT;
    var_SPInfo TEXT;
    var_LogID INTEGER;
    var_RowCount INTEGER;
    var_AuditMessage TEXT;
    var_Trancnt INTEGER;
    var_OverridePrintEnabling NUMERIC(1, 0);
    var_res INTEGER;
    var_OpenRowSet TEXT;
    var_sqlcmd TEXT;
    var_NewVersionCount INTEGER;
    var_xmlString TEXT;
    var_url VARCHAR(255);
    var_h INTEGER;
    var_StartDate TIMESTAMP WITHOUT TIME ZONE;
    var_FinishDate TIMESTAMP WITHOUT TIME ZONE;
    var_RowCounttmp INTEGER;
    var_MaxCount INTEGER;
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
    var_AuditMessage := '[upload].[upl_CbrUsdRate]; start';
    CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);

    BEGIN

        par_FromDate := make_date(date_part('year', par_FromDate)::INTEGER, date_part('month', par_FromDate)::INTEGER, date_part('day', par_FromDate)::INTEGER);

        IF (par_ToDate > clock_timestamp()) THEN
            par_ToDate := make_date(date_part('year', clock_timestamp())::INTEGER, date_part('month', clock_timestamp())::INTEGER, date_part('day', clock_timestamp())::INTEGER);
        ELSE
            par_ToDate := make_date(date_part('year', par_ToDate)::INTEGER, date_part('month', par_ToDate)::INTEGER, date_part('day', par_ToDate)::INTEGER);
        END IF;

        IF (aws_sqlserver_ext.datediff('day', par_FromDate::TIMESTAMP, par_ToDate::TIMESTAMP) < 0) THEN
            RAISE 'Error %, severity %, state % was raised. Message: %.', '50000', 16, 1, 'Error: Parameter @FromDate must be be less than @ToDate.' USING ERRCODE = '50000';
        END IF;
        var_StartDate := par_FromDate;

        IF (aws_sqlserver_ext.datediff('day', par_FromDate::TIMESTAMP, par_ToDate::TIMESTAMP) > 54) THEN
            var_FinishDate := var_StartDate + (55::NUMERIC || ' DAY')::INTERVAL - (1::NUMERIC || ' days')::INTERVAL;
        ELSE
            var_FinishDate := par_ToDate;
        END IF;
       
        var_MaxCount := 0;

        WHILE (var_MaxCount < 45) loop
        
            /* Maximum 5 year */
            SELECT
                'http://www.cbr.ru/scripts/XML_dynamic.asp?date_req1=' || aws_sqlserver_ext.conv_datetime_to_string('CHAR(10)', 'DATETIME', var_StartDate, 104) || '&date_req2=' || aws_sqlserver_ext.conv_datetime_to_string('CHAR(10)', 'DATETIME', var_FinishDate, 104) || '&VAL_NM_RQ=R01235'
                INTO var_url;
               
            CALL audit.sp_print(var_url, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);           
            var_xmlString := NULL;
            SELECT upload.upl_loadxmlfromfile(var_url) INTO var_xmlString;

           SELECT
                t.DocHandle
                FROM aws_sqlserver_ext.sp_xml_preparedocument(var_xmlString)
                    AS t
                INTO var_h;

            INSERT INTO upload.cbrusdrate (date, exchangerates)
            SELECT
                (make_date(CAST (SUBSTR(date, 7, 4) AS INTEGER), CAST (SUBSTR(date, 4, 2) AS INTEGER), CAST (SUBSTR(date, 1, 2) AS INTEGER))) AS date, CAST (REPLACE(value, ',', '.') AS NUMERIC(19, 4)) AS exchangerates
                FROM aws_sqlserver_ext.openxml(var_h::BIGINT), XMLTABLE('//Record'
                    PASSING (SELECT
                        XmlData)
                    COLUMNS date CHAR(10) PATH '@Date',
                    nominal INTEGER PATH './Nominal',
                    value VARCHAR(10) PATH './Value');
            GET DIAGNOSTICS var_RowCounttmp = ROW_COUNT;
            var_RowCount := (COALESCE(var_RowCount, 0) + var_RowCounttmp)::INT;

            SELECT
                var_FinishDate + (1::NUMERIC || ' days')::INTERVAL
                INTO var_StartDate;
            SELECT
                var_MaxCount + 1
                INTO var_MaxCount;
            PERFORM aws_sqlserver_ext.sp_xml_removedocument(var_h::BIGINT);

            IF (aws_sqlserver_ext.datediff('day', var_FinishDate::TIMESTAMP, par_ToDate::TIMESTAMP) <= 0) THEN
                SELECT
                    45
                    INTO var_MaxCount;
            END IF;

            IF (aws_sqlserver_ext.datediff('day', var_StartDate::TIMESTAMP, par_ToDate::TIMESTAMP) > 54) THEN
                var_FinishDate := var_StartDate + (55::NUMERIC || ' DAY')::INTERVAL - (1::NUMERIC || ' days')::INTERVAL;
            ELSE
                var_FinishDate := par_ToDate;
            END IF;
        END LOOP;

        IF var_Trancnt = 0 THEN
            COMMIT;
        END IF;
        var_AuditMessage := '[upload].[upl_CbrUsdRate];@RowCount=' || LTRIM(to_char(COALESCE(var_RowCount, 0)::DOUBLE PRECISION, '9999999999')) || ' finish';
        CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);
        CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);
        EXCEPTION
            WHEN OTHERS THEN
                error_catch$ERROR_NUMBER := '0';
                error_catch$ERROR_SEVERITY := '0';
                error_catch$ERROR_LINE := '0';
                error_catch$ERROR_PROCEDURE := 'UPL_CBRUSDRATE';
                GET STACKED DIAGNOSTICS error_catch$ERROR_STATE = RETURNED_SQLSTATE,
                    error_catch$ERROR_MESSAGE = MESSAGE_TEXT;
                SELECT
                    error_catch$ERROR_MESSAGE
                    INTO par_ErrMessage;

                    var_AuditMessage := '[upload].[upl_CbrUsdRate]; error=''' || par_ErrMessage || '''';
                    CALL audit.sp_print(var_AuditMessage, 2, return_code => sp_print$ReturnCode);

                --CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);
                return_code := - 1;
                RETURN;
    END;
    /*
    
    DROP TABLE IF EXISTS t$auditproc;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
END;
$BODY$
LANGUAGE plpgsql;