
INSERT INTO meta.configapp(parameter,strvalue) VALUES('ExcelFileIncomeBook','/prj/IncomeBook.xlsx');

DROP ROUTINE IF EXISTS upload.upl_incomebook(IN VARCHAR, IN VARCHAR, INOUT VARCHAR, INOUT int);

-- DROP FUNCTION upload.py_xls_income(character varying) 
CREATE OR REPLACE FUNCTION upload.py_xls_income(xls_path varchar)
RETURNS
TABLE (
    Date date,
    IncomeUsd numeric(15,6),
    ExchangeDate date,
    ExchangeValue numeric(15,6),
    ExchangeRate numeric(15,6)
)
AS
$BODY$
from openpyxl import load_workbook
res = []
wb = load_workbook(xls_path)
sheet = wb.worksheets[0]
for row in sheet.iter_rows(min_row=2):
  Date=row[0].value if row[0].value else None
  IncomeUsd=row[1].value if row[1].value else none
  ExchangeDate=row[2].value if row[2].value else None
  ExchangeValue=row[3].value if row[3].value else None
  ExchangeRate=row[4].value if row[4].value else None
  res.append((Date,IncomeUsd,ExchangeDate,ExchangeValue,ExchangeRate))
return res
$BODY$
LANGUAGE 'plpython3u' STRICT;


-- drop PROCEDURE upload.upl_incomebook()
CREATE OR REPLACE PROCEDURE upload.upl_incomebook(IN par_excelfile VARCHAR DEFAULT NULL, IN par_excelfilecmd VARCHAR DEFAULT NULL, INOUT par_errmessage VARCHAR DEFAULT NULL, INOUT return_code int DEFAULT 0)
AS 
$BODY$

DECLARE
var_SPName VARCHAR(510);
    var_SPParams TEXT;
    var_SPInfo TEXT;
    var_LogID INTEGER;
    var_RowCount INTEGER;
    var_AuditMessage TEXT;
    var_tranc INTEGER;
    var_OverridePrintEnabling NUMERIC(1, 0);
    var_res INTEGER;
    var_OpenRowSet TEXT;
    var_sqlcmd TEXT;
    var_NewVersionCount INTEGER;
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

	var_SPName := '[upload].[upl_incomebook]';

    IF par_ExcelFile IS NULL THEN
        SELECT
            meta.ufn_getconfigvalue('ExcelFileIncomeBook')
            INTO par_ExcelFile;
    END IF;

    IF par_ExcelFileCmd IS NULL THEN
        SELECT
            meta.ufn_getconfigvalue('ExcelFileIncomeBookCmd')
            INTO par_ExcelFileCmd;
    END IF;
    par_ExcelFileCmd := COALESCE(par_ExcelFileCmd,'');
    var_SPParams := '@ExcelFile=' || par_ExcelFile || ', @ExcelFileCmd=' || par_ExcelFileCmd || ';';
    var_AuditMessage := COALESCE(var_SPName || ' ' || var_SPParams,'');
  
    CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);

    BEGIN
        

        TRUNCATE TABLE upload.incomebook;

        IF par_ExcelFile IS NULL THEN
            RAISE 'Error %, severity %, state % was raised. Message: %.', '50000', 16, 1, 'Error: Parameter @ExcelFile must be defined.' USING ERRCODE = '50000';
        END IF;

        IF par_ExcelFileCmd IS NULL THEN
            RAISE 'Error %, severity %, state % was raised. Message: %.', '50000', 16, 1, 'Error: Parameter @ExcelFile must be defined.' USING ERRCODE = '50000';
        END IF;
        
        var_sqlcmd := '
		INSERT INTO upload.IncomeBook (Date, IncomeUsd, ExchangeDate, ExchangeValue, ExchangeRate)
		SELECT Date, IncomeUsd, ExchangeDate, ExchangeValue, ExchangeRate FROM upload.py_xls_income(''' || par_ExcelFile || ''');
		';
        CALL audit.sp_print(var_sqlcmd, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);
        EXECUTE var_sqlcmd;
        get diagnostics var_RowCount = row_count;
        var_AuditMessage := '[upload].[upl_IncomeBook];@RowCount=' || LTRIM(to_char(var_RowCount::DOUBLE PRECISION, '9999999999')) || ' finish';
        CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);
        
        EXCEPTION
            WHEN OTHERS THEN
                error_catch$ERROR_NUMBER := '0';
                error_catch$ERROR_SEVERITY := '0';
                error_catch$ERROR_LINE := '0';
                error_catch$ERROR_PROCEDURE := 'UPL_INCOMEBOOK';
                GET STACKED DIAGNOSTICS error_catch$ERROR_STATE = RETURNED_SQLSTATE,
                    error_catch$ERROR_MESSAGE = MESSAGE_TEXT;
                SELECT
                    error_catch$ERROR_MESSAGE
                    INTO par_ErrMessage;

                var_AuditMessage := '[upload].[upl_IncomeBook]; error=''' || par_ErrMessage || '''';
                CALL audit.sp_print(var_AuditMessage, 2, return_code => sp_print$ReturnCode);
                return_code := - 1;
                RETURN;
    END;

END;
$BODY$
LANGUAGE plpgsql;
