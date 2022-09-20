
CREATE EXTENSION IF NOT EXISTS plpython3u WITH SCHEMA pg_catalog;
COMMENT ON EXTENSION plpython3u IS 'Python';

CREATE EXTENSION IF NOT EXISTS pg_repack WITH SCHEMA public;
COMMENT ON EXTENSION pg_repack IS 'Reorganize tables in PostgreSQL databases with minimal locks';

CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;
COMMENT ON EXTENSION dblink IS 'connect to other PostgreSQL databases from within a database';

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;
COMMENT ON EXTENSION pg_stat_statements IS 'track execution statistics of all SQL statements executed';

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;
COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';

CREATE EXTENSION IF NOT EXISTS pgstattuple WITH SCHEMA public;
COMMENT ON EXTENSION pgstattuple IS 'show tuple-level statistics';

CREATE EXTENSION IF NOT EXISTS postgres_fdw WITH SCHEMA public;
COMMENT ON EXTENSION postgres_fdw IS 'foreign-data wrapper for remote PostgreSQL servers';

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';
--
-- PostgreSQL database dump
--

-- Dumped from database version 14.5
-- Dumped by pg_dump version 14.4

-- Started on 2022-09-14 21:57:05

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5 (class 2615 OID 16879)
-- Name: aws_sqlserver_ext; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA aws_sqlserver_ext;


ALTER SCHEMA aws_sqlserver_ext OWNER TO postgres;

--
-- TOC entry 12 (class 2615 OID 16878)
-- Name: aws_sqlserver_ext_data; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA aws_sqlserver_ext_data;


ALTER SCHEMA aws_sqlserver_ext_data OWNER TO postgres;

--
-- TOC entry 338 (class 1255 OID 17025)
-- Name: char(integer); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext."char"(x integer) RETURNS character
    LANGUAGE plpgsql
    AS $$
BEGIN
/***************************************************************
EXTENSION PACK function CHAR(x)
***************************************************************/
	if x between 1 and 255 then
		return chr(x);
	else
		return null; 
	end if;	
END;
$$;


ALTER FUNCTION aws_sqlserver_ext."char"(x integer) OWNER TO postgres;

--
-- TOC entry 337 (class 1255 OID 17024)
-- Name: checksum(text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.checksum(_input text) RETURNS integer
    LANGUAGE sql
    AS $$
  SELECT ('x'||SUBSTR(MD5(_input),1,8))::BIT(32)::INTEGER;
$$;


ALTER FUNCTION aws_sqlserver_ext.checksum(_input text) OWNER TO postgres;

--
-- TOC entry 386 (class 1255 OID 17049)
-- Name: conv_date_to_string(text, date, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.conv_date_to_string(p_datatype text, p_dateval date, p_style numeric DEFAULT 20) RETURNS text
    LANGUAGE plpgsql STRICT
    AS $_$
DECLARE
    v_day VARCHAR;
    v_dateval DATE;
    v_style SMALLINT;
    v_month SMALLINT;
    v_resmask VARCHAR;
    v_datatype VARCHAR;
    v_language VARCHAR;
    v_monthname VARCHAR;
    v_resstring VARCHAR;
    v_lengthexpr VARCHAR;
    v_maxlength SMALLINT;
    v_res_length SMALLINT;
    v_err_message VARCHAR;
    v_res_datatype VARCHAR;
    v_lang_metadata_json JSONB;
    VARCHAR_MAX CONSTANT SMALLINT := 8000;
    NVARCHAR_MAX CONSTANT SMALLINT := 4000;
    CONVERSION_LANG CONSTANT VARCHAR := 'English';
    CHARACTER_REGEXP CONSTANT VARCHAR := 'CHAR|NCHAR|CHARACTER|NATIONAL CHARACTER';
    VARCHAR_REGEXP CONSTANT VARCHAR := 'VARCHAR|NVARCHAR|CHARACTER VARYING|NATIONAL CHARACTER VARYING';
    DATATYPE_REGEXP CONSTANT VARCHAR := concat('^\s*(', CHARACTER_REGEXP, '|', VARCHAR_REGEXP, ')\s*$');
    DATATYPE_MASK_REGEXP CONSTANT VARCHAR := concat('^\s*(?:', CHARACTER_REGEXP, '|', VARCHAR_REGEXP, ')\s*\(\s*(\d+|MAX)\s*\)\s*$');
BEGIN
    v_datatype := regexp_replace(upper(trim(p_datatype)), '\s+', ' ', 'gi');
    v_style := floor(p_style)::SMALLINT;

    IF (scale(p_style) > 0) THEN
        RAISE most_specific_type_mismatch;
    ELSIF (NOT ((v_style BETWEEN 0 AND 13) OR
                (v_style BETWEEN 20 AND 25) OR
                (v_style BETWEEN 100 AND 113) OR
                v_style IN (120, 121, 126, 127, 130, 131)))
    THEN
        RAISE invalid_parameter_value;
    ELSIF (v_style IN (8, 24, 108)) THEN
        RAISE invalid_datetime_format;
    END IF;

    IF (v_datatype ~* DATATYPE_MASK_REGEXP) THEN
        v_res_datatype := rtrim(split_part(v_datatype, '(', 1));

        v_maxlength := CASE
                          WHEN substring(v_res_datatype, '^(NCHAR|NATIONAL.*)$') IS NULL
                          THEN VARCHAR_MAX
                          ELSE NVARCHAR_MAX
                       END;

        v_lengthexpr := substring(v_datatype, DATATYPE_MASK_REGEXP);

        IF (v_lengthexpr <> 'MAX' AND char_length(v_lengthexpr) > 4) THEN
            RAISE interval_field_overflow;
        END IF;

        v_res_length := CASE v_lengthexpr
                           WHEN 'MAX' THEN v_maxlength
                           ELSE v_lengthexpr::SMALLINT
                        END;
    ELSIF (v_datatype ~* DATATYPE_REGEXP) THEN
        v_res_datatype := v_datatype;
    ELSE
        RAISE datatype_mismatch;
    END IF;

    v_dateval := CASE
                    WHEN (v_style NOT IN (130, 131)) THEN p_dateval
                    ELSE aws_sqlserver_ext.conv_greg_to_hijri(p_dateval) + 1
                 END;

    v_day := ltrim(to_char(v_dateval, 'DD'), '0');
    v_month := to_char(v_dateval, 'MM')::SMALLINT;

    v_language := CASE
                     WHEN (v_style IN (130, 131)) THEN 'HIJRI'
                     ELSE CONVERSION_LANG
                  END;
    BEGIN
        v_lang_metadata_json := aws_sqlserver_ext.get_lang_metadata_json(v_language);
    EXCEPTION
        WHEN OTHERS THEN
        RAISE invalid_character_value_for_cast;
    END;

    v_monthname := (v_lang_metadata_json -> 'months_shortnames') ->> v_month - 1;

    v_resmask := CASE
                    WHEN (v_style IN (1, 22)) THEN 'MM/DD/YY'
                    WHEN (v_style = 101) THEN 'MM/DD/YYYY'
                    WHEN (v_style = 2) THEN 'YY.MM.DD'
                    WHEN (v_style = 102) THEN 'YYYY.MM.DD'
                    WHEN (v_style = 3) THEN 'DD/MM/YY'
                    WHEN (v_style = 103) THEN 'DD/MM/YYYY'
                    WHEN (v_style = 4) THEN 'DD.MM.YY'
                    WHEN (v_style = 104) THEN 'DD.MM.YYYY'
                    WHEN (v_style = 5) THEN 'DD-MM-YY'
                    WHEN (v_style = 105) THEN 'DD-MM-YYYY'
                    WHEN (v_style = 6) THEN 'DD $mnme$ YY'
                    WHEN (v_style IN (13, 106, 113)) THEN 'DD $mnme$ YYYY'
                    WHEN (v_style = 7) THEN '$mnme$ DD, YY'
                    WHEN (v_style = 107) THEN '$mnme$ DD, YYYY'
                    WHEN (v_style = 10) THEN 'MM-DD-YY'
                    WHEN (v_style = 110) THEN 'MM-DD-YYYY'
                    WHEN (v_style = 11) THEN 'YY/MM/DD'
                    WHEN (v_style = 111) THEN 'YYYY/MM/DD'
                    WHEN (v_style = 12) THEN 'YYMMDD'
                    WHEN (v_style = 112) THEN 'YYYYMMDD'
                    WHEN (v_style IN (20, 21, 23, 25, 120, 121, 126, 127)) THEN 'YYYY-MM-DD'
                    WHEN (v_style = 130) THEN 'DD $mnme$ YYYY'
                    WHEN (v_style = 131) THEN format('%s/MM/YYYY', lpad(v_day, 2, ' '))
                    WHEN (v_style IN (0, 9, 100, 109)) THEN format('$mnme$ %s YYYY', lpad(v_day, 2, ' '))
                 END;

    v_resstring := to_char(v_dateval, v_resmask);
    v_resstring := replace(v_resstring, '$mnme$', v_monthname);

    v_resstring := substring(v_resstring, 1, coalesce(v_res_length, char_length(v_resstring)));

    RETURN CASE
              WHEN substring(v_res_datatype, concat('^(', CHARACTER_REGEXP, ')$')) IS NOT NULL
              THEN rpad(v_resstring, coalesce(v_res_length, 30), ' ')
              ELSE v_resstring
           END;
EXCEPTION
    WHEN most_specific_type_mismatch THEN
        RAISE USING MESSAGE := 'Argument data type NUMERIC is invalid for argument 3 of convert function.',
                    DETAIL := 'Use of incorrect "style" parameter value during conversion process.',
                    HINT := 'Change "style" parameter to the proper value and try again.';

    WHEN invalid_parameter_value THEN
        RAISE USING MESSAGE := format('%s is not a valid style number when converting from DATE to a character string.', v_style),
                    DETAIL := 'Use of incorrect "style" parameter value during conversion process.',
                    HINT := 'Change "style" parameter to the proper value and try again.';

    WHEN invalid_datetime_format THEN
        RAISE USING MESSAGE := format('Error converting data type DATE to %s.', trim(p_datatype)),
                    DETAIL := 'Incorrect using of pair of input parameters values during conversion process.',
                    HINT := 'Check the input parameters values, correct them if needed, and try again.';

   WHEN interval_field_overflow THEN
       RAISE USING MESSAGE := format('The size (%s) given to the convert specification ''%s'' exceeds the maximum allowed for any data type (%s).',
                                     v_lengthexpr,
                                     lower(v_res_datatype),
                                     v_maxlength),
                   DETAIL := 'Use of incorrect size value of data type parameter during conversion process.',
                   HINT := 'Change size component of data type parameter to the allowable value and try again.';

    WHEN datatype_mismatch THEN
        RAISE USING MESSAGE := concat('Data type should be one of these values: ''CHAR(n|MAX)'', ''NCHAR(n|MAX)'', ''VARCHAR(n|MAX)'', ''NVARCHAR(n|MAX)'', ',
                                      '''CHARACTER VARYING(n|MAX)'', ''NATIONAL CHARACTER VARYING(n|MAX)''.'),
                    DETAIL := 'Use of incorrect "datatype" parameter value during conversion process.',
                    HINT := 'Change "datatype" parameter to the proper value and try again.';

    WHEN invalid_character_value_for_cast THEN
        RAISE USING MESSAGE := format('Invalid CONVERSION_LANG constant value - ''%s''. Allowed values are: ''English'', ''Deutsch'', etc.',
                                      CONVERSION_LANG),
                    DETAIL := 'Compiled incorrect CONVERSION_LANG constant value in function''s body.',
                    HINT := 'Correct CONVERSION_LANG constant value in function''s body, recompile it and try again.';

    WHEN invalid_text_representation THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
        v_err_message := substring(lower(v_err_message), 'integer\:\s\"(.*)\"');

        RAISE USING MESSAGE := format('Error while trying to convert "%s" value to SMALLINT (or INTEGER) data type.',
                                      v_err_message),
                    DETAIL := 'Supplied value contains illegal characters.',
                    HINT := 'Correct supplied value, remove all illegal characters.';
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.conv_date_to_string(p_datatype text, p_dateval date, p_style numeric) OWNER TO postgres;

--
-- TOC entry 3865 (class 0 OID 0)
-- Dependencies: 386
-- Name: FUNCTION conv_date_to_string(p_datatype text, p_dateval date, p_style numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.conv_date_to_string(p_datatype text, p_dateval date, p_style numeric) IS 'This function converts the DATE value into a character string, according to specified style (conversion mask).';


--
-- TOC entry 387 (class 1255 OID 17051)
-- Name: conv_datetime_to_string(text, text, timestamp without time zone, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.conv_datetime_to_string(p_datatype text, p_src_datatype text, p_datetimeval timestamp without time zone, p_style numeric DEFAULT '-1'::integer) RETURNS text
    LANGUAGE plpgsql STRICT
    AS $_$
DECLARE
    v_day VARCHAR;
    v_hour VARCHAR;
    v_month SMALLINT;
    v_style SMALLINT;
    v_scale SMALLINT;
    v_resmask VARCHAR;
    v_language VARCHAR;
    v_datatype VARCHAR;
    v_fseconds VARCHAR;
    v_fractsep VARCHAR;
    v_monthname VARCHAR;
    v_resstring VARCHAR;
    v_lengthexpr VARCHAR;
    v_maxlength SMALLINT;
    v_res_length SMALLINT;
    v_err_message VARCHAR;
    v_src_datatype VARCHAR;
    v_res_datatype VARCHAR;
    v_lang_metadata_json JSONB;
    VARCHAR_MAX CONSTANT SMALLINT := 8000;
    NVARCHAR_MAX CONSTANT SMALLINT := 4000;
    CONVERSION_LANG CONSTANT VARCHAR := 'English';
    CHARACTER_REGEXP CONSTANT VARCHAR := 'CHAR|NCHAR|CHARACTER|NATIONAL CHARACTER';
    VARCHAR_REGEXP CONSTANT VARCHAR := 'VARCHAR|NVARCHAR|CHARACTER VARYING|NATIONAL CHARACTER VARYING';
    DATATYPE_REGEXP CONSTANT VARCHAR := concat('^\s*(', CHARACTER_REGEXP, '|', VARCHAR_REGEXP, ')\s*$');
    DATATYPE_MASK_REGEXP CONSTANT VARCHAR := concat('^\s*(?:', CHARACTER_REGEXP, '|', VARCHAR_REGEXP, ')\s*\(\s*(\d+|MAX)\s*\)\s*$');
    SRCDATATYPE_MASK_REGEXP VARCHAR := '^(?:DATETIME|SMALLDATETIME|DATETIME2)\s*(?:\s*\(\s*(\d+)\s*\)\s*)?$';
    v_datetimeval TIMESTAMP(6) WITHOUT TIME ZONE;
BEGIN
    v_datatype := regexp_replace(upper(trim(p_datatype)), '\s+', ' ', 'gi');
    v_src_datatype := upper(trim(p_src_datatype));
    v_style := floor(p_style)::SMALLINT;

    IF (v_src_datatype ~* SRCDATATYPE_MASK_REGEXP)
    THEN
        v_scale := substring(v_src_datatype, SRCDATATYPE_MASK_REGEXP)::SMALLINT;

        v_src_datatype := rtrim(split_part(v_src_datatype, '(', 1));

        IF (v_src_datatype <> 'DATETIME2' AND v_scale IS NOT NULL) THEN
            RAISE invalid_indicator_parameter_value;
        ELSIF (v_scale NOT BETWEEN 0 AND 7) THEN
            RAISE invalid_regular_expression;
        END IF;

        v_scale := coalesce(v_scale, 7);
    ELSE
        RAISE most_specific_type_mismatch;
    END IF;

    IF (scale(p_style) > 0) THEN
        RAISE escape_character_conflict;
    ELSIF (NOT ((v_style BETWEEN 0 AND 14) OR
                (v_style BETWEEN 20 AND 25) OR
                (v_style BETWEEN 100 AND 114) OR
                v_style IN (-1, 120, 121, 126, 127, 130, 131)))
    THEN
        RAISE invalid_parameter_value;
    END IF;

    IF (v_datatype ~* DATATYPE_MASK_REGEXP) THEN
        v_res_datatype := rtrim(split_part(v_datatype, '(', 1));

        v_maxlength := CASE
                          WHEN substring(v_res_datatype, '^(NCHAR|NATIONAL.*)$') IS NULL
                          THEN VARCHAR_MAX
                          ELSE NVARCHAR_MAX
                       END;

        v_lengthexpr := substring(v_datatype, DATATYPE_MASK_REGEXP);

        IF (v_lengthexpr <> 'MAX' AND char_length(v_lengthexpr) > 4)
        THEN
            RAISE interval_field_overflow;
        END IF;

        v_res_length := CASE v_lengthexpr
                           WHEN 'MAX' THEN v_maxlength
                           ELSE v_lengthexpr::SMALLINT
                        END;
    ELSIF (v_datatype ~* DATATYPE_REGEXP) THEN
        v_res_datatype := v_datatype;
    ELSE
        RAISE datatype_mismatch;
    END IF;

    v_datetimeval := CASE
                        WHEN (v_style NOT IN (130, 131)) THEN p_datetimeval
                        ELSE aws_sqlserver_ext.conv_greg_to_hijri(p_datetimeval) + INTERVAL '1 day'
                     END;

    v_day := ltrim(to_char(v_datetimeval, 'DD'), '0');
    v_hour := ltrim(to_char(v_datetimeval, 'HH12'), '0');
    v_month := to_char(v_datetimeval, 'MM')::SMALLINT;

    v_language := CASE
                     WHEN (v_style IN (130, 131)) THEN 'HIJRI'
                     ELSE CONVERSION_LANG
                  END;
    BEGIN
        v_lang_metadata_json := aws_sqlserver_ext.get_lang_metadata_json(v_language);
    EXCEPTION
        WHEN OTHERS THEN
        RAISE invalid_character_value_for_cast;
    END;

    v_monthname := (v_lang_metadata_json -> 'months_shortnames') ->> v_month - 1;

    IF (v_src_datatype IN ('DATETIME', 'SMALLDATETIME')) THEN
        v_fseconds := aws_sqlserver_ext.round_fractseconds(to_char(v_datetimeval, 'MS'));

        IF (v_fseconds::INTEGER = 1000) THEN
            v_fseconds := '000';
            v_datetimeval := v_datetimeval + INTERVAL '1 second';
        ELSE
            v_fseconds := lpad(v_fseconds, 3, '0');
        END IF;
    ELSE
        v_fseconds := aws_sqlserver_ext.get_microsecs_from_fractsecs(to_char(v_datetimeval, 'US'), v_scale);

        IF (v_scale = 7) THEN
            v_fseconds := concat(v_fseconds, '0');
        END IF;
    END IF;

    v_fractsep := CASE v_src_datatype
                     WHEN 'DATETIME2' THEN '.'
                     ELSE ':'
                  END;

    IF ((v_style = -1 AND v_src_datatype <> 'DATETIME2') OR
        v_style IN (0, 9, 100, 109))
    THEN
        v_resmask := format('$mnme$ %s YYYY %s:MI%s',
                            lpad(v_day, 2, ' '),
                            lpad(v_hour, 2, ' '),
                            CASE
                               WHEN (v_style IN (-1, 0, 100)) THEN 'AM'
                               ELSE CASE
                                       WHEN char_length(v_fseconds) > 0
                                       THEN format(':SS:%sAM', v_fseconds)
                                       ELSE ':SSAM'
                                    END
                            END);
    ELSIF (v_style = 1) THEN
        v_resmask := 'MM/DD/YY';
    ELSIF (v_style = 101) THEN
        v_resmask := 'MM/DD/YYYY';
    ELSIF (v_style = 2) THEN
        v_resmask := 'YY.MM.DD';
    ELSIF (v_style = 102) THEN
        v_resmask := 'YYYY.MM.DD';
    ELSIF (v_style = 3) THEN
        v_resmask := 'DD/MM/YY';
    ELSIF (v_style = 103) THEN
        v_resmask := 'DD/MM/YYYY';
    ELSIF (v_style = 4) THEN
        v_resmask := 'DD.MM.YY';
    ELSIF (v_style = 104) THEN
        v_resmask := 'DD.MM.YYYY';
    ELSIF (v_style = 5) THEN
        v_resmask := 'DD-MM-YY';
    ELSIF (v_style = 105) THEN
        v_resmask := 'DD-MM-YYYY';
    ELSIF (v_style = 6) THEN
        v_resmask := 'DD $mnme$ YY';
    ELSIF (v_style = 106) THEN
        v_resmask := 'DD $mnme$ YYYY';
    ELSIF (v_style = 7) THEN
        v_resmask := '$mnme$ DD, YY';
    ELSIF (v_style = 107) THEN
        v_resmask := '$mnme$ DD, YYYY';
    ELSIF (v_style IN (8, 24, 108)) THEN
        v_resmask := 'HH24:MI:SS';
    ELSIF (v_style = 10) THEN
        v_resmask := 'MM-DD-YY';
    ELSIF (v_style = 110) THEN
        v_resmask := 'MM-DD-YYYY';
    ELSIF (v_style = 11) THEN
        v_resmask := 'YY/MM/DD';
    ELSIF (v_style = 111) THEN
        v_resmask := 'YYYY/MM/DD';
    ELSIF (v_style = 12) THEN
        v_resmask := 'YYMMDD';
    ELSIF (v_style = 112) THEN
        v_resmask := 'YYYYMMDD';
    ELSIF (v_style IN (13, 113)) THEN
        v_resmask := format('DD $mnme$ YYYY HH24:MI:SS%s%s', v_fractsep, v_fseconds);
    ELSIF (v_style IN (14, 114)) THEN
        v_resmask := format('HH24:MI:SS%s%s', v_fractsep, v_fseconds);
    ELSIF (v_style IN (20, 120)) THEN
        v_resmask := 'YYYY-MM-DD HH24:MI:SS';
    ELSIF ((v_style = -1 AND v_src_datatype = 'DATETIME2') OR
           v_style IN (21, 25, 121))
    THEN
        v_resmask := format('YYYY-MM-DD HH24:MI:SS%s',
                            CASE
                               WHEN char_length(v_fseconds) > 0 THEN '.' || v_fseconds
                            END);
    ELSIF (v_style = 22) THEN
        v_resmask := format('MM/DD/YY %s:MI:SS AM', lpad(v_hour, 2, ' '));
    ELSIF (v_style = 23) THEN
        v_resmask := 'YYYY-MM-DD';
    ELSIF (v_style IN (126, 127)) THEN
        v_resmask := CASE v_src_datatype
                        WHEN 'SMALLDATETIME' THEN 'YYYY-MM-DDT$rem$HH24:MI:SS'
                        ELSE format('YYYY-MM-DDT$rem$HH24:MI:SS%s',
                                    CASE
                                       WHEN char_length(v_fseconds) > 0 THEN '.' || v_fseconds
                                    END)
                     END;
    ELSIF (v_style IN (130, 131)) THEN
        v_resmask := concat(CASE p_style
                               WHEN 131 THEN format('%s/MM/YYYY ', lpad(v_day, 2, ' '))
                               ELSE format('%s $mnme$ YYYY ', lpad(v_day, 2, ' '))
                            END,
                            format('%s:MI:SS%sAM', lpad(v_hour, 2, ' '),
                                   CASE
                                      WHEN char_length(v_fseconds) > 0 THEN concat(v_fractsep, v_fseconds)
                                   END));
    END IF;

    v_resstring := to_char(v_datetimeval, v_resmask);
    v_resstring := replace(v_resstring, '$mnme$', v_monthname);
    v_resstring := replace(v_resstring, '$rem$', '');

    v_resstring := substring(v_resstring, 1, coalesce(v_res_length, char_length(v_resstring)));

    RETURN CASE
              WHEN substring(v_res_datatype, concat('^(', CHARACTER_REGEXP, ')$')) IS NOT NULL
              THEN rpad(v_resstring, coalesce(v_res_length, 30), ' ')
              ELSE v_resstring
           END;
EXCEPTION
    WHEN most_specific_type_mismatch THEN
        RAISE USING MESSAGE := 'Source data type should be one of these values: ''DATETIME'', ''SMALLDATETIME'', ''DATETIME2'' or ''DATETIME2(n)''.',
                    DETAIL := 'Use of incorrect "src_datatype" parameter value during conversion process.',
                    HINT := 'Change "srcdatatype" parameter to the proper value and try again.';

   WHEN invalid_regular_expression THEN
       RAISE USING MESSAGE := format('The source data type scale (%s) given to the convert specification exceeds the maximum allowable value (7).',
                                     v_scale),
                   DETAIL := 'Use of incorrect scale value of source data type parameter during conversion process.',
                   HINT := 'Change scale component of source data type parameter to the allowable value and try again.';

    WHEN invalid_indicator_parameter_value THEN
        RAISE USING MESSAGE := format('Invalid attributes specified for data type %s.', v_src_datatype),
                    DETAIL := 'Use of incorrect scale value, which is not corresponding to specified data type.',
                    HINT := 'Change data type scale component or select different data type and try again.';

    WHEN escape_character_conflict THEN
        RAISE USING MESSAGE := 'Argument data type NUMERIC is invalid for argument 4 of convert function.',
                    DETAIL := 'Use of incorrect "style" parameter value during conversion process.',
                    HINT := 'Change "style" parameter to the proper value and try again.';

    WHEN invalid_parameter_value THEN
        RAISE USING MESSAGE := format('%s is not a valid style number when converting from %s to a character string.',
                                      v_style, v_src_datatype),
                    DETAIL := 'Use of incorrect "style" parameter value during conversion process.',
                    HINT := 'Change "style" parameter to the proper value and try again.';

    WHEN interval_field_overflow THEN
        RAISE USING MESSAGE := format('The size (%s) given to the convert specification ''%s'' exceeds the maximum allowed for any data type (%s).',
                                      v_lengthexpr, lower(v_res_datatype), v_maxlength),
                    DETAIL := 'Use of incorrect size value of data type parameter during conversion process.',
                    HINT := 'Change size component of data type parameter to the allowable value and try again.';

    WHEN datatype_mismatch THEN
        RAISE USING MESSAGE := concat('Data type should be one of these values: ''CHAR(n|MAX)'', ''NCHAR(n|MAX)'', ''VARCHAR(n|MAX)'', ''NVARCHAR(n|MAX)'', ',
                                      '''CHARACTER VARYING(n|MAX)'', ''NATIONAL CHARACTER VARYING(n|MAX)''.'),
                    DETAIL := 'Use of incorrect "datatype" parameter value during conversion process.',
                    HINT := 'Change "datatype" parameter to the proper value and try again.';

    WHEN invalid_character_value_for_cast THEN
        RAISE USING MESSAGE := format('Invalid CONVERSION_LANG constant value - ''%s''. Allowed values are: ''English'', ''Deutsch'', etc.',
                                      CONVERSION_LANG),
                    DETAIL := 'Compiled incorrect CONVERSION_LANG constant value in function''s body.',
                    HINT := 'Correct CONVERSION_LANG constant value in function''s body, recompile it and try again.';

    WHEN invalid_text_representation THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
        v_err_message := substring(lower(v_err_message), 'integer\:[[:space:]]\"(.*)\"');

        RAISE USING MESSAGE := format('Error while trying to convert "%s" value to SMALLINT data type.',
                                      v_err_message),
                    DETAIL := 'Supplied value contains illegal characters.',
                    HINT := 'Correct supplied value, remove all illegal characters.';
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.conv_datetime_to_string(p_datatype text, p_src_datatype text, p_datetimeval timestamp without time zone, p_style numeric) OWNER TO postgres;

--
-- TOC entry 3866 (class 0 OID 0)
-- Dependencies: 387
-- Name: FUNCTION conv_datetime_to_string(p_datatype text, p_src_datatype text, p_datetimeval timestamp without time zone, p_style numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.conv_datetime_to_string(p_datatype text, p_src_datatype text, p_datetimeval timestamp without time zone, p_style numeric) IS 'This function converts the DATETIME value into a character string, according to specified style (conversion mask).';


--
-- TOC entry 343 (class 1255 OID 17030)
-- Name: conv_greg_to_hijri(date); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.conv_greg_to_hijri(p_dateval date) RETURNS date
    LANGUAGE plpgsql STRICT
    AS $$
BEGIN
    RETURN aws_sqlserver_ext.conv_greg_to_hijri(extract(day from p_dateval)::NUMERIC,
                                                extract(month from p_dateval)::NUMERIC,
                                                extract(year from p_dateval)::NUMERIC);
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.conv_greg_to_hijri(p_dateval date) OWNER TO postgres;

--
-- TOC entry 3867 (class 0 OID 0)
-- Dependencies: 343
-- Name: FUNCTION conv_greg_to_hijri(p_dateval date); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.conv_greg_to_hijri(p_dateval date) IS 'This function converts date from Gregorian calendar to the appropriate date in Hijri calendar.';


--
-- TOC entry 346 (class 1255 OID 17033)
-- Name: conv_greg_to_hijri(timestamp without time zone); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.conv_greg_to_hijri(p_datetimeval timestamp without time zone) RETURNS timestamp without time zone
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
    v_hijri_date DATE;
BEGIN
    v_hijri_date := aws_sqlserver_ext.conv_greg_to_hijri(extract(day from p_datetimeval)::SMALLINT,
                                                         extract(month from p_datetimeval)::SMALLINT,
                                                         extract(year from p_datetimeval)::INTEGER);

    RETURN to_timestamp(format('%s %s', to_char(v_hijri_date, 'DD.MM.YYYY'),
                                        to_char(p_datetimeval, ' HH24:MI:SS.US')),
                        'DD.MM.YYYY HH24:MI:SS.US');
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.conv_greg_to_hijri(p_datetimeval timestamp without time zone) OWNER TO postgres;

--
-- TOC entry 3868 (class 0 OID 0)
-- Dependencies: 346
-- Name: FUNCTION conv_greg_to_hijri(p_datetimeval timestamp without time zone); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.conv_greg_to_hijri(p_datetimeval timestamp without time zone) IS 'This function converts date and time from Gregorian calendar to the appropriate date and time in Hijri calendar.';


--
-- TOC entry 344 (class 1255 OID 17031)
-- Name: conv_greg_to_hijri(numeric, numeric, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.conv_greg_to_hijri(p_day numeric, p_month numeric, p_year numeric) RETURNS date
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
    v_day SMALLINT;
    v_month SMALLINT;
    v_year INTEGER;
    v_jdnum DOUBLE PRECISION;
    v_lnum DOUBLE PRECISION;
    v_inum DOUBLE PRECISION;
    v_nnum DOUBLE PRECISION;
    v_jnum DOUBLE PRECISION;
BEGIN
    v_day := floor(p_day)::SMALLINT;
    v_month := floor(p_month)::SMALLINT;
    v_year := floor(p_year)::INTEGER;

    IF ((sign(v_day) = -1) OR (sign(v_month) = -1) OR (sign(v_year) = -1))
    THEN
        RAISE invalid_character_value_for_cast;
    ELSIF (v_year = 0) THEN
        RAISE null_value_not_allowed;
    END IF;

    IF ((p_year > 1582) OR ((p_year = 1582) AND (p_month > 10)) OR ((p_year = 1582) AND (p_month = 10) AND (p_day > 14)))
    THEN
        v_jdnum := aws_sqlserver_ext.get_int_part((1461 * (p_year + 4800 + aws_sqlserver_ext.get_int_part((p_month - 14) / 12))) / 4) +
                   aws_sqlserver_ext.get_int_part((367 * (p_month - 2 - 12 * (aws_sqlserver_ext.get_int_part((p_month - 14) / 12)))) / 12) -
                   aws_sqlserver_ext.get_int_part((3 * (aws_sqlserver_ext.get_int_part((p_year + 4900 +
                   aws_sqlserver_ext.get_int_part((p_month - 14) / 12)) / 100))) / 4) + p_day - 32075;
    ELSE
        v_jdnum := 367 * p_year - aws_sqlserver_ext.get_int_part((7 * (p_year + 5001 +
                   aws_sqlserver_ext.get_int_part((p_month - 9) / 7))) / 4) +
                   aws_sqlserver_ext.get_int_part((275 * p_month) / 9) + p_day + 1729777;
    END IF;

    v_lnum := v_jdnum - 1948440 + 10632;
    v_nnum := aws_sqlserver_ext.get_int_part((v_lnum - 1) / 10631);
    v_lnum := v_lnum - 10631 * v_nnum + 354;
    v_jnum := (aws_sqlserver_ext.get_int_part((10985 - v_lnum) / 5316)) * (aws_sqlserver_ext.get_int_part((50 * v_lnum) / 17719)) +
              (aws_sqlserver_ext.get_int_part(v_lnum / 5670)) * (aws_sqlserver_ext.get_int_part((43 * v_lnum) / 15238));
    v_lnum := v_lnum - (aws_sqlserver_ext.get_int_part((30 - v_jnum) / 15)) * (aws_sqlserver_ext.get_int_part((17719 * v_jnum) / 50)) -
              (aws_sqlserver_ext.get_int_part(v_jnum / 16)) * (aws_sqlserver_ext.get_int_part((15238 * v_jnum) / 43)) + 29;

    v_month := aws_sqlserver_ext.get_int_part((24 * v_lnum) / 709);
    v_day := v_lnum - aws_sqlserver_ext.get_int_part((709 * v_month) / 24);
    v_year := 30 * v_nnum + v_jnum - 30;

    RETURN to_date(concat_ws('.', v_day, v_month, v_year), 'DD.MM.YYYY');
EXCEPTION
    WHEN invalid_character_value_for_cast THEN
        RAISE USING MESSAGE := 'Could not convert Gregorian to Hijri date if any part of the date is negative.',
                    DETAIL := 'Some of the supplied date parts (day, month, year) is negative.',
                    HINT := 'Change the value of the date part (day, month, year) wich was found to be negative.';

    WHEN null_value_not_allowed THEN
        RAISE USING MESSAGE := 'Could not convert Gregorian to Hijri date if year value is equal to zero.',
                    DETAIL := 'Supplied year value is equal to zero.',
                    HINT := 'Change the value of the year so that it is greater than zero.';
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.conv_greg_to_hijri(p_day numeric, p_month numeric, p_year numeric) OWNER TO postgres;

--
-- TOC entry 3869 (class 0 OID 0)
-- Dependencies: 344
-- Name: FUNCTION conv_greg_to_hijri(p_day numeric, p_month numeric, p_year numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.conv_greg_to_hijri(p_day numeric, p_month numeric, p_year numeric) IS 'This function converts date from Gregorian calendar to the appropriate date in Hijri calendar.';


--
-- TOC entry 345 (class 1255 OID 17032)
-- Name: conv_greg_to_hijri(text, text, text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.conv_greg_to_hijri(p_day text, p_month text, p_year text) RETURNS date
    LANGUAGE plpgsql STRICT
    AS $$
BEGIN
    RETURN aws_sqlserver_ext.conv_greg_to_hijri(p_day::NUMERIC,
                                                p_month::NUMERIC,
                                                p_year::NUMERIC);
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.conv_greg_to_hijri(p_day text, p_month text, p_year text) OWNER TO postgres;

--
-- TOC entry 3870 (class 0 OID 0)
-- Dependencies: 345
-- Name: FUNCTION conv_greg_to_hijri(p_day text, p_month text, p_year text); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.conv_greg_to_hijri(p_day text, p_month text, p_year text) IS 'This function converts date from Gregorian calendar to the appropriate date in Hijri calendar.';


--
-- TOC entry 347 (class 1255 OID 17034)
-- Name: conv_hijri_to_greg(date); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.conv_hijri_to_greg(p_dateval date) RETURNS date
    LANGUAGE plpgsql STRICT
    AS $$
BEGIN
    RETURN aws_sqlserver_ext.conv_hijri_to_greg(extract(day from p_dateval)::NUMERIC,
                                                extract(month from p_dateval)::NUMERIC,
                                                extract(year from p_dateval)::NUMERIC);
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.conv_hijri_to_greg(p_dateval date) OWNER TO postgres;

--
-- TOC entry 3871 (class 0 OID 0)
-- Dependencies: 347
-- Name: FUNCTION conv_hijri_to_greg(p_dateval date); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.conv_hijri_to_greg(p_dateval date) IS 'This function converts date from Hijri calendar to the appropriate date in Gregorian calendar.';


--
-- TOC entry 370 (class 1255 OID 17037)
-- Name: conv_hijri_to_greg(timestamp without time zone); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.conv_hijri_to_greg(p_datetimeval timestamp without time zone) RETURNS timestamp without time zone
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
    v_hijri_date DATE;
BEGIN
    v_hijri_date := aws_sqlserver_ext.conv_hijri_to_greg(extract(day from p_datetimeval)::NUMERIC,
                                                         extract(month from p_datetimeval)::NUMERIC,
                                                         extract(year from p_datetimeval)::NUMERIC);

    RETURN to_timestamp(format('%s %s', to_char(v_hijri_date, 'DD.MM.YYYY'),
                                        to_char(p_datetimeval, ' HH24:MI:SS.US')),
                        'DD.MM.YYYY HH24:MI:SS.US');
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.conv_hijri_to_greg(p_datetimeval timestamp without time zone) OWNER TO postgres;

--
-- TOC entry 3872 (class 0 OID 0)
-- Dependencies: 370
-- Name: FUNCTION conv_hijri_to_greg(p_datetimeval timestamp without time zone); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.conv_hijri_to_greg(p_datetimeval timestamp without time zone) IS 'This function converts date from Hijri calendar to the appropriate date in Gregorian calendar.';


--
-- TOC entry 368 (class 1255 OID 17035)
-- Name: conv_hijri_to_greg(numeric, numeric, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.conv_hijri_to_greg(p_day numeric, p_month numeric, p_year numeric) RETURNS date
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
    v_day SMALLINT;
    v_month SMALLINT;
    v_year INTEGER;
    v_err_message VARCHAR;
    v_jdnum DOUBLE PRECISION;
    v_lnum DOUBLE PRECISION;
    v_inum DOUBLE PRECISION;
    v_nnum DOUBLE PRECISION;
    v_jnum DOUBLE PRECISION;
    v_knum DOUBLE PRECISION;
BEGIN
    v_day := floor(p_day)::SMALLINT;
    v_month := floor(p_month)::SMALLINT;
    v_year := floor(p_year)::INTEGER;

    IF ((sign(v_day) = -1) OR (sign(v_month) = -1) OR (sign(v_year) = -1))
    THEN
        RAISE invalid_character_value_for_cast;
    ELSIF (v_year = 0) THEN
        RAISE null_value_not_allowed;
    END IF;

    v_jdnum = aws_sqlserver_ext.get_int_part((11 * v_year + 3) / 30) + 354 * v_year + 30 * v_month -
              aws_sqlserver_ext.get_int_part((v_month - 1) / 2) + v_day + 1948440 - 385;

    IF (v_jdnum > 2299160)
    THEN
        v_lnum := v_jdnum + 68569;
        v_nnum := aws_sqlserver_ext.get_int_part((4 * v_lnum) / 146097);
        v_lnum := v_lnum - aws_sqlserver_ext.get_int_part((146097 * v_nnum + 3) / 4);
        v_inum := aws_sqlserver_ext.get_int_part((4000 * (v_lnum + 1)) / 1461001);
        v_lnum := v_lnum - aws_sqlserver_ext.get_int_part((1461 * v_inum) / 4) + 31;
        v_jnum := aws_sqlserver_ext.get_int_part((80 * v_lnum) / 2447);
        v_day := v_lnum - aws_sqlserver_ext.get_int_part((2447 * v_jnum) / 80);
        v_lnum := aws_sqlserver_ext.get_int_part(v_jnum / 11);
        v_month := v_jnum + 2 - 12 * v_lnum;
        v_year := 100 * (v_nnum - 49) + v_inum + v_lnum;
    ELSE
        v_jnum := v_jdnum + 1402;
        v_knum := aws_sqlserver_ext.get_int_part((v_jnum - 1) / 1461);
        v_lnum := v_jnum - 1461 * v_knum;
        v_nnum := aws_sqlserver_ext.get_int_part((v_lnum - 1) / 365) - aws_sqlserver_ext.get_int_part(v_lnum / 1461);
        v_inum := v_lnum - 365 * v_nnum + 30;
        v_jnum := aws_sqlserver_ext.get_int_part((80 * v_inum) / 2447);
        v_day := v_inum - aws_sqlserver_ext.get_int_part((2447 * v_jnum) / 80);
        v_inum := aws_sqlserver_ext.get_int_part(v_jnum / 11);
        v_month := v_jnum + 2 - 12 * v_inum;
        v_year := 4 * v_knum + v_nnum + v_inum - 4716;
    END IF;

    RETURN to_date(concat_ws('.', v_day, v_month, v_year), 'DD.MM.YYYY');
EXCEPTION
    WHEN invalid_character_value_for_cast THEN
        RAISE USING MESSAGE := 'Could not convert Hijri to Gregorian date if any part of the date is negative.',
                    DETAIL := 'Some of the supplied date parts (day, month, year) is negative.',
                    HINT := 'Change the value of the date part (day, month, year) wich was found to be negative.';

    WHEN null_value_not_allowed THEN
        RAISE USING MESSAGE := 'Could not convert Hijri to Gregorian date if year value is equal to zero.',
                    DETAIL := 'Supplied year value is equal to zero.',
                    HINT := 'Change the value of the year so that it is greater than zero.';

    WHEN invalid_text_representation THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
        v_err_message := substring(lower(v_err_message), 'integer\:\s\"(.*)\"');

        RAISE USING MESSAGE := format('Error while trying to convert "%s" value to SMALLINT data type.', v_err_message),
                    DETAIL := 'Supplied value contains illegal characters.',
                    HINT := 'Correct supplied value, remove all illegal characters.';
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.conv_hijri_to_greg(p_day numeric, p_month numeric, p_year numeric) OWNER TO postgres;

--
-- TOC entry 3873 (class 0 OID 0)
-- Dependencies: 368
-- Name: FUNCTION conv_hijri_to_greg(p_day numeric, p_month numeric, p_year numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.conv_hijri_to_greg(p_day numeric, p_month numeric, p_year numeric) IS 'This function converts date from Hijri calendar to the appropriate date in Gregorian calendar.';


--
-- TOC entry 369 (class 1255 OID 17036)
-- Name: conv_hijri_to_greg(text, text, text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.conv_hijri_to_greg(p_day text, p_month text, p_year text) RETURNS date
    LANGUAGE plpgsql STRICT
    AS $$
BEGIN
    RETURN aws_sqlserver_ext.conv_hijri_to_greg(p_day::NUMERIC,
                                                p_month::NUMERIC,
                                                p_year::NUMERIC);
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.conv_hijri_to_greg(p_day text, p_month text, p_year text) OWNER TO postgres;

--
-- TOC entry 3874 (class 0 OID 0)
-- Dependencies: 369
-- Name: FUNCTION conv_hijri_to_greg(p_day text, p_month text, p_year text); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.conv_hijri_to_greg(p_day text, p_month text, p_year text) IS 'This function converts date from Hijri calendar to the appropriate date in Gregorian calendar.';


--
-- TOC entry 389 (class 1255 OID 17055)
-- Name: conv_string_to_date(text, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.conv_string_to_date(p_datestring text, p_style numeric DEFAULT 0) RETURNS date
    LANGUAGE plpgsql STRICT
    AS $_$
DECLARE
    v_day VARCHAR;
    v_year VARCHAR;
    v_month VARCHAR;
    v_hijridate DATE;
    v_style SMALLINT;
    v_leftpart VARCHAR;
    v_middlepart VARCHAR;
    v_rightpart VARCHAR;
    v_fractsecs VARCHAR;
    v_datestring VARCHAR;
    v_err_message VARCHAR;
    v_date_format VARCHAR;
    v_regmatch_groups TEXT[];
    v_lang_metadata_json JSONB;
    v_compmonth_regexp VARCHAR;
    CONVERSION_LANG CONSTANT VARCHAR := 'English';
    DATE_FORMAT CONSTANT VARCHAR := '';
    DAYMM_REGEXP CONSTANT VARCHAR := '(\d{1,2})';
    FULLYEAR_REGEXP CONSTANT VARCHAR := '(\d{4})';
    SHORTYEAR_REGEXP CONSTANT VARCHAR := '(\d{1,2})';
    COMPYEAR_REGEXP CONSTANT VARCHAR := '(\d{1,2}|\d{4})';
    AMPM_REGEXP CONSTANT VARCHAR := '(?:[AP]M)';
    TIMEUNIT_REGEXP CONSTANT VARCHAR := '\s*\d{1,2}\s*';
    FRACTSECS_REGEXP CONSTANT VARCHAR := '\s*\d{1,9}';
    HHMMSSFS_PART_REGEXP CONSTANT VARCHAR := concat('(', TIMEUNIT_REGEXP, AMPM_REGEXP, '|',
                                                    TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '|',
                                                    TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '|',
                                                    TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '(?:\.|\:)', FRACTSECS_REGEXP,
                                                    ')\s*', AMPM_REGEXP, '?');
    HHMMSSFS_DOTPART_REGEXP CONSTANT VARCHAR := concat('(', TIMEUNIT_REGEXP, AMPM_REGEXP, '|',
                                                       TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '|',
                                                       TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '|',
                                                       TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '\.', FRACTSECS_REGEXP,
                                                       ')\s*', AMPM_REGEXP, '?');
    HHMMSSFS_REGEXP CONSTANT VARCHAR := concat('^', HHMMSSFS_PART_REGEXP, '$');
    HHMMSSFS_DOT_REGEXP CONSTANT VARCHAR := concat('^', HHMMSSFS_DOTPART_REGEXP, '$');
    v_defmask1_regexp VARCHAR := concat('^($comp_month$)\s*', DAYMM_REGEXP, '\s+', COMPYEAR_REGEXP, '$');
    v_defmask2_regexp VARCHAR := concat('^', DAYMM_REGEXP, '\s*($comp_month$)\s*', COMPYEAR_REGEXP, '$');
    v_defmask3_regexp VARCHAR := concat('^', FULLYEAR_REGEXP, '\s*($comp_month$)\s*', DAYMM_REGEXP, '$');
    v_defmask4_regexp VARCHAR := concat('^', FULLYEAR_REGEXP, '\s+', DAYMM_REGEXP, '\s*($comp_month$)$');
    v_defmask5_regexp VARCHAR := concat('^', DAYMM_REGEXP, '\s+', COMPYEAR_REGEXP, '\s*($comp_month$)$');
    v_defmask6_regexp VARCHAR := concat('^($comp_month$)\s*', FULLYEAR_REGEXP, '\s+', DAYMM_REGEXP, '$');
    v_defmask7_regexp VARCHAR := concat('^($comp_month$)\s*', DAYMM_REGEXP, '\s*\,\s*', COMPYEAR_REGEXP, '$');
    v_defmask8_regexp VARCHAR := concat('^', FULLYEAR_REGEXP, '\s*($comp_month$)$');
    v_defmask9_regexp VARCHAR := concat('^($comp_month$)\s*', FULLYEAR_REGEXP, '$');
    v_defmask10_regexp VARCHAR := concat('^', DAYMM_REGEXP, '\s*(?:\.|/|-)\s*($comp_month$)\s*(?:\.|/|-)\s*', COMPYEAR_REGEXP, '$');
    DOT_SHORTYEAR_REGEXP CONSTANT VARCHAR := concat('^', DAYMM_REGEXP, '\s*\.\s*', DAYMM_REGEXP, '\s*\.\s*', SHORTYEAR_REGEXP, '$');
    DOT_FULLYEAR_REGEXP CONSTANT VARCHAR := concat('^', DAYMM_REGEXP, '\s*\.\s*', DAYMM_REGEXP, '\s*\.\s*', FULLYEAR_REGEXP, '$');
    SLASH_SHORTYEAR_REGEXP CONSTANT VARCHAR := concat('^', DAYMM_REGEXP, '\s*/\s*', DAYMM_REGEXP, '\s*/\s*', SHORTYEAR_REGEXP, '$');
    SLASH_FULLYEAR_REGEXP CONSTANT VARCHAR := concat('^', DAYMM_REGEXP, '\s*/\s*', DAYMM_REGEXP, '\s*/\s*', FULLYEAR_REGEXP, '$');
    DASH_SHORTYEAR_REGEXP CONSTANT VARCHAR := concat('^', DAYMM_REGEXP, '\s*-\s*', DAYMM_REGEXP, '\s*-\s*', SHORTYEAR_REGEXP, '$');
    DASH_FULLYEAR_REGEXP CONSTANT VARCHAR := concat('^', DAYMM_REGEXP, '\s*-\s*', DAYMM_REGEXP, '\s*-\s*', FULLYEAR_REGEXP, '$');
    DOT_SLASH_DASH_YEAR_REGEXP CONSTANT VARCHAR := concat('^', DAYMM_REGEXP, '\s*(?:\.|/|-)\s*', DAYMM_REGEXP, '\s*(?:\.|/|-)\s*', COMPYEAR_REGEXP, '$');
    YEAR_DOTMASK_REGEXP CONSTANT VARCHAR := concat('^', FULLYEAR_REGEXP, '\s*\.\s*', DAYMM_REGEXP, '\s*\.\s*', DAYMM_REGEXP, '$');
    YEAR_SLASHMASK_REGEXP CONSTANT VARCHAR := concat('^', FULLYEAR_REGEXP, '\s*/\s*', DAYMM_REGEXP, '\s*/\s*', DAYMM_REGEXP, '$');
    YEAR_DASHMASK_REGEXP CONSTANT VARCHAR := concat('^', FULLYEAR_REGEXP, '\s*-\s*', DAYMM_REGEXP, '\s*-\s*', DAYMM_REGEXP, '$');
    YEAR_DOT_SLASH_DASH_REGEXP CONSTANT VARCHAR := concat('^', FULLYEAR_REGEXP, '\s*(?:\.|/|-)\s*', DAYMM_REGEXP, '\s*(?:\.|/|-)\s*', DAYMM_REGEXP, '$');
    DIGITMASK1_REGEXP CONSTANT VARCHAR := '^\d{6}$';
    DIGITMASK2_REGEXP CONSTANT VARCHAR := '^\d{8}$';
BEGIN
    v_style := floor(p_style)::SMALLINT;
    v_datestring := trim(p_datestring);

    IF (scale(p_style) > 0) THEN
        RAISE most_specific_type_mismatch;
    ELSIF (NOT ((v_style BETWEEN 0 AND 14) OR
                (v_style BETWEEN 20 AND 25) OR
                (v_style BETWEEN 100 AND 114) OR
                v_style IN (120, 121, 126, 127, 130, 131)))
    THEN
        RAISE invalid_parameter_value;
    END IF;

    IF (v_datestring ~* HHMMSSFS_PART_REGEXP AND v_datestring !~* HHMMSSFS_REGEXP)
    THEN
        v_datestring := trim(regexp_replace(v_datestring, HHMMSSFS_PART_REGEXP, '', 'gi'));
    END IF;

    BEGIN
        v_lang_metadata_json := aws_sqlserver_ext.get_lang_metadata_json(CONVERSION_LANG);
    EXCEPTION
        WHEN OTHERS THEN
        RAISE invalid_character_value_for_cast;
    END;

    v_date_format := coalesce(nullif(DATE_FORMAT, ''), v_lang_metadata_json ->> 'date_format');

    v_compmonth_regexp := array_to_string(array_cat(ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'months_shortnames')),
                                                    ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'months_names'))), '|');

    v_defmask1_regexp := replace(v_defmask1_regexp, '$comp_month$', v_compmonth_regexp);
    v_defmask2_regexp := replace(v_defmask2_regexp, '$comp_month$', v_compmonth_regexp);
    v_defmask3_regexp := replace(v_defmask3_regexp, '$comp_month$', v_compmonth_regexp);
    v_defmask4_regexp := replace(v_defmask4_regexp, '$comp_month$', v_compmonth_regexp);
    v_defmask5_regexp := replace(v_defmask5_regexp, '$comp_month$', v_compmonth_regexp);
    v_defmask6_regexp := replace(v_defmask6_regexp, '$comp_month$', v_compmonth_regexp);
    v_defmask7_regexp := replace(v_defmask7_regexp, '$comp_month$', v_compmonth_regexp);
    v_defmask8_regexp := replace(v_defmask8_regexp, '$comp_month$', v_compmonth_regexp);
    v_defmask9_regexp := replace(v_defmask9_regexp, '$comp_month$', v_compmonth_regexp);
    v_defmask10_regexp := replace(v_defmask10_regexp, '$comp_month$', v_compmonth_regexp);

    IF (v_datestring ~* v_defmask1_regexp OR
        v_datestring ~* v_defmask2_regexp OR
        v_datestring ~* v_defmask3_regexp OR
        v_datestring ~* v_defmask4_regexp OR
        v_datestring ~* v_defmask5_regexp OR
        v_datestring ~* v_defmask6_regexp OR
        v_datestring ~* v_defmask7_regexp OR
        v_datestring ~* v_defmask8_regexp OR
        v_datestring ~* v_defmask9_regexp OR
        v_datestring ~* v_defmask10_regexp)
    THEN
        IF (v_style IN (130, 131)) THEN
            RAISE invalid_datetime_format;
        END IF;

        IF (v_datestring ~* v_defmask1_regexp)
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, v_defmask1_regexp, 'gi');
            v_day := v_regmatch_groups[2];
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[1], v_lang_metadata_json);
            v_year := aws_sqlserver_ext.get_full_year(v_regmatch_groups[3]);

        ELSIF (v_datestring ~* v_defmask2_regexp)
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, v_defmask2_regexp, 'gi');
            v_day := v_regmatch_groups[1];
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
            v_year := aws_sqlserver_ext.get_full_year(v_regmatch_groups[3]);

        ELSIF (v_datestring ~* v_defmask3_regexp)
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, v_defmask3_regexp, 'gi');
            v_day := v_regmatch_groups[3];
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
            v_year := v_regmatch_groups[1];

        ELSIF (v_datestring ~* v_defmask4_regexp)
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, v_defmask4_regexp, 'gi');
            v_day := v_regmatch_groups[2];
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[3], v_lang_metadata_json);
            v_year := v_regmatch_groups[1];

        ELSIF (v_datestring ~* v_defmask5_regexp)
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, v_defmask5_regexp, 'gi');
            v_day := v_regmatch_groups[1];
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[3], v_lang_metadata_json);
            v_year := aws_sqlserver_ext.get_full_year(v_regmatch_groups[2]);

        ELSIF (v_datestring ~* v_defmask6_regexp)
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, v_defmask6_regexp, 'gi');
            v_day := v_regmatch_groups[3];
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[1], v_lang_metadata_json);
            v_year := v_regmatch_groups[2];

        ELSIF (v_datestring ~* v_defmask7_regexp)
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, v_defmask7_regexp, 'gi');
            v_day := v_regmatch_groups[2];
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[1], v_lang_metadata_json);
            v_year := aws_sqlserver_ext.get_full_year(v_regmatch_groups[3]);

        ELSIF (v_datestring ~* v_defmask8_regexp)
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, v_defmask8_regexp, 'gi');
            v_day := '01';
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
            v_year := v_regmatch_groups[1];

        ELSIF (v_datestring ~* v_defmask9_regexp)
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, v_defmask9_regexp, 'gi');
            v_day := '01';
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[1], v_lang_metadata_json);
            v_year := v_regmatch_groups[2];
        ELSE
            v_regmatch_groups := regexp_matches(v_datestring, v_defmask10_regexp, 'gi');
            v_day := v_regmatch_groups[1];
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
            v_year := aws_sqlserver_ext.get_full_year(v_regmatch_groups[3]);
        END IF;
    ELSEIF (v_datestring ~* DOT_SHORTYEAR_REGEXP OR
            v_datestring ~* DOT_FULLYEAR_REGEXP OR
            v_datestring ~* SLASH_SHORTYEAR_REGEXP OR
            v_datestring ~* SLASH_FULLYEAR_REGEXP OR
            v_datestring ~* DASH_SHORTYEAR_REGEXP OR
            v_datestring ~* DASH_FULLYEAR_REGEXP)
    THEN
        IF (v_style IN (6, 7, 8, 9, 12, 13, 14, 24, 100, 106, 107, 108, 109, 112, 113, 114, 130)) THEN
            RAISE invalid_regular_expression;
        ELSIF (v_style IN (20, 21, 23, 25, 102, 111, 120, 121, 126, 127)) THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_datestring, DOT_SLASH_DASH_YEAR_REGEXP, 'gi');
        v_leftpart := v_regmatch_groups[1];
        v_middlepart := v_regmatch_groups[2];
        v_rightpart := v_regmatch_groups[3];

        IF (v_datestring ~* DOT_SHORTYEAR_REGEXP OR
            v_datestring ~* SLASH_SHORTYEAR_REGEXP OR
            v_datestring ~* DASH_SHORTYEAR_REGEXP)
        THEN
            IF ((v_style IN (1, 10, 22) AND v_date_format <> 'MDY') OR
                ((v_style IS NULL OR v_style IN (0, 1, 10, 22)) AND v_date_format NOT IN ('YDM', 'YMD', 'DMY', 'DYM', 'MYD')))
            THEN
                v_day := v_middlepart;
                v_month := v_leftpart;
                v_year := aws_sqlserver_ext.get_full_year(v_rightpart);

            ELSIF ((v_style IN (2, 11) AND v_date_format <> 'YMD') OR
                   ((v_style IS NULL OR v_style IN (0, 2, 11)) AND v_date_format = 'YMD'))
            THEN
                v_day := v_rightpart;
                v_month := v_middlepart;
                v_year := aws_sqlserver_ext.get_full_year(v_leftpart);

            ELSIF ((v_style IN (3, 4, 5) AND v_date_format <> 'DMY') OR
                   ((v_style IS NULL OR v_style IN (0, 3, 4, 5)) AND v_date_format = 'DMY'))
            THEN
                v_day := v_leftpart;
                v_month := v_middlepart;
                v_year := aws_sqlserver_ext.get_full_year(v_rightpart);

            ELSIF ((v_style IS NULL OR v_style = 0) AND v_date_format = 'DYM')
            THEN
                v_day := v_leftpart;
                v_month := v_rightpart;
                v_year := aws_sqlserver_ext.get_full_year(v_middlepart);

            ELSIF ((v_style IS NULL OR v_style = 0) AND v_date_format = 'MYD')
            THEN
                v_day := v_rightpart;
                v_month := v_leftpart;
                v_year := aws_sqlserver_ext.get_full_year(v_middlepart);

            ELSIF ((v_style IS NULL OR v_style = 0) AND v_date_format = 'YDM') THEN
                RAISE character_not_in_repertoire;
            ELSIF (v_style IN (101, 103, 104, 105, 110, 131)) THEN
                RAISE invalid_datetime_format;
            END IF;
        ELSE
            v_year := v_rightpart;

            IF (v_leftpart::SMALLINT <= 12)
            THEN
                IF ((v_style IN (103, 104, 105, 131) AND v_date_format <> 'DMY') OR
                    ((v_style IS NULL OR v_style IN (0, 103, 104, 105, 131)) AND v_date_format = 'DMY'))
                THEN
                    v_day := v_leftpart;
                    v_month := v_middlepart;
                ELSIF ((v_style IN (101, 110) AND v_date_format IN ('YDM', 'DMY', 'DYM')) OR
                       ((v_style IS NULL OR v_style IN (0, 101, 110)) AND v_date_format NOT IN ('YDM', 'DMY', 'DYM')))
                THEN
                    v_day := v_middlepart;
                    v_month := v_leftpart;
                ELSIF ((v_style IN (1, 2, 3, 4, 5, 10, 11, 22) AND v_date_format <> 'YDM') OR
                       ((v_style IS NULL OR v_style IN (0, 1, 2, 3, 4, 5, 10, 11, 22)) AND v_date_format = 'YDM'))
                THEN
                    RAISE invalid_datetime_format;
                END IF;
            ELSE
                IF ((v_style IN (103, 104, 105, 131) AND v_date_format <> 'DMY') OR
                    ((v_style IS NULL OR v_style IN (0, 103, 104, 105, 131)) AND v_date_format = 'DMY'))
                THEN
                    v_day := v_leftpart;
                    v_month := v_middlepart;
                ELSIF ((v_style IN (1, 2, 3, 4, 5, 10, 11, 22, 101, 110) AND v_date_format = 'DMY') OR
                       ((v_style IS NULL OR v_style IN (0, 1, 2, 3, 4, 5, 10, 11, 22, 101, 110)) AND v_date_format <> 'DMY'))
                THEN
                    RAISE invalid_datetime_format;
                END IF;
            END IF;
        END IF;
    ELSIF (v_datestring ~* YEAR_DOTMASK_REGEXP OR
           v_datestring ~* YEAR_SLASHMASK_REGEXP OR
           v_datestring ~* YEAR_DASHMASK_REGEXP)
    THEN
        IF (v_style IN (6, 7, 8, 9, 12, 13, 14, 24, 100, 106, 107, 108, 109, 112, 113, 114, 130)) THEN
            RAISE invalid_regular_expression;
        ELSIF (v_style IN (1, 2, 3, 4, 5, 10, 11, 22, 101, 103, 104, 105, 110, 131)) THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_datestring, YEAR_DOT_SLASH_DASH_REGEXP, 'gi');
        v_day := v_regmatch_groups[3];
        v_month := v_regmatch_groups[2];
        v_year := v_regmatch_groups[1];

    ELSIF (v_datestring ~* DIGITMASK1_REGEXP OR
           v_datestring ~* DIGITMASK2_REGEXP)
    THEN
        IF (v_datestring ~* DIGITMASK1_REGEXP)
        THEN
            v_day := substring(v_datestring, 5, 2);
            v_month := substring(v_datestring, 3, 2);
            v_year := aws_sqlserver_ext.get_full_year(substring(v_datestring, 1, 2));
        ELSE
            v_day := substring(v_datestring, 7, 2);
            v_month := substring(v_datestring, 5, 2);
            v_year := substring(v_datestring, 1, 4);
        END IF;
    ELSIF (v_datestring ~* HHMMSSFS_REGEXP)
    THEN
        v_fractsecs := coalesce(aws_sqlserver_ext.get_timeunit_from_string(v_datestring, 'FRACTSECONDS'), '');
        IF (v_datestring !~* HHMMSSFS_DOT_REGEXP AND char_length(v_fractsecs) > 3) THEN
            RAISE invalid_datetime_format;
        END IF;

        v_day := '01';
        v_month := '01';
        v_year := '1900';
    ELSE
        RAISE invalid_datetime_format;
    END IF;

    IF (((v_datestring ~* HHMMSSFS_REGEXP OR v_datestring ~* DIGITMASK1_REGEXP OR v_datestring ~* DIGITMASK2_REGEXP) AND v_style IN (130, 131)) OR
        ((v_datestring ~* DOT_FULLYEAR_REGEXP OR v_datestring ~* SLASH_FULLYEAR_REGEXP OR v_datestring ~* DASH_FULLYEAR_REGEXP) AND v_style = 131))
    THEN
        IF ((v_day::SMALLINT NOT BETWEEN 1 AND 29) OR
            (v_month::SMALLINT NOT BETWEEN 1 AND 12))
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_hijridate := aws_sqlserver_ext.conv_hijri_to_greg(v_day, v_month, v_year) - 1;
        v_datestring := to_char(v_hijridate, 'DD.MM.YYYY');

        v_day := split_part(v_datestring, '.', 1);
        v_month := split_part(v_datestring, '.', 2);
        v_year := split_part(v_datestring, '.', 3);
    END IF;

    RETURN to_date(concat_ws('.', v_day, v_month, v_year), 'DD.MM.YYYY');
EXCEPTION
    WHEN most_specific_type_mismatch THEN
        RAISE USING MESSAGE := 'Argument data type NUMERIC is invalid for argument 2 of conv_string_to_date function.',
                    DETAIL := 'Use of incorrect "style" parameter value during conversion process.',
                    HINT := 'Change "style" parameter to the proper value and try again.';

    WHEN invalid_parameter_value THEN
        RAISE USING MESSAGE := format('The style %s is not supported for conversions from VARCHAR to DATE.', v_style),
                    DETAIL := 'Use of incorrect "style" parameter value during conversion process.',
                    HINT := 'Change "style" parameter to the proper value and try again.';

    WHEN invalid_regular_expression THEN
        RAISE USING MESSAGE := format('The input character string doesn''t follow style %s.', v_style),
                    DETAIL := 'Selected "style" param value isn''t valid for conversion of passed character string.',
                    HINT := 'Either change the input character string or use a different style.';

    WHEN invalid_datetime_format THEN
        RAISE USING MESSAGE := 'Conversion failed when converting date from character string.',
                    DETAIL := 'Incorrect using of pair of input parameters values during conversion process.',
                    HINT := 'Check the input parameters values, correct them if needed, and try again.';

    WHEN character_not_in_repertoire THEN
        RAISE USING MESSAGE := 'The YDM date format isn''t supported when converting from this string format to date.',
                    DETAIL := 'Use of incorrect DATE_FORMAT constant value regarding string format parameter during conversion process.',
                    HINT := 'Change DATE_FORMAT constant to one of these values: MDY|DMY|DYM, recompile function and try again.';

    WHEN invalid_character_value_for_cast THEN
        RAISE USING MESSAGE := format('Invalid CONVERSION_LANG constant value - ''%s''. Allowed values are: ''English'', ''Deutsch'', etc.',
                                      CONVERSION_LANG),
                    DETAIL := 'Compiled incorrect CONVERSION_LANG constant value in function''s body.',
                    HINT := 'Correct CONVERSION_LANG constant value in function''s body, recompile it and try again.';

    WHEN invalid_text_representation THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
        v_err_message := substring(lower(v_err_message), 'integer\:\s\"(.*)\"');

        RAISE USING MESSAGE := format('Error while trying to convert "%s" value to SMALLINT data type.',
                                      v_err_message),
                    DETAIL := 'Passed argument value contains illegal characters.',
                    HINT := 'Correct passed argument value, remove all illegal characters.';
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.conv_string_to_date(p_datestring text, p_style numeric) OWNER TO postgres;

--
-- TOC entry 3875 (class 0 OID 0)
-- Dependencies: 389
-- Name: FUNCTION conv_string_to_date(p_datestring text, p_style numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.conv_string_to_date(p_datestring text, p_style numeric) IS 'This function parses the TEXT string and converts it into a DATE value, according to specified style (conversion mask).';


--
-- TOC entry 390 (class 1255 OID 17057)
-- Name: conv_string_to_datetime(text, text, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.conv_string_to_datetime(p_datatype text, p_datetimestring text, p_style numeric DEFAULT 0) RETURNS timestamp without time zone
    LANGUAGE plpgsql STRICT
    AS $_$
DECLARE
    v_day VARCHAR;
    v_year VARCHAR;
    v_month VARCHAR;
    v_style SMALLINT;
    v_scale SMALLINT;
    v_hours VARCHAR;
    v_hijridate DATE;
    v_minutes VARCHAR;
    v_seconds VARCHAR;
    v_fseconds VARCHAR;
    v_datatype VARCHAR;
    v_timepart VARCHAR;
    v_leftpart VARCHAR;
    v_middlepart VARCHAR;
    v_rightpart VARCHAR;
    v_datestring VARCHAR;
    v_err_message VARCHAR;
    v_date_format VARCHAR;
    v_res_datatype VARCHAR;
    v_datetimestring VARCHAR;
    v_datatype_groups TEXT[];
    v_regmatch_groups TEXT[];
    v_lang_metadata_json JSONB;
    v_compmonth_regexp VARCHAR;
    v_resdatetime TIMESTAMP(6) WITHOUT TIME ZONE;
    CONVERSION_LANG CONSTANT VARCHAR := 'English';
    DATE_FORMAT CONSTANT VARCHAR := '';
    DAYMM_REGEXP CONSTANT VARCHAR := '(\d{1,2})';
    FULLYEAR_REGEXP CONSTANT VARCHAR := '(\d{4})';
    SHORTYEAR_REGEXP CONSTANT VARCHAR := '(\d{1,2})';
    COMPYEAR_REGEXP CONSTANT VARCHAR := '(\d{1,2}|\d{4})';
    AMPM_REGEXP CONSTANT VARCHAR := '(?:[AP]M)';
    MASKSEP_REGEXP CONSTANT VARCHAR := '(?:\.|-|/)';
    TIMEUNIT_REGEXP CONSTANT VARCHAR := '\s*\d{1,2}\s*';
    FRACTSECS_REGEXP CONSTANT VARCHAR := '\s*\d{1,9}\s*';
    DATATYPE_REGEXP CONSTANT VARCHAR := '^(DATETIME|SMALLDATETIME|DATETIME2)\s*(?:\()?\s*((?:-)?\d+)?\s*(?:\))?$';
    HHMMSSFS_PART_REGEXP CONSTANT VARCHAR := concat(TIMEUNIT_REGEXP, AMPM_REGEXP, '|',
                                                    TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, AMPM_REGEXP, '?|',
                                                    TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '\.', FRACTSECS_REGEXP, AMPM_REGEXP, '?|',
                                                    TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, AMPM_REGEXP, '?|',
                                                    TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '(?:\.|\:)', FRACTSECS_REGEXP, AMPM_REGEXP, '?');
    HHMMSSFS_DOT_PART_REGEXP CONSTANT VARCHAR := concat(TIMEUNIT_REGEXP, AMPM_REGEXP, '|',
                                                        TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, AMPM_REGEXP, '?|',
                                                        TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '\.', FRACTSECS_REGEXP, AMPM_REGEXP, '?|',
                                                        TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, AMPM_REGEXP, '?|',
                                                        TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '(?:\.)', FRACTSECS_REGEXP, AMPM_REGEXP, '?');
    HHMMSSFS_REGEXP CONSTANT VARCHAR := concat('^(', HHMMSSFS_PART_REGEXP, ')$');
    DEFMASK1_0_REGEXP CONSTANT VARCHAR := concat('^(', HHMMSSFS_PART_REGEXP, ')?\s*',
                                                 MASKSEP_REGEXP, '*\s*($comp_month$)\s*', DAYMM_REGEXP, '\s+', COMPYEAR_REGEXP,
                                                 '\s*(', HHMMSSFS_PART_REGEXP, ')?$');
    DEFMASK1_1_REGEXP CONSTANT VARCHAR := concat('^', MASKSEP_REGEXP, '?\s*($comp_month$)\s*', DAYMM_REGEXP, '\s+', COMPYEAR_REGEXP, '$');
    DEFMASK1_2_REGEXP CONSTANT VARCHAR := concat('^', MASKSEP_REGEXP, '\s*($comp_month$)\s*', DAYMM_REGEXP, '\s+', COMPYEAR_REGEXP, '$');
    DEFMASK2_0_REGEXP CONSTANT VARCHAR := concat('^(', HHMMSSFS_PART_REGEXP, ')?\s*',
                                                 DAYMM_REGEXP, '\s*', MASKSEP_REGEXP, '*\s*($comp_month$)\s*', COMPYEAR_REGEXP,
                                                 '\s*(', HHMMSSFS_PART_REGEXP, ')?$');
    DEFMASK2_1_REGEXP CONSTANT VARCHAR := concat('^', DAYMM_REGEXP, '\s*', MASKSEP_REGEXP, '?\s*($comp_month$)\s*', COMPYEAR_REGEXP, '$');
    DEFMASK2_2_REGEXP CONSTANT VARCHAR := concat('^', DAYMM_REGEXP, '\s*', MASKSEP_REGEXP, '\s*($comp_month$)\s*', COMPYEAR_REGEXP, '$');
    DEFMASK3_0_REGEXP CONSTANT VARCHAR := concat('^(', HHMMSSFS_PART_REGEXP, ')?\s*',
                                                 FULLYEAR_REGEXP, '\s*', MASKSEP_REGEXP, '*\s*($comp_month$)\s*', DAYMM_REGEXP,
                                                 '\s*(', HHMMSSFS_PART_REGEXP, ')?$');
    DEFMASK3_1_REGEXP CONSTANT VARCHAR := concat('^', FULLYEAR_REGEXP, '\s*', MASKSEP_REGEXP, '?\s*($comp_month$)\s*', DAYMM_REGEXP, '$');
    DEFMASK3_2_REGEXP CONSTANT VARCHAR := concat('^', FULLYEAR_REGEXP, '\s*', MASKSEP_REGEXP, '\s*($comp_month$)\s*', DAYMM_REGEXP, '$');
    DEFMASK4_0_REGEXP CONSTANT VARCHAR := concat('^(', HHMMSSFS_PART_REGEXP, ')?\s*',
                                                 FULLYEAR_REGEXP, '\s+', DAYMM_REGEXP, '\s*', MASKSEP_REGEXP, '*\s*($comp_month$)',
                                                 '\s*(', HHMMSSFS_PART_REGEXP, ')?$');
    DEFMASK4_1_REGEXP CONSTANT VARCHAR := concat('^', FULLYEAR_REGEXP, '\s+', DAYMM_REGEXP, '\s*', MASKSEP_REGEXP, '?\s*($comp_month$)$');
    DEFMASK4_2_REGEXP CONSTANT VARCHAR := concat('^', FULLYEAR_REGEXP, '\s+', DAYMM_REGEXP, '\s*', MASKSEP_REGEXP, '\s*($comp_month$)$');
    DEFMASK5_0_REGEXP CONSTANT VARCHAR := concat('^(', HHMMSSFS_PART_REGEXP, ')?\s*',
                                                 DAYMM_REGEXP, '\s+', COMPYEAR_REGEXP, '\s*', MASKSEP_REGEXP, '*\s*($comp_month$)',
                                                 '\s*(', HHMMSSFS_PART_REGEXP, ')?$');
    DEFMASK5_1_REGEXP CONSTANT VARCHAR := concat('^', DAYMM_REGEXP, '\s+', COMPYEAR_REGEXP, '\s*', MASKSEP_REGEXP, '?\s*($comp_month$)$');
    DEFMASK5_2_REGEXP CONSTANT VARCHAR := concat('^', DAYMM_REGEXP, '\s+', COMPYEAR_REGEXP, '\s*', MASKSEP_REGEXP, '\s*($comp_month$)$');
    DEFMASK6_0_REGEXP CONSTANT VARCHAR := concat('^(', HHMMSSFS_PART_REGEXP, ')?\s*',
                                                 MASKSEP_REGEXP, '*\s*($comp_month$)\s*', FULLYEAR_REGEXP, '\s+', DAYMM_REGEXP,
                                                 '\s*(', HHMMSSFS_PART_REGEXP, ')?$');
    DEFMASK6_1_REGEXP CONSTANT VARCHAR := concat('^', MASKSEP_REGEXP, '?\s*($comp_month$)\s*', FULLYEAR_REGEXP, '\s+', DAYMM_REGEXP, '$');
    DEFMASK6_2_REGEXP CONSTANT VARCHAR := concat('^', MASKSEP_REGEXP, '\s*($comp_month$)\s*', FULLYEAR_REGEXP, '\s+', DAYMM_REGEXP, '$');
    DEFMASK7_0_REGEXP CONSTANT VARCHAR := concat('^(', HHMMSSFS_PART_REGEXP, ')?\s*',
                                                 MASKSEP_REGEXP, '*\s*($comp_month$)\s*', DAYMM_REGEXP, '\s*,\s*', COMPYEAR_REGEXP,
                                                 '\s*(', HHMMSSFS_PART_REGEXP, ')?$');
    DEFMASK7_1_REGEXP CONSTANT VARCHAR := concat('^', MASKSEP_REGEXP, '?\s*($comp_month$)\s*', DAYMM_REGEXP, '\s*,\s*', COMPYEAR_REGEXP, '$');
    DEFMASK7_2_REGEXP CONSTANT VARCHAR := concat('^', MASKSEP_REGEXP, '\s*($comp_month$)\s*', DAYMM_REGEXP, '\s*,\s*', COMPYEAR_REGEXP, '$');
    DEFMASK8_0_REGEXP CONSTANT VARCHAR := concat('^(', HHMMSSFS_PART_REGEXP, ')?\s*',
                                                 FULLYEAR_REGEXP, '\s*', MASKSEP_REGEXP, '*\s*($comp_month$)',
                                                 '\s*(', HHMMSSFS_PART_REGEXP, ')?$');
    DEFMASK8_1_REGEXP CONSTANT VARCHAR := concat('^', FULLYEAR_REGEXP, '\s*', MASKSEP_REGEXP, '?\s*($comp_month$)$');
    DEFMASK8_2_REGEXP CONSTANT VARCHAR := concat('^', FULLYEAR_REGEXP, '\s*', MASKSEP_REGEXP, '\s*($comp_month$)$');
    DEFMASK9_0_REGEXP CONSTANT VARCHAR := concat('^(', HHMMSSFS_PART_REGEXP, ')?\s*',
                                                 MASKSEP_REGEXP, '*\s*($comp_month$)\s*', FULLYEAR_REGEXP,
                                                 '\s*(', HHMMSSFS_PART_REGEXP, ')?$');
    DEFMASK9_1_REGEXP CONSTANT VARCHAR := concat('^', MASKSEP_REGEXP, '?\s*($comp_month$)\s*', FULLYEAR_REGEXP, '$');
    DEFMASK9_2_REGEXP CONSTANT VARCHAR := concat('^', MASKSEP_REGEXP, '\s*($comp_month$)\s*', FULLYEAR_REGEXP, '$');
    DEFMASK10_0_REGEXP CONSTANT VARCHAR := concat('^(', HHMMSSFS_PART_REGEXP, ')?\s*',
                                                  DAYMM_REGEXP, '\s*', MASKSEP_REGEXP, '\s*($comp_month$)\s*', MASKSEP_REGEXP, '\s*', COMPYEAR_REGEXP,
                                                  '\s*(', HHMMSSFS_PART_REGEXP, ')?$');
    DEFMASK10_1_REGEXP CONSTANT VARCHAR := concat('^', DAYMM_REGEXP, '\s*', MASKSEP_REGEXP, '\s*($comp_month$)\s*', MASKSEP_REGEXP, '\s*', COMPYEAR_REGEXP, '$');
    DOT_SLASH_DASH_COMPYEAR1_0_REGEXP CONSTANT VARCHAR := concat('^(', HHMMSSFS_PART_REGEXP, ')?\s*',
                                                                 DAYMM_REGEXP, '\s*(?:\.|/|-)\s*', DAYMM_REGEXP, '\s*(?:\.|/|-)\s*', COMPYEAR_REGEXP,
                                                                 '\s*(', HHMMSSFS_PART_REGEXP, ')?$');
    DOT_SLASH_DASH_COMPYEAR1_1_REGEXP CONSTANT VARCHAR := concat('^', DAYMM_REGEXP, '\s*', MASKSEP_REGEXP, '\s*', DAYMM_REGEXP, '\s*', MASKSEP_REGEXP, '\s*', COMPYEAR_REGEXP, '$');
    DOT_SLASH_DASH_SHORTYEAR_REGEXP CONSTANT VARCHAR := concat('^', DAYMM_REGEXP, '\s*', MASKSEP_REGEXP, '\s*', DAYMM_REGEXP, '\s*', MASKSEP_REGEXP, '\s*', SHORTYEAR_REGEXP, '$');
    DOT_SLASH_DASH_FULLYEAR1_0_REGEXP CONSTANT VARCHAR := concat('^(', HHMMSSFS_PART_REGEXP, ')?\s*',
                                                                 DAYMM_REGEXP, '\s*(?:\.|/|-)\s*', DAYMM_REGEXP, '\s*(?:\.|/|-)\s*', FULLYEAR_REGEXP,
                                                                 '\s*(', HHMMSSFS_PART_REGEXP, ')?$');
    DOT_SLASH_DASH_FULLYEAR1_1_REGEXP CONSTANT VARCHAR := concat('^', DAYMM_REGEXP, '\s*', MASKSEP_REGEXP, '\s*', DAYMM_REGEXP, '\s*', MASKSEP_REGEXP, '\s*', FULLYEAR_REGEXP, '$');
    FULLYEAR_DOT_SLASH_DASH1_0_REGEXP CONSTANT VARCHAR := concat('^(', HHMMSSFS_PART_REGEXP, ')?\s*',
                                                                 FULLYEAR_REGEXP, '\s*', MASKSEP_REGEXP, '\s*', DAYMM_REGEXP, '\s*', MASKSEP_REGEXP, '\s*', DAYMM_REGEXP,
                                                                 '\s*(', HHMMSSFS_PART_REGEXP, ')?$');
    FULLYEAR_DOT_SLASH_DASH1_1_REGEXP CONSTANT VARCHAR := concat('^', FULLYEAR_REGEXP, '\s*', MASKSEP_REGEXP, '\s*', DAYMM_REGEXP, '\s*', MASKSEP_REGEXP, '\s*', DAYMM_REGEXP, '$');
    SHORT_DIGITMASK1_0_REGEXP CONSTANT VARCHAR := concat('^(', HHMMSSFS_PART_REGEXP, ')?\s*\d{6}\s*(', HHMMSSFS_PART_REGEXP, ')?$');
    FULL_DIGITMASK1_0_REGEXP CONSTANT VARCHAR := concat('^(', HHMMSSFS_PART_REGEXP, ')?\s*\d{8}\s*(', HHMMSSFS_PART_REGEXP, ')?$');
BEGIN
    v_datatype := trim(p_datatype);
    v_datetimestring := upper(trim(p_datetimestring));
    v_style := floor(p_style)::SMALLINT;

    v_datatype_groups := regexp_matches(v_datatype, DATATYPE_REGEXP, 'gi');

    v_res_datatype := upper(v_datatype_groups[1]);
    v_scale := v_datatype_groups[2]::SMALLINT;

    IF (v_res_datatype IS NULL) THEN
        RAISE datatype_mismatch;
    ELSIF (v_res_datatype <> 'DATETIME2' AND v_scale IS NOT NULL)
    THEN
        RAISE invalid_indicator_parameter_value;
    ELSIF (coalesce(v_scale, 0) NOT BETWEEN 0 AND 7)
    THEN
        RAISE interval_field_overflow;
    ELSIF (v_scale IS NULL) THEN
        v_scale := 7;
    END IF;

    IF (scale(p_style) > 0) THEN
        RAISE most_specific_type_mismatch;
    ELSIF (NOT ((v_style BETWEEN 0 AND 14) OR
             (v_style BETWEEN 20 AND 25) OR
             (v_style BETWEEN 100 AND 114) OR
             (v_style IN (120, 121, 126, 127, 130, 131))) AND
             v_res_datatype = 'DATETIME2')
    THEN
        RAISE invalid_parameter_value;
    END IF;

    v_timepart := trim(substring(v_datetimestring, HHMMSSFS_PART_REGEXP));
    v_datestring := trim(regexp_replace(v_datetimestring, HHMMSSFS_PART_REGEXP, '', 'gi'));

    BEGIN
        v_lang_metadata_json := aws_sqlserver_ext.get_lang_metadata_json(CONVERSION_LANG);
    EXCEPTION
        WHEN OTHERS THEN
        RAISE invalid_escape_sequence;
    END;

    v_date_format := coalesce(nullif(DATE_FORMAT, ''), v_lang_metadata_json ->> 'date_format');

    v_compmonth_regexp := array_to_string(array_cat(ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'months_shortnames')),
                                                    ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'months_names'))), '|');

    IF (v_datetimestring ~* replace(DEFMASK1_0_REGEXP, '$comp_month$', v_compmonth_regexp) OR
        v_datetimestring ~* replace(DEFMASK2_0_REGEXP, '$comp_month$', v_compmonth_regexp) OR
        v_datetimestring ~* replace(DEFMASK3_0_REGEXP, '$comp_month$', v_compmonth_regexp) OR
        v_datetimestring ~* replace(DEFMASK4_0_REGEXP, '$comp_month$', v_compmonth_regexp) OR
        v_datetimestring ~* replace(DEFMASK5_0_REGEXP, '$comp_month$', v_compmonth_regexp) OR
        v_datetimestring ~* replace(DEFMASK6_0_REGEXP, '$comp_month$', v_compmonth_regexp) OR
        v_datetimestring ~* replace(DEFMASK7_0_REGEXP, '$comp_month$', v_compmonth_regexp) OR
        v_datetimestring ~* replace(DEFMASK8_0_REGEXP, '$comp_month$', v_compmonth_regexp) OR
        v_datetimestring ~* replace(DEFMASK9_0_REGEXP, '$comp_month$', v_compmonth_regexp) OR
        v_datetimestring ~* replace(DEFMASK10_0_REGEXP, '$comp_month$', v_compmonth_regexp))
    THEN
        IF ((v_style IN (127, 130, 131) AND v_res_datatype IN ('DATETIME', 'SMALLDATETIME')) OR
            (v_style IN (130, 131) AND v_res_datatype = 'DATETIME2'))
        THEN
            RAISE invalid_datetime_format;
        END IF;

        IF ((v_datestring ~* replace(DEFMASK1_2_REGEXP, '$comp_month$', v_compmonth_regexp) OR
             v_datestring ~* replace(DEFMASK2_2_REGEXP, '$comp_month$', v_compmonth_regexp) OR
             v_datestring ~* replace(DEFMASK3_2_REGEXP, '$comp_month$', v_compmonth_regexp) OR
             v_datestring ~* replace(DEFMASK4_2_REGEXP, '$comp_month$', v_compmonth_regexp) OR
             v_datestring ~* replace(DEFMASK5_2_REGEXP, '$comp_month$', v_compmonth_regexp) OR
             v_datestring ~* replace(DEFMASK6_2_REGEXP, '$comp_month$', v_compmonth_regexp) OR
             v_datestring ~* replace(DEFMASK7_2_REGEXP, '$comp_month$', v_compmonth_regexp) OR
             v_datestring ~* replace(DEFMASK8_2_REGEXP, '$comp_month$', v_compmonth_regexp) OR
             v_datestring ~* replace(DEFMASK9_2_REGEXP, '$comp_month$', v_compmonth_regexp)) AND
            v_res_datatype = 'DATETIME2')
        THEN
            RAISE invalid_datetime_format;
        END IF;

        IF (v_datestring ~* replace(DEFMASK1_1_REGEXP, '$comp_month$', v_compmonth_regexp))
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, replace(DEFMASK1_1_REGEXP, '$comp_month$', v_compmonth_regexp), 'gi');
            v_day := v_regmatch_groups[2];
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[1], v_lang_metadata_json);
            v_year := aws_sqlserver_ext.get_full_year(v_regmatch_groups[3]);

        ELSIF (v_datestring ~* replace(DEFMASK2_1_REGEXP, '$comp_month$', v_compmonth_regexp))
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, replace(DEFMASK2_1_REGEXP, '$comp_month$', v_compmonth_regexp), 'gi');
            v_day := v_regmatch_groups[1];
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
            v_year := aws_sqlserver_ext.get_full_year(v_regmatch_groups[3]);

        ELSIF (v_datestring ~* replace(DEFMASK3_1_REGEXP, '$comp_month$', v_compmonth_regexp))
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, replace(DEFMASK3_1_REGEXP, '$comp_month$', v_compmonth_regexp), 'gi');
            v_day := v_regmatch_groups[3];
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
            v_year := v_regmatch_groups[1];

        ELSIF (v_datestring ~* replace(DEFMASK4_1_REGEXP, '$comp_month$', v_compmonth_regexp))
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, replace(DEFMASK4_1_REGEXP, '$comp_month$', v_compmonth_regexp), 'gi');
            v_day := v_regmatch_groups[2];
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[3], v_lang_metadata_json);
            v_year := v_regmatch_groups[1];

        ELSIF (v_datestring ~* replace(DEFMASK5_1_REGEXP, '$comp_month$', v_compmonth_regexp))
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, replace(DEFMASK5_1_REGEXP, '$comp_month$', v_compmonth_regexp), 'gi');
            v_day := v_regmatch_groups[1];
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[3], v_lang_metadata_json);
            v_year := aws_sqlserver_ext.get_full_year(v_regmatch_groups[2]);

        ELSIF (v_datestring ~* replace(DEFMASK6_1_REGEXP, '$comp_month$', v_compmonth_regexp))
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, replace(DEFMASK6_1_REGEXP, '$comp_month$', v_compmonth_regexp), 'gi');
            v_day := v_regmatch_groups[3];
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[1], v_lang_metadata_json);
            v_year := v_regmatch_groups[2];

        ELSIF (v_datestring ~* replace(DEFMASK7_1_REGEXP, '$comp_month$', v_compmonth_regexp))
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, replace(DEFMASK7_1_REGEXP, '$comp_month$', v_compmonth_regexp), 'gi');
            v_day := v_regmatch_groups[2];
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[1], v_lang_metadata_json);
            v_year := aws_sqlserver_ext.get_full_year(v_regmatch_groups[3]);

        ELSIF (v_datestring ~* replace(DEFMASK8_1_REGEXP, '$comp_month$', v_compmonth_regexp))
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, replace(DEFMASK8_1_REGEXP, '$comp_month$', v_compmonth_regexp), 'gi');
            v_day := '01';
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
            v_year := v_regmatch_groups[1];

        ELSIF (v_datestring ~* replace(DEFMASK9_1_REGEXP, '$comp_month$', v_compmonth_regexp))
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, replace(DEFMASK9_1_REGEXP, '$comp_month$', v_compmonth_regexp), 'gi');
            v_day := '01';
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[1], v_lang_metadata_json);
            v_year := v_regmatch_groups[2];

        ELSIF (v_datestring ~* replace(DEFMASK10_1_REGEXP, '$comp_month$', v_compmonth_regexp))
        THEN
            v_regmatch_groups := regexp_matches(v_datestring, replace(DEFMASK10_1_REGEXP, '$comp_month$', v_compmonth_regexp), 'gi');
            v_day := v_regmatch_groups[1];
            v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
            v_year := aws_sqlserver_ext.get_full_year(v_regmatch_groups[3]);
        ELSE
            RAISE invalid_character_value_for_cast;
        END IF;
    ELSIF (v_datetimestring ~* DOT_SLASH_DASH_COMPYEAR1_0_REGEXP)
    THEN
        IF (v_style IN (6, 7, 8, 9, 12, 13, 14, 24, 100, 106, 107, 108, 109, 112, 113, 114, 130) AND
            v_res_datatype = 'DATETIME2')
        THEN
            RAISE invalid_regular_expression;
        END IF;

        v_regmatch_groups := regexp_matches(v_datestring, DOT_SLASH_DASH_COMPYEAR1_1_REGEXP, 'gi');
        v_leftpart := v_regmatch_groups[1];
        v_middlepart := v_regmatch_groups[2];
        v_rightpart := v_regmatch_groups[3];

        IF (v_datestring ~* DOT_SLASH_DASH_SHORTYEAR_REGEXP)
        THEN
            IF ((v_style NOT IN (0, 1, 2, 3, 4, 5, 10, 11) AND v_res_datatype IN ('DATETIME', 'SMALLDATETIME')) OR
                (v_style NOT IN (0, 1, 2, 3, 4, 5, 10, 11, 12) AND v_res_datatype = 'DATETIME2'))
            THEN
                RAISE invalid_datetime_format;
            END IF;

            IF ((v_style IN (1, 10) AND v_date_format <> 'MDY' AND v_res_datatype IN ('DATETIME', 'SMALLDATETIME')) OR
                (v_style IN (0, 1, 10) AND v_date_format NOT IN ('DMY', 'DYM', 'MYD', 'YMD', 'YDM') AND v_res_datatype IN ('DATETIME', 'SMALLDATETIME')) OR
                (v_style IN (0, 1, 10, 22) AND v_date_format NOT IN ('DMY', 'DYM', 'MYD', 'YMD', 'YDM') AND v_res_datatype = 'DATETIME2') OR
                (v_style IN (1, 10, 22) AND v_date_format IN ('DMY', 'DYM', 'MYD', 'YMD', 'YDM') AND v_res_datatype = 'DATETIME2'))
            THEN
                v_day := v_middlepart;
                v_month := v_leftpart;
                v_year := aws_sqlserver_ext.get_full_year(v_rightpart);

            ELSIF ((v_style IN (2, 11) AND v_date_format <> 'YMD') OR
                   (v_style IN (0, 2, 11) AND v_date_format = 'YMD'))
            THEN
                v_day := v_rightpart;
                v_month := v_middlepart;
                v_year := aws_sqlserver_ext.get_full_year(v_leftpart);

            ELSIF ((v_style IN (3, 4, 5) AND v_date_format <> 'DMY') OR
                   (v_style IN (0, 3, 4, 5) AND v_date_format = 'DMY'))
            THEN
                v_day := v_leftpart;
                v_month := v_middlepart;
                v_year := aws_sqlserver_ext.get_full_year(v_rightpart);

            ELSIF (v_style = 0 AND v_date_format = 'DYM')
            THEN
                v_day = v_leftpart;
                v_month = v_rightpart;
                v_year = aws_sqlserver_ext.get_full_year(v_middlepart);

            ELSIF (v_style = 0 AND v_date_format = 'MYD')
            THEN
                v_day := v_rightpart;
                v_month := v_leftpart;
                v_year = aws_sqlserver_ext.get_full_year(v_middlepart);

            ELSIF (v_style = 0 AND v_date_format = 'YDM')
            THEN
                IF (v_res_datatype = 'DATETIME2') THEN
                    RAISE character_not_in_repertoire;
                END IF;

                v_day := v_middlepart;
                v_month := v_rightpart;
                v_year := aws_sqlserver_ext.get_full_year(v_leftpart);
            ELSE
                RAISE invalid_character_value_for_cast;
            END IF;
        ELSIF (v_datestring ~* DOT_SLASH_DASH_FULLYEAR1_1_REGEXP)
        THEN
            IF (v_style NOT IN (0, 20, 21, 101, 102, 103, 104, 105, 110, 111, 120, 121, 130, 131) AND
                v_res_datatype IN ('DATETIME', 'SMALLDATETIME'))
            THEN
                RAISE invalid_datetime_format;
            ELSIF (v_style IN (130, 131) AND v_res_datatype = 'SMALLDATETIME') THEN
                RAISE invalid_character_value_for_cast;
            END IF;

            v_year := v_rightpart;
            IF (v_leftpart::SMALLINT <= 12)
            THEN
                IF ((v_style IN (103, 104, 105, 130, 131) AND v_date_format NOT IN ('DMY', 'DYM', 'YDM')) OR
                    (v_style IN (0, 103, 104, 105, 130, 131) AND ((v_date_format = 'DMY' AND v_res_datatype = 'DATETIME2') OR
                    (v_date_format IN ('DMY', 'DYM', 'YDM') AND v_res_datatype <> 'DATETIME2'))) OR
                    (v_style IN (103, 104, 105, 130, 131) AND v_date_format IN ('DMY', 'DYM', 'YDM') AND v_res_datatype = 'DATETIME2'))
                THEN
                    v_day := v_leftpart;
                    v_month := v_middlepart;

                ELSIF ((v_style IN (20, 21, 101, 102, 110, 111, 120, 121) AND v_date_format IN ('DMY', 'DYM', 'YDM') AND v_res_datatype IN ('DATETIME', 'SMALLDATETIME')) OR
                       (v_style IN (0, 20, 21, 101, 102, 110, 111, 120, 121) AND v_date_format NOT IN ('DMY', 'DYM', 'YDM') AND v_res_datatype IN ('DATETIME', 'SMALLDATETIME')) OR
                       (v_style IN (101, 110) AND v_date_format IN ('DMY', 'DYM', 'MYD', 'YDM') AND v_res_datatype = 'DATETIME2') OR
                       (v_style IN (0, 101, 110) AND v_date_format NOT IN ('DMY', 'DYM', 'MYD', 'YDM') AND v_res_datatype = 'DATETIME2'))
                THEN
                    v_day := v_middlepart;
                    v_month := v_leftpart;
                END IF;
            ELSE
                IF ((v_style IN (103, 104, 105, 130, 131) AND v_date_format NOT IN ('DMY', 'DYM', 'YDM')) OR
                    (v_style IN (0, 103, 104, 105, 130, 131) AND ((v_date_format = 'DMY' AND v_res_datatype = 'DATETIME2') OR
                    (v_date_format IN ('DMY', 'DYM', 'YDM') AND v_res_datatype <> 'DATETIME2'))) OR
                    (v_style IN (103, 104, 105, 130, 131) AND v_date_format IN ('DMY', 'DYM', 'YDM') AND v_res_datatype = 'DATETIME2'))
                THEN
                    v_day := v_leftpart;
                    v_month := v_middlepart;
                ELSE
                    IF (v_res_datatype = 'DATETIME2') THEN
                        RAISE invalid_datetime_format;
                    END IF;

                    RAISE invalid_character_value_for_cast;
                END IF;
            END IF;
        END IF;
    ELSIF (v_datetimestring ~* FULLYEAR_DOT_SLASH_DASH1_0_REGEXP)
    THEN
        IF (v_style NOT IN (0, 20, 21, 101, 102, 103, 104, 105, 110, 111, 120, 121, 130, 131) AND
            v_res_datatype IN ('DATETIME', 'SMALLDATETIME'))
        THEN
            RAISE invalid_datetime_format;
        ELSIF (v_style IN (6, 7, 8, 9, 12, 13, 14, 24, 100, 106, 107, 108, 109, 112, 113, 114, 130) AND
            v_res_datatype = 'DATETIME2')
        THEN
            RAISE invalid_regular_expression;
        ELSIF (v_style IN (130, 131) AND v_res_datatype = 'SMALLDATETIME')
        THEN
            RAISE invalid_character_value_for_cast;
        END IF;

        v_regmatch_groups := regexp_matches(v_datestring, FULLYEAR_DOT_SLASH_DASH1_1_REGEXP, 'gi');
        v_year := v_regmatch_groups[1];
        v_middlepart := v_regmatch_groups[2];
        v_rightpart := v_regmatch_groups[3];

        IF ((v_res_datatype IN ('DATETIME', 'SMALLDATETIME') AND v_rightpart::SMALLINT <= 12) OR v_res_datatype = 'DATETIME2')
        THEN
            IF ((v_style IN (20, 21, 101, 102, 110, 111, 120, 121) AND v_date_format IN ('DMY', 'DYM', 'YDM') AND v_res_datatype <> 'DATETIME2') OR
                (v_style IN (0, 20, 21, 101, 102, 110, 111, 120, 121) AND v_date_format NOT IN ('DMY', 'DYM', 'YDM') AND v_res_datatype <> 'DATETIME2') OR                
                (v_style IN (0, 20, 21, 23, 25, 101, 102, 110, 111, 120, 121, 126, 127) AND v_res_datatype = 'DATETIME2'))
            THEN
                v_day := v_rightpart;
                v_month := v_middlepart;

            ELSIF ((v_style IN (103, 104, 105, 130, 131) AND v_date_format NOT IN ('DMY', 'DYM', 'YDM')) OR
                    v_style IN (0, 103, 104, 105, 130, 131) AND v_date_format IN ('DMY', 'DYM', 'YDM'))
            THEN
                v_day := v_middlepart;
                v_month := v_rightpart;
            END IF;
        ELSIF (v_res_datatype IN ('DATETIME', 'SMALLDATETIME') AND v_rightpart::SMALLINT > 12)
        THEN
            IF ((v_style IN (20, 21, 101, 102, 110, 111, 120, 121) AND v_date_format IN ('DMY', 'DYM', 'YDM')) OR
                (v_style IN (0, 20, 21, 101, 102, 110, 111, 120, 121) AND v_date_format NOT IN ('DMY', 'DYM', 'YDM')))
            THEN
                v_day := v_rightpart;
                v_month := v_middlepart;

            ELSIF ((v_style IN (103, 104, 105, 130, 131) AND v_date_format NOT IN ('DMY', 'DYM', 'YDM')) OR
                   (v_style IN (0, 103, 104, 105, 130, 131) AND v_date_format IN ('DMY', 'DYM', 'YDM')))
            THEN
                RAISE invalid_character_value_for_cast;
            END IF;
        END IF;
    ELSIF (v_datetimestring ~* SHORT_DIGITMASK1_0_REGEXP OR
           v_datetimestring ~* FULL_DIGITMASK1_0_REGEXP)
    THEN
        IF (v_style = 127 AND v_res_datatype <> 'DATETIME2')
        THEN
            RAISE invalid_datetime_format;
        ELSIF (v_style IN (130, 131) AND v_res_datatype = 'SMALLDATETIME')
        THEN
            RAISE invalid_character_value_for_cast;
        END IF;

        IF (v_datestring ~* '^\d{6}$')
        THEN
            v_day := substr(v_datestring, 5, 2);
            v_month := substr(v_datestring, 3, 2);
            v_year := aws_sqlserver_ext.get_full_year(substr(v_datestring, 1, 2));

        ELSIF (v_datestring ~* '^\d{8}$')
        THEN
            v_day := substr(v_datestring, 7, 2);
            v_month := substr(v_datestring, 5, 2);
            v_year := substr(v_datestring, 1, 4);
        END IF;
    ELSIF (v_datetimestring ~* HHMMSSFS_REGEXP)
    THEN
        v_day := '01';
        v_month := '01';
        v_year := '1900';
    ELSE
        RAISE invalid_datetime_format;
    END IF;

    IF (((v_datetimestring ~* HHMMSSFS_PART_REGEXP AND v_res_datatype = 'DATETIME2') OR
        (v_datetimestring ~* SHORT_DIGITMASK1_0_REGEXP OR v_datetimestring ~* FULL_DIGITMASK1_0_REGEXP OR
          v_datetimestring ~* FULLYEAR_DOT_SLASH_DASH1_0_REGEXP OR v_datetimestring ~* DOT_SLASH_DASH_FULLYEAR1_0_REGEXP)) AND
        v_style IN (130, 131))
    THEN
        v_hijridate := aws_sqlserver_ext.conv_hijri_to_greg(v_day, v_month, v_year) - 1;
        v_day = to_char(v_hijridate, 'DD');
        v_month = to_char(v_hijridate, 'MM');
        v_year = to_char(v_hijridate, 'YYYY');
    END IF;

    v_hours := coalesce(aws_sqlserver_ext.get_timeunit_from_string(v_timepart, 'HOURS'), '0');
    v_minutes := coalesce(aws_sqlserver_ext.get_timeunit_from_string(v_timepart, 'MINUTES'), '0');
    v_seconds := coalesce(aws_sqlserver_ext.get_timeunit_from_string(v_timepart, 'SECONDS'), '0');
    v_fseconds := coalesce(aws_sqlserver_ext.get_timeunit_from_string(v_timepart, 'FRACTSECONDS'), '0');

    IF ((v_res_datatype IN ('DATETIME', 'SMALLDATETIME') OR
         (v_res_datatype = 'DATETIME2' AND v_timepart !~* HHMMSSFS_DOT_PART_REGEXP)) AND
        char_length(v_fseconds) > 3)
    THEN
        RAISE invalid_datetime_format;
    END IF;

    BEGIN
        IF (v_res_datatype IN ('DATETIME', 'SMALLDATETIME'))
        THEN
            v_resdatetime := aws_sqlserver_ext.datetimefromparts(v_year, v_month, v_day,
                                                                 v_hours, v_minutes, v_seconds,
                                                                 rpad(v_fseconds, 3, '0'));
            IF (v_res_datatype = 'SMALLDATETIME' AND
                to_char(v_resdatetime, 'SS') <> '00')
            THEN
                IF (to_char(v_resdatetime, 'SS')::SMALLINT >= 30) THEN
                    v_resdatetime := v_resdatetime + INTERVAL '1 minute';
                END IF;

                v_resdatetime := to_timestamp(to_char(v_resdatetime, 'DD.MM.YYYY.HH24.MI'), 'DD.MM.YYYY.HH24.MI');
            END IF;
        ELSIF (v_res_datatype = 'DATETIME2')
        THEN
            v_fseconds := aws_sqlserver_ext.get_microsecs_from_fractsecs(v_fseconds, v_scale);
            v_seconds := concat_ws('.', v_seconds, v_fseconds);

            v_resdatetime := make_timestamp(v_year::SMALLINT, v_month::SMALLINT, v_day::SMALLINT,
                                            v_hours::SMALLINT, v_minutes::SMALLINT, v_seconds::NUMERIC);
        END IF;
    EXCEPTION
        WHEN datetime_field_overflow THEN
            RAISE invalid_datetime_format;
        WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;

        IF (v_err_message ~* 'Cannot construct data type') THEN
            RAISE invalid_character_value_for_cast;
        END IF;
    END;

    RETURN v_resdatetime;
EXCEPTION
    WHEN most_specific_type_mismatch THEN
        RAISE USING MESSAGE := 'Argument data type NUMERIC is invalid for argument 3 of conv_string_to_datetime function.',
                    DETAIL := 'Use of incorrect "style" parameter value during conversion process.',
                    HINT := 'Change "style" parameter to the proper value and try again.';

    WHEN invalid_parameter_value THEN
        RAISE USING MESSAGE := format('The style %s is not supported for conversions from VARCHAR to %s.', v_style, v_res_datatype),
                    DETAIL := 'Use of incorrect "style" parameter value during conversion process.',
                    HINT := 'Change "style" parameter to the proper value and try again.';

    WHEN invalid_regular_expression THEN
        RAISE USING MESSAGE := format('The input character string doesn''t follow style %s.', v_style),
                    DETAIL := 'Selected "style" param value isn''t valid for conversion of passed character string.',
                    HINT := 'Either change the input character string or use a different style.';

    WHEN datatype_mismatch THEN
        RAISE USING MESSAGE := 'Data type should be one of these values: ''DATETIME'', ''SMALLDATETIME'', ''DATETIME2''/''DATETIME2(n)''.',
                    DETAIL := 'Use of incorrect "datatype" parameter value during conversion process.',
                    HINT := 'Change "datatype" parameter to the proper value and try again.';

    WHEN invalid_indicator_parameter_value THEN
        RAISE USING MESSAGE := format('Invalid attributes specified for data type %s.', v_res_datatype),
                    DETAIL := 'Use of incorrect scale value, which is not corresponding to specified data type.',
                    HINT := 'Change data type scale component or select different data type and try again.';

    WHEN interval_field_overflow THEN
        RAISE USING MESSAGE := format('Specified scale %s is invalid.', v_scale),
                    DETAIL := 'Use of incorrect data type scale value during conversion process.',
                    HINT := 'Change scale component of data type parameter to be in range [0..7] and try again.';

    WHEN invalid_datetime_format THEN
        RAISE USING MESSAGE := CASE v_res_datatype
                                  WHEN 'SMALLDATETIME' THEN 'Conversion failed when converting character string to SMALLDATETIME data type.'
                                  ELSE 'Conversion failed when converting date and time from character string.'
                               END,
                    DETAIL := 'Incorrect using of pair of input parameters values during conversion process.',
                    HINT := 'Check the input parameters values, correct them if needed, and try again.';

    WHEN invalid_character_value_for_cast THEN
        RAISE USING MESSAGE := 'The conversion of a VARCHAR data type to a DATETIME data type resulted in an out-of-range value.',
                    DETAIL := 'Use of incorrect pair of input parameter values during conversion process.',
                    HINT := 'Check input parameter values, correct them if needed, and try again.';

    WHEN character_not_in_repertoire THEN
        RAISE USING MESSAGE := 'The YDM date format isn''t supported when converting from this string format to date and time.',
                    DETAIL := 'Use of incorrect DATE_FORMAT constant value regarding string format parameter during conversion process.',
                    HINT := 'Change DATE_FORMAT constant to one of these values: MDY|DMY|DYM, recompile function and try again.';

    WHEN invalid_escape_sequence THEN
        RAISE USING MESSAGE := format('Invalid CONVERSION_LANG constant value - ''%s''. Allowed values are: ''English'', ''Deutsch'', etc.',
                                      CONVERSION_LANG),
                    DETAIL := 'Compiled incorrect CONVERSION_LANG constant value in function''s body.',
                    HINT := 'Correct CONVERSION_LANG constant value in function''s body, recompile it and try again.';

    WHEN invalid_text_representation THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
        v_err_message := substring(lower(v_err_message), 'integer\:\s\"(.*)\"');

        RAISE USING MESSAGE := format('Error while trying to convert "%s" value to SMALLINT data type.',
                                      v_err_message),
                    DETAIL := 'Passed argument value contains illegal characters.',
                    HINT := 'Correct passed argument value, remove all illegal characters.';
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.conv_string_to_datetime(p_datatype text, p_datetimestring text, p_style numeric) OWNER TO postgres;

--
-- TOC entry 3876 (class 0 OID 0)
-- Dependencies: 390
-- Name: FUNCTION conv_string_to_datetime(p_datatype text, p_datetimestring text, p_style numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.conv_string_to_datetime(p_datatype text, p_datetimestring text, p_style numeric) IS 'This function parses the TEXT string and converts it into a DATETIME value, according to specified style (conversion mask).';


--
-- TOC entry 391 (class 1255 OID 17059)
-- Name: conv_string_to_time(text, text, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.conv_string_to_time(p_datatype text, p_timestring text, p_style numeric DEFAULT 0) RETURNS time without time zone
    LANGUAGE plpgsql STRICT
    AS $_$
DECLARE
    v_hours SMALLINT;
    v_style SMALLINT;
    v_scale SMALLINT;
    v_daypart VARCHAR;
    v_seconds VARCHAR;
    v_minutes SMALLINT;
    v_fseconds VARCHAR;
    v_datatype VARCHAR;
    v_timestring VARCHAR;
    v_err_message VARCHAR;
    v_src_datatype VARCHAR;
    v_timeunit_mask VARCHAR;
    v_datatype_groups TEXT[];
    v_regmatch_groups TEXT[];
    AMPM_REGEXP CONSTANT VARCHAR := '\s*([AP]M)';
    TIMEUNIT_REGEXP CONSTANT VARCHAR := '\s*(\d{1,2})\s*';
    FRACTSECS_REGEXP CONSTANT VARCHAR := '\s*(\d{1,9})';
    HHMMSSFS_REGEXP CONSTANT VARCHAR := concat('^', TIMEUNIT_REGEXP,
                                               '\:', TIMEUNIT_REGEXP,
                                               '\:', TIMEUNIT_REGEXP,
                                               '(?:\.|\:)', FRACTSECS_REGEXP, '$');
    HHMMSS_REGEXP CONSTANT VARCHAR := concat('^', TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '$');
    HHMMFS_REGEXP CONSTANT VARCHAR := concat('^', TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '\.', FRACTSECS_REGEXP, '$');
    HHMM_REGEXP CONSTANT VARCHAR := concat('^', TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '$');
    HH_REGEXP CONSTANT VARCHAR := concat('^', TIMEUNIT_REGEXP, '$');
    DATATYPE_REGEXP CONSTANT VARCHAR := '^(TIME)\s*(?:\()?\s*((?:-)?\d+)?\s*(?:\))?$';
BEGIN
    v_datatype := trim(regexp_replace(p_datatype, 'DATETIME', 'TIME', 'gi'));
    v_timestring := upper(trim(p_timestring));
    v_style := floor(p_style)::SMALLINT;

    v_datatype_groups := regexp_matches(v_datatype, DATATYPE_REGEXP, 'gi');

    v_src_datatype := upper(v_datatype_groups[1]);
    v_scale := v_datatype_groups[2]::SMALLINT;

    IF (v_src_datatype IS NULL) THEN
        RAISE datatype_mismatch;
    ELSIF (coalesce(v_scale, 0) NOT BETWEEN 0 AND 7)
    THEN
        RAISE interval_field_overflow;
    ELSIF (v_scale IS NULL) THEN
        v_scale := 7;
    END IF;

    IF (scale(p_style) > 0) THEN
        RAISE most_specific_type_mismatch;
    ELSIF (NOT ((v_style BETWEEN 0 AND 14) OR
             (v_style BETWEEN 20 AND 25) OR
             (v_style BETWEEN 100 AND 114) OR
             v_style IN (120, 121, 126, 127, 130, 131)))
    THEN
        RAISE invalid_parameter_value;
    END IF;

    v_daypart := substring(v_timestring, 'AM|PM');
    v_timestring := trim(regexp_replace(v_timestring, coalesce(v_daypart, ''), ''));

    v_timeunit_mask :=
        CASE
           WHEN (v_timestring ~* HHMMSSFS_REGEXP) THEN HHMMSSFS_REGEXP
           WHEN (v_timestring ~* HHMMSS_REGEXP) THEN HHMMSS_REGEXP
           WHEN (v_timestring ~* HHMMFS_REGEXP) THEN HHMMFS_REGEXP
           WHEN (v_timestring ~* HHMM_REGEXP) THEN HHMM_REGEXP
           WHEN (v_timestring ~* HH_REGEXP) THEN HH_REGEXP
        END;

    IF (v_timeunit_mask IS NULL) THEN
        RAISE invalid_datetime_format;
    END IF;

    v_regmatch_groups := regexp_matches(v_timestring, v_timeunit_mask, 'gi');

    v_hours := v_regmatch_groups[1]::SMALLINT;
    v_minutes := v_regmatch_groups[2]::SMALLINT;

    IF (v_timestring ~* HHMMFS_REGEXP) THEN
        v_fseconds := v_regmatch_groups[3];
    ELSE
        v_seconds := v_regmatch_groups[3];
        v_fseconds := v_regmatch_groups[4];
    END IF;

   IF (v_daypart IS NOT NULL) THEN
      IF ((v_daypart = 'AM' AND v_hours NOT BETWEEN 0 AND 12) OR
          (v_daypart = 'PM' AND v_hours NOT BETWEEN 1 AND 23))
      THEN
          RAISE numeric_value_out_of_range;
      ELSIF (v_daypart = 'PM' AND v_hours < 12) THEN
          v_hours := v_hours + 12;
      ELSIF (v_daypart = 'AM' AND v_hours = 12) THEN
          v_hours := v_hours - 12;
      END IF;
   END IF;

    v_fseconds := aws_sqlserver_ext.get_microsecs_from_fractsecs(v_fseconds, v_scale);
    v_seconds := concat_ws('.', v_seconds, v_fseconds);

    RETURN make_time(v_hours, v_minutes, v_seconds::NUMERIC);
EXCEPTION
    WHEN most_specific_type_mismatch THEN
        RAISE USING MESSAGE := 'Argument data type NUMERIC is invalid for argument 3 of conv_string_to_time function.',
                    DETAIL := 'Use of incorrect "style" parameter value during conversion process.',
                    HINT := 'Change "style" parameter to the proper value and try again.';

    WHEN invalid_parameter_value THEN
        RAISE USING MESSAGE := format('The style %s is not supported for conversions from VARCHAR to TIME.', v_style),
                    DETAIL := 'Use of incorrect "style" parameter value during conversion process.',
                    HINT := 'Change "style" parameter to the proper value and try again.';

    WHEN datatype_mismatch THEN
        RAISE USING MESSAGE := 'Source data type should be ''TIME'' or ''TIME(n)''.',
                    DETAIL := 'Use of incorrect "datatype" parameter value during conversion process.',
                    HINT := 'Change "datatype" parameter to the proper value and try again.';

    WHEN interval_field_overflow THEN
        RAISE USING MESSAGE := format('Specified scale %s is invalid.', v_scale),
                    DETAIL := 'Use of incorrect data type scale value during conversion process.',
                    HINT := 'Change scale component of data type parameter to be in range [0..7] and try again.';

    WHEN numeric_value_out_of_range THEN
        RAISE USING MESSAGE := 'Could not extract correct hour value due to it''s inconsistency with AM|PM day part mark.',
                    DETAIL := 'Extracted hour value doesn''t fall in correct day part mark range: 0..12 for "AM" or 1..23 for "PM".',
                    HINT := 'Correct a hour value in the source string or remove AM|PM day part mark out of it.';

    WHEN invalid_datetime_format THEN
        RAISE USING MESSAGE := 'Conversion failed when converting time from character string.',
                    DETAIL := 'Incorrect using of pair of input parameters values during conversion process.',
                    HINT := 'Check the input parameters values, correct them if needed, and try again.';

    WHEN invalid_text_representation THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
        v_err_message := substring(lower(v_err_message), 'integer\:\s\"(.*)\"');

        RAISE USING MESSAGE := format('Error while trying to convert "%s" value to SMALLINT data type.',
                                      v_err_message),
                    DETAIL := 'Supplied value contains illegal characters.',
                    HINT := 'Correct supplied value, remove all illegal characters.';
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.conv_string_to_time(p_datatype text, p_timestring text, p_style numeric) OWNER TO postgres;

--
-- TOC entry 3877 (class 0 OID 0)
-- Dependencies: 391
-- Name: FUNCTION conv_string_to_time(p_datatype text, p_timestring text, p_style numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.conv_string_to_time(p_datatype text, p_timestring text, p_style numeric) IS 'This function parses the TEXT string and converts it into a TIME value, according to specified style (conversion mask).';


--
-- TOC entry 388 (class 1255 OID 17053)
-- Name: conv_time_to_string(text, text, time without time zone, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.conv_time_to_string(p_datatype text, p_src_datatype text, p_timeval time without time zone, p_style numeric DEFAULT 25) RETURNS text
    LANGUAGE plpgsql STRICT
    AS $_$
DECLARE
    v_hours VARCHAR;
    v_style SMALLINT;
    v_scale SMALLINT;
    v_resmask VARCHAR;
    v_fseconds VARCHAR;
    v_datatype VARCHAR;
    v_resstring VARCHAR;
    v_lengthexpr VARCHAR;
    v_res_length SMALLINT;
    v_res_datatype VARCHAR;
    v_src_datatype VARCHAR;
    v_res_maxlength SMALLINT;
    VARCHAR_MAX CONSTANT SMALLINT := 8000;
    NVARCHAR_MAX CONSTANT SMALLINT := 4000;
    CHARACTER_REGEXP CONSTANT VARCHAR := 'CHAR|NCHAR|CHARACTER|NATIONAL CHARACTER';
    VARCHAR_REGEXP CONSTANT VARCHAR := 'VARCHAR|NVARCHAR|CHARACTER VARYING|NATIONAL CHARACTER VARYING';
    DATATYPE_REGEXP CONSTANT VARCHAR := concat('^\s*(', CHARACTER_REGEXP, '|', VARCHAR_REGEXP, ')\s*$');
    DATATYPE_MASK_REGEXP CONSTANT VARCHAR := concat('^\s*(?:', CHARACTER_REGEXP, '|', VARCHAR_REGEXP, ')\s*\(\s*(\d+|MAX)\s*\)\s*$');
    SRCDATATYPE_MASK_REGEXP CONSTANT VARCHAR := '^\s*(?:TIME)\s*(?:\s*\(\s*(\d+)\s*\)\s*)?\s*$';
BEGIN
    v_datatype := regexp_replace(upper(trim(p_datatype)), '\s+', ' ', 'gi');
    v_src_datatype := upper(trim(p_src_datatype));
    v_style := floor(p_style)::SMALLINT;

    IF (v_src_datatype ~* SRCDATATYPE_MASK_REGEXP)
    THEN
        v_scale := coalesce(substring(v_src_datatype, SRCDATATYPE_MASK_REGEXP)::SMALLINT, 7);

        IF (v_scale NOT BETWEEN 0 AND 7) THEN
            RAISE invalid_regular_expression;
        END IF;
    ELSE
        RAISE most_specific_type_mismatch;
    END IF;

    IF (v_datatype ~* DATATYPE_MASK_REGEXP)
    THEN
        v_res_datatype := rtrim(split_part(v_datatype, '(', 1));

        v_res_maxlength := CASE
                              WHEN substring(v_res_datatype, '^(NCHAR|NATIONAL.*)$') IS NULL
                              THEN VARCHAR_MAX
                              ELSE NVARCHAR_MAX
                           END;

        v_lengthexpr := substring(v_datatype, DATATYPE_MASK_REGEXP);

        IF (v_lengthexpr <> 'MAX' AND char_length(v_lengthexpr) > 4) THEN
            RAISE interval_field_overflow;
        END IF;

        v_res_length := CASE v_lengthexpr
                           WHEN 'MAX' THEN v_res_maxlength
                           ELSE v_lengthexpr::SMALLINT
                        END;
    ELSIF (v_datatype ~* DATATYPE_REGEXP) THEN
        v_res_datatype := v_datatype;
    ELSE
        RAISE datatype_mismatch;
    END IF;

    IF (scale(p_style) > 0) THEN
        RAISE escape_character_conflict;
    ELSIF (NOT ((v_style BETWEEN 0 AND 14) OR
                (v_style BETWEEN 20 AND 25) OR
                (v_style BETWEEN 100 AND 114) OR
                v_style IN (120, 121, 126, 127, 130, 131)))
    THEN
        RAISE invalid_parameter_value;
    ELSIF ((v_style BETWEEN 1 AND 7) OR
           (v_style BETWEEN 10 AND 12) OR
           (v_style BETWEEN 101 AND 107) OR
           (v_style BETWEEN 110 AND 112) OR
           v_style = 23)
    THEN
        RAISE invalid_datetime_format;
    END IF;

    v_hours := ltrim(to_char(p_timeval, 'HH12'), '0');
    v_fseconds := aws_sqlserver_ext.get_microsecs_from_fractsecs(to_char(p_timeval, 'US'), v_scale);

    IF (v_scale = 7) THEN
        v_fseconds := concat(v_fseconds, '0');
    END IF;

    IF (v_style IN (0, 100))
    THEN
        v_resmask := concat(v_hours, ':MIAM');
    ELSIF (v_style IN (8, 20, 24, 108, 120))
    THEN
        v_resmask := 'HH24:MI:SS';
    ELSIF (v_style IN (9, 109))
    THEN
        v_resmask := CASE
                        WHEN (char_length(v_fseconds) = 0) THEN concat(v_hours, ':MI:SSAM')
                        ELSE format('%s:MI:SS.%sAM', v_hours, v_fseconds)
                     END;
    ELSIF (v_style IN (13, 14, 21, 25, 113, 114, 121, 126, 127))
    THEN
        v_resmask := CASE
                        WHEN (char_length(v_fseconds) = 0) THEN 'HH24:MI:SS'
                        ELSE concat('HH24:MI:SS.', v_fseconds)
                     END;
    ELSIF (v_style = 22)
    THEN
        v_resmask := format('%s:MI:SS AM', lpad(v_hours, 2, ' '));
    ELSIF (v_style IN (130, 131))
    THEN
        v_resmask := CASE
                        WHEN (char_length(v_fseconds) = 0) THEN concat(lpad(v_hours, 2, ' '), ':MI:SSAM')
                        ELSE format('%s:MI:SS.%sAM', lpad(v_hours, 2, ' '), v_fseconds)
                     END;
    END IF;

    v_resstring := to_char(p_timeval, v_resmask);

    v_resstring := substring(v_resstring, 1, coalesce(v_res_length, char_length(v_resstring)));

    RETURN CASE
              WHEN substring(v_res_datatype, concat('^(', CHARACTER_REGEXP, ')$')) IS NOT NULL
              THEN rpad(v_resstring, coalesce(v_res_length, 30), ' ')
              ELSE v_resstring
           END;
EXCEPTION
    WHEN most_specific_type_mismatch THEN
        RAISE USING MESSAGE := 'Source data type should be ''TIME'' or ''TIME(n)''.',
                    DETAIL := 'Use of incorrect "src_datatype" parameter value during conversion process.',
                    HINT := 'Change "src_datatype" parameter to the proper value and try again.';

   WHEN invalid_regular_expression THEN
       RAISE USING MESSAGE := format('The source data type scale (%s) given to the convert specification exceeds the maximum allowable value (7).',
                                     v_scale),
                   DETAIL := 'Use of incorrect scale value of source data type parameter during conversion process.',
                   HINT := 'Change scale component of source data type parameter to the allowable value and try again.';

   WHEN interval_field_overflow THEN
       RAISE USING MESSAGE := format('The size (%s) given to the convert specification ''%s'' exceeds the maximum allowed for any data type (%s).',
                                     v_lengthexpr, lower(v_res_datatype), v_res_maxlength),
                   DETAIL := 'Use of incorrect size value of target data type parameter during conversion process.',
                   HINT := 'Change size component of data type parameter to the allowable value and try again.';

    WHEN escape_character_conflict THEN
        RAISE USING MESSAGE := 'Argument data type NUMERIC is invalid for argument 4 of convert function.',
                    DETAIL := 'Use of incorrect "style" parameter value during conversion process.',
                    HINT := 'Change "style" parameter to the proper value and try again.';

    WHEN invalid_parameter_value THEN
        RAISE USING MESSAGE := format('%s is not a valid style number when converting from TIME to a character string.', v_style),
                    DETAIL := 'Use of incorrect "style" parameter value during conversion process.',
                    HINT := 'Change "style" parameter to the proper value and try again.';

    WHEN datatype_mismatch THEN
        RAISE USING MESSAGE := concat('Data type should be one of these values: ''CHAR(n|MAX)'', ''NCHAR(n|MAX)'', ''VARCHAR(n|MAX)'', ''NVARCHAR(n|MAX)'', ',
                                      '''CHARACTER VARYING(n|MAX)'', ''NATIONAL CHARACTER VARYING(n|MAX)''.'),
                    DETAIL := 'Use of incorrect "datatype" parameter value during conversion process.',
                    HINT := 'Change "datatype" parameter to the proper value and try again.';

    WHEN invalid_datetime_format THEN
        RAISE USING MESSAGE := format('Error converting data type TIME to %s.',
                                      rtrim(split_part(trim(p_datatype), '(', 1))),
                    DETAIL := 'Incorrect using of pair of input parameters values during conversion process.',
                    HINT := 'Check the input parameters values, correct them if needed, and try again.';
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.conv_time_to_string(p_datatype text, p_src_datatype text, p_timeval time without time zone, p_style numeric) OWNER TO postgres;

--
-- TOC entry 3878 (class 0 OID 0)
-- Dependencies: 388
-- Name: FUNCTION conv_time_to_string(p_datatype text, p_src_datatype text, p_timeval time without time zone, p_style numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.conv_time_to_string(p_datatype text, p_src_datatype text, p_timeval time without time zone, p_style numeric) IS 'This function converts the TIME value into a character string, according to specified style (conversion mask).';


--
-- TOC entry 349 (class 1255 OID 17157)
-- Name: datediff(character varying, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.datediff(units character varying, start_t timestamp without time zone, end_t timestamp without time zone) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  diff_interval INTERVAL; 
  diff INT = 0;
  years_diff INT = 0;
BEGIN
  IF units IN ('ms', 'millisecond', 'microsecond', 'mcs' ) THEN   
    IF units IN ('ms', 'millisecond') THEN   
      RETURN trunc((EXTRACT('epoch' FROM end_t) - EXTRACT('epoch' FROM start_t)) * 1000);
    END IF;
    
    IF units IN ('microsecond', 'mcs') THEN   
      RETURN trunc((EXTRACT('epoch' FROM end_t) - EXTRACT('epoch' FROM start_t)) * 1000000);
    END IF;
  END IF;
  
  IF units IN ('yy', 'yyyy', 'year', 'mm', 'm', 'month') THEN
    years_diff = DATE_PART('year', end_t) - DATE_PART('year', start_t);
 
    IF units IN ('yy', 'yyyy', 'year') THEN
      -- SQL Server does not count full years passed (only difference between year parts)
      RETURN years_diff;
    ELSE
      -- If end month is less than start month it will subtracted
      RETURN years_diff * 12 + (DATE_PART('month', end_t) - DATE_PART('month', start_t)); 
    END IF;
  END IF;

  IF units IN ('quarter', 'qq', 'q') THEN  
    -- RETURN (EXTRACT(QUARTER FROM end_t) + date_part('year',age(end_t,start_t)) * 4) - 1 QUARTER;
    years_diff = DATE_PART('year', end_t) - DATE_PART('year', start_t);
    RETURN (4-EXTRACT(QUARTER FROM start_t)) + EXTRACT(QUARTER FROM end_t) + (years_diff - 1) * 4;
  END IF;
 
  -- Minus operator returns interval 'DDD days HH:MI:SS'  
  diff_interval = date_trunc('day',end_t) - date_trunc('day',start_t);
  diff = diff + DATE_PART('day', diff_interval);
 
  IF units IN ('wk', 'ww', 'week') THEN
    diff = diff/7;
    RETURN diff;
  END IF;
 
  -- dayofyear , day, and weekday return in SQL SERVER the same value
  IF units IN ('dd', 'd', 'day', 'dayofyear', 'dy', 'y', 'weekday', 'dw', 'w' ) THEN
    RETURN diff;
  END IF;
 
  -- diff = diff * 24 + DATE_PART('hour', diff_interval); 
  diff_interval = end_t - start_t;
  diff = DATE_PART('day', diff_interval) * 24 + DATE_PART('hour', diff_interval); 
 
  IF units IN ('hh', 'hour') THEN
    IF DATE_PART('minute', diff_interval) > 0 THEN
      RETURN diff + 1;
    ELSE   
      RETURN diff;
    END IF;  
  END IF;
 
  diff = diff * 60 + DATE_PART('minute', diff_interval);
 
  IF units IN ('mi', 'n', 'minute') THEN
    IF DATE_PART('second', diff_interval) > 0 THEN
      RETURN diff + 1;
    ELSE   
      RETURN diff;
    END IF;  
  END IF;

  diff = diff * 60 + DATE_PART('second', diff_interval);                               
 
  RETURN diff;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.datediff(units character varying, start_t timestamp without time zone, end_t timestamp without time zone) OWNER TO postgres;

--
-- TOC entry 372 (class 1255 OID 17039)
-- Name: datetime2fromparts(numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.datetime2fromparts(p_year numeric, p_month numeric, p_day numeric, p_hour numeric, p_minute numeric, p_seconds numeric, p_fractions numeric, p_precision numeric) RETURNS timestamp without time zone
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
   v_fractions VARCHAR;
   v_precision SMALLINT;
   v_err_message VARCHAR;
   v_calc_seconds NUMERIC;
BEGIN
   v_fractions := floor(p_fractions)::INTEGER::VARCHAR;
   v_precision := p_precision::SMALLINT;

   IF (scale(p_precision) > 0) THEN
      RAISE most_specific_type_mismatch;
   ELSIF ((p_year NOT BETWEEN 1 AND 9999) OR
       (p_month NOT BETWEEN 1 AND 12) OR
       (p_day NOT BETWEEN 1 AND 31) OR
       (p_hour NOT BETWEEN 0 AND 23) OR
       (p_minute NOT BETWEEN 0 AND 59) OR
       (p_seconds NOT BETWEEN 0 AND 59) OR
       (p_fractions NOT BETWEEN 0 AND 9999999) OR
       (p_fractions != 0 AND char_length(v_fractions) > p_precision))
   THEN
      RAISE invalid_datetime_format;
   ELSIF (v_precision NOT BETWEEN 0 AND 7) THEN
      RAISE invalid_parameter_value;
   END IF;

   v_calc_seconds := format('%s.%s',
                            floor(p_seconds)::SMALLINT,
                            substring(rpad(lpad(v_fractions, v_precision, '0'), 7, '0'), 1, 6))::NUMERIC;

   RETURN make_timestamp(floor(p_year)::SMALLINT,
                         floor(p_month)::SMALLINT,
                         floor(p_day)::SMALLINT,
                         floor(p_hour)::SMALLINT,
                         floor(p_minute)::SMALLINT,
                         v_calc_seconds);
EXCEPTION
   WHEN most_specific_type_mismatch THEN
      RAISE USING MESSAGE := 'Scale argument is not valid. Valid expressions for data type DATETIME2 scale argument are integer constants and integer constant expressions.',
                  DETAIL := 'Use of incorrect "precision" parameter value during conversion process.',
                  HINT := 'Change "precision" parameter to the proper value and try again.';

   WHEN invalid_parameter_value THEN
      RAISE USING MESSAGE := format('Specified scale %s is invalid.', v_precision),
                  DETAIL := 'Use of incorrect "precision" parameter value during conversion process.',
                  HINT := 'Change "precision" parameter to the proper value and try again.';

   WHEN invalid_datetime_format THEN
      RAISE USING MESSAGE := 'Cannot construct data type DATETIME2, some of the arguments have values which are not valid.',
                  DETAIL := 'Possible use of incorrect value of date or time part (which lies outside of valid range).',
                  HINT := 'Check each input argument belongs to the valid range and try again.';

   WHEN numeric_value_out_of_range THEN
      GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
      v_err_message := upper(split_part(v_err_message, ' ', 1));

      RAISE USING MESSAGE := format('Error while trying to cast to %s data type.', v_err_message),
                  DETAIL := format('Source value is out of %s data type range.', v_err_message),
                  HINT := format('Correct the source value you are trying to cast to %s data type and try again.',
                                 v_err_message);
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.datetime2fromparts(p_year numeric, p_month numeric, p_day numeric, p_hour numeric, p_minute numeric, p_seconds numeric, p_fractions numeric, p_precision numeric) OWNER TO postgres;

--
-- TOC entry 3879 (class 0 OID 0)
-- Dependencies: 372
-- Name: FUNCTION datetime2fromparts(p_year numeric, p_month numeric, p_day numeric, p_hour numeric, p_minute numeric, p_seconds numeric, p_fractions numeric, p_precision numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.datetime2fromparts(p_year numeric, p_month numeric, p_day numeric, p_hour numeric, p_minute numeric, p_seconds numeric, p_fractions numeric, p_precision numeric) IS 'This function returns a fully initialized DATETIME2 value, constructed from separate date and time parts.';


--
-- TOC entry 373 (class 1255 OID 17040)
-- Name: datetime2fromparts(text, text, text, text, text, text, text, text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.datetime2fromparts(p_year text, p_month text, p_day text, p_hour text, p_minute text, p_seconds text, p_fractions text, p_precision text) RETURNS timestamp without time zone
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
    v_err_message VARCHAR;
BEGIN
    RETURN aws_sqlserver_ext.datetime2fromparts(p_year::NUMERIC, p_month::NUMERIC, p_day::NUMERIC,
                                                p_hour::NUMERIC, p_minute::NUMERIC, p_seconds::NUMERIC,
                                                p_fractions::NUMERIC, p_precision::NUMERIC);
EXCEPTION
    WHEN invalid_text_representation THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
        v_err_message := substring(lower(v_err_message), 'numeric\:\s\"(.*)\"');

        RAISE USING MESSAGE := format('Error while trying to convert "%s" value to NUMERIC data type.', v_err_message),
                    DETAIL := 'Supplied string value contains illegal characters.',
                    HINT := 'Correct supplied value, remove all illegal characters and try again.';
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.datetime2fromparts(p_year text, p_month text, p_day text, p_hour text, p_minute text, p_seconds text, p_fractions text, p_precision text) OWNER TO postgres;

--
-- TOC entry 3880 (class 0 OID 0)
-- Dependencies: 373
-- Name: FUNCTION datetime2fromparts(p_year text, p_month text, p_day text, p_hour text, p_minute text, p_seconds text, p_fractions text, p_precision text); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.datetime2fromparts(p_year text, p_month text, p_day text, p_hour text, p_minute text, p_seconds text, p_fractions text, p_precision text) IS 'This function returns a fully initialized DATETIME2 value, constructed from separate date and time parts.';


--
-- TOC entry 376 (class 1255 OID 17041)
-- Name: datetimefromparts(numeric, numeric, numeric, numeric, numeric, numeric, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.datetimefromparts(p_year numeric, p_month numeric, p_day numeric, p_hour numeric, p_minute numeric, p_seconds numeric, p_milliseconds numeric) RETURNS timestamp without time zone
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
    v_err_message VARCHAR;
    v_calc_seconds NUMERIC;
    v_milliseconds SMALLINT;
    v_resdatetime TIMESTAMP WITHOUT TIME ZONE;
BEGIN
    IF ((p_year NOT BETWEEN 1753 AND 9999) OR
        (p_month NOT BETWEEN 1 AND 12) OR
        (p_day NOT BETWEEN 1 AND 31) OR
        (p_hour NOT BETWEEN 0 AND 23) OR
        (p_minute NOT BETWEEN 0 AND 59) OR
        (p_seconds NOT BETWEEN 0 AND 59) OR
        (p_milliseconds NOT BETWEEN 0 AND 999))
    THEN
        RAISE invalid_datetime_format;
    END IF;

    v_milliseconds := aws_sqlserver_ext.round_fractseconds(p_milliseconds::INTEGER);

    v_calc_seconds := format('%s.%s',
                             floor(p_seconds)::SMALLINT,
                             CASE v_milliseconds
                                WHEN 1000 THEN '0'
                                ELSE lpad(v_milliseconds::VARCHAR, 3, '0')
                             END)::NUMERIC;

    v_resdatetime := make_timestamp(floor(p_year)::SMALLINT,
                                    floor(p_month)::SMALLINT,
                                    floor(p_day)::SMALLINT,
                                    floor(p_hour)::SMALLINT,
                                    floor(p_minute)::SMALLINT,
                                    v_calc_seconds);
    RETURN CASE
              WHEN (v_milliseconds != 1000) THEN v_resdatetime
              ELSE v_resdatetime + INTERVAL '1 second'
           END;
EXCEPTION
    WHEN invalid_datetime_format THEN
        RAISE USING MESSAGE := 'Cannot construct data type datetime, some of the arguments have values which are not valid.',
                    DETAIL := 'Possible use of incorrect value of date or time part (which lies outside of valid range).',
                    HINT := 'Check each input argument belongs to the valid range and try again.';

    WHEN numeric_value_out_of_range THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
        v_err_message := upper(split_part(v_err_message, ' ', 1));

        RAISE USING MESSAGE := format('Error while trying to cast to %s data type.', v_err_message),
                    DETAIL := format('Source value is out of %s data type range.', v_err_message),
                    HINT := format('Correct the source value you are trying to cast to %s data type and try again.',
                                   v_err_message);
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.datetimefromparts(p_year numeric, p_month numeric, p_day numeric, p_hour numeric, p_minute numeric, p_seconds numeric, p_milliseconds numeric) OWNER TO postgres;

--
-- TOC entry 3881 (class 0 OID 0)
-- Dependencies: 376
-- Name: FUNCTION datetimefromparts(p_year numeric, p_month numeric, p_day numeric, p_hour numeric, p_minute numeric, p_seconds numeric, p_milliseconds numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.datetimefromparts(p_year numeric, p_month numeric, p_day numeric, p_hour numeric, p_minute numeric, p_seconds numeric, p_milliseconds numeric) IS 'This function returns a fully initialized DATETIME value, constructed from separate date and time parts.';


--
-- TOC entry 377 (class 1255 OID 17042)
-- Name: datetimefromparts(text, text, text, text, text, text, text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.datetimefromparts(p_year text, p_month text, p_day text, p_hour text, p_minute text, p_seconds text, p_milliseconds text) RETURNS timestamp without time zone
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
    v_err_message VARCHAR;
BEGIN
    RETURN aws_sqlserver_ext.datetimefromparts(p_year::NUMERIC, p_month::NUMERIC, p_day::NUMERIC,
                                               p_hour::NUMERIC, p_minute::NUMERIC,
                                               p_seconds::NUMERIC, p_milliseconds::NUMERIC);
EXCEPTION
    WHEN invalid_text_representation THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
        v_err_message := substring(lower(v_err_message), 'numeric\:\s\"(.*)\"');

        RAISE USING MESSAGE := format('Error while trying to convert "%s" value to NUMERIC data type.', v_err_message),
                    DETAIL := 'Supplied string value contains illegal characters.',
                    HINT := 'Correct supplied value, remove all illegal characters and try again.';
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.datetimefromparts(p_year text, p_month text, p_day text, p_hour text, p_minute text, p_seconds text, p_milliseconds text) OWNER TO postgres;

--
-- TOC entry 3882 (class 0 OID 0)
-- Dependencies: 377
-- Name: FUNCTION datetimefromparts(p_year text, p_month text, p_day text, p_hour text, p_minute text, p_seconds text, p_milliseconds text); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.datetimefromparts(p_year text, p_month text, p_day text, p_hour text, p_minute text, p_seconds text, p_milliseconds text) IS 'This function returns a fully initialized DATETIME value, constructed from separate date and time parts.';


--
-- TOC entry 444 (class 1255 OID 17153)
-- Name: dbts(); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.dbts() RETURNS bigint
    LANGUAGE plpgsql
    AS $$
declare
  v_res bigint;
begin
  SELECT last_value INTO v_res FROM aws_sqlserver_ext_data.inc_seq_rowversion;
  return v_res;
end;
$$;


ALTER FUNCTION aws_sqlserver_ext.dbts() OWNER TO postgres;

--
-- TOC entry 380 (class 1255 OID 17045)
-- Name: get_full_year(text, text, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.get_full_year(p_short_year text, p_base_century text DEFAULT ''::text, p_year_cutoff numeric DEFAULT 49) RETURNS character varying
    LANGUAGE plpgsql STABLE STRICT
    AS $_$
DECLARE
    v_err_message VARCHAR;
    v_full_year SMALLINT;
    v_short_year SMALLINT;
    v_base_century SMALLINT;
    v_result_param_set JSONB;
    v_full_year_res_jsonb JSONB;
BEGIN
    v_short_year := p_short_year::SMALLINT;

    BEGIN
        v_full_year_res_jsonb := nullif(current_setting('aws_sqlserver_ext.full_year_res_json'), '')::JSONB;
    EXCEPTION
        WHEN undefined_object THEN
        v_full_year_res_jsonb := NULL;
    END;

    SELECT result
      INTO v_full_year
      FROM jsonb_to_recordset(v_full_year_res_jsonb) AS result_set (param1 SMALLINT,
                                                                    param2 TEXT,
                                                                    param3 NUMERIC,
                                                                    result VARCHAR)
     WHERE param1 = v_short_year
       AND param2 = p_base_century
       AND param3 = p_year_cutoff;

    IF (v_full_year IS NULL)
    THEN
        IF (v_short_year <= 99)
        THEN
            v_base_century := CASE
                                 WHEN (p_base_century ~ '^\s*([1-9]{1,2})\s*$') THEN concat(trim(p_base_century), '00')::SMALLINT
                                 ELSE trunc(extract(year from current_date)::NUMERIC, -2)
                              END;

            v_full_year = v_base_century + v_short_year;
            v_full_year = CASE
                             WHEN (v_short_year > p_year_cutoff) THEN v_full_year - 100
                             ELSE v_full_year
                          END;
        ELSE v_full_year := v_short_year;
        END IF;

        v_result_param_set := jsonb_build_object('param1', v_short_year,
                                                 'param2', p_base_century,
                                                 'param3', p_year_cutoff,
                                                 'result', v_full_year);
        v_full_year_res_jsonb := CASE
                                    WHEN (v_full_year_res_jsonb IS NULL) THEN jsonb_build_array(v_result_param_set)
                                    ELSE v_full_year_res_jsonb || v_result_param_set
                                 END;

        PERFORM set_config('aws_sqlserver_ext.full_year_res_json',
                           v_full_year_res_jsonb::TEXT,
                           FALSE);
    END IF;

    RETURN v_full_year;
EXCEPTION
    WHEN invalid_text_representation THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
        v_err_message := substring(lower(v_err_message), 'integer\:\s\"(.*)\"');

        RAISE USING MESSAGE := format('Error while trying to convert "%s" value to SMALLINT data type.',
                                      v_err_message),
                    DETAIL := 'Supplied value contains illegal characters.',
                    HINT := 'Correct supplied value, remove all illegal characters.';
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.get_full_year(p_short_year text, p_base_century text, p_year_cutoff numeric) OWNER TO postgres;

--
-- TOC entry 3883 (class 0 OID 0)
-- Dependencies: 380
-- Name: FUNCTION get_full_year(p_short_year text, p_base_century text, p_year_cutoff numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.get_full_year(p_short_year text, p_base_century text, p_year_cutoff numeric) IS 'This function transforms two-digit year to full-size four digit year value, according to base century and cutoff boundary optional parameters.';


--
-- TOC entry 375 (class 1255 OID 17076)
-- Name: get_id_by_name(text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.get_id_by_name(object_name text) RETURNS bigint
    LANGUAGE plpgsql STRICT
    AS $$
declare res bigint;
begin
  execute 'select x''' || substring(encode(digest(object_name, 'sha1'), 'hex'), 1, 8) || '''::bigint' into res;
  return res;  
end;
$$;


ALTER FUNCTION aws_sqlserver_ext.get_id_by_name(object_name text) OWNER TO postgres;

--
-- TOC entry 339 (class 1255 OID 17026)
-- Name: get_int_part(double precision); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.get_int_part(p_srcnumber double precision) RETURNS double precision
    LANGUAGE plpgsql STABLE STRICT
    AS $$
BEGIN
    RETURN CASE
              WHEN (p_srcnumber < -0.0000001) THEN ceil(p_srcnumber - 0.0000001)
              ELSE floor(p_srcnumber + 0.0000001)
           END;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.get_int_part(p_srcnumber double precision) OWNER TO postgres;

--
-- TOC entry 3884 (class 0 OID 0)
-- Dependencies: 339
-- Name: FUNCTION get_int_part(p_srcnumber double precision); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.get_int_part(p_srcnumber double precision) IS 'This function returns an integer part of the passed value. Rounding to integer is applied according to the special logic.';


--
-- TOC entry 381 (class 1255 OID 17077)
-- Name: get_jobs(); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.get_jobs() RETURNS TABLE(job integer, what text, search_path character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_job integer;
  var_what text;
  var_search_path varchar;
BEGIN

  SELECT js.job_step_id, js.command, '' 
    FROM aws_sqlserver_ext.sysjobschedules s
   INNER JOIN aws_sqlserver_ext.sysjobs j on j.job_id = s.job_id
   INNER JOIN aws_sqlserver_ext.sysjobsteps js ON js.job_id = j.job_id
    INTO var_job, var_what, var_search_path 
   WHERE (s.next_run_date + s.next_run_time) <= now()::timestamp
     AND j.enabled = 1
   ORDER BY (s.next_run_date + s.next_run_time) ASC
   LIMIT 1;

  IF var_job > 0
  THEN
    return query select var_job, var_what, var_search_path;
  END IF;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.get_jobs() OWNER TO postgres;

--
-- TOC entry 342 (class 1255 OID 17029)
-- Name: get_lang_metadata_json(text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.get_lang_metadata_json(p_lang_spec_culture text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_locale_parts TEXT[];
    v_lang_data_jsonb JSONB;
    v_lang_spec_culture VARCHAR;
    v_is_cached BOOLEAN := FALSE;
BEGIN
    v_lang_spec_culture := upper(trim(p_lang_spec_culture));

    IF (char_length(v_lang_spec_culture) > 0)
    THEN
        BEGIN
            v_lang_data_jsonb := nullif(current_setting(format('aws_sqlserver_ext.lang_metadata_json.%s',
                                                               v_lang_spec_culture)), '')::JSONB;
        EXCEPTION
            WHEN undefined_object THEN
            v_lang_data_jsonb := NULL;
        END;

        IF (v_lang_data_jsonb IS NULL)
        THEN
            IF (v_lang_spec_culture IN ('AR', 'FI') OR
                v_lang_spec_culture ~ '-')
            THEN
                SELECT lang_data_jsonb
                  INTO STRICT v_lang_data_jsonb
                  FROM aws_sqlserver_ext.sys_languages
                 WHERE spec_culture = v_lang_spec_culture;
            ELSE
                SELECT lang_data_jsonb
                  INTO STRICT v_lang_data_jsonb
                  FROM aws_sqlserver_ext.sys_languages
                 WHERE lang_name_mssql = v_lang_spec_culture
                    OR lang_alias_mssql = v_lang_spec_culture;
            END IF;
        ELSE
            v_is_cached := TRUE;
        END IF;
    ELSE
        v_lang_spec_culture := current_setting('LC_TIME');

        v_lang_spec_culture := CASE
                                  WHEN (v_lang_spec_culture !~ '\.') THEN v_lang_spec_culture
                                  ELSE substring(v_lang_spec_culture, '(.*)(?:\.)')
                               END;

        v_lang_spec_culture := upper(regexp_replace(v_lang_spec_culture, '_|,\s*', '-', 'gi'));

        BEGIN
            v_lang_data_jsonb := nullif(current_setting(format('aws_sqlserver_ext.lang_metadata_json.%s',
                                                               v_lang_spec_culture)), '')::JSONB;
        EXCEPTION
            WHEN undefined_object THEN
            v_lang_data_jsonb := NULL;
        END;

        IF (v_lang_data_jsonb IS NULL)
        THEN
            BEGIN
                IF (char_length(v_lang_spec_culture) = 5)
                THEN
                    SELECT lang_data_jsonb
                      INTO STRICT v_lang_data_jsonb
                      FROM aws_sqlserver_ext.sys_languages
                     WHERE spec_culture = v_lang_spec_culture;
                ELSE
                    v_locale_parts := string_to_array(v_lang_spec_culture, '-');

                    SELECT lang_data_jsonb
                      INTO STRICT v_lang_data_jsonb
                      FROM aws_sqlserver_ext.sys_languages
                     WHERE lang_name_pg = v_locale_parts[1]
                       AND territory = v_locale_parts[2];
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    v_lang_spec_culture := 'EN-US';

                    SELECT lang_data_jsonb
                      INTO v_lang_data_jsonb
                      FROM aws_sqlserver_ext.sys_languages
                     WHERE spec_culture = v_lang_spec_culture;
            END;
        ELSE
            v_is_cached := TRUE;
        END IF;
    END IF;

    IF (NOT v_is_cached) THEN
        PERFORM set_config(format('aws_sqlserver_ext.lang_metadata_json.%s',
                                  v_lang_spec_culture),
                           v_lang_data_jsonb::TEXT,
                           FALSE);
    END IF;

    RETURN v_lang_data_jsonb;
EXCEPTION
    WHEN invalid_text_representation THEN
        RAISE USING MESSAGE := format('The language metadata JSON value extracted from chache is not a valid JSON object.',
                                      p_lang_spec_culture),
                    HINT := 'Drop the current session, fix the appropriate record in "aws_sqlserver_ext.sys_languages" table, and try again after reconnection.';

    WHEN OTHERS THEN
        RAISE USING MESSAGE := format('"%s" is not a valid special culture or language name parameter.',
                                      p_lang_spec_culture),
                    DETAIL := 'Use of incorrect "lang_spec_culture" parameter value during conversion process.',
                    HINT := 'Change "lang_spec_culture" parameter to the proper value and try again.';
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.get_lang_metadata_json(p_lang_spec_culture text) OWNER TO postgres;

--
-- TOC entry 3885 (class 0 OID 0)
-- Dependencies: 342
-- Name: FUNCTION get_lang_metadata_json(p_lang_spec_culture text); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.get_lang_metadata_json(p_lang_spec_culture text) IS 'This function returns language metadata JSON by corresponding lang name or spec culture abbreviation.';


--
-- TOC entry 371 (class 1255 OID 17038)
-- Name: get_microsecs_from_fractsecs(text, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.get_microsecs_from_fractsecs(p_fractsecs text, p_scale numeric DEFAULT 7) RETURNS character varying
    LANGUAGE plpgsql STABLE STRICT
    AS $$
DECLARE
    v_scale SMALLINT;
    v_decplaces INTEGER;
    v_fractsecs VARCHAR;
    v_pureplaces VARCHAR;
    v_rnd_fractsecs INTEGER;
    v_fractsecs_len INTEGER;
    v_pureplaces_len INTEGER;
    v_err_message VARCHAR;
BEGIN
    v_fractsecs := trim(p_fractsecs);
    v_fractsecs_len := char_length(v_fractsecs);
    v_scale := floor(p_scale)::SMALLINT;

    IF (v_fractsecs_len < 7) THEN
        v_fractsecs := rpad(v_fractsecs, 7, '0');
        v_fractsecs_len := char_length(v_fractsecs);
    END IF;

    v_pureplaces := trim(leading '0' from v_fractsecs);
    v_pureplaces_len := char_length(v_pureplaces);

    v_decplaces := v_fractsecs_len - v_pureplaces_len;

    v_rnd_fractsecs := round(v_fractsecs::INTEGER, (v_pureplaces_len - (v_scale - (v_fractsecs_len - v_pureplaces_len))) * (-1));

    v_fractsecs := concat(replace(rpad('', v_decplaces), ' ', '0'), v_rnd_fractsecs);

    RETURN substring(v_fractsecs, 1, CASE
                                        WHEN (v_scale >= 7) THEN 6
                                        ELSE v_scale
                                     END);
EXCEPTION
    WHEN invalid_text_representation THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
        v_err_message := substring(lower(v_err_message), 'integer\:\s\"(.*)\"');

        RAISE USING MESSAGE := format('Error while trying to convert "%s" value to SMALLINT data type.', v_err_message),
                    DETAIL := 'Supplied value contains illegal characters.',
                    HINT := 'Correct supplied value, remove all illegal characters.';
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.get_microsecs_from_fractsecs(p_fractsecs text, p_scale numeric) OWNER TO postgres;

--
-- TOC entry 3886 (class 0 OID 0)
-- Dependencies: 371
-- Name: FUNCTION get_microsecs_from_fractsecs(p_fractsecs text, p_scale numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.get_microsecs_from_fractsecs(p_fractsecs text, p_scale numeric) IS 'This function transforms MS SQL Server DATETIME2 fractions and precision (scale) parts into PostgreSQL microsecond values.';


--
-- TOC entry 385 (class 1255 OID 17048)
-- Name: get_monthnum_by_name(text, jsonb); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.get_monthnum_by_name(p_monthname text, p_lang_metadata_json jsonb) RETURNS smallint
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
DECLARE
    v_monthname TEXT;
    v_monthnum SMALLINT;
BEGIN
    v_monthname := lower(trim(p_monthname));

    v_monthnum := array_position(ARRAY(SELECT lower(jsonb_array_elements_text(p_lang_metadata_json -> 'months_shortnames'))), v_monthname);

    v_monthnum := coalesce(v_monthnum,
                           array_position(ARRAY(SELECT lower(jsonb_array_elements_text(p_lang_metadata_json -> 'months_names'))), v_monthname));

    v_monthnum := coalesce(v_monthnum,
                           array_position(ARRAY(SELECT lower(jsonb_array_elements_text(p_lang_metadata_json -> 'months_extrashortnames'))), v_monthname));

    v_monthnum := coalesce(v_monthnum,
                           array_position(ARRAY(SELECT lower(jsonb_array_elements_text(p_lang_metadata_json -> 'months_extranames'))), v_monthname));

    IF (v_monthnum IS NULL) THEN
        RAISE datetime_field_overflow;
    END IF;

    RETURN v_monthnum;
EXCEPTION
    WHEN datetime_field_overflow THEN
        RAISE USING MESSAGE := format('Can not convert value "%s" to a correct month number.',
                                      trim(p_monthname)),
                    DETAIL := 'Supplied month name is not valid.',
                    HINT := 'Correct supplied month name value and try again.';
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.get_monthnum_by_name(p_monthname text, p_lang_metadata_json jsonb) OWNER TO postgres;

--
-- TOC entry 3887 (class 0 OID 0)
-- Dependencies: 385
-- Name: FUNCTION get_monthnum_by_name(p_monthname text, p_lang_metadata_json jsonb); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.get_monthnum_by_name(p_monthname text, p_lang_metadata_json jsonb) IS 'This function returns month number (1-12) by corresponding month name, matched from language metadata JSON.';


--
-- TOC entry 382 (class 1255 OID 17078)
-- Name: get_sequence_value(character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.get_sequence_value(sequence_name character varying) RETURNS bigint
    LANGUAGE plpgsql STRICT
    AS $$
declare
  v_res bigint;
begin
  execute 'select last_value from '|| sequence_name into v_res;
  return v_res;
end;
$$;


ALTER FUNCTION aws_sqlserver_ext.get_sequence_value(sequence_name character varying) OWNER TO postgres;

--
-- TOC entry 348 (class 1255 OID 17156)
-- Name: get_service_setting(character varying, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.get_service_setting(p_service character varying, p_setting character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
  settingValue aws_sqlserver_ext_data.service_settings.value%TYPE;
BEGIN
  SELECT value
    INTO settingValue 
    FROM aws_sqlserver_ext_data.service_settings 
   WHERE service = p_service 
     AND setting = p_setting;
 
  RETURN settingValue;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.get_service_setting(p_service character varying, p_setting character varying) OWNER TO postgres;

--
-- TOC entry 383 (class 1255 OID 17046)
-- Name: get_timeunit_from_string(text, text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.get_timeunit_from_string(p_timepart text, p_timeunit text) RETURNS character varying
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $_$
DECLARE
    v_hours VARCHAR;
    v_minutes VARCHAR;
    v_seconds VARCHAR;
    v_fractsecs VARCHAR;
    v_daypart VARCHAR;
    v_timepart VARCHAR;
    v_timeunit VARCHAR;
    v_err_message VARCHAR;
    v_timeunit_mask VARCHAR;
    v_regmatch_groups TEXT[];
    AMPM_REGEXP CONSTANT VARCHAR := '\s*([AP]M)';
    TIMEUNIT_REGEXP CONSTANT VARCHAR := '\s*(\d{1,2})\s*';
    FRACTSECS_REGEXP CONSTANT VARCHAR := '\s*(\d{1,9})';
    HHMMSSFS_REGEXP CONSTANT VARCHAR := concat('^', TIMEUNIT_REGEXP,
                                               '\:', TIMEUNIT_REGEXP,
                                               '\:', TIMEUNIT_REGEXP,
                                               '(?:\.|\:)', FRACTSECS_REGEXP, '$');
    HHMMSS_REGEXP CONSTANT VARCHAR := concat('^', TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '$');
    HHMMFS_REGEXP CONSTANT VARCHAR := concat('^', TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '\.', FRACTSECS_REGEXP, '$');
    HHMM_REGEXP CONSTANT VARCHAR := concat('^', TIMEUNIT_REGEXP, '\:', TIMEUNIT_REGEXP, '$');
    HH_REGEXP CONSTANT VARCHAR := concat('^', TIMEUNIT_REGEXP, '$');
BEGIN
    v_timepart := upper(trim(p_timepart));
    v_timeunit := upper(trim(p_timeunit));

    v_daypart := substring(v_timepart, 'AM|PM');
    v_timepart := trim(regexp_replace(v_timepart, coalesce(v_daypart, ''), ''));

    v_timeunit_mask :=
        CASE
           WHEN (v_timepart ~* HHMMSSFS_REGEXP) THEN HHMMSSFS_REGEXP
           WHEN (v_timepart ~* HHMMSS_REGEXP) THEN HHMMSS_REGEXP
           WHEN (v_timepart ~* HHMMFS_REGEXP) THEN HHMMFS_REGEXP
           WHEN (v_timepart ~* HHMM_REGEXP) THEN HHMM_REGEXP
           WHEN (v_timepart ~* HH_REGEXP) THEN HH_REGEXP
        END;

    v_regmatch_groups := regexp_matches(v_timepart, v_timeunit_mask, 'gi');

    v_hours := v_regmatch_groups[1];
    v_minutes := v_regmatch_groups[2];

    IF (v_timepart ~* HHMMFS_REGEXP) THEN
        v_fractsecs := v_regmatch_groups[3];
    ELSE
        v_seconds := v_regmatch_groups[3];
        v_fractsecs := v_regmatch_groups[4];
    END IF;

    IF (v_timeunit = 'HOURS' AND v_daypart IS NOT NULL)
    THEN
        IF ((v_daypart = 'AM' AND v_hours::SMALLINT NOT BETWEEN 0 AND 12) OR
            (v_daypart = 'PM' AND v_hours::SMALLINT NOT BETWEEN 1 AND 23))
        THEN
            RAISE numeric_value_out_of_range;
        ELSIF (v_daypart = 'PM' AND v_hours::SMALLINT < 12) THEN
            v_hours := (v_hours::SMALLINT + 12)::VARCHAR;
        ELSIF (v_daypart = 'AM' AND v_hours::SMALLINT = 12) THEN
            v_hours := (v_hours::SMALLINT - 12)::VARCHAR;
        END IF;
    END IF;

    RETURN CASE v_timeunit
              WHEN 'HOURS' THEN v_hours
              WHEN 'MINUTES' THEN v_minutes
              WHEN 'SECONDS' THEN v_seconds
              WHEN 'FRACTSECONDS' THEN v_fractsecs
           END;
EXCEPTION
    WHEN numeric_value_out_of_range THEN
        RAISE USING MESSAGE := 'Could not extract correct hour value due to it''s inconsistency with AM|PM day part mark.',
                    DETAIL := 'Extracted hour value doesn''t fall in correct day part mark range: 0..12 for "AM" or 1..23 for "PM".',
                    HINT := 'Correct a hour value in the source string or remove AM|PM day part mark out of it.';

    WHEN invalid_text_representation THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
        v_err_message := substring(lower(v_err_message), 'integer\:\s\"(.*)\"');

        RAISE USING MESSAGE := format('Error while trying to convert "%s" value to SMALLINT data type.', v_err_message),
                    DETAIL := 'Supplied value contains illegal characters.',
                    HINT := 'Correct supplied value, remove all illegal characters.';
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.get_timeunit_from_string(p_timepart text, p_timeunit text) OWNER TO postgres;

--
-- TOC entry 3888 (class 0 OID 0)
-- Dependencies: 383
-- Name: FUNCTION get_timeunit_from_string(p_timepart text, p_timeunit text); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.get_timeunit_from_string(p_timepart text, p_timeunit text) IS 'This function returns certain time part (identified by p_timeunit param) extracted from the source string.';


--
-- TOC entry 312 (class 1255 OID 17079)
-- Name: get_version(character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.get_version(pcomponentname character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
  lComponentVersion VARCHAR(256);
BEGIN
	SELECT componentversion 
	  INTO lComponentVersion 
	  FROM aws_sqlserver_ext.versions
	 WHERE extpackcomponentname = pComponentName;

	RETURN lComponentVersion;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.get_version(pcomponentname character varying) OWNER TO postgres;

--
-- TOC entry 384 (class 1255 OID 17047)
-- Name: get_weekdaynum_by_name(text, jsonb); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.get_weekdaynum_by_name(p_weekdayname text, p_lang_metadata_json jsonb) RETURNS smallint
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
DECLARE
    v_weekdayname TEXT;
    v_weekdaynum SMALLINT;
BEGIN
    v_weekdayname := lower(trim(p_weekdayname));

    v_weekdaynum := array_position(ARRAY(SELECT lower(jsonb_array_elements_text(p_lang_metadata_json -> 'days_names'))), v_weekdayname);

    v_weekdaynum := coalesce(v_weekdaynum,
                             array_position(ARRAY(SELECT lower(jsonb_array_elements_text(p_lang_metadata_json -> 'days_shortnames'))), v_weekdayname));

    v_weekdaynum := coalesce(v_weekdaynum,
                             array_position(ARRAY(SELECT lower(jsonb_array_elements_text(p_lang_metadata_json -> 'days_extrashortnames'))), v_weekdayname));

    IF (v_weekdaynum IS NULL) THEN
        RAISE datetime_field_overflow;
    END IF;

    RETURN v_weekdaynum;
EXCEPTION
    WHEN datetime_field_overflow THEN
        RAISE USING MESSAGE := format('Can not convert value "%s" to a correct weekday number.',
                                      trim(p_weekdayname)),
                    DETAIL := 'Supplied weekday name is not valid.',
                    HINT := 'Correct supplied weekday name value and try again.';
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.get_weekdaynum_by_name(p_weekdayname text, p_lang_metadata_json jsonb) OWNER TO postgres;

--
-- TOC entry 3889 (class 0 OID 0)
-- Dependencies: 384
-- Name: FUNCTION get_weekdaynum_by_name(p_weekdayname text, p_lang_metadata_json jsonb); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.get_weekdaynum_by_name(p_weekdayname text, p_lang_metadata_json jsonb) IS 'This function returns weekday number (1-7) by corresponding weekday name, matched from language metadata JSON.';


--
-- TOC entry 313 (class 1255 OID 17080)
-- Name: isdate(text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.isdate(v text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
  perform v::date;
  return true;
exception
  when others then
   return false;
end
$$;


ALTER FUNCTION aws_sqlserver_ext.isdate(v text) OWNER TO postgres;

--
-- TOC entry 314 (class 1255 OID 17081)
-- Name: isnumeric(numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.isnumeric(_input numeric) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $_$
DECLARE x NUMERIC;
/***************************************************************
EXTENSION PACK function ISNUMERIC(x)
***************************************************************/
BEGIN
    x = $1::VARCHAR::NUMERIC;
    RETURN TRUE;
EXCEPTION WHEN others THEN
    RETURN FALSE;
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.isnumeric(_input numeric) OWNER TO postgres;

--
-- TOC entry 326 (class 1255 OID 17082)
-- Name: isnumeric(text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.isnumeric(_input text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $_$
DECLARE x NUMERIC;
/***************************************************************
EXTENSION PACK function ISNUMERIC(x)
***************************************************************/
BEGIN
    x = $1::VARCHAR::NUMERIC;
    RETURN TRUE;
EXCEPTION WHEN others THEN
    RETURN FALSE;
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.isnumeric(_input text) OWNER TO postgres;

--
-- TOC entry 327 (class 1255 OID 17083)
-- Name: istime(text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.istime(v text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
  perform v::time;
  return true;
exception
  when others then
   return false;
end
$$;


ALTER FUNCTION aws_sqlserver_ext.istime(v text) OWNER TO postgres;

--
-- TOC entry 328 (class 1255 OID 17084)
-- Name: newid(); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.newid() RETURNS uuid
    LANGUAGE plpgsql
    AS $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
  RETURN uuid_generate_v4();
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.newid() OWNER TO postgres;

--
-- TOC entry 443 (class 1255 OID 17152)
-- Name: object_id(character varying, character); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.object_id(object_name character varying, object_type character DEFAULT ''::bpchar) RETURNS integer
    LANGUAGE plpgsql STABLE STRICT
    AS $$ 
declare id oid;
        lower_object_name character varying;
        is_temp_object boolean;
begin

  id := null;  
  lower_object_name := lower(object_name);
  is_temp_object := position('tempdb..#' in lower_object_name) > 0;
  
  while position('.' in lower_object_name) > 0 loop
    lower_object_name := substring(lower_object_name from strpos(lower_object_name, '.') + 1);
  end loop;
   
  if object_type <> '' then
    case 
      when upper(object_type) in ('S', 'U', 'V', 'IT', 'ET', 'SO') and is_temp_object then 
	id := (select oid from pg_class where lower(relname) = lower_object_name and relpersistence in ('u', 't') limit 1); 
	           
      when upper(object_type) in ('S', 'U', 'V', 'IT', 'ET', 'SO') and not is_temp_object then 
	id := (select oid from pg_class where lower(relname) = lower_object_name limit 1);      
	
      when upper(object_type) in ('C', 'D', 'F', 'PK', 'UQ') then 
	id := (select oid from pg_constraint where lower(conname) = lower_object_name limit 1);            
	
      when upper(object_type) in ('AF', 'FN', 'FS', 'FT', 'IF', 'P', 'PC', 'TF', 'RF', 'X') then 
	id := (select oid from pg_proc where lower(proname) = lower_object_name limit 1);      
	
      when upper(object_type) in ('TR', 'TA') then 
	id := (select oid from pg_trigger where lower(tgname) = lower_object_name limit 1);            

      -- unsupported object_type
      else id := null;
    end case;
  else 
    if not is_temp_object then id := (
				      select oid from pg_class where lower(relname) = lower_object_name
					union
				      select oid from pg_constraint where lower(conname) = lower_object_name
					union
				      select oid from pg_proc where lower(proname) = lower_object_name
					union
				      select oid from pg_trigger where lower(tgname) = lower_object_name
				      limit 1);
    else
      -- temp object without "object_type" in-argument 
      id := (select oid from pg_class where lower(relname) = lower_object_name and relpersistence in ('u', 't') limit 1);     
    end if;
  end if;  

  return id::integer;
  
end; 
$$;


ALTER FUNCTION aws_sqlserver_ext.object_id(object_name character varying, object_type character) OWNER TO postgres;

--
-- TOC entry 354 (class 1255 OID 17352)
-- Name: openxml(bigint); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.openxml(dochandle bigint) RETURNS TABLE(xmldata xml)
    LANGUAGE plpgsql
    AS $_$
DECLARE                       
   XmlDocument$data XML;
BEGIN
	 
    SELECT t.XmlData     
	  INTO STRICT XmlDocument$data
	  FROM aws_sqlserver_ext$openxml t
	 WHERE t.DocID = DocHandle;	  
   
   RETURN QUERY SELECT XmlDocument$data;
  
   EXCEPTION
	  WHEN SQLSTATE '42P01' OR SQLSTATE 'P0002' THEN 
	      RAISE EXCEPTION '%','Could not find prepared statement with handle '||CASE 
                                                                              WHEN DocHandle IS NULL THEN 'null'
                                                                                ELSE DocHandle::TEXT
                                                                             END;
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.openxml(dochandle bigint) OWNER TO postgres;

--
-- TOC entry 363 (class 1255 OID 17067)
-- Name: parse_to_date(text, text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.parse_to_date(p_datestring text, p_culture text DEFAULT ''::text) RETURNS date
    LANGUAGE plpgsql STRICT
    AS $_$
DECLARE
    v_day VARCHAR;
    v_year SMALLINT;
    v_month VARCHAR;
    v_res_date DATE;
    v_hijridate DATE;
    v_culture VARCHAR;
    v_dayparts TEXT[];
    v_resmask VARCHAR;
    v_raw_year VARCHAR;
    v_left_part VARCHAR;
    v_right_part VARCHAR;
    v_resmask_fi VARCHAR;
    v_datestring VARCHAR;
    v_timestring VARCHAR;
    v_correctnum VARCHAR;
    v_weekdaynum SMALLINT;
    v_err_message VARCHAR;
    v_date_format VARCHAR;
    v_weekdaynames TEXT[];
    v_hours SMALLINT := 0;
    v_minutes SMALLINT := 0;
    v_seconds NUMERIC := 0;
    v_found BOOLEAN := TRUE;
    v_compday_regexp VARCHAR;
    v_regmatch_groups TEXT[];
    v_compmonth_regexp VARCHAR;
    v_lang_metadata_json JSONB;
    v_resmask_cnt SMALLINT := 10;
    DAYMM_REGEXP CONSTANT VARCHAR := '(\d{1,2})';
    FULLYEAR_REGEXP CONSTANT VARCHAR := '(\d{3,4})';
    SHORTYEAR_REGEXP CONSTANT VARCHAR := '(\d{1,2})';
    COMPYEAR_REGEXP CONSTANT VARCHAR := '(\d{1,4})';
    AMPM_REGEXP CONSTANT VARCHAR := '(?:[AP]M|Шµ|Щ…)';
    TIMEUNIT_REGEXP CONSTANT VARCHAR := '\s*\d{1,2}\s*';
    MASKSEPONE_REGEXP CONSTANT VARCHAR := '\s*(?:/|-)?';
    MASKSEPTWO_REGEXP CONSTANT VARCHAR := '\s*(?:\s|/|-|\.|,)';
    MASKSEPTWO_FI_REGEXP CONSTANT VARCHAR := '\s*(?:\s|/|-|,)';
    MASKSEPTHREE_REGEXP CONSTANT VARCHAR := '\s*(?:/|-|\.|,)';
    TIME_MASKSEP_REGEXP CONSTANT VARCHAR := '(?:\s|\.|,)*';
    TIME_MASKSEP_FI_REGEXP CONSTANT VARCHAR := '(?:\s|,)*';
    WEEKDAYAMPM_START_REGEXP CONSTANT VARCHAR := '(^|[[:digit:][:space:]\.,])';
    WEEKDAYAMPM_END_REGEXP CONSTANT VARCHAR := '([[:digit:][:space:]\.,]|$)(?=[^/-]|$)';
    CORRECTNUM_REGEXP CONSTANT VARCHAR := '(?:([+-]\d{1,4})(?:[[:space:]\.,]|[AP]M|Шµ|Щ…|$))';
    ANNO_DOMINI_REGEXP VARCHAR := '(AD|A\.D\.)';
    ANNO_DOMINI_COMPREGEXP VARCHAR := concat(WEEKDAYAMPM_START_REGEXP, ANNO_DOMINI_REGEXP, WEEKDAYAMPM_END_REGEXP);
    HHMMSSFS_PART_REGEXP CONSTANT VARCHAR :=
        concat(TIMEUNIT_REGEXP, AMPM_REGEXP, '|',
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '\:', TIME_MASKSEP_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '(?!\d)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?|',
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '\:', TIME_MASKSEP_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '\:', TIME_MASKSEP_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '(?!\d)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?|',
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '\:', TIME_MASKSEP_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '\:', TIME_MASKSEP_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\s*\d{1,2}\.\d+(?!\d)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?|',
               AMPM_REGEXP, '?');
    HHMMSSFS_PART_FI_REGEXP CONSTANT VARCHAR :=
        concat(TIMEUNIT_REGEXP, AMPM_REGEXP, '|',
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '[\:\.]', TIME_MASKSEP_FI_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '(?!\d)', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?\.?|',
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '[\:\.]', TIME_MASKSEP_FI_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '[\:\.]', TIME_MASKSEP_FI_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '(?!\d)', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?|',
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '[\:\.]', TIME_MASKSEP_FI_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '[\:\.]', TIME_MASKSEP_FI_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, '\s*\d{1,2}\.\d+(?!\d)\.?', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?|',
               AMPM_REGEXP, '?');
    v_defmask1_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        TIME_MASKSEP_REGEXP, '(?:[\.|,]+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)', TIME_MASKSEP_REGEXP, '$');
    v_defmask1_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP,
                                           '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_FI_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:', MASKSEPTWO_FI_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP,
                                           CORRECTNUM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[,]+', AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           TIME_MASKSEP_FI_REGEXP, '(?:[\.|,]+', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask2_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        FULLYEAR_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        AMPM_REGEXP, TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        TIME_MASKSEP_REGEXP, '(?:(?:[\.|,]+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?)|',
                                        CORRECTNUM_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP, '$');
    v_defmask2_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP,
                                           '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           CORRECTNUM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP,
                                           FULLYEAR_REGEXP,
                                           '(?:(?:', MASKSEPTWO_FI_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:', TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP,
                                           AMPM_REGEXP, TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           TIME_MASKSEP_FI_REGEXP, '(?:(?:[\.|,]+', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?)|',
                                           CORRECTNUM_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask3_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, ')|',
                                        '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        FULLYEAR_REGEXP,
                                        TIME_MASKSEP_REGEXP, '(', TIME_MASKSEP_REGEXP, AMPM_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask3_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           TIME_MASKSEP_FI_REGEXP, '[\./]?', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)',
                                           FULLYEAR_REGEXP,
                                           TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask4_0_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP, '\s*(', AMPM_REGEXP, ')',
                                          TIME_MASKSEP_REGEXP, '$');
    v_defmask4_1_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          '(?:\s|,)+',
                                          DAYMM_REGEXP, '\s*(', AMPM_REGEXP, ')',
                                          TIME_MASKSEP_REGEXP, '$');
    v_defmask4_2_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          '\s*[\.]+', TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP, '\s*(', AMPM_REGEXP, ')',
                                          TIME_MASKSEP_REGEXP, '$');
    v_defmask5_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        FULLYEAR_REGEXP,
                                        TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask5_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           FULLYEAR_REGEXP,
                                           TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask6_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        FULLYEAR_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '((?:(?:\s|\.|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_REGEXP, '))?', TIME_MASKSEP_REGEXP, '$');
    v_defmask6_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           FULLYEAR_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:\s*[\.])?',
                                           '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask7_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        FULLYEAR_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '((?:(?:\s|\.|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_REGEXP, '))?', TIME_MASKSEP_REGEXP, '$');
    v_defmask7_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           FULLYEAR_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask8_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:[\.|,]+', AMPM_REGEXP, ')?',
                                        TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask8_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_FI_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:[\,]+|\s*/\s*)', AMPM_REGEXP, ')?',
                                           TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask9_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(',
                                        HHMMSSFS_PART_REGEXP,
                                        ')', TIME_MASKSEP_REGEXP, '$');
    v_defmask9_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, '(',
                                           HHMMSSFS_PART_FI_REGEXP,
                                           ')', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask10_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)?', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask10_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            DAYMM_REGEXP,
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)?', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask11_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask11_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           '($comp_month$)',
                                           '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask12_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         FULLYEAR_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                         '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask12_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            FULLYEAR_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                            '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask13_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         FULLYEAR_REGEXP,
                                         TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$');
    v_defmask13_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            '($comp_month$)',
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                            FULLYEAR_REGEXP,
                                            TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask14_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)'
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)', TIME_MASKSEP_REGEXP,
                                         COMPYEAR_REGEXP,
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask14_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            '($comp_month$)'
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_FI_REGEXP,
                                            DAYMM_REGEXP,
                                            '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)', TIME_MASKSEP_FI_REGEXP,
                                            COMPYEAR_REGEXP,
                                            '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask15_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                         '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         COMPYEAR_REGEXP,
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask15_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            DAYMM_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                            '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                            COMPYEAR_REGEXP,
                                            '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask16_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)', TIME_MASKSEP_REGEXP,
                                         COMPYEAR_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                         '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask16_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            DAYMM_REGEXP,
                                            '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)', TIME_MASKSEP_REGEXP,
                                            COMPYEAR_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                            '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask17_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         FULLYEAR_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                         '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask17_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            FULLYEAR_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                            '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                            DAYMM_REGEXP,
                                            '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask18_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         FULLYEAR_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                         '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                         '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask18_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            FULLYEAR_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                            '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                            DAYMM_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                            '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask19_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         FULLYEAR_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                         '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '((?:(?:\s|\.|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_REGEXP, '))?', TIME_MASKSEP_REGEXP, '$');
    v_defmask19_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            '($comp_month$)',
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                            FULLYEAR_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                            '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                            DAYMM_REGEXP,
                                            '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    CONVERSION_LANG CONSTANT VARCHAR := 'English';
    DATE_FORMAT CONSTANT VARCHAR := '';
BEGIN
    v_datestring := upper(trim(p_datestring));
    v_culture := coalesce(nullif(upper(trim(p_culture)), ''), 'EN-US');

    v_dayparts := ARRAY(SELECT upper(array_to_string(regexp_matches(v_datestring, '[AP]M|Шµ|Щ…', 'gi'), '')));

    IF (array_length(v_dayparts, 1) > 1) THEN
        RAISE invalid_datetime_format;
    END IF;

    BEGIN
        v_lang_metadata_json := aws_sqlserver_ext.get_lang_metadata_json(coalesce(nullif(CONVERSION_LANG, ''), p_culture));
    EXCEPTION
        WHEN OTHERS THEN
        RAISE invalid_parameter_value;
    END;

    v_compday_regexp := array_to_string(array_cat(array_cat(ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'days_names')),
                                                            ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'days_shortnames'))),
                                                  ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'days_extrashortnames'))), '|');

    v_weekdaynames := ARRAY(SELECT array_to_string(regexp_matches(v_datestring, v_compday_regexp, 'gi'), ''));

    IF (array_length(v_weekdaynames, 1) > 1) THEN
        RAISE invalid_datetime_format;
    END IF;

    IF (v_weekdaynames[1] IS NOT NULL AND
        v_datestring ~* concat(WEEKDAYAMPM_START_REGEXP, '(', v_compday_regexp, ')', WEEKDAYAMPM_END_REGEXP))
    THEN
        v_datestring := replace(v_datestring, v_weekdaynames[1], ' ');
    END IF;

    IF (v_datestring ~* ANNO_DOMINI_COMPREGEXP)
    THEN
        IF (v_culture !~ 'EN[-_]US|DA[-_]DK|SV[-_]SE|EN[-_]GB|HI[-_]IS') THEN
            RAISE invalid_datetime_format;
        END IF;

        v_datestring := regexp_replace(v_datestring,
                                       ANNO_DOMINI_COMPREGEXP,
                                       regexp_replace(array_to_string(regexp_matches(v_datestring, ANNO_DOMINI_COMPREGEXP, 'gi'), ''),
                                                      ANNO_DOMINI_REGEXP, ' ', 'gi'),
                                       'gi');
    END IF;

    v_date_format := coalesce(nullif(upper(trim(DATE_FORMAT)), ''), v_lang_metadata_json ->> 'date_format');

    v_compmonth_regexp :=
        array_to_string(array_cat(array_cat(ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'months_shortnames')),
                                            ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'months_names'))),
                                  array_cat(ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'months_extrashortnames')),
                                            ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'months_extranames')))
                                 ), '|');

    IF ((v_datestring ~* v_defmask1_regexp AND v_culture <> 'FI') OR
        (v_datestring ~* v_defmask1_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_datestring ~ concat(CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                  CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP,
                                  AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}|',
                                  '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                  CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
            v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV')
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_datestring, CASE v_culture
                                                             WHEN 'FI' THEN v_defmask1_fi_regexp
                                                             ELSE v_defmask1_regexp
                                                          END, 'gi');
        v_timestring := v_regmatch_groups[2];
        v_correctnum := coalesce(v_regmatch_groups[1], v_regmatch_groups[3],
                                 v_regmatch_groups[5], v_regmatch_groups[6]);

        IF (v_date_format = 'DMY' OR
            v_culture IN ('SV-SE', 'SV_SE', 'LV-LV', 'LV_LV'))
        THEN
            v_day := v_regmatch_groups[4];
            v_month := v_regmatch_groups[7];
        ELSE
            v_day := v_regmatch_groups[7];
            v_month := v_regmatch_groups[4];
        END IF;

        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA'))
        THEN
            IF (v_day::SMALLINT > 30 OR
                v_month::SMALLINT > 12) THEN
                RAISE invalid_datetime_format;
            END IF;

            v_raw_year := to_char(aws_sqlserver_ext.conv_greg_to_hijri(current_date + 1), 'YYYY');
            v_hijridate := aws_sqlserver_ext.conv_hijri_to_greg(v_day, v_month, v_raw_year) - 1;

            v_day := to_char(v_hijridate, 'DD');
            v_month := to_char(v_hijridate, 'MM');
            v_year := to_char(v_hijridate, 'YYYY')::SMALLINT;
        ELSE
            v_year := to_char(current_date, 'YYYY')::SMALLINT;
        END IF;

    ELSIF ((v_datestring ~* v_defmask6_regexp AND v_culture <> 'FI') OR
           (v_datestring ~* v_defmask6_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA') OR
            (v_datestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{3,4}',
                                   '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                   '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP, '\d{1,2}|',
                                   '\d{3,4}', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP,
                                   TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}\s*(?:\.)+|',
                                   '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
             v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV'))
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_datestring, CASE v_culture
                                                             WHEN 'FI' THEN v_defmask6_fi_regexp
                                                             ELSE v_defmask6_regexp
                                                          END, 'gi');
        v_timestring := concat(v_regmatch_groups[1], v_regmatch_groups[5]);
        v_day := v_regmatch_groups[4];
        v_month := v_regmatch_groups[3];
        v_year := CASE
                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_regmatch_groups[2]::SMALLINT - 543
                     ELSE v_regmatch_groups[2]::SMALLINT
                  END;

    ELSIF ((v_datestring ~* v_defmask2_regexp AND v_culture <> 'FI') OR
           (v_datestring ~* v_defmask2_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA') OR
            (v_datestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{3,4}',
                                   '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                   '(?:', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                   AMPM_REGEXP, TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?))', TIME_MASKSEP_REGEXP, '\d{1,2}|',
                                   '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
             v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV'))
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_datestring, CASE v_culture
                                                             WHEN 'FI' THEN v_defmask2_fi_regexp
                                                             ELSE v_defmask2_regexp
                                                          END, 'gi');
        v_timestring := v_regmatch_groups[2];
        v_correctnum := coalesce(v_regmatch_groups[1], v_regmatch_groups[3], v_regmatch_groups[5],
                                 v_regmatch_groups[6], v_regmatch_groups[8], v_regmatch_groups[9]);
        v_day := '01';
        v_month := v_regmatch_groups[7];
        v_year := CASE
                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_regmatch_groups[4]::SMALLINT - 543
                     ELSE v_regmatch_groups[4]::SMALLINT
                  END;

    ELSIF (v_datestring ~* v_defmask4_1_regexp OR
           (v_datestring ~* v_defmask4_2_regexp AND v_culture !~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV') OR
           (v_datestring ~* v_defmask9_regexp AND v_culture <> 'FI') OR
           (v_datestring ~* v_defmask9_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_datestring ~ concat('\d+\s*\.?(?:,+|,*', AMPM_REGEXP, ')', TIME_MASKSEP_FI_REGEXP, '\.+', TIME_MASKSEP_REGEXP, '$|',
                                  '\d+\s*\.', TIME_MASKSEP_FI_REGEXP, '\.', TIME_MASKSEP_FI_REGEXP, '$') AND
            v_culture = 'FI')
        THEN
            RAISE invalid_datetime_format;
        END IF;

        IF (v_datestring ~* v_defmask4_0_regexp) THEN
            v_timestring := (regexp_matches(v_datestring, v_defmask4_0_regexp, 'gi'))[1];
        ELSE
            v_timestring := v_datestring;
        END IF;

        v_res_date := current_date;
        v_day := to_char(v_res_date, 'DD');
        v_month := to_char(v_res_date, 'MM');
        v_year := to_char(v_res_date, 'YYYY')::SMALLINT;

    ELSIF ((v_datestring ~* v_defmask3_regexp AND v_culture <> 'FI') OR
           (v_datestring ~* v_defmask3_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA') OR
            (v_datestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?',
                                   TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP, '|',
                                   '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
             v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV'))
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_datestring, CASE v_culture
                                                             WHEN 'FI' THEN v_defmask3_fi_regexp
                                                             ELSE v_defmask3_regexp
                                                          END, 'gi');
        v_timestring := v_regmatch_groups[1];
        v_day := '01';
        v_month := v_regmatch_groups[2];
        v_year := CASE
                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_regmatch_groups[3]::SMALLINT - 543
                     ELSE v_regmatch_groups[3]::SMALLINT
                  END;

    ELSIF ((v_datestring ~* v_defmask5_regexp AND v_culture <> 'FI') OR
           (v_datestring ~* v_defmask5_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA') OR
            (v_datestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP,
                                   TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP,
                                   TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{3,4}', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$|',
                                   '\d{1,2}', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{3,4}\s*(?:\.)+|',
                                   '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
             v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV'))
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_datestring, v_defmask5_regexp, 'gi');
        v_timestring := concat(v_regmatch_groups[1], v_regmatch_groups[5]);
        v_year := CASE
                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_regmatch_groups[4]::SMALLINT - 543
                     ELSE v_regmatch_groups[4]::SMALLINT
                  END;

        IF (v_date_format = 'DMY' OR
            v_culture IN ('LV-LV', 'LV_LV'))
        THEN
            v_day := v_regmatch_groups[2];
            v_month := v_regmatch_groups[3];
        ELSE
            v_day := v_regmatch_groups[3];
            v_month := v_regmatch_groups[2];
        END IF;

    ELSIF ((v_datestring ~* v_defmask7_regexp AND v_culture <> 'FI') OR
           (v_datestring ~* v_defmask7_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA') OR
            (v_datestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}',
                                   MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{3,4}|',
                                   '\d{3,4}', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}\s*(?:\.)+|',
                                   '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
             v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV'))
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_datestring, CASE v_culture
                                                             WHEN 'FI' THEN v_defmask7_fi_regexp
                                                             ELSE v_defmask7_regexp
                                                          END, 'gi');
        v_timestring := concat(v_regmatch_groups[1], v_regmatch_groups[5]);
        v_day := v_regmatch_groups[4];
        v_month := v_regmatch_groups[2];
        v_year := CASE
                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_regmatch_groups[3]::SMALLINT - 543
                     ELSE v_regmatch_groups[3]::SMALLINT
                  END;

    ELSIF ((v_datestring ~* v_defmask8_regexp AND v_culture <> 'FI') OR
           (v_datestring ~* v_defmask8_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_datestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}',
                                  MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP,
                                  TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}|',
                                  '\d{1,2}', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP,
                                  TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}\s*(?:\.)+|',
                                  '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
            v_culture ~ 'FI|DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV')
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_datestring, CASE v_culture
                                                             WHEN 'FI' THEN v_defmask8_fi_regexp
                                                             ELSE v_defmask8_regexp
                                                          END, 'gi');
        v_timestring := concat(v_regmatch_groups[1], v_regmatch_groups[5]);

        IF (v_date_format = 'DMY' OR
            v_culture IN ('LV-LV', 'LV_LV'))
        THEN
            v_day := v_regmatch_groups[2];
            v_month := v_regmatch_groups[3];
            v_raw_year := v_regmatch_groups[4];
        ELSIF (v_date_format = 'YMD')
        THEN
            v_day := v_regmatch_groups[4];
            v_month := v_regmatch_groups[3];
            v_raw_year := v_regmatch_groups[2];
        ELSE
            v_day := v_regmatch_groups[3];
            v_month := v_regmatch_groups[2];
            v_raw_year := v_regmatch_groups[4];
        END IF;

        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA'))
        THEN
            IF (v_day::SMALLINT > 30 OR
                v_month::SMALLINT > 12) THEN
                RAISE invalid_datetime_format;
            END IF;

            v_raw_year := aws_sqlserver_ext.get_full_year(v_raw_year, '14');
            v_hijridate := aws_sqlserver_ext.conv_hijri_to_greg(v_day, v_month, v_raw_year) - 1;

            v_day := to_char(v_hijridate, 'DD');
            v_month := to_char(v_hijridate, 'MM');
            v_year := to_char(v_hijridate, 'YYYY')::SMALLINT;

        ELSIF (v_culture IN ('TH-TH', 'TH_TH')) THEN
            v_year := aws_sqlserver_ext.get_full_year(v_raw_year)::SMALLINT - 43;
        ELSE
            v_year := aws_sqlserver_ext.get_full_year(v_raw_year, '', 29)::SMALLINT;
        END IF;
    ELSE
        v_found := FALSE;
    END IF;

    WHILE (NOT v_found AND v_resmask_cnt < 20)
    LOOP
        v_resmask := replace(CASE v_resmask_cnt
                                WHEN 10 THEN v_defmask10_regexp
                                WHEN 11 THEN v_defmask11_regexp
                                WHEN 12 THEN v_defmask12_regexp
                                WHEN 13 THEN v_defmask13_regexp
                                WHEN 14 THEN v_defmask14_regexp
                                WHEN 15 THEN v_defmask15_regexp
                                WHEN 16 THEN v_defmask16_regexp
                                WHEN 17 THEN v_defmask17_regexp
                                WHEN 18 THEN v_defmask18_regexp
                                WHEN 19 THEN v_defmask19_regexp
                             END,
                             '$comp_month$', v_compmonth_regexp);

        v_resmask_fi := replace(CASE v_resmask_cnt
                                   WHEN 10 THEN v_defmask10_fi_regexp
                                   WHEN 11 THEN v_defmask11_fi_regexp
                                   WHEN 12 THEN v_defmask12_fi_regexp
                                   WHEN 13 THEN v_defmask13_fi_regexp
                                   WHEN 14 THEN v_defmask14_fi_regexp
                                   WHEN 15 THEN v_defmask15_fi_regexp
                                   WHEN 16 THEN v_defmask16_fi_regexp
                                   WHEN 17 THEN v_defmask17_fi_regexp
                                   WHEN 18 THEN v_defmask18_fi_regexp
                                   WHEN 19 THEN v_defmask19_fi_regexp
                                END,
                                '$comp_month$', v_compmonth_regexp);

        IF ((v_datestring ~* v_resmask AND v_culture <> 'FI') OR
            (v_datestring ~* v_resmask_fi AND v_culture = 'FI'))
        THEN
            v_found := TRUE;
            v_regmatch_groups := regexp_matches(v_datestring, CASE v_culture
                                                                 WHEN 'FI' THEN v_resmask_fi
                                                                 ELSE v_resmask
                                                              END, 'gi');
            v_timestring := CASE
                               WHEN v_resmask_cnt IN (10, 11, 12, 13) THEN concat(v_regmatch_groups[1], v_regmatch_groups[4])
                               ELSE concat(v_regmatch_groups[1], v_regmatch_groups[5])
                            END;

            IF (v_resmask_cnt = 10)
            THEN
                IF (v_regmatch_groups[3] = 'MAR' AND
                    v_culture IN ('IT-IT', 'IT_IT'))
                THEN
                    RAISE invalid_datetime_format;
                END IF;

                IF (v_date_format = 'YMD' AND v_culture NOT IN ('SV-SE', 'SV_SE', 'LV-LV', 'LV_LV'))
                THEN
                    v_day := '01';
                    v_year := aws_sqlserver_ext.get_full_year(v_regmatch_groups[2], '', 29)::SMALLINT;
                ELSE
                    v_day := v_regmatch_groups[2];
                    v_year := to_char(current_date, 'YYYY')::SMALLINT;
                END IF;

                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[3], v_lang_metadata_json);
                v_raw_year := to_char(aws_sqlserver_ext.conv_greg_to_hijri(current_date + 1), 'YYYY');

            ELSIF (v_resmask_cnt = 11)
            THEN
                IF (v_date_format IN ('YMD', 'MDY') AND v_culture NOT IN ('SV-SE', 'SV_SE'))
                THEN
                    v_day := v_regmatch_groups[3];
                    v_year := to_char(current_date, 'YYYY')::SMALLINT;
                ELSE
                    v_day := '01';
                    v_year := CASE
                                 WHEN v_culture IN ('TH-TH', 'TH_TH') THEN aws_sqlserver_ext.get_full_year(v_regmatch_groups[3])::SMALLINT - 43
                                 ELSE aws_sqlserver_ext.get_full_year(v_regmatch_groups[3], '', 29)::SMALLINT
                              END;
                END IF;

                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
                v_raw_year := aws_sqlserver_ext.get_full_year(substring(v_year::TEXT, 3, 2), '14');

            ELSIF (v_resmask_cnt = 12)
            THEN
                v_day := '01';
                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[3], v_lang_metadata_json);
                v_raw_year := v_regmatch_groups[2];

            ELSIF (v_resmask_cnt = 13)
            THEN
                v_day := '01';
                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
                v_raw_year := v_regmatch_groups[3];

            ELSIF (v_resmask_cnt IN (14, 15, 16))
            THEN
                IF (v_resmask_cnt = 14)
                THEN
                    v_left_part := v_regmatch_groups[4];
                    v_right_part := v_regmatch_groups[3];
                    v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
                ELSIF (v_resmask_cnt = 15)
                THEN
                    v_left_part := v_regmatch_groups[4];
                    v_right_part := v_regmatch_groups[2];
                    v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[3], v_lang_metadata_json);
                ELSE
                    v_left_part := v_regmatch_groups[3];
                    v_right_part := v_regmatch_groups[2];
                    v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[4], v_lang_metadata_json);
                END IF;

                IF (char_length(v_left_part) <= 2)
                THEN
                    IF (v_date_format = 'YMD' AND v_culture NOT IN ('LV-LV', 'LV_LV'))
                    THEN
                        v_day := v_left_part;
                        v_raw_year := aws_sqlserver_ext.get_full_year(v_right_part, '14');
                        v_year := CASE
                                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN aws_sqlserver_ext.get_full_year(v_right_part)::SMALLINT - 43
                                     ELSE aws_sqlserver_ext.get_full_year(v_right_part, '', 29)::SMALLINT
                                  END;
                        BEGIN
                            v_res_date := make_date(v_year, v_month::SMALLINT, v_day::SMALLINT);
                        EXCEPTION
                        WHEN OTHERS THEN
                            v_day := v_right_part;
                            v_raw_year := aws_sqlserver_ext.get_full_year(v_left_part, '14');
                            v_year := CASE
                                         WHEN v_culture IN ('TH-TH', 'TH_TH') THEN aws_sqlserver_ext.get_full_year(v_left_part)::SMALLINT - 43
                                         ELSE aws_sqlserver_ext.get_full_year(v_left_part, '', 29)::SMALLINT
                                      END;
                        END;
                    END IF;

                    IF (v_date_format IN ('MDY', 'DMY') OR v_culture IN ('LV-LV', 'LV_LV'))
                    THEN
                        v_day := v_right_part;
                        v_raw_year := aws_sqlserver_ext.get_full_year(v_left_part, '14');
                        v_year := CASE
                                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN aws_sqlserver_ext.get_full_year(v_left_part)::SMALLINT - 43
                                     ELSE aws_sqlserver_ext.get_full_year(v_left_part, '', 29)::SMALLINT
                                  END;
                        BEGIN
                            v_res_date := make_date(v_year, v_month::SMALLINT, v_day::SMALLINT);
                        EXCEPTION
                        WHEN OTHERS THEN
                            v_day := v_left_part;
                            v_raw_year := aws_sqlserver_ext.get_full_year(v_right_part, '14');
                            v_year := CASE
                                         WHEN v_culture IN ('TH-TH', 'TH_TH') THEN aws_sqlserver_ext.get_full_year(v_right_part)::SMALLINT - 43
                                         ELSE aws_sqlserver_ext.get_full_year(v_right_part, '', 29)::SMALLINT
                                      END;
                        END;
                    END IF;
                ELSE
                    v_day := v_right_part;
                    v_raw_year := v_left_part;
	            v_year := CASE
                                 WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_left_part::SMALLINT - 543
                                 ELSE v_left_part::SMALLINT
                              END;
                END IF;

            ELSIF (v_resmask_cnt = 17)
            THEN
                v_day := v_regmatch_groups[4];
                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[3], v_lang_metadata_json);
                v_raw_year := v_regmatch_groups[2];

            ELSIF (v_resmask_cnt = 18)
            THEN
                v_day := v_regmatch_groups[3];
                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[4], v_lang_metadata_json);
                v_raw_year := v_regmatch_groups[2];

            ELSIF (v_resmask_cnt = 19)
            THEN
                v_day := v_regmatch_groups[4];
                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
                v_raw_year := v_regmatch_groups[3];
            END IF;

            IF (v_resmask_cnt NOT IN (10, 11, 14, 15, 16))
            THEN
                v_year := CASE
                             WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_raw_year::SMALLINT - 543
                             ELSE v_raw_year::SMALLINT
                          END;
            END IF;

            IF (v_culture IN ('AR', 'AR-SA', 'AR_SA'))
            THEN
                IF (v_day::SMALLINT > 30 OR
                    (v_resmask_cnt NOT IN (10, 11, 14, 15, 16) AND v_year NOT BETWEEN 1318 AND 1501) OR
                    (v_resmask_cnt IN (14, 15, 16) AND v_raw_year::SMALLINT NOT BETWEEN 1318 AND 1501))
                THEN
                    RAISE invalid_datetime_format;
                END IF;

                v_hijridate := aws_sqlserver_ext.conv_hijri_to_greg(v_day, v_month, v_raw_year) - 1;

                v_day := to_char(v_hijridate, 'DD');
                v_month := to_char(v_hijridate, 'MM');
                v_year := to_char(v_hijridate, 'YYYY')::SMALLINT;
            END IF;
        END IF;

        v_resmask_cnt := v_resmask_cnt + 1;
    END LOOP;

    IF (NOT v_found) THEN
        RAISE invalid_datetime_format;
    END IF;

    IF (char_length(v_timestring) > 0 AND v_timestring NOT IN ('AM', 'Шµ', 'PM', 'Щ…'))
    THEN
        IF (v_culture = 'FI') THEN
            v_timestring := translate(v_timestring, '.,', ': ');

            IF (char_length(split_part(v_timestring, ':', 4)) > 0) THEN
                v_timestring := regexp_replace(v_timestring, ':(?=\s*\d+\s*:?\s*(?:[AP]M|Шµ|Щ…)?\s*$)', '.');
            END IF;
        END IF;

        v_timestring := replace(regexp_replace(v_timestring, '\.?[AP]M|Шµ|Щ…|\s|\,|\.\D|[\.|:]$', '', 'gi'), ':.', ':');
        BEGIN
            v_hours := coalesce(split_part(v_timestring, ':', 1)::SMALLINT, 0);

            IF ((v_dayparts[1] IN ('AM', 'Шµ') AND v_hours NOT BETWEEN 0 AND 12) OR
                (v_dayparts[1] IN ('PM', 'Щ…') AND v_hours NOT BETWEEN 1 AND 23))
            THEN
                RAISE invalid_datetime_format;
            END IF;

            v_minutes := coalesce(nullif(split_part(v_timestring, ':', 2), '')::SMALLINT, 0);
            v_seconds := coalesce(nullif(split_part(v_timestring, ':', 3), '')::NUMERIC, 0);
        EXCEPTION
            WHEN OTHERS THEN
            RAISE invalid_datetime_format;
        END;
    ELSIF (v_dayparts[1] IN ('PM', 'Щ…'))
    THEN
        v_hours := 12;
    END IF;

    v_res_date := make_timestamp(v_year, v_month::SMALLINT, v_day::SMALLINT,
                                 v_hours, v_minutes, v_seconds);

    IF (v_weekdaynames[1] IS NOT NULL) THEN
        v_weekdaynum := aws_sqlserver_ext.get_weekdaynum_by_name(v_weekdaynames[1], v_lang_metadata_json);

        IF (CASE date_part('dow', v_res_date)::SMALLINT
               WHEN 0 THEN 7
               ELSE date_part('dow', v_res_date)::SMALLINT
            END <> v_weekdaynum)
        THEN
            RAISE invalid_datetime_format;
        END IF;
    END IF;

    RETURN v_res_date;
EXCEPTION
    WHEN invalid_datetime_format OR datetime_field_overflow THEN
        RAISE USING MESSAGE := format('Error converting string value ''%s'' into data type DATE using culture ''%s''.',
                                      p_datestring, p_culture),
                    DETAIL := 'Incorrect using of pair of input parameters values during conversion process.',
                    HINT := 'Check the input parameters values, correct them if needed, and try again.';

    WHEN invalid_parameter_value THEN
        RAISE USING MESSAGE := CASE char_length(coalesce(CONVERSION_LANG, ''))
                                  WHEN 0 THEN format('The culture parameter ''%s'' provided in the function call is not supported.',
                                                     p_culture)
                                  ELSE format('Invalid CONVERSION_LANG constant value - ''%s''. Allowed values are: ''English'', ''Deutsch'', etc.',
                                              CONVERSION_LANG)
                               END,
                    DETAIL := 'Passed incorrect value for "p_culture" parameter or compiled incorrect CONVERSION_LANG constant value in function''s body.',
                    HINT := 'Check "p_culture" input parameter value, correct it if needed, and try again. Also check CONVERSION_LANG constant value.';

    WHEN invalid_text_representation THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
        v_err_message := substring(lower(v_err_message), 'integer\:\s\"(.*)\"');

        RAISE USING MESSAGE := format('Error while trying to convert "%s" value to SMALLINT data type.',
                                      v_err_message),
                    DETAIL := 'Supplied value contains illegal characters.',
                    HINT := 'Correct supplied value, remove all illegal characters.';
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.parse_to_date(p_datestring text, p_culture text) OWNER TO postgres;

--
-- TOC entry 3890 (class 0 OID 0)
-- Dependencies: 363
-- Name: FUNCTION parse_to_date(p_datestring text, p_culture text); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.parse_to_date(p_datestring text, p_culture text) IS 'This function parses the TEXT string and translate it into a DATE value, according to specified culture (conversion mask).';


--
-- TOC entry 364 (class 1255 OID 17069)
-- Name: parse_to_datetime(text, text, text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.parse_to_datetime(p_datatype text, p_datetimestring text, p_culture text DEFAULT ''::text) RETURNS timestamp without time zone
    LANGUAGE plpgsql STRICT
    AS $_$
DECLARE
    v_day VARCHAR;
    v_year SMALLINT;
    v_month VARCHAR;
    v_res_date DATE;
    v_scale SMALLINT;
    v_hijridate DATE;
    v_culture VARCHAR;
    v_dayparts TEXT[];
    v_resmask VARCHAR;
    v_datatype VARCHAR;
    v_raw_year VARCHAR;
    v_left_part VARCHAR;
    v_right_part VARCHAR;
    v_resmask_fi VARCHAR;
    v_timestring VARCHAR;
    v_correctnum VARCHAR;
    v_weekdaynum SMALLINT;
    v_err_message VARCHAR;
    v_date_format VARCHAR;
    v_weekdaynames TEXT[];
    v_hours SMALLINT := 0;
    v_minutes SMALLINT := 0;
    v_res_datatype VARCHAR;
    v_error_message VARCHAR;
    v_found BOOLEAN := TRUE;
    v_compday_regexp VARCHAR;
    v_regmatch_groups TEXT[];
    v_datatype_groups TEXT[];
    v_datetimestring VARCHAR;
    v_seconds VARCHAR := '0';
    v_fseconds VARCHAR := '0';
    v_compmonth_regexp VARCHAR;
    v_lang_metadata_json JSONB;
    v_resmask_cnt SMALLINT := 10;
    v_res_datetime TIMESTAMP(6) WITHOUT TIME ZONE;
    DAYMM_REGEXP CONSTANT VARCHAR := '(\d{1,2})';
    FULLYEAR_REGEXP CONSTANT VARCHAR := '(\d{3,4})';
    SHORTYEAR_REGEXP CONSTANT VARCHAR := '(\d{1,2})';
    COMPYEAR_REGEXP CONSTANT VARCHAR := '(\d{1,4})';
    AMPM_REGEXP CONSTANT VARCHAR := '(?:[AP]M|Шµ|Щ…)';
    TIMEUNIT_REGEXP CONSTANT VARCHAR := '\s*\d{1,2}\s*';
    MASKSEPONE_REGEXP CONSTANT VARCHAR := '\s*(?:/|-)?';
    MASKSEPTWO_REGEXP CONSTANT VARCHAR := '\s*(?:\s|/|-|\.|,)';
    MASKSEPTWO_FI_REGEXP CONSTANT VARCHAR := '\s*(?:\s|/|-|,)';
    MASKSEPTHREE_REGEXP CONSTANT VARCHAR := '\s*(?:/|-|\.|,)';
    TIME_MASKSEP_REGEXP CONSTANT VARCHAR := '(?:\s|\.|,)*';
    TIME_MASKSEP_FI_REGEXP CONSTANT VARCHAR := '(?:\s|,)*';
    WEEKDAYAMPM_START_REGEXP CONSTANT VARCHAR := '(^|[[:digit:][:space:]\.,])';
    WEEKDAYAMPM_END_REGEXP CONSTANT VARCHAR := '([[:digit:][:space:]\.,]|$)(?=[^/-]|$)';
    CORRECTNUM_REGEXP CONSTANT VARCHAR := '(?:([+-]\d{1,4})(?:[[:space:]\.,]|[AP]M|Шµ|Щ…|$))';
    DATATYPE_REGEXP CONSTANT VARCHAR := '^(DATETIME|SMALLDATETIME|DATETIME2)\s*(?:\()?\s*((?:-)?\d+)?\s*(?:\))?$';
    ANNO_DOMINI_REGEXP VARCHAR := '(AD|A\.D\.)';
    ANNO_DOMINI_COMPREGEXP VARCHAR := concat(WEEKDAYAMPM_START_REGEXP, ANNO_DOMINI_REGEXP, WEEKDAYAMPM_END_REGEXP);
    HHMMSSFS_PART_REGEXP CONSTANT VARCHAR :=
        concat(TIMEUNIT_REGEXP, AMPM_REGEXP, '|',
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '\:', TIME_MASKSEP_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '(?!\d)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?|',
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '\:', TIME_MASKSEP_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '\:', TIME_MASKSEP_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '(?!\d)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?|',
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '\:', TIME_MASKSEP_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '\:', TIME_MASKSEP_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\s*\d{1,2}\.\d+(?!\d)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?|',
               AMPM_REGEXP, '?');
    HHMMSSFS_PART_FI_REGEXP CONSTANT VARCHAR :=
        concat(TIMEUNIT_REGEXP, AMPM_REGEXP, '|',
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '[\:\.]', TIME_MASKSEP_FI_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '(?!\d)', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?\.?|',
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '[\:\.]', TIME_MASKSEP_FI_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '[\:\.]', TIME_MASKSEP_FI_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '(?!\d)', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?|',
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '[\:\.]', TIME_MASKSEP_FI_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '[\:\.]', TIME_MASKSEP_FI_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, '\s*\d{1,2}\.\d+(?!\d)\.?', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?|',
               AMPM_REGEXP, '?');
    v_defmask1_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        TIME_MASKSEP_REGEXP, '(?:[\.|,]+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)', TIME_MASKSEP_REGEXP, '$');
    v_defmask1_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP,
                                           '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_FI_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:', MASKSEPTWO_FI_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP,
                                           CORRECTNUM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[,]+', AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           TIME_MASKSEP_FI_REGEXP, '(?:[\.|,]+', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask2_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        FULLYEAR_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        AMPM_REGEXP, TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        TIME_MASKSEP_REGEXP, '(?:(?:[\.|,]+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?)|',
                                        CORRECTNUM_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP, '$');
    v_defmask2_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP,
                                           '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           CORRECTNUM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP,
                                           FULLYEAR_REGEXP,
                                           '(?:(?:', MASKSEPTWO_FI_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:', TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP,
                                           AMPM_REGEXP, TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           TIME_MASKSEP_FI_REGEXP, '(?:(?:[\.|,]+', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?)|',
                                           CORRECTNUM_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask3_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, ')|',
                                        '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        FULLYEAR_REGEXP,
                                        TIME_MASKSEP_REGEXP, '(', TIME_MASKSEP_REGEXP, AMPM_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask3_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           TIME_MASKSEP_FI_REGEXP, '[\./]?', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)',
                                           FULLYEAR_REGEXP,
                                           TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask4_0_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP, '\s*(', AMPM_REGEXP, ')',
                                          TIME_MASKSEP_REGEXP, '$');
    v_defmask4_1_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          '(?:\s|,)+',
                                          DAYMM_REGEXP, '\s*(', AMPM_REGEXP, ')',
                                          TIME_MASKSEP_REGEXP, '$');
    v_defmask4_2_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          '\s*[\.]+', TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP, '\s*(', AMPM_REGEXP, ')',
                                          TIME_MASKSEP_REGEXP, '$');
    v_defmask5_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        FULLYEAR_REGEXP,
                                        TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask5_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           FULLYEAR_REGEXP,
                                           TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask6_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        FULLYEAR_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '((?:(?:\s|\.|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_REGEXP, '))?', TIME_MASKSEP_REGEXP, '$');
    v_defmask6_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           FULLYEAR_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:\s*[\.])?',
                                           '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask7_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        FULLYEAR_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '((?:(?:\s|\.|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_REGEXP, '))?', TIME_MASKSEP_REGEXP, '$');
    v_defmask7_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           FULLYEAR_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask8_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:[\.|,]+', AMPM_REGEXP, ')?',
                                        TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask8_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_FI_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:[\,]+|\s*/\s*)', AMPM_REGEXP, ')?',
                                           TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask9_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(',
                                        HHMMSSFS_PART_REGEXP,
                                        ')', TIME_MASKSEP_REGEXP, '$');
    v_defmask9_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, '(',
                                           HHMMSSFS_PART_FI_REGEXP,
                                           ')', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask10_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)?', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask10_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            DAYMM_REGEXP,
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)?', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask11_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask11_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           '($comp_month$)',
                                           '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask12_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         FULLYEAR_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                         '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask12_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            FULLYEAR_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                            '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask13_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         FULLYEAR_REGEXP,
                                         TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$');
    v_defmask13_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            '($comp_month$)',
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                            FULLYEAR_REGEXP,
                                            TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask14_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)'
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)', TIME_MASKSEP_REGEXP,
                                         COMPYEAR_REGEXP,
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask14_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            '($comp_month$)'
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_FI_REGEXP,
                                            DAYMM_REGEXP,
                                            '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)', TIME_MASKSEP_FI_REGEXP,
                                            COMPYEAR_REGEXP,
                                            '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask15_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                         '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         COMPYEAR_REGEXP,
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask15_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            DAYMM_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                            '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                            COMPYEAR_REGEXP,
                                            '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask16_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)', TIME_MASKSEP_REGEXP,
                                         COMPYEAR_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                         '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask16_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            DAYMM_REGEXP,
                                            '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)', TIME_MASKSEP_REGEXP,
                                            COMPYEAR_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                            '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask17_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         FULLYEAR_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                         '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask17_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            FULLYEAR_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                            '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                            DAYMM_REGEXP,
                                            '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask18_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         FULLYEAR_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                         '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                         '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask18_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            FULLYEAR_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                            '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                            DAYMM_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                            '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask19_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         FULLYEAR_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                         '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '((?:(?:\s|\.|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_REGEXP, '))?', TIME_MASKSEP_REGEXP, '$');
    v_defmask19_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            '($comp_month$)',
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                            FULLYEAR_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                            '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                            DAYMM_REGEXP,
                                            '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    CONVERSION_LANG CONSTANT VARCHAR := 'English';
    DATE_FORMAT CONSTANT VARCHAR := '';
BEGIN
    v_datatype := trim(p_datatype);
    v_datetimestring := upper(trim(p_datetimestring));
    v_culture := coalesce(nullif(upper(trim(p_culture)), ''), 'EN-US');

    v_datatype_groups := regexp_matches(v_datatype, DATATYPE_REGEXP, 'gi');

    v_res_datatype := upper(v_datatype_groups[1]);
    v_scale := v_datatype_groups[2]::SMALLINT;

    IF (v_res_datatype IS NULL) THEN
        RAISE datatype_mismatch;
    ELSIF (v_res_datatype <> 'DATETIME2' AND v_scale IS NOT NULL)
    THEN
        RAISE invalid_indicator_parameter_value;
    ELSIF (coalesce(v_scale, 0) NOT BETWEEN 0 AND 7)
    THEN
        RAISE interval_field_overflow;
    ELSIF (v_scale IS NULL) THEN
        v_scale := 7;
    END IF;

    v_dayparts := ARRAY(SELECT upper(array_to_string(regexp_matches(v_datetimestring, '[AP]M|Шµ|Щ…', 'gi'), '')));

    IF (array_length(v_dayparts, 1) > 1) THEN
        RAISE invalid_datetime_format;
    END IF;

    BEGIN
        v_lang_metadata_json := aws_sqlserver_ext.get_lang_metadata_json(coalesce(nullif(CONVERSION_LANG, ''), p_culture));
    EXCEPTION
        WHEN OTHERS THEN
        RAISE invalid_parameter_value;
    END;

    v_compday_regexp := array_to_string(array_cat(array_cat(ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'days_names')),
                                                            ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'days_shortnames'))),
                                                  ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'days_extrashortnames'))), '|');

    v_weekdaynames := ARRAY(SELECT array_to_string(regexp_matches(v_datetimestring, v_compday_regexp, 'gi'), ''));

    IF (array_length(v_weekdaynames, 1) > 1) THEN
        RAISE invalid_datetime_format;
    END IF;

    IF (v_weekdaynames[1] IS NOT NULL AND
        v_datetimestring ~* concat(WEEKDAYAMPM_START_REGEXP, '(', v_compday_regexp, ')', WEEKDAYAMPM_END_REGEXP))
    THEN
        v_datetimestring := replace(v_datetimestring, v_weekdaynames[1], ' ');
    END IF;

    IF (v_datetimestring ~* ANNO_DOMINI_COMPREGEXP)
    THEN
        IF (v_culture !~ 'EN[-_]US|DA[-_]DK|SV[-_]SE|EN[-_]GB|HI[-_]IS') THEN
            RAISE invalid_datetime_format;
        END IF;

        v_datetimestring := regexp_replace(v_datetimestring,
                                           ANNO_DOMINI_COMPREGEXP,
                                           regexp_replace(array_to_string(regexp_matches(v_datetimestring, ANNO_DOMINI_COMPREGEXP, 'gi'), ''),
                                                          ANNO_DOMINI_REGEXP, ' ', 'gi'),
                                           'gi');
    END IF;

    v_date_format := coalesce(nullif(upper(trim(DATE_FORMAT)), ''), v_lang_metadata_json ->> 'date_format');

    v_compmonth_regexp :=
        array_to_string(array_cat(array_cat(ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'months_shortnames')),
                                            ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'months_names'))),
                                  array_cat(ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'months_extrashortnames')),
                                            ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'months_extranames')))
                                 ), '|');

    IF ((v_datetimestring ~* v_defmask1_regexp AND v_culture <> 'FI') OR
        (v_datetimestring ~* v_defmask1_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_datetimestring ~ concat(CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                      CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP,
                                      AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}|',
                                      '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                      CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
            v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV')
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_datetimestring, CASE v_culture
                                                                 WHEN 'FI' THEN v_defmask1_fi_regexp
                                                                 ELSE v_defmask1_regexp
                                                              END, 'gi');
        v_timestring := v_regmatch_groups[2];
        v_correctnum := coalesce(v_regmatch_groups[1], v_regmatch_groups[3],
                                 v_regmatch_groups[5], v_regmatch_groups[6]);

        IF (v_date_format = 'DMY' OR
            v_culture IN ('SV-SE', 'SV_SE', 'LV-LV', 'LV_LV'))
        THEN
            v_day := v_regmatch_groups[4];
            v_month := v_regmatch_groups[7];
        ELSE
            v_day := v_regmatch_groups[7];
            v_month := v_regmatch_groups[4];
        END IF;

        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA'))
        THEN
            IF (v_day::SMALLINT > 30 OR
                v_month::SMALLINT > 12) THEN
                RAISE invalid_datetime_format;
            END IF;

            v_raw_year := to_char(aws_sqlserver_ext.conv_greg_to_hijri(current_date + 1), 'YYYY');
            v_hijridate := aws_sqlserver_ext.conv_hijri_to_greg(v_day, v_month, v_raw_year) - 1;

            v_day := to_char(v_hijridate, 'DD');
            v_month := to_char(v_hijridate, 'MM');
            v_year := to_char(v_hijridate, 'YYYY')::SMALLINT;
        ELSE
            v_year := to_char(current_date, 'YYYY')::SMALLINT;
        END IF;

    ELSIF ((v_datetimestring ~* v_defmask6_regexp AND v_culture <> 'FI') OR
           (v_datetimestring ~* v_defmask6_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA') OR
            (v_datetimestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{3,4}',
                                       '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                       '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP, '\d{1,2}|',
                                       '\d{3,4}', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP,
                                       TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}\s*(?:\.)+|',
                                       '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
             v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV'))
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_datetimestring, CASE v_culture
                                                                 WHEN 'FI' THEN v_defmask6_fi_regexp
                                                                 ELSE v_defmask6_regexp
                                                              END, 'gi');
        v_timestring := concat(v_regmatch_groups[1], v_regmatch_groups[5]);
        v_day := v_regmatch_groups[4];
        v_month := v_regmatch_groups[3];
        v_year := CASE
                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_regmatch_groups[2]::SMALLINT - 543
                     ELSE v_regmatch_groups[2]::SMALLINT
                  END;

    ELSIF ((v_datetimestring ~* v_defmask2_regexp AND v_culture <> 'FI') OR
           (v_datetimestring ~* v_defmask2_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA') OR
            (v_datetimestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{3,4}',
                                       '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                       '(?:', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                       AMPM_REGEXP, TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?))', TIME_MASKSEP_REGEXP, '\d{1,2}|',
                                       '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
             v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV'))
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_datetimestring, CASE v_culture
                                                                 WHEN 'FI' THEN v_defmask2_fi_regexp
                                                                 ELSE v_defmask2_regexp
                                                              END, 'gi');
        v_timestring := v_regmatch_groups[2];
        v_correctnum := coalesce(v_regmatch_groups[1], v_regmatch_groups[3], v_regmatch_groups[5],
                                 v_regmatch_groups[6], v_regmatch_groups[8], v_regmatch_groups[9]);
        v_day := '01';
        v_month := v_regmatch_groups[7];
        v_year := CASE
                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_regmatch_groups[4]::SMALLINT - 543
                     ELSE v_regmatch_groups[4]::SMALLINT
                  END;

    ELSIF (v_datetimestring ~* v_defmask4_1_regexp OR
           (v_datetimestring ~* v_defmask4_2_regexp AND v_culture !~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV') OR
           (v_datetimestring ~* v_defmask9_regexp AND v_culture <> 'FI') OR
           (v_datetimestring ~* v_defmask9_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_datetimestring ~ concat('\d+\s*\.?(?:,+|,*', AMPM_REGEXP, ')', TIME_MASKSEP_FI_REGEXP, '\.+', TIME_MASKSEP_REGEXP, '$|',
                                      '\d+\s*\.', TIME_MASKSEP_FI_REGEXP, '\.', TIME_MASKSEP_FI_REGEXP, '$') AND
            v_culture = 'FI')
        THEN
            RAISE invalid_datetime_format;
        END IF;

        IF (v_datetimestring ~* v_defmask4_0_regexp) THEN
            v_timestring := (regexp_matches(v_datetimestring, v_defmask4_0_regexp, 'gi'))[1];
        ELSE
            v_timestring := v_datetimestring;
        END IF;

        v_res_date := current_date;
        v_day := to_char(v_res_date, 'DD');
        v_month := to_char(v_res_date, 'MM');
        v_year := to_char(v_res_date, 'YYYY')::SMALLINT;

    ELSIF ((v_datetimestring ~* v_defmask3_regexp AND v_culture <> 'FI') OR
           (v_datetimestring ~* v_defmask3_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA') OR
            (v_datetimestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?',
                                       TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP, '|',
                                       '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
             v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV'))
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_datetimestring, CASE v_culture
                                                                 WHEN 'FI' THEN v_defmask3_fi_regexp
                                                                 ELSE v_defmask3_regexp
                                                              END, 'gi');
        v_timestring := v_regmatch_groups[1];
        v_day := '01';
        v_month := v_regmatch_groups[2];
        v_year := CASE
                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_regmatch_groups[3]::SMALLINT - 543
                     ELSE v_regmatch_groups[3]::SMALLINT
                  END;

    ELSIF ((v_datetimestring ~* v_defmask5_regexp AND v_culture <> 'FI') OR
           (v_datetimestring ~* v_defmask5_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA') OR
            (v_datetimestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP,
                                       TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP,
                                       TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{3,4}', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$|',
                                       '\d{1,2}', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{3,4}\s*(?:\.)+|',
                                       '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
             v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV'))
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_datetimestring, v_defmask5_regexp, 'gi');
        v_timestring := concat(v_regmatch_groups[1], v_regmatch_groups[5]);
        v_year := CASE
                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_regmatch_groups[4]::SMALLINT - 543
                     ELSE v_regmatch_groups[4]::SMALLINT
                  END;

        IF (v_date_format = 'DMY' OR
            v_culture IN ('LV-LV', 'LV_LV'))
        THEN
            v_day := v_regmatch_groups[2];
            v_month := v_regmatch_groups[3];
        ELSE
            v_day := v_regmatch_groups[3];
            v_month := v_regmatch_groups[2];
        END IF;

    ELSIF ((v_datetimestring ~* v_defmask7_regexp AND v_culture <> 'FI') OR
           (v_datetimestring ~* v_defmask7_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA') OR
            (v_datetimestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}',
                                       MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{3,4}|',
                                       '\d{3,4}', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}\s*(?:\.)+|',
                                       '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
             v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV'))
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_datetimestring, CASE v_culture
                                                                 WHEN 'FI' THEN v_defmask7_fi_regexp
                                                                 ELSE v_defmask7_regexp
                                                              END, 'gi');
        v_timestring := concat(v_regmatch_groups[1], v_regmatch_groups[5]);
        v_day := v_regmatch_groups[4];
        v_month := v_regmatch_groups[2];
        v_year := CASE
                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_regmatch_groups[3]::SMALLINT - 543
                     ELSE v_regmatch_groups[3]::SMALLINT
                  END;

    ELSIF ((v_datetimestring ~* v_defmask8_regexp AND v_culture <> 'FI') OR
           (v_datetimestring ~* v_defmask8_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_datetimestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}',
                                      MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP,
                                      TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}|',
                                      '\d{1,2}', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP,
                                      TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}\s*(?:\.)+|',
                                      '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
            v_culture ~ 'FI|DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV')
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_datetimestring, CASE v_culture
                                                                 WHEN 'FI' THEN v_defmask8_fi_regexp
                                                                 ELSE v_defmask8_regexp
                                                              END, 'gi');
        v_timestring := concat(v_regmatch_groups[1], v_regmatch_groups[5]);

        IF (v_date_format = 'DMY' OR
            v_culture IN ('LV-LV', 'LV_LV'))
        THEN
            v_day := v_regmatch_groups[2];
            v_month := v_regmatch_groups[3];
            v_raw_year := v_regmatch_groups[4];
        ELSIF (v_date_format = 'YMD')
        THEN
            v_day := v_regmatch_groups[4];
            v_month := v_regmatch_groups[3];
            v_raw_year := v_regmatch_groups[2];
        ELSE
            v_day := v_regmatch_groups[3];
            v_month := v_regmatch_groups[2];
            v_raw_year := v_regmatch_groups[4];
        END IF;

        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA'))
        THEN
            IF (v_day::SMALLINT > 30 OR
                v_month::SMALLINT > 12) THEN
                RAISE invalid_datetime_format;
            END IF;

            v_raw_year := aws_sqlserver_ext.get_full_year(v_raw_year, '14');
            v_hijridate := aws_sqlserver_ext.conv_hijri_to_greg(v_day, v_month, v_raw_year) - 1;

            v_day := to_char(v_hijridate, 'DD');
            v_month := to_char(v_hijridate, 'MM');
            v_year := to_char(v_hijridate, 'YYYY')::SMALLINT;

        ELSIF (v_culture IN ('TH-TH', 'TH_TH')) THEN
            v_year := aws_sqlserver_ext.get_full_year(v_raw_year)::SMALLINT - 43;
        ELSE
            v_year := aws_sqlserver_ext.get_full_year(v_raw_year, '', 29)::SMALLINT;
        END IF;
    ELSE
        v_found := FALSE;
    END IF;

    WHILE (NOT v_found AND v_resmask_cnt < 20)
    LOOP
        v_resmask := replace(CASE v_resmask_cnt
                                WHEN 10 THEN v_defmask10_regexp
                                WHEN 11 THEN v_defmask11_regexp
                                WHEN 12 THEN v_defmask12_regexp
                                WHEN 13 THEN v_defmask13_regexp
                                WHEN 14 THEN v_defmask14_regexp
                                WHEN 15 THEN v_defmask15_regexp
                                WHEN 16 THEN v_defmask16_regexp
                                WHEN 17 THEN v_defmask17_regexp
                                WHEN 18 THEN v_defmask18_regexp
                                WHEN 19 THEN v_defmask19_regexp
                             END,
                             '$comp_month$', v_compmonth_regexp);

        v_resmask_fi := replace(CASE v_resmask_cnt
                                   WHEN 10 THEN v_defmask10_fi_regexp
                                   WHEN 11 THEN v_defmask11_fi_regexp
                                   WHEN 12 THEN v_defmask12_fi_regexp
                                   WHEN 13 THEN v_defmask13_fi_regexp
                                   WHEN 14 THEN v_defmask14_fi_regexp
                                   WHEN 15 THEN v_defmask15_fi_regexp
                                   WHEN 16 THEN v_defmask16_fi_regexp
                                   WHEN 17 THEN v_defmask17_fi_regexp
                                   WHEN 18 THEN v_defmask18_fi_regexp
                                   WHEN 19 THEN v_defmask19_fi_regexp
                                END,
                                '$comp_month$', v_compmonth_regexp);

        IF ((v_datetimestring ~* v_resmask AND v_culture <> 'FI') OR
            (v_datetimestring ~* v_resmask_fi AND v_culture = 'FI'))
        THEN
            v_found := TRUE;
            v_regmatch_groups := regexp_matches(v_datetimestring, CASE v_culture
                                                                     WHEN 'FI' THEN v_resmask_fi
                                                                     ELSE v_resmask
                                                                  END, 'gi');
            v_timestring := CASE
                               WHEN v_resmask_cnt IN (10, 11, 12, 13) THEN concat(v_regmatch_groups[1], v_regmatch_groups[4])
                               ELSE concat(v_regmatch_groups[1], v_regmatch_groups[5])
                            END;

            IF (v_resmask_cnt = 10)
            THEN
                IF (v_regmatch_groups[3] = 'MAR' AND
                    v_culture IN ('IT-IT', 'IT_IT'))
                THEN
                    RAISE invalid_datetime_format;
                END IF;

                IF (v_date_format = 'YMD' AND v_culture NOT IN ('SV-SE', 'SV_SE', 'LV-LV', 'LV_LV'))
                THEN
                    v_day := '01';
                    v_year := aws_sqlserver_ext.get_full_year(v_regmatch_groups[2], '', 29)::SMALLINT;
                ELSE
                    v_day := v_regmatch_groups[2];
                    v_year := to_char(current_date, 'YYYY')::SMALLINT;
                END IF;

                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[3], v_lang_metadata_json);
                v_raw_year := to_char(aws_sqlserver_ext.conv_greg_to_hijri(current_date + 1), 'YYYY');

            ELSIF (v_resmask_cnt = 11)
            THEN
                IF (v_date_format IN ('YMD', 'MDY') AND v_culture NOT IN ('SV-SE', 'SV_SE'))
                THEN
                    v_day := v_regmatch_groups[3];
                    v_year := to_char(current_date, 'YYYY')::SMALLINT;
                ELSE
                    v_day := '01';
                    v_year := CASE
                                 WHEN v_culture IN ('TH-TH', 'TH_TH') THEN aws_sqlserver_ext.get_full_year(v_regmatch_groups[3])::SMALLINT - 43
                                 ELSE aws_sqlserver_ext.get_full_year(v_regmatch_groups[3], '', 29)::SMALLINT
                              END;
                END IF;

                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
                v_raw_year := aws_sqlserver_ext.get_full_year(substring(v_year::TEXT, 3, 2), '14');

            ELSIF (v_resmask_cnt = 12)
            THEN
                v_day := '01';
                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[3], v_lang_metadata_json);
                v_raw_year := v_regmatch_groups[2];

            ELSIF (v_resmask_cnt = 13)
            THEN
                v_day := '01';
                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
                v_raw_year := v_regmatch_groups[3];

            ELSIF (v_resmask_cnt IN (14, 15, 16))
            THEN
                IF (v_resmask_cnt = 14)
                THEN
                    v_left_part := v_regmatch_groups[4];
                    v_right_part := v_regmatch_groups[3];
                    v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
                ELSIF (v_resmask_cnt = 15)
                THEN
                    v_left_part := v_regmatch_groups[4];
                    v_right_part := v_regmatch_groups[2];
                    v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[3], v_lang_metadata_json);
                ELSE
                    v_left_part := v_regmatch_groups[3];
                    v_right_part := v_regmatch_groups[2];
                    v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[4], v_lang_metadata_json);
                END IF;

                IF (char_length(v_left_part) <= 2)
                THEN
                    IF (v_date_format = 'YMD' AND v_culture NOT IN ('LV-LV', 'LV_LV'))
                    THEN
                        v_day := v_left_part;
                        v_raw_year := aws_sqlserver_ext.get_full_year(v_right_part, '14');
                        v_year := CASE
                                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN aws_sqlserver_ext.get_full_year(v_right_part)::SMALLINT - 43
                                     ELSE aws_sqlserver_ext.get_full_year(v_right_part, '', 29)::SMALLINT
                                  END;
                        BEGIN
                            v_res_date := make_date(v_year, v_month::SMALLINT, v_day::SMALLINT);
                        EXCEPTION
                        WHEN OTHERS THEN
                            v_day := v_right_part;
                            v_raw_year := aws_sqlserver_ext.get_full_year(v_left_part, '14');
                            v_year := CASE
                                         WHEN v_culture IN ('TH-TH', 'TH_TH') THEN aws_sqlserver_ext.get_full_year(v_left_part)::SMALLINT - 43
                                         ELSE aws_sqlserver_ext.get_full_year(v_left_part, '', 29)::SMALLINT
                                      END;
                        END;
                    END IF;

                    IF (v_date_format IN ('MDY', 'DMY') OR v_culture IN ('LV-LV', 'LV_LV'))
                    THEN
                        v_day := v_right_part;
                        v_raw_year := aws_sqlserver_ext.get_full_year(v_left_part, '14');
                        v_year := CASE
                                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN aws_sqlserver_ext.get_full_year(v_left_part)::SMALLINT - 43
                                     ELSE aws_sqlserver_ext.get_full_year(v_left_part, '', 29)::SMALLINT
                                  END;
                        BEGIN
                            v_res_date := make_date(v_year, v_month::SMALLINT, v_day::SMALLINT);
                        EXCEPTION
                        WHEN OTHERS THEN
                            v_day := v_left_part;
                            v_raw_year := aws_sqlserver_ext.get_full_year(v_right_part, '14');
                            v_year := CASE
                                         WHEN v_culture IN ('TH-TH', 'TH_TH') THEN aws_sqlserver_ext.get_full_year(v_right_part)::SMALLINT - 43
                                         ELSE aws_sqlserver_ext.get_full_year(v_right_part, '', 29)::SMALLINT
                                      END;
                        END;
                    END IF;
                ELSE
                    v_day := v_right_part;
                    v_raw_year := v_left_part;
	            v_year := CASE
                                 WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_left_part::SMALLINT - 543
                                 ELSE v_left_part::SMALLINT
                              END;
                END IF;

            ELSIF (v_resmask_cnt = 17)
            THEN
                v_day := v_regmatch_groups[4];
                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[3], v_lang_metadata_json);
                v_raw_year := v_regmatch_groups[2];

            ELSIF (v_resmask_cnt = 18)
            THEN
                v_day := v_regmatch_groups[3];
                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[4], v_lang_metadata_json);
                v_raw_year := v_regmatch_groups[2];

            ELSIF (v_resmask_cnt = 19)
            THEN
                v_day := v_regmatch_groups[4];
                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
                v_raw_year := v_regmatch_groups[3];
            END IF;

            IF (v_resmask_cnt NOT IN (10, 11, 14, 15, 16))
            THEN
                v_year := CASE
                             WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_raw_year::SMALLINT - 543
                             ELSE v_raw_year::SMALLINT
                          END;
            END IF;

            IF (v_culture IN ('AR', 'AR-SA', 'AR_SA'))
            THEN
                IF (v_day::SMALLINT > 30 OR
                    (v_resmask_cnt NOT IN (10, 11, 14, 15, 16) AND v_year NOT BETWEEN 1318 AND 1501) OR
                    (v_resmask_cnt IN (14, 15, 16) AND v_raw_year::SMALLINT NOT BETWEEN 1318 AND 1501))
                THEN
                    RAISE invalid_datetime_format;
                END IF;

                v_hijridate := aws_sqlserver_ext.conv_hijri_to_greg(v_day, v_month, v_raw_year) - 1;

                v_day := to_char(v_hijridate, 'DD');
                v_month := to_char(v_hijridate, 'MM');
                v_year := to_char(v_hijridate, 'YYYY')::SMALLINT;
            END IF;
        END IF;

        v_resmask_cnt := v_resmask_cnt + 1;
    END LOOP;

    IF (NOT v_found) THEN
        RAISE invalid_datetime_format;
    END IF;

    IF (char_length(v_timestring) > 0 AND v_timestring NOT IN ('AM', 'Шµ', 'PM', 'Щ…'))
    THEN
        IF (v_culture = 'FI') THEN
            v_timestring := translate(v_timestring, '.,', ': ');

            IF (char_length(split_part(v_timestring, ':', 4)) > 0) THEN
                v_timestring := regexp_replace(v_timestring, ':(?=\s*\d+\s*:?\s*(?:[AP]M|Шµ|Щ…)?\s*$)', '.');
            END IF;
        END IF;

        v_timestring := replace(regexp_replace(v_timestring, '\.?[AP]M|Шµ|Щ…|\s|\,|\.\D|[\.|:]$', '', 'gi'), ':.', ':');
        BEGIN
            v_hours := coalesce(split_part(v_timestring, ':', 1)::SMALLINT, 0);

            IF ((v_dayparts[1] IN ('AM', 'Шµ') AND v_hours NOT BETWEEN 0 AND 12) OR
                (v_dayparts[1] IN ('PM', 'Щ…') AND v_hours NOT BETWEEN 1 AND 23))
            THEN
                RAISE invalid_datetime_format;
            ELSIF (v_dayparts[1] = 'PM' AND v_hours < 12) THEN
                v_hours := v_hours + 12;
            ELSIF (v_dayparts[1] = 'AM' AND v_hours = 12) THEN
                v_hours := v_hours - 12;
            END IF;

            v_minutes := coalesce(nullif(split_part(v_timestring, ':', 2), '')::SMALLINT, 0);
            v_seconds := coalesce(nullif(split_part(v_timestring, ':', 3), ''), '0');

            IF (v_seconds ~ '\.') THEN
                v_fseconds := split_part(v_seconds, '.', 2);
                v_seconds := split_part(v_seconds, '.', 1);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
            RAISE invalid_datetime_format;
        END;
    ELSIF (v_dayparts[1] IN ('PM', 'Щ…'))
    THEN
        v_hours := 12;
    END IF;

    BEGIN
        IF (v_res_datatype IN ('DATETIME', 'SMALLDATETIME'))
        THEN
            v_res_datetime := aws_sqlserver_ext.datetimefromparts(v_year, v_month::SMALLINT, v_day::SMALLINT,
                                                                  v_hours, v_minutes, v_seconds::SMALLINT,
                                                                  rpad(v_fseconds, 3, '0')::NUMERIC);
            IF (v_res_datatype = 'SMALLDATETIME' AND
                to_char(v_res_datetime, 'SS') <> '00')
            THEN
                IF (to_char(v_res_datetime, 'SS')::SMALLINT >= 30) THEN
                    v_res_datetime := v_res_datetime + INTERVAL '1 minute';
                END IF;

                v_res_datetime := to_timestamp(to_char(v_res_datetime, 'DD.MM.YYYY.HH24.MI'), 'DD.MM.YYYY.HH24.MI');
            END IF;
        ELSE
            v_fseconds := aws_sqlserver_ext.get_microsecs_from_fractsecs(rpad(v_fseconds, 9, '0'), v_scale);
            v_seconds := concat_ws('.', v_seconds, v_fseconds);

            v_res_datetime := make_timestamp(v_year, v_month::SMALLINT, v_day::SMALLINT,
                                             v_hours, v_minutes, v_seconds::NUMERIC);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;

        IF (v_err_message ~* 'Cannot construct data type') THEN
            RAISE invalid_datetime_format;
        END IF;
    END;

    IF (v_weekdaynames[1] IS NOT NULL) THEN
        v_weekdaynum := aws_sqlserver_ext.get_weekdaynum_by_name(v_weekdaynames[1], v_lang_metadata_json);

        IF (CASE date_part('dow', v_res_date)::SMALLINT
               WHEN 0 THEN 7
               ELSE date_part('dow', v_res_date)::SMALLINT
            END <> v_weekdaynum)
        THEN
            RAISE invalid_datetime_format;
        END IF;
    END IF;

    RETURN v_res_datetime;
EXCEPTION
    WHEN invalid_datetime_format OR datetime_field_overflow THEN
        RAISE USING MESSAGE := format('Error converting string value ''%s'' into data type %s using culture ''%s''.',
                                      p_datetimestring, v_res_datatype, p_culture),
                    DETAIL := 'Incorrect using of pair of input parameters values during conversion process.',
                    HINT := 'Check the input parameters values, correct them if needed, and try again.';

    WHEN datatype_mismatch THEN
        RAISE USING MESSAGE := 'Data type should be one of these values: ''DATETIME'', ''SMALLDATETIME'', ''DATETIME2''/''DATETIME2(n)''.',
                    DETAIL := 'Use of incorrect "datatype" parameter value during conversion process.',
                    HINT := 'Change "datatype" parameter to the proper value and try again.';

    WHEN invalid_indicator_parameter_value THEN
        RAISE USING MESSAGE := format('Invalid attributes specified for data type %s.', v_res_datatype),
                    DETAIL := 'Use of incorrect scale value, which is not corresponding to specified data type.',
                    HINT := 'Change data type scale component or select different data type and try again.';

    WHEN interval_field_overflow THEN
        RAISE USING MESSAGE := format('Specified scale %s is invalid.', v_scale),
                    DETAIL := 'Use of incorrect data type scale value during conversion process.',
                    HINT := 'Change scale component of data type parameter to be in range [0..7] and try again.';

    WHEN invalid_parameter_value THEN
        RAISE USING MESSAGE := CASE char_length(coalesce(CONVERSION_LANG, ''))
                                  WHEN 0 THEN format('The culture parameter ''%s'' provided in the function call is not supported.',
                                                     p_culture)
                                  ELSE format('Invalid CONVERSION_LANG constant value - ''%s''. Allowed values are: ''English'', ''Deutsch'', etc.',
                                              CONVERSION_LANG)
                               END,
                    DETAIL := 'Passed incorrect value for "p_culture" parameter or compiled incorrect CONVERSION_LANG constant value in function''s body.',
                    HINT := 'Check "p_culture" input parameter value, correct it if needed, and try again. Also check CONVERSION_LANG constant value.';

    WHEN invalid_text_representation THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
        v_err_message := substring(lower(v_err_message), 'integer\:\s\"(.*)\"');

        RAISE USING MESSAGE := format('Error while trying to convert "%s" value to SMALLINT data type.',
                                      v_err_message),
                    DETAIL := 'Supplied value contains illegal characters.',
                    HINT := 'Correct supplied value, remove all illegal characters.';
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.parse_to_datetime(p_datatype text, p_datetimestring text, p_culture text) OWNER TO postgres;

--
-- TOC entry 3891 (class 0 OID 0)
-- Dependencies: 364
-- Name: FUNCTION parse_to_datetime(p_datatype text, p_datetimestring text, p_culture text); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.parse_to_datetime(p_datatype text, p_datetimestring text, p_culture text) IS 'This function parses the TEXT string and converts it into a DATETIME value, according to specified culture (conversion mask).';


--
-- TOC entry 365 (class 1255 OID 17071)
-- Name: parse_to_time(text, text, text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.parse_to_time(p_datatype text, p_srctimestring text, p_culture text DEFAULT ''::text) RETURNS time without time zone
    LANGUAGE plpgsql STRICT
    AS $_$
DECLARE
    v_day VARCHAR;
    v_year SMALLINT;
    v_month VARCHAR;
    v_res_date DATE;
    v_scale SMALLINT;
    v_hijridate DATE;
    v_culture VARCHAR;
    v_dayparts TEXT[];
    v_resmask VARCHAR;
    v_datatype VARCHAR;
    v_raw_year VARCHAR;
    v_left_part VARCHAR;
    v_right_part VARCHAR;
    v_resmask_fi VARCHAR;
    v_timestring VARCHAR;
    v_correctnum VARCHAR;
    v_weekdaynum SMALLINT;
    v_err_message VARCHAR;
    v_date_format VARCHAR;
    v_weekdaynames TEXT[];
    v_hours SMALLINT := 0;
    v_srctimestring VARCHAR;
    v_minutes SMALLINT := 0;
    v_res_datatype VARCHAR;
    v_error_message VARCHAR;
    v_found BOOLEAN := TRUE;
    v_compday_regexp VARCHAR;
    v_regmatch_groups TEXT[];
    v_datatype_groups TEXT[];
    v_seconds VARCHAR := '0';
    v_fseconds VARCHAR := '0';
    v_compmonth_regexp VARCHAR;
    v_lang_metadata_json JSONB;
    v_resmask_cnt SMALLINT := 10;
    v_res_time TIME WITHOUT TIME ZONE;
    DAYMM_REGEXP CONSTANT VARCHAR := '(\d{1,2})';
    FULLYEAR_REGEXP CONSTANT VARCHAR := '(\d{3,4})';
    SHORTYEAR_REGEXP CONSTANT VARCHAR := '(\d{1,2})';
    COMPYEAR_REGEXP CONSTANT VARCHAR := '(\d{1,4})';
    AMPM_REGEXP CONSTANT VARCHAR := '(?:[AP]M|Шµ|Щ…)';
    TIMEUNIT_REGEXP CONSTANT VARCHAR := '\s*\d{1,2}\s*';
    MASKSEPONE_REGEXP CONSTANT VARCHAR := '\s*(?:/|-)?';
    MASKSEPTWO_REGEXP CONSTANT VARCHAR := '\s*(?:\s|/|-|\.|,)';
    MASKSEPTWO_FI_REGEXP CONSTANT VARCHAR := '\s*(?:\s|/|-|,)';
    MASKSEPTHREE_REGEXP CONSTANT VARCHAR := '\s*(?:/|-|\.|,)';
    TIME_MASKSEP_REGEXP CONSTANT VARCHAR := '(?:\s|\.|,)*';
    TIME_MASKSEP_FI_REGEXP CONSTANT VARCHAR := '(?:\s|,)*';
    WEEKDAYAMPM_START_REGEXP CONSTANT VARCHAR := '(^|[[:digit:][:space:]\.,])';
    WEEKDAYAMPM_END_REGEXP CONSTANT VARCHAR := '([[:digit:][:space:]\.,]|$)(?=[^/-]|$)';
    CORRECTNUM_REGEXP CONSTANT VARCHAR := '(?:([+-]\d{1,4})(?:[[:space:]\.,]|[AP]M|Шµ|Щ…|$))';
    DATATYPE_REGEXP CONSTANT VARCHAR := '^(TIME)\s*(?:\()?\s*((?:-)?\d+)?\s*(?:\))?$';
    ANNO_DOMINI_REGEXP VARCHAR := '(AD|A\.D\.)';
    ANNO_DOMINI_COMPREGEXP VARCHAR := concat(WEEKDAYAMPM_START_REGEXP, ANNO_DOMINI_REGEXP, WEEKDAYAMPM_END_REGEXP);
    HHMMSSFS_PART_REGEXP CONSTANT VARCHAR :=
        concat(TIMEUNIT_REGEXP, AMPM_REGEXP, '|',
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '\:', TIME_MASKSEP_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '(?!\d)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?|',
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '\:', TIME_MASKSEP_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '\:', TIME_MASKSEP_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '(?!\d)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?|',
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '\:', TIME_MASKSEP_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, TIMEUNIT_REGEXP, '\:', TIME_MASKSEP_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\s*\d{1,2}\.\d+(?!\d)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?|',
               AMPM_REGEXP, '?');
    HHMMSSFS_PART_FI_REGEXP CONSTANT VARCHAR :=
        concat(TIMEUNIT_REGEXP, AMPM_REGEXP, '|',
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '[\:\.]', TIME_MASKSEP_FI_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '(?!\d)', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?\.?|',
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '[\:\.]', TIME_MASKSEP_FI_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '[\:\.]', TIME_MASKSEP_FI_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '(?!\d)', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?|',
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '[\:\.]', TIME_MASKSEP_FI_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, TIMEUNIT_REGEXP, '[\:\.]', TIME_MASKSEP_FI_REGEXP,
               AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, '\s*\d{1,2}\.\d+(?!\d)\.?', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?|',
               AMPM_REGEXP, '?');
    v_defmask1_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        TIME_MASKSEP_REGEXP, '(?:[\.|,]+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)', TIME_MASKSEP_REGEXP, '$');
    v_defmask1_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP,
                                           '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_FI_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:', MASKSEPTWO_FI_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP,
                                           CORRECTNUM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[,]+', AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           TIME_MASKSEP_FI_REGEXP, '(?:[\.|,]+', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask2_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        FULLYEAR_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                        AMPM_REGEXP, TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        TIME_MASKSEP_REGEXP, '(?:(?:[\.|,]+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?)|',
                                        CORRECTNUM_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP, '$');
    v_defmask2_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP,
                                           '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           CORRECTNUM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP,
                                           FULLYEAR_REGEXP,
                                           '(?:(?:', MASKSEPTWO_FI_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:', TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP,
                                           AMPM_REGEXP, TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           TIME_MASKSEP_FI_REGEXP, '(?:(?:[\.|,]+', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, TIME_MASKSEP_FI_REGEXP, CORRECTNUM_REGEXP, '?)|',
                                           CORRECTNUM_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask3_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, ')|',
                                        '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        FULLYEAR_REGEXP,
                                        TIME_MASKSEP_REGEXP, '(', TIME_MASKSEP_REGEXP, AMPM_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask3_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           TIME_MASKSEP_FI_REGEXP, '[\./]?', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)',
                                           FULLYEAR_REGEXP,
                                           TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask4_0_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP, '\s*(', AMPM_REGEXP, ')',
                                          TIME_MASKSEP_REGEXP, '$');
    v_defmask4_1_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          '(?:\s|,)+',
                                          DAYMM_REGEXP, '\s*(', AMPM_REGEXP, ')',
                                          TIME_MASKSEP_REGEXP, '$');
    v_defmask4_2_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP,
                                          '\s*[\.]+', TIME_MASKSEP_REGEXP,
                                          DAYMM_REGEXP, '\s*(', AMPM_REGEXP, ')',
                                          TIME_MASKSEP_REGEXP, '$');
    v_defmask5_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        FULLYEAR_REGEXP,
                                        TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask5_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           FULLYEAR_REGEXP,
                                           TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask6_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        FULLYEAR_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '((?:(?:\s|\.|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_REGEXP, '))?', TIME_MASKSEP_REGEXP, '$');
    v_defmask6_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           FULLYEAR_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:\s*[\.])?',
                                           '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask7_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        FULLYEAR_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '((?:(?:\s|\.|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_REGEXP, '))?', TIME_MASKSEP_REGEXP, '$');
    v_defmask7_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           FULLYEAR_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask8_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                        '(?:[\.|,]+', AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                        DAYMM_REGEXP,
                                        '(?:[\.|,]+', AMPM_REGEXP, ')?',
                                        TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask8_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_FI_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)|',
                                           '(?:[,]+', AMPM_REGEXP, '))', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '(?:(?:[\,]+|\s*/\s*)', AMPM_REGEXP, ')?',
                                           TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask9_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(',
                                        HHMMSSFS_PART_REGEXP,
                                        ')', TIME_MASKSEP_REGEXP, '$');
    v_defmask9_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, '(',
                                           HHMMSSFS_PART_FI_REGEXP,
                                           ')', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask10_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)?', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask10_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            DAYMM_REGEXP,
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)?', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask11_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask11_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                           '($comp_month$)',
                                           '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_FI_REGEXP,
                                           DAYMM_REGEXP,
                                           '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask12_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         FULLYEAR_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                         '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask12_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            FULLYEAR_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                            '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask13_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         FULLYEAR_REGEXP,
                                         TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$');
    v_defmask13_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            '($comp_month$)',
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                            FULLYEAR_REGEXP,
                                            TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask14_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)'
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)', TIME_MASKSEP_REGEXP,
                                         COMPYEAR_REGEXP,
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask14_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            '($comp_month$)'
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_FI_REGEXP,
                                            DAYMM_REGEXP,
                                            '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_FI_REGEXP, AMPM_REGEXP, '?)', TIME_MASKSEP_FI_REGEXP,
                                            COMPYEAR_REGEXP,
                                            '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask15_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                         '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         COMPYEAR_REGEXP,
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask15_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            DAYMM_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                            '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                            COMPYEAR_REGEXP,
                                            '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask16_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)', TIME_MASKSEP_REGEXP,
                                         COMPYEAR_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                         '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask16_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            DAYMM_REGEXP,
                                            '(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)', TIME_MASKSEP_REGEXP,
                                            COMPYEAR_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                            '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask17_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         FULLYEAR_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                         '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask17_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            FULLYEAR_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                            '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                            DAYMM_REGEXP,
                                            '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask18_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         FULLYEAR_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                         '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                         '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP, '$');
    v_defmask18_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            FULLYEAR_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                            '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                            DAYMM_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, '(?:', AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))?)|',
                                            '(?:(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '(?=(?:[[:space:]\.,])+))))', TIME_MASKSEP_REGEXP,
                                            '($comp_month$)',
                                            TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP, '$');
    v_defmask19_regexp VARCHAR := concat('^', TIME_MASKSEP_REGEXP, '(', HHMMSSFS_PART_REGEXP, ')?', TIME_MASKSEP_REGEXP,
                                         '($comp_month$)',
                                         '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                         FULLYEAR_REGEXP,
                                         '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                         '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                         DAYMM_REGEXP,
                                         '((?:(?:\s|\.|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_REGEXP, '))?', TIME_MASKSEP_REGEXP, '$');
    v_defmask19_fi_regexp VARCHAR := concat('^', TIME_MASKSEP_FI_REGEXP, '(', HHMMSSFS_PART_FI_REGEXP, ')?', TIME_MASKSEP_FI_REGEXP,
                                            '($comp_month$)',
                                            '(?:', MASKSEPTHREE_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)?', TIME_MASKSEP_REGEXP,
                                            FULLYEAR_REGEXP,
                                            '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                            '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP,
                                            DAYMM_REGEXP,
                                            '((?:(?:\s|,)+|', AMPM_REGEXP, ')(?:', HHMMSSFS_PART_FI_REGEXP, '))?', TIME_MASKSEP_FI_REGEXP, '$');
    CONVERSION_LANG CONSTANT VARCHAR := 'English';
    DATE_FORMAT CONSTANT VARCHAR := '';
BEGIN
    v_datatype := trim(p_datatype);
    v_srctimestring := upper(trim(p_srctimestring));
    v_culture := coalesce(nullif(upper(trim(p_culture)), ''), 'EN-US');

    v_datatype_groups := regexp_matches(v_datatype, DATATYPE_REGEXP, 'gi');

    v_res_datatype := upper(v_datatype_groups[1]);
    v_scale := v_datatype_groups[2]::SMALLINT;

    IF (v_res_datatype IS NULL) THEN
        RAISE datatype_mismatch;
    ELSIF (coalesce(v_scale, 0) NOT BETWEEN 0 AND 7)
    THEN
        RAISE interval_field_overflow;
    ELSIF (v_scale IS NULL) THEN
        v_scale := 7;
    END IF;

    v_dayparts := ARRAY(SELECT upper(array_to_string(regexp_matches(v_srctimestring, '[AP]M|Шµ|Щ…', 'gi'), '')));

    IF (array_length(v_dayparts, 1) > 1) THEN
        RAISE invalid_datetime_format;
    END IF;

    BEGIN
        v_lang_metadata_json := aws_sqlserver_ext.get_lang_metadata_json(coalesce(nullif(CONVERSION_LANG, ''), p_culture));
    EXCEPTION
        WHEN OTHERS THEN
        RAISE invalid_parameter_value;
    END;

    v_compday_regexp := array_to_string(array_cat(array_cat(ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'days_names')),
                                                            ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'days_shortnames'))),
                                                  ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'days_extrashortnames'))), '|');

    v_weekdaynames := ARRAY(SELECT array_to_string(regexp_matches(v_srctimestring, v_compday_regexp, 'gi'), ''));

    IF (array_length(v_weekdaynames, 1) > 1) THEN
        RAISE invalid_datetime_format;
    END IF;

    IF (v_weekdaynames[1] IS NOT NULL AND
        v_srctimestring ~* concat(WEEKDAYAMPM_START_REGEXP, '(', v_compday_regexp, ')', WEEKDAYAMPM_END_REGEXP))
    THEN
        v_srctimestring := replace(v_srctimestring, v_weekdaynames[1], ' ');
    END IF;

    IF (v_srctimestring ~* ANNO_DOMINI_COMPREGEXP)
    THEN
        IF (v_culture !~ 'EN[-_]US|DA[-_]DK|SV[-_]SE|EN[-_]GB|HI[-_]IS') THEN
            RAISE invalid_datetime_format;
        END IF;

        v_srctimestring := regexp_replace(v_srctimestring,
                                          ANNO_DOMINI_COMPREGEXP,
                                          regexp_replace(array_to_string(regexp_matches(v_srctimestring, ANNO_DOMINI_COMPREGEXP, 'gi'), ''),
                                                         ANNO_DOMINI_REGEXP, ' ', 'gi'),
                                          'gi');
    END IF;

    v_date_format := coalesce(nullif(upper(trim(DATE_FORMAT)), ''), v_lang_metadata_json ->> 'date_format');

    v_compmonth_regexp :=
        array_to_string(array_cat(array_cat(ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'months_shortnames')),
                                            ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'months_names'))),
                                  array_cat(ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'months_extrashortnames')),
                                            ARRAY(SELECT jsonb_array_elements_text(v_lang_metadata_json -> 'months_extranames')))
                                 ), '|');

    IF ((v_srctimestring ~* v_defmask1_regexp AND v_culture <> 'FI') OR
        (v_srctimestring ~* v_defmask1_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_srctimestring ~ concat(CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                     CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP,
                                     AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}|',
                                     '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                     CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
            v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV')
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_srctimestring, CASE v_culture
                                                                WHEN 'FI' THEN v_defmask1_fi_regexp
                                                                ELSE v_defmask1_regexp
                                                             END, 'gi');
        v_timestring := v_regmatch_groups[2];
        v_correctnum := coalesce(v_regmatch_groups[1], v_regmatch_groups[3],
                                 v_regmatch_groups[5], v_regmatch_groups[6]);

        IF (v_date_format = 'DMY' OR
            v_culture IN ('SV-SE', 'SV_SE', 'LV-LV', 'LV_LV'))
        THEN
            v_day := v_regmatch_groups[4];
            v_month := v_regmatch_groups[7];
        ELSE
            v_day := v_regmatch_groups[7];
            v_month := v_regmatch_groups[4];
        END IF;

        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA'))
        THEN
            IF (v_day::SMALLINT > 30 OR
                v_month::SMALLINT > 12) THEN
                RAISE invalid_datetime_format;
            END IF;

            v_raw_year := to_char(aws_sqlserver_ext.conv_greg_to_hijri(current_date + 1), 'YYYY');
            v_hijridate := aws_sqlserver_ext.conv_hijri_to_greg(v_day, v_month, v_raw_year) - 1;

            v_day := to_char(v_hijridate, 'DD');
            v_month := to_char(v_hijridate, 'MM');
            v_year := to_char(v_hijridate, 'YYYY')::SMALLINT;
        ELSE
            v_year := to_char(current_date, 'YYYY')::SMALLINT;
        END IF;

    ELSIF ((v_srctimestring ~* v_defmask6_regexp AND v_culture <> 'FI') OR
           (v_srctimestring ~* v_defmask6_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA') OR
            (v_srctimestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{3,4}',
                                      '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                      '(?:', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '))', TIME_MASKSEP_REGEXP, '\d{1,2}|',
                                      '\d{3,4}', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP,
                                      TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}\s*(?:\.)+|',
                                      '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
             v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV'))
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_srctimestring, CASE v_culture
                                                                WHEN 'FI' THEN v_defmask6_fi_regexp
                                                                ELSE v_defmask6_regexp
                                                             END, 'gi');
        v_timestring := concat(v_regmatch_groups[1], v_regmatch_groups[5]);
        v_day := v_regmatch_groups[4];
        v_month := v_regmatch_groups[3];
        v_year := CASE
                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_regmatch_groups[2]::SMALLINT - 543
                     ELSE v_regmatch_groups[2]::SMALLINT
                  END;

    ELSIF ((v_srctimestring ~* v_defmask2_regexp AND v_culture <> 'FI') OR
           (v_srctimestring ~* v_defmask2_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA') OR
            (v_srctimestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{3,4}',
                                      '(?:(?:', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?)|',
                                      '(?:', TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?', TIME_MASKSEP_REGEXP,
                                      AMPM_REGEXP, TIME_MASKSEP_REGEXP, CORRECTNUM_REGEXP, '?))', TIME_MASKSEP_REGEXP, '\d{1,2}|',
                                      '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
             v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV'))
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_srctimestring, CASE v_culture
                                                                WHEN 'FI' THEN v_defmask2_fi_regexp
                                                                ELSE v_defmask2_regexp
                                                             END, 'gi');
        v_timestring := v_regmatch_groups[2];
        v_correctnum := coalesce(v_regmatch_groups[1], v_regmatch_groups[3], v_regmatch_groups[5],
                                 v_regmatch_groups[6], v_regmatch_groups[8], v_regmatch_groups[9]);
        v_day := '01';
        v_month := v_regmatch_groups[7];
        v_year := CASE
                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_regmatch_groups[4]::SMALLINT - 543
                     ELSE v_regmatch_groups[4]::SMALLINT
                  END;

    ELSIF (v_srctimestring ~* v_defmask4_1_regexp OR
           (v_srctimestring ~* v_defmask4_2_regexp AND v_culture !~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV') OR
           (v_srctimestring ~* v_defmask9_regexp AND v_culture <> 'FI') OR
           (v_srctimestring ~* v_defmask9_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_srctimestring ~ concat('\d+\s*\.?(?:,+|,*', AMPM_REGEXP, ')', TIME_MASKSEP_FI_REGEXP, '\.+', TIME_MASKSEP_REGEXP, '$|',
                                     '\d+\s*\.', TIME_MASKSEP_FI_REGEXP, '\.', TIME_MASKSEP_FI_REGEXP, '$') AND
            v_culture = 'FI')
        THEN
            RAISE invalid_datetime_format;
        END IF;

        IF (v_srctimestring ~* v_defmask4_0_regexp) THEN
            v_timestring := (regexp_matches(v_srctimestring, v_defmask4_0_regexp, 'gi'))[1];
        ELSE
            v_timestring := v_srctimestring;
        END IF;

        v_res_date := current_date;
        v_day := to_char(v_res_date, 'DD');
        v_month := to_char(v_res_date, 'MM');
        v_year := to_char(v_res_date, 'YYYY')::SMALLINT;

    ELSIF ((v_srctimestring ~* v_defmask3_regexp AND v_culture <> 'FI') OR
           (v_srctimestring ~* v_defmask3_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA') OR
            (v_srctimestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?',
                                      TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP, '|',
                                      '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
             v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV'))
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_srctimestring, CASE v_culture
                                                                WHEN 'FI' THEN v_defmask3_fi_regexp
                                                                ELSE v_defmask3_regexp
                                                             END, 'gi');
        v_timestring := v_regmatch_groups[1];
        v_day := '01';
        v_month := v_regmatch_groups[2];
        v_year := CASE
                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_regmatch_groups[3]::SMALLINT - 543
                     ELSE v_regmatch_groups[3]::SMALLINT
                  END;

    ELSIF ((v_srctimestring ~* v_defmask5_regexp AND v_culture <> 'FI') OR
           (v_srctimestring ~* v_defmask5_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA') OR
            (v_srctimestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP,
                                      TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP,
                                      TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{3,4}', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$|',
                                      '\d{1,2}', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{3,4}\s*(?:\.)+|',
                                      '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
             v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV'))
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_srctimestring, v_defmask5_regexp, 'gi');
        v_timestring := concat(v_regmatch_groups[1], v_regmatch_groups[5]);
        v_year := CASE
                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_regmatch_groups[4]::SMALLINT - 543
                     ELSE v_regmatch_groups[4]::SMALLINT
                  END;

        IF (v_date_format = 'DMY' OR
            v_culture IN ('LV-LV', 'LV_LV'))
        THEN
            v_day := v_regmatch_groups[2];
            v_month := v_regmatch_groups[3];
        ELSE
            v_day := v_regmatch_groups[3];
            v_month := v_regmatch_groups[2];
        END IF;

    ELSIF ((v_srctimestring ~* v_defmask7_regexp AND v_culture <> 'FI') OR
           (v_srctimestring ~* v_defmask7_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA') OR
            (v_srctimestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}',
                                      MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{3,4}|',
                                      '\d{3,4}', MASKSEPTWO_REGEXP, '?', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}\s*(?:\.)+|',
                                      '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
             v_culture ~ 'DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV'))
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_srctimestring, CASE v_culture
                                                                WHEN 'FI' THEN v_defmask7_fi_regexp
                                                                ELSE v_defmask7_regexp
                                                             END, 'gi');
        v_timestring := concat(v_regmatch_groups[1], v_regmatch_groups[5]);
        v_day := v_regmatch_groups[4];
        v_month := v_regmatch_groups[2];
        v_year := CASE
                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_regmatch_groups[3]::SMALLINT - 543
                     ELSE v_regmatch_groups[3]::SMALLINT
                  END;

    ELSIF ((v_srctimestring ~* v_defmask8_regexp AND v_culture <> 'FI') OR
           (v_srctimestring ~* v_defmask8_fi_regexp AND v_culture = 'FI'))
    THEN
        IF (v_srctimestring ~ concat('\s*\d{1,2}\.\s*(?:\.|\d+(?!\d)\s*\.)', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}',
                                     MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP,
                                     TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}|',
                                     '\d{1,2}', MASKSEPTWO_REGEXP, TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}', MASKSEPTWO_REGEXP,
                                     TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '\d{1,2}\s*(?:\.)+|',
                                     '\d+\s*(?:\.)+', TIME_MASKSEP_REGEXP, AMPM_REGEXP, '?', TIME_MASKSEP_REGEXP, '$') AND
            v_culture ~ 'FI|DE[-_]DE|NN[-_]NO|CS[-_]CZ|PL[-_]PL|RO[-_]RO|SK[-_]SK|SL[-_]SI|BG[-_]BG|RU[-_]RU|TR[-_]TR|ET[-_]EE|LV[-_]LV')
        THEN
            RAISE invalid_datetime_format;
        END IF;

        v_regmatch_groups := regexp_matches(v_srctimestring, CASE v_culture
                                                                WHEN 'FI' THEN v_defmask8_fi_regexp
                                                                ELSE v_defmask8_regexp
                                                             END, 'gi');
        v_timestring := concat(v_regmatch_groups[1], v_regmatch_groups[5]);

        IF (v_date_format = 'DMY' OR
            v_culture IN ('LV-LV', 'LV_LV'))
        THEN
            v_day := v_regmatch_groups[2];
            v_month := v_regmatch_groups[3];
            v_raw_year := v_regmatch_groups[4];
        ELSIF (v_date_format = 'YMD')
        THEN
            v_day := v_regmatch_groups[4];
            v_month := v_regmatch_groups[3];
            v_raw_year := v_regmatch_groups[2];
        ELSE
            v_day := v_regmatch_groups[3];
            v_month := v_regmatch_groups[2];
            v_raw_year := v_regmatch_groups[4];
        END IF;

        IF (v_culture IN ('AR', 'AR-SA', 'AR_SA'))
        THEN
            IF (v_day::SMALLINT > 30 OR
                v_month::SMALLINT > 12) THEN
                RAISE invalid_datetime_format;
            END IF;

            v_raw_year := aws_sqlserver_ext.get_full_year(v_raw_year, '14');
            v_hijridate := aws_sqlserver_ext.conv_hijri_to_greg(v_day, v_month, v_raw_year) - 1;

            v_day := to_char(v_hijridate, 'DD');
            v_month := to_char(v_hijridate, 'MM');
            v_year := to_char(v_hijridate, 'YYYY')::SMALLINT;

        ELSIF (v_culture IN ('TH-TH', 'TH_TH')) THEN
            v_year := aws_sqlserver_ext.get_full_year(v_raw_year)::SMALLINT - 43;
        ELSE
            v_year := aws_sqlserver_ext.get_full_year(v_raw_year, '', 29)::SMALLINT;
        END IF;
    ELSE
        v_found := FALSE;
    END IF;

    WHILE (NOT v_found AND v_resmask_cnt < 20)
    LOOP
        v_resmask := replace(CASE v_resmask_cnt
                                WHEN 10 THEN v_defmask10_regexp
                                WHEN 11 THEN v_defmask11_regexp
                                WHEN 12 THEN v_defmask12_regexp
                                WHEN 13 THEN v_defmask13_regexp
                                WHEN 14 THEN v_defmask14_regexp
                                WHEN 15 THEN v_defmask15_regexp
                                WHEN 16 THEN v_defmask16_regexp
                                WHEN 17 THEN v_defmask17_regexp
                                WHEN 18 THEN v_defmask18_regexp
                                WHEN 19 THEN v_defmask19_regexp
                             END,
                             '$comp_month$', v_compmonth_regexp);

        v_resmask_fi := replace(CASE v_resmask_cnt
                                   WHEN 10 THEN v_defmask10_fi_regexp
                                   WHEN 11 THEN v_defmask11_fi_regexp
                                   WHEN 12 THEN v_defmask12_fi_regexp
                                   WHEN 13 THEN v_defmask13_fi_regexp
                                   WHEN 14 THEN v_defmask14_fi_regexp
                                   WHEN 15 THEN v_defmask15_fi_regexp
                                   WHEN 16 THEN v_defmask16_fi_regexp
                                   WHEN 17 THEN v_defmask17_fi_regexp
                                   WHEN 18 THEN v_defmask18_fi_regexp
                                   WHEN 19 THEN v_defmask19_fi_regexp
                                END,
                                '$comp_month$', v_compmonth_regexp);

        IF ((v_srctimestring ~* v_resmask AND v_culture <> 'FI') OR
            (v_srctimestring ~* v_resmask_fi AND v_culture = 'FI'))
        THEN
            v_found := TRUE;
            v_regmatch_groups := regexp_matches(v_srctimestring, CASE v_culture
                                                                    WHEN 'FI' THEN v_resmask_fi
                                                                    ELSE v_resmask
                                                                 END, 'gi');
            v_timestring := CASE
                               WHEN v_resmask_cnt IN (10, 11, 12, 13) THEN concat(v_regmatch_groups[1], v_regmatch_groups[4])
                               ELSE concat(v_regmatch_groups[1], v_regmatch_groups[5])
                            END;

            IF (v_resmask_cnt = 10)
            THEN
                IF (v_regmatch_groups[3] = 'MAR' AND
                    v_culture IN ('IT-IT', 'IT_IT'))
                THEN
                    RAISE invalid_datetime_format;
                END IF;

                IF (v_date_format = 'YMD' AND v_culture NOT IN ('SV-SE', 'SV_SE', 'LV-LV', 'LV_LV'))
                THEN
                    v_day := '01';
                    v_year := aws_sqlserver_ext.get_full_year(v_regmatch_groups[2], '', 29)::SMALLINT;
                ELSE
                    v_day := v_regmatch_groups[2];
                    v_year := to_char(current_date, 'YYYY')::SMALLINT;
                END IF;

                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[3], v_lang_metadata_json);
                v_raw_year := to_char(aws_sqlserver_ext.conv_greg_to_hijri(current_date + 1), 'YYYY');

            ELSIF (v_resmask_cnt = 11)
            THEN
                IF (v_date_format IN ('YMD', 'MDY') AND v_culture NOT IN ('SV-SE', 'SV_SE'))
                THEN
                    v_day := v_regmatch_groups[3];
                    v_year := to_char(current_date, 'YYYY')::SMALLINT;
                ELSE
                    v_day := '01';
                    v_year := CASE
                                 WHEN v_culture IN ('TH-TH', 'TH_TH') THEN aws_sqlserver_ext.get_full_year(v_regmatch_groups[3])::SMALLINT - 43
                                 ELSE aws_sqlserver_ext.get_full_year(v_regmatch_groups[3], '', 29)::SMALLINT
                              END;
                END IF;

                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
                v_raw_year := aws_sqlserver_ext.get_full_year(substring(v_year::TEXT, 3, 2), '14');

            ELSIF (v_resmask_cnt = 12)
            THEN
                v_day := '01';
                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[3], v_lang_metadata_json);
                v_raw_year := v_regmatch_groups[2];

            ELSIF (v_resmask_cnt = 13)
            THEN
                v_day := '01';
                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
                v_raw_year := v_regmatch_groups[3];

            ELSIF (v_resmask_cnt IN (14, 15, 16))
            THEN
                IF (v_resmask_cnt = 14)
                THEN
                    v_left_part := v_regmatch_groups[4];
                    v_right_part := v_regmatch_groups[3];
                    v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
                ELSIF (v_resmask_cnt = 15)
                THEN
                    v_left_part := v_regmatch_groups[4];
                    v_right_part := v_regmatch_groups[2];
                    v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[3], v_lang_metadata_json);
                ELSE
                    v_left_part := v_regmatch_groups[3];
                    v_right_part := v_regmatch_groups[2];
                    v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[4], v_lang_metadata_json);
                END IF;

                IF (char_length(v_left_part) <= 2)
                THEN
                    IF (v_date_format = 'YMD' AND v_culture NOT IN ('LV-LV', 'LV_LV'))
                    THEN
                        v_day := v_left_part;
                        v_raw_year := aws_sqlserver_ext.get_full_year(v_right_part, '14');
                        v_year := CASE
                                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN aws_sqlserver_ext.get_full_year(v_right_part)::SMALLINT - 43
                                     ELSE aws_sqlserver_ext.get_full_year(v_right_part, '', 29)::SMALLINT
                                  END;
                        BEGIN
                            v_res_date := make_date(v_year, v_month::SMALLINT, v_day::SMALLINT);
                        EXCEPTION
                        WHEN OTHERS THEN
                            v_day := v_right_part;
                            v_raw_year := aws_sqlserver_ext.get_full_year(v_left_part, '14');
                            v_year := CASE
                                         WHEN v_culture IN ('TH-TH', 'TH_TH') THEN aws_sqlserver_ext.get_full_year(v_left_part)::SMALLINT - 43
                                         ELSE aws_sqlserver_ext.get_full_year(v_left_part, '', 29)::SMALLINT
                                      END;
                        END;
                    END IF;

                    IF (v_date_format IN ('MDY', 'DMY') OR v_culture IN ('LV-LV', 'LV_LV'))
                    THEN
                        v_day := v_right_part;
                        v_raw_year := aws_sqlserver_ext.get_full_year(v_left_part, '14');
                        v_year := CASE
                                     WHEN v_culture IN ('TH-TH', 'TH_TH') THEN aws_sqlserver_ext.get_full_year(v_left_part)::SMALLINT - 43
                                     ELSE aws_sqlserver_ext.get_full_year(v_left_part, '', 29)::SMALLINT
                                  END;
                        BEGIN
                            v_res_date := make_date(v_year, v_month::SMALLINT, v_day::SMALLINT);
                        EXCEPTION
                        WHEN OTHERS THEN
                            v_day := v_left_part;
                            v_raw_year := aws_sqlserver_ext.get_full_year(v_right_part, '14');
                            v_year := CASE
                                         WHEN v_culture IN ('TH-TH', 'TH_TH') THEN aws_sqlserver_ext.get_full_year(v_right_part)::SMALLINT - 43
                                         ELSE aws_sqlserver_ext.get_full_year(v_right_part, '', 29)::SMALLINT
                                      END;
                        END;
                    END IF;
                ELSE
                    v_day := v_right_part;
                    v_raw_year := v_left_part;
	            v_year := CASE
                                 WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_left_part::SMALLINT - 543
                                 ELSE v_left_part::SMALLINT
                              END;
                END IF;

            ELSIF (v_resmask_cnt = 17)
            THEN
                v_day := v_regmatch_groups[4];
                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[3], v_lang_metadata_json);
                v_raw_year := v_regmatch_groups[2];

            ELSIF (v_resmask_cnt = 18)
            THEN
                v_day := v_regmatch_groups[3];
                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[4], v_lang_metadata_json);
                v_raw_year := v_regmatch_groups[2];

            ELSIF (v_resmask_cnt = 19)
            THEN
                v_day := v_regmatch_groups[4];
                v_month := aws_sqlserver_ext.get_monthnum_by_name(v_regmatch_groups[2], v_lang_metadata_json);
                v_raw_year := v_regmatch_groups[3];
            END IF;

            IF (v_resmask_cnt NOT IN (10, 11, 14, 15, 16))
            THEN
                v_year := CASE
                             WHEN v_culture IN ('TH-TH', 'TH_TH') THEN v_raw_year::SMALLINT - 543
                             ELSE v_raw_year::SMALLINT
                          END;
            END IF;

            IF (v_culture IN ('AR', 'AR-SA', 'AR_SA'))
            THEN
                IF (v_day::SMALLINT > 30 OR
                    (v_resmask_cnt NOT IN (10, 11, 14, 15, 16) AND v_year NOT BETWEEN 1318 AND 1501) OR
                    (v_resmask_cnt IN (14, 15, 16) AND v_raw_year::SMALLINT NOT BETWEEN 1318 AND 1501))
                THEN
                    RAISE invalid_datetime_format;
                END IF;

                v_hijridate := aws_sqlserver_ext.conv_hijri_to_greg(v_day, v_month, v_raw_year) - 1;

                v_day := to_char(v_hijridate, 'DD');
                v_month := to_char(v_hijridate, 'MM');
                v_year := to_char(v_hijridate, 'YYYY')::SMALLINT;
            END IF;
        END IF;

        v_resmask_cnt := v_resmask_cnt + 1;
    END LOOP;

    IF (NOT v_found) THEN
        RAISE invalid_datetime_format;
    END IF;

    v_res_date := make_date(v_year, v_month::SMALLINT, v_day::SMALLINT);

    IF (v_weekdaynames[1] IS NOT NULL) THEN
        v_weekdaynum := aws_sqlserver_ext.get_weekdaynum_by_name(v_weekdaynames[1], v_lang_metadata_json);

        IF (date_part('dow', v_res_date)::SMALLINT <> v_weekdaynum) THEN
            RAISE invalid_datetime_format;
        END IF;
    END IF;

    IF (char_length(v_timestring) > 0 AND v_timestring NOT IN ('AM', 'Шµ', 'PM', 'Щ…'))
    THEN
        IF (v_culture = 'FI') THEN
            v_timestring := translate(v_timestring, '.,', ': ');

            IF (char_length(split_part(v_timestring, ':', 4)) > 0) THEN
                v_timestring := regexp_replace(v_timestring, ':(?=\s*\d+\s*:?\s*(?:[AP]M|Шµ|Щ…)?\s*$)', '.');
            END IF;
        END IF;

        v_timestring := replace(regexp_replace(v_timestring, '\.?[AP]M|Шµ|Щ…|\s|\,|\.\D|[\.|:]$', '', 'gi'), ':.', ':');

        BEGIN
            v_hours := coalesce(split_part(v_timestring, ':', 1)::SMALLINT, 0);

            IF ((v_dayparts[1] IN ('AM', 'Шµ') AND v_hours NOT BETWEEN 0 AND 12) OR
                (v_dayparts[1] IN ('PM', 'Щ…') AND v_hours NOT BETWEEN 1 AND 23))
            THEN
                RAISE invalid_datetime_format;
            ELSIF (v_dayparts[1] = 'PM' AND v_hours < 12) THEN
                v_hours := v_hours + 12;
            ELSIF (v_dayparts[1] = 'AM' AND v_hours = 12) THEN
                v_hours := v_hours - 12;
            END IF;

            v_minutes := coalesce(nullif(split_part(v_timestring, ':', 2), '')::SMALLINT, 0);
            v_seconds := coalesce(nullif(split_part(v_timestring, ':', 3), ''), '0');

            IF (v_seconds ~ '\.') THEN
                v_fseconds := split_part(v_seconds, '.', 2);
                v_seconds := split_part(v_seconds, '.', 1);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
            RAISE invalid_datetime_format;
        END;
    ELSIF (v_dayparts[1] IN ('PM', 'Щ…'))
    THEN
        v_hours := 12;
    END IF;

    v_fseconds := aws_sqlserver_ext.get_microsecs_from_fractsecs(rpad(v_fseconds, 9, '0'), v_scale);
    v_seconds := concat_ws('.', v_seconds, v_fseconds);

    v_res_time := make_time(v_hours, v_minutes, v_seconds::NUMERIC);

    RETURN v_res_time;
EXCEPTION
    WHEN invalid_datetime_format OR datetime_field_overflow THEN
        RAISE USING MESSAGE := format('Error converting string value ''%s'' into data type %s using culture ''%s''.',
                                      p_srctimestring, v_res_datatype, p_culture),
                    DETAIL := 'Incorrect using of pair of input parameters values during conversion process.',
                    HINT := 'Check the input parameters values, correct them if needed, and try again.';

    WHEN datatype_mismatch THEN
        RAISE USING MESSAGE := 'Source data type should be ''TIME'' or ''TIME(n)''.',
                    DETAIL := 'Use of incorrect "datatype" parameter value during conversion process.',
                    HINT := 'Change "datatype" parameter to the proper value and try again.';

    WHEN invalid_indicator_parameter_value THEN
        RAISE USING MESSAGE := format('Invalid attributes specified for data type %s.', v_res_datatype),
                    DETAIL := 'Use of incorrect scale value, which is not corresponding to specified data type.',
                    HINT := 'Change data type scale component or select different data type and try again.';

    WHEN interval_field_overflow THEN
        RAISE USING MESSAGE := format('Specified scale %s is invalid.', v_scale),
                    DETAIL := 'Use of incorrect data type scale value during conversion process.',
                    HINT := 'Change scale component of data type parameter to be in range [0..7] and try again.';

    WHEN invalid_parameter_value THEN
        RAISE USING MESSAGE := CASE char_length(coalesce(CONVERSION_LANG, ''))
                                  WHEN 0 THEN format('The culture parameter ''%s'' provided in the function call is not supported.',
                                                     p_culture)
                                  ELSE format('Invalid CONVERSION_LANG constant value - ''%s''. Allowed values are: ''English'', ''Deutsch'', etc.',
                                              CONVERSION_LANG)
                               END,
                    DETAIL := 'Passed incorrect value for "p_culture" parameter or compiled incorrect CONVERSION_LANG constant value in function''s body.',
                    HINT := 'Check "p_culture" input parameter value, correct it if needed, and try again. Also check CONVERSION_LANG constant value.';

    WHEN invalid_text_representation THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
        v_err_message := substring(lower(v_err_message), 'integer\:\s\"(.*)\"');

        RAISE USING MESSAGE := format('Error while trying to convert "%s" value to SMALLINT data type.',
                                      v_err_message),
                    DETAIL := 'Supplied value contains illegal characters.',
                    HINT := 'Correct supplied value, remove all illegal characters.';
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.parse_to_time(p_datatype text, p_srctimestring text, p_culture text) OWNER TO postgres;

--
-- TOC entry 3892 (class 0 OID 0)
-- Dependencies: 365
-- Name: FUNCTION parse_to_time(p_datatype text, p_srctimestring text, p_culture text); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.parse_to_time(p_datatype text, p_srctimestring text, p_culture text) IS 'This function parses the TEXT string and converts it into a TIME value, according to specified culture (conversion mask).';


--
-- TOC entry 329 (class 1255 OID 17085)
-- Name: parsename(character varying, integer); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.parsename(object_name character varying, object_piece integer) RETURNS character varying
    LANGUAGE sql IMMUTABLE
    AS $_$
/***************************************************************
EXTENSION PACK function PARSENAME(x)
***************************************************************/
SELECT CASE 
		WHEN char_length($1) < char_length(replace($1, '.', '')) + 4
			AND $2 BETWEEN 1
				AND 4
			THEN reverse(split_part(reverse($1), '.', $2))
		ELSE NULL
		END $_$;


ALTER FUNCTION aws_sqlserver_ext.parsename(object_name character varying, object_piece integer) OWNER TO postgres;

--
-- TOC entry 330 (class 1255 OID 17086)
-- Name: patindex(character varying, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.patindex(pattern character varying, expression character varying) RETURNS bigint
    LANGUAGE plpgsql STRICT
    AS $_$
declare 
  v_find_result character varying;
  v_pos bigint;
  v_regexp_pattern character varying;
begin  
  v_pos := null;
  if left(pattern, 1) = '%' then
    v_regexp_pattern := regexp_replace(pattern, '^%', '%#"');
  else 
    v_regexp_pattern := '#"' || pattern;
  end if;
  
  if right(pattern, 1) = '%' then
    v_regexp_pattern := regexp_replace(v_regexp_pattern, '%$', '#"%');
  else  
   v_regexp_pattern := v_regexp_pattern || '#"';
 end if;  
  v_find_result := substring(expression from v_regexp_pattern for '#');
  if v_find_result <> '' then
    v_pos := strpos(expression, v_find_result);
  end if;  
  return v_pos;
end;
$_$;


ALTER FUNCTION aws_sqlserver_ext.patindex(pattern character varying, expression character varying) OWNER TO postgres;

--
-- TOC entry 331 (class 1255 OID 17087)
-- Name: rand(integer); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.rand(x integer) RETURNS double precision
    LANGUAGE plpgsql
    AS $$
BEGIN
/***************************************************************
EXTENSION PACK function RAND(x)
***************************************************************/
	perform setseed(x::double precision/2147483649);
	return random();
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.rand(x integer) OWNER TO postgres;

--
-- TOC entry 332 (class 1255 OID 17088)
-- Name: round3(numeric, integer, integer); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.round3(x numeric, y integer, z integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
BEGIN
/***************************************************************
EXTENSION PACK function ROUND3(arg1, arg2, arg3)
***************************************************************/
	if z = 0 or z is null then
		return round(x,y);
	else
		return trunc(x,y);
	end if;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.round3(x numeric, y integer, z integer) OWNER TO postgres;

--
-- TOC entry 340 (class 1255 OID 17027)
-- Name: round_fractseconds(numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.round_fractseconds(p_fractseconds numeric) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
DECLARE
   v_modpart INTEGER;
   v_decpart INTEGER;
   v_fractseconds INTEGER;
BEGIN
    v_fractseconds := floor(p_fractseconds)::INTEGER;
    v_modpart := v_fractseconds % 10;
    v_decpart := v_fractseconds - v_modpart;  

    RETURN CASE
              WHEN (v_modpart BETWEEN 0 AND 1) THEN v_decpart
              WHEN (v_modpart BETWEEN 2 AND 4) THEN v_decpart + 3
              WHEN (v_modpart BETWEEN 5 AND 8) THEN v_decpart + 7
              ELSE v_decpart + 10 -- 9
           END;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.round_fractseconds(p_fractseconds numeric) OWNER TO postgres;

--
-- TOC entry 3893 (class 0 OID 0)
-- Dependencies: 340
-- Name: FUNCTION round_fractseconds(p_fractseconds numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.round_fractseconds(p_fractseconds numeric) IS 'This function rounds milliseconds or microseconds in accordance with MS SQL Server conversion policy of datetime fractional second precision part.';


--
-- TOC entry 341 (class 1255 OID 17028)
-- Name: round_fractseconds(text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.round_fractseconds(p_fractseconds text) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
BEGIN
    RETURN aws_sqlserver_ext.round_fractseconds(p_fractseconds::NUMERIC);
EXCEPTION
    WHEN invalid_text_representation THEN
        RAISE USING MESSAGE := format('Error while trying to convert "%s" value to NUMERIC data type.', trim(p_fractseconds)),
                    DETAIL := 'Passed argument value contains illegal characters.',
                    HINT := 'Correct passed argument value, remove all illegal characters.';


END;
$$;


ALTER FUNCTION aws_sqlserver_ext.round_fractseconds(p_fractseconds text) OWNER TO postgres;

--
-- TOC entry 3894 (class 0 OID 0)
-- Dependencies: 341
-- Name: FUNCTION round_fractseconds(p_fractseconds text); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.round_fractseconds(p_fractseconds text) IS 'This function rounds milliseconds or microseconds in accordance with MS SQL Server conversion policy of datetime fractional second precision part.';


--
-- TOC entry 446 (class 1255 OID 17155)
-- Name: set_service_setting(character varying, character varying, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.set_service_setting(p_service character varying, p_setting character varying, p_value character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  DELETE FROM aws_sqlserver_ext_data.service_settings
   WHERE service = p_service
     AND setting = p_setting;

  INSERT INTO aws_sqlserver_ext_data.service_settings(service, setting, value)
  VALUES (p_service, p_setting, p_value);

  DELETE FROM aws_sqlserver_ext.sysmail_server;
 
  IF p_service = 'MAIL' THEN 
    PERFORM aws_sqlserver_ext.sysmail_set_arn_sp(p_value);
  END IF;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.set_service_setting(p_service character varying, p_setting character varying, p_value character varying) OWNER TO postgres;

--
-- TOC entry 350 (class 1255 OID 17158)
-- Name: set_up_rows(); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.set_up_rows() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE 
  TabInserted VARCHAR(100);
  TabDeleted VARCHAR(100);
BEGIN
  TabInserted := 'inserted_' || TG_TABLE_NAME;
  TabDeleted := 'deleted_' || TG_TABLE_NAME;
  EXECUTE 'DROP TABLE IF EXISTS ' || TabInserted;
  EXECUTE 'DROP TABLE IF EXISTS ' || TabDeleted;  
  EXECUTE 'CREATE TEMPORARY TABLE ' || TabInserted || ' ON COMMIT DROP AS TABLE ' || TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME || ' WITH NO DATA';
  EXECUTE 'CREATE TEMPORARY TABLE ' || TabDeleted || ' ON COMMIT DROP AS TABLE ' || TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME || ' WITH NO DATA';
  -- EXECUTE 'CREATE TEMPORARY TABLE IF NOT EXISTS ' || TabInserted || ' ON COMMIT DROP AS TABLE ' || TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME || ' WITH NO DATA';
  -- EXECUTE 'CREATE TEMPORARY TABLE IF NOT EXISTS ' || TabDeleted || ' ON COMMIT DROP AS TABLE ' || TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME || ' WITH NO DATA'; 
  -- EXECUTE 'TRUNCATE TABLE ' || TabInserted;
  -- EXECUTE 'TRUNCATE TABLE ' || TabDeleted; 
  RETURN NULL;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.set_up_rows() OWNER TO postgres;

--
-- TOC entry 333 (class 1255 OID 17089)
-- Name: set_version(character varying, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.set_version(pcomponentversion character varying, pcomponentname character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  rowcount smallint;
BEGIN
	UPDATE aws_sqlserver_ext.versions 
	   SET componentversion = pComponentVersion
	 WHERE extpackcomponentname = pComponentName;	 
	GET DIAGNOSTICS rowcount = ROW_COUNT;
	
	IF rowcount < 1 THEN
	 INSERT INTO aws_sqlserver_ext.versions(extpackcomponentname,componentversion) 
	      VALUES (pComponentName,pComponentVersion);
	END IF;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.set_version(pcomponentversion character varying, pcomponentname character varying) OWNER TO postgres;

--
-- TOC entry 335 (class 1255 OID 17091)
-- Name: sp_add_job(character varying, smallint, character varying, integer, character varying, integer, character varying, integer, integer, integer, integer, character varying, character varying, character varying, integer, integer, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_add_job(par_job_name character varying, par_enabled smallint DEFAULT 1, par_description character varying DEFAULT NULL::character varying, par_start_step_id integer DEFAULT 1, par_category_name character varying DEFAULT NULL::character varying, par_category_id integer DEFAULT NULL::integer, par_owner_login_name character varying DEFAULT NULL::character varying, par_notify_level_eventlog integer DEFAULT 2, par_notify_level_email integer DEFAULT 0, par_notify_level_netsend integer DEFAULT 0, par_notify_level_page integer DEFAULT 0, par_notify_email_operator_name character varying DEFAULT NULL::character varying, par_notify_netsend_operator_name character varying DEFAULT NULL::character varying, par_notify_page_operator_name character varying DEFAULT NULL::character varying, par_delete_level integer DEFAULT 0, INOUT par_job_id integer DEFAULT NULL::integer, par_originating_server character varying DEFAULT NULL::character varying, OUT returncode integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_retval INT DEFAULT 0;
  var_notify_email_operator_id INT DEFAULT 0;
  var_notify_email_operator_name VARCHAR(128);
  var_notify_netsend_operator_id INT DEFAULT 0;
  var_notify_page_operator_id INT DEFAULT 0;
  var_owner_sid CHAR(85) ;
  var_originating_server_id INT DEFAULT 0;
BEGIN
  /* Remove any leading/trailing spaces from parameters (except @owner_login_name) */
  SELECT UPPER(LTRIM(RTRIM(par_originating_server))) INTO par_originating_server;
  SELECT LTRIM(RTRIM(par_job_name)) INTO par_job_name;
  SELECT LTRIM(RTRIM(par_description)) INTO par_description;
  SELECT '[Uncategorized (Local)]' INTO par_category_name;
  SELECT 0 INTO par_category_id;
  SELECT LTRIM(RTRIM(par_notify_email_operator_name)) INTO par_notify_email_operator_name;
  SELECT LTRIM(RTRIM(par_notify_netsend_operator_name)) INTO par_notify_netsend_operator_name;
  SELECT LTRIM(RTRIM(par_notify_page_operator_name)) INTO par_notify_page_operator_name;
  SELECT NULL INTO var_originating_server_id; /* Turn [nullable] empty string parameters into NULLs */
  SELECT NULL INTO par_job_id;

  IF (par_originating_server = '') 
  THEN
    SELECT NULL INTO par_originating_server;
  END IF;

  IF (par_description = '') 
  THEN
    SELECT NULL INTO par_description;
  END IF;

  IF (par_category_name = '') 
  THEN
    SELECT NULL INTO par_category_name;
  END IF;

  IF (par_notify_email_operator_name = '') 
  THEN 
    SELECT NULL INTO par_notify_email_operator_name;
  END IF;

  IF (par_notify_netsend_operator_name = '') 
  THEN
    SELECT NULL INTO par_notify_netsend_operator_name;
  END IF;

  IF (par_notify_page_operator_name = '') 
  THEN 
    SELECT NULL INTO par_notify_page_operator_name;
  END IF;

  /* Check parameters */
  SELECT t.par_owner_sid
       , t.par_notify_level_email
       , t.par_notify_level_netsend
       , t.par_notify_level_page
       , t.par_category_id
       , t.par_notify_email_operator_id
       , t.par_notify_netsend_operator_id
       , t.par_notify_page_operator_id
       , t.par_originating_server
       , t.returncode
    FROM aws_sqlserver_ext.sp_verify_job(
         par_job_id /* NULL::integer */
       , par_job_name
       , par_enabled
       , par_start_step_id
       , par_category_name
       , var_owner_sid /* par_owner_sid */
       , par_notify_level_eventlog
       , par_notify_level_email
       , par_notify_level_netsend
       , par_notify_level_page
       , par_notify_email_operator_name
       , par_notify_netsend_operator_name
       , par_notify_page_operator_name
       , par_delete_level
       , par_category_id
       , var_notify_email_operator_id /* par_notify_email_operator_id */
       , var_notify_netsend_operator_id /* par_notify_netsend_operator_id */
       , var_notify_page_operator_id /* par_notify_page_operator_id */
       , par_originating_server
       ) t
    INTO var_owner_sid
       , par_notify_level_email
       , par_notify_level_netsend
       , par_notify_level_page
       , par_category_id
       , var_notify_email_operator_id
       , var_notify_netsend_operator_id
       , var_notify_page_operator_id
       , par_originating_server
       , var_retval;

  IF (var_retval <> 0)  /* Failure */
  THEN
    returncode := 1;
    RETURN;
  END IF;

  var_notify_email_operator_name := par_notify_email_operator_name;

  /* Default the description (if not supplied) */
  IF (par_description IS NULL) 
  THEN
    SELECT 'No description available.' INTO par_description;
  END IF;
  
  var_originating_server_id := 0;
  var_owner_sid := '';
    
  INSERT 
    INTO aws_sqlserver_ext.sysjobs (
         originating_server_id
       , name
       , enabled
       , description
       , start_step_id
       , category_id
       , owner_sid
       , notify_level_eventlog
       , notify_level_email
       , notify_level_netsend
       , notify_level_page
       , notify_email_operator_id
       , notify_email_operator_name
       , notify_netsend_operator_id
       , notify_page_operator_id
       , delete_level
       , version_number
    )
  VALUES (
         var_originating_server_id
       , par_job_name
       , par_enabled
       , par_description
       , par_start_step_id
       , par_category_id
       , var_owner_sid
       , par_notify_level_eventlog
       , par_notify_level_email
       , par_notify_level_netsend
       , par_notify_level_page
       , var_notify_email_operator_id
       , var_notify_email_operator_name
       , var_notify_netsend_operator_id
       , var_notify_page_operator_id
       , par_delete_level
       , 1);
  
  /* scope_identity() */
  SELECT LASTVAL() INTO par_job_id;
       
  /* Version number 1 */
  /* SELECT @retval = @@error */
  /* 0 means success */
  returncode := var_retval;
  RETURN;
    
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_add_job(par_job_name character varying, par_enabled smallint, par_description character varying, par_start_step_id integer, par_category_name character varying, par_category_id integer, par_owner_login_name character varying, par_notify_level_eventlog integer, par_notify_level_email integer, par_notify_level_netsend integer, par_notify_level_page integer, par_notify_email_operator_name character varying, par_notify_netsend_operator_name character varying, par_notify_page_operator_name character varying, par_delete_level integer, INOUT par_job_id integer, par_originating_server character varying, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 334 (class 1255 OID 17090)
-- Name: sp_add_jobschedule(integer, character varying, character varying, smallint, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, smallint, character); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_add_jobschedule(par_job_id integer DEFAULT NULL::integer, par_job_name character varying DEFAULT NULL::character varying, par_name character varying DEFAULT NULL::character varying, par_enabled smallint DEFAULT 1, par_freq_type integer DEFAULT 1, par_freq_interval integer DEFAULT 0, par_freq_subday_type integer DEFAULT 0, par_freq_subday_interval integer DEFAULT 0, par_freq_relative_interval integer DEFAULT 0, par_freq_recurrence_factor integer DEFAULT 0, par_active_start_date integer DEFAULT 20000101, par_active_end_date integer DEFAULT 99991231, par_active_start_time integer DEFAULT 0, par_active_end_time integer DEFAULT 235959, INOUT par_schedule_id integer DEFAULT NULL::integer, par_automatic_post smallint DEFAULT 1, INOUT par_schedule_uid character DEFAULT NULL::bpchar, OUT returncode integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_retval INT;
  var_owner_login_name VARCHAR(128);
BEGIN

  -- Check that we can uniquely identify the job
  SELECT t.par_job_name
       , t.par_job_id
       , t.returncode
    FROM aws_sqlserver_ext.sp_verify_job_identifiers (
         '@job_name'
       , '@job_id'
       , par_job_name
       , par_job_id
       , 'TEST'::character varying
       , NULL::bpchar
       ) t
    INTO par_job_name
       , par_job_id
       , var_retval;
  
  IF (var_retval <> 0) 
  THEN /* Failure */
    returncode := 1;
    RETURN;
  END IF;  

  /* Add the schedule first */
  SELECT t.par_schedule_uid
       , t.par_schedule_id
       , t.returncode
    FROM aws_sqlserver_ext.sp_add_schedule(
         par_name
       , par_enabled
       , par_freq_type
       , par_freq_interval
       , par_freq_subday_type
       , par_freq_subday_interval
       , par_freq_relative_interval
       , par_freq_recurrence_factor
       , par_active_start_date
       , par_active_end_date
       , par_active_start_time
       , par_active_end_time
       , var_owner_login_name
       , par_schedule_uid
       , par_schedule_id
       , NULL
       ) t
    INTO par_schedule_uid
       , par_schedule_id
       , var_retval;

  IF (var_retval <> 0) THEN /* Failure */
    returncode := 1;
    RETURN;
  END IF;
    
  SELECT t.returncode
    FROM aws_sqlserver_ext.sp_attach_schedule(
         par_job_id := par_job_id
       , par_job_name := NULL
       , par_schedule_id := par_schedule_id
       , par_schedule_name := NULL
       , par_automatic_post := par_automatic_post
       ) t
    INTO var_retval;

  IF (var_retval <> 0) THEN /* Failure */
    returncode := 1;
    RETURN;
  END IF;
    
  SELECT t.returncode 
    FROM aws_sqlserver_ext.sp_aws_add_jobschedule(par_job_id, par_schedule_id) t
    INTO var_retval;  

  IF (var_retval <> 0) THEN /* Failure */
    returncode := 1;
    RETURN;
  END IF;

  /* 0 means success */
  returncode := (var_retval);
  RETURN;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_add_jobschedule(par_job_id integer, par_job_name character varying, par_name character varying, par_enabled smallint, par_freq_type integer, par_freq_interval integer, par_freq_subday_type integer, par_freq_subday_interval integer, par_freq_relative_interval integer, par_freq_recurrence_factor integer, par_active_start_date integer, par_active_end_date integer, par_active_start_time integer, par_active_end_time integer, INOUT par_schedule_id integer, par_automatic_post smallint, INOUT par_schedule_uid character, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 392 (class 1255 OID 17093)
-- Name: sp_add_jobstep(integer, character varying, integer, character varying, character varying, text, text, integer, smallint, integer, smallint, integer, character varying, character varying, character varying, integer, integer, integer, character varying, integer, integer, character varying, character); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_add_jobstep(par_job_id integer DEFAULT NULL::integer, par_job_name character varying DEFAULT NULL::character varying, par_step_id integer DEFAULT NULL::integer, par_step_name character varying DEFAULT NULL::character varying, par_subsystem character varying DEFAULT 'TSQL'::bpchar, par_command text DEFAULT NULL::text, par_additional_parameters text DEFAULT NULL::text, par_cmdexec_success_code integer DEFAULT 0, par_on_success_action smallint DEFAULT 1, par_on_success_step_id integer DEFAULT 0, par_on_fail_action smallint DEFAULT 2, par_on_fail_step_id integer DEFAULT 0, par_server character varying DEFAULT NULL::character varying, par_database_name character varying DEFAULT NULL::character varying, par_database_user_name character varying DEFAULT NULL::character varying, par_retry_attempts integer DEFAULT 0, par_retry_interval integer DEFAULT 0, par_os_run_priority integer DEFAULT 0, par_output_file_name character varying DEFAULT NULL::character varying, par_flags integer DEFAULT 0, par_proxy_id integer DEFAULT NULL::integer, par_proxy_name character varying DEFAULT NULL::character varying, INOUT par_step_uid character DEFAULT NULL::bpchar, OUT returncode integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_retval INT;
  var_max_step_id INT;
  var_step_id INT;
BEGIN

  SELECT t.par_job_name
       , t.par_job_id
       , t.returncode
    FROM aws_sqlserver_ext.sp_verify_job_identifiers (
         '@job_name'
       , '@job_id'
       , par_job_name
       , par_job_id
       , 'TEST'::character varying
       , NULL::bpchar
       ) t
    INTO par_job_name
       , par_job_id
       , var_retval;
  
  IF (var_retval <> 0) THEN
    returncode := 1;
    RETURN;
  END IF;  
    
  -- Default step id (if not supplied)
  IF (par_step_id IS NULL) 
  THEN
     SELECT COALESCE(MAX(step_id), 0) + 1
        INTO var_step_id
       FROM aws_sqlserver_ext.sysjobsteps
      WHERE (job_id = par_job_id);
  ELSE 
    var_step_id := par_step_id; 
  END IF;

  -- Get current maximum step id    
  SELECT COALESCE(MAX(step_id), 0)
    INTO var_max_step_id
    FROM aws_sqlserver_ext.sysjobsteps
   WHERE (job_id = par_job_id);

  /* Check parameters */
  SELECT t.returncode
    FROM aws_sqlserver_ext.sp_verify_jobstep(
         par_job_id
       , var_step_id --par_step_id
       , par_step_name
       , par_subsystem
       , par_command
       , par_server
       , par_on_success_action
       , par_on_success_step_id
       , par_on_fail_action
       , par_on_fail_step_id
       , par_os_run_priority
       , par_flags
       , par_output_file_name
       , par_proxy_id
    ) t
    INTO var_retval;

  IF (var_retval <> 0) 
  THEN /* Failure */
    returncode := 1;
    RETURN;
  END IF;
    
  /* Modify database. */
  /* Update the job's version/last-modified information */
  UPDATE aws_sqlserver_ext.sysjobs
     SET version_number = version_number + 1
       --, date_modified = GETDATE() 
   WHERE (job_id = par_job_id);
   
  /* Adjust step id's (unless the new step is being inserted at the 'end') */
  /* NOTE: We MUST do this before inserting the step. */
  IF (var_step_id <= var_max_step_id) 
  THEN
    UPDATE aws_sqlserver_ext.sysjobsteps
       SET step_id = step_id + 1
     WHERE (step_id >= var_step_id) AND (job_id = par_job_id);
     
    /* Clean up OnSuccess/OnFail references */
    UPDATE aws_sqlserver_ext.sysjobsteps
       SET on_success_step_id = on_success_step_id + 1
     WHERE (on_success_step_id >= var_step_id) AND (job_id = par_job_id);
     
    UPDATE aws_sqlserver_ext.sysjobsteps
       SET on_fail_step_id = on_fail_step_id + 1
     WHERE (on_fail_step_id >= var_step_id) AND (job_id = par_job_id);
     
    UPDATE aws_sqlserver_ext.sysjobsteps
       SET on_success_step_id = 0
         , on_success_action = 1 /* Quit With Success */
     WHERE (on_success_step_id = var_step_id) 
       AND (job_id = par_job_id);
       
    UPDATE aws_sqlserver_ext.sysjobsteps
       SET on_fail_step_id = 0
         , on_fail_action = 2 /* Quit With Failure */
     WHERE (on_fail_step_id = var_step_id) 
       AND (job_id = par_job_id);
  END IF;

  /* uuid without extensions uuid-ossp (cheat) */
  SELECT uuid_in(md5(random()::text || clock_timestamp()::text)::cstring) INTO par_step_uid;
  
  /* Insert the step */
  INSERT 
    INTO aws_sqlserver_ext.sysjobsteps (
         job_id
       , step_id
       , step_name
       , subsystem
       , command
       , flags
       , additional_parameters
       , cmdexec_success_code
       , on_success_action
       , on_success_step_id
       , on_fail_action
       , on_fail_step_id
       , server
       , database_name
       , database_user_name
       , retry_attempts
       , retry_interval
       , os_run_priority
       , output_file_name
       , last_run_outcome
       , last_run_duration
       , last_run_retries
       , last_run_date
       , last_run_time
       , proxy_id
       , step_uid
   )
  VALUES (
         par_job_id
       , var_step_id
       , par_step_name
       , par_subsystem
       , par_command
       , par_flags
       , par_additional_parameters
       , par_cmdexec_success_code
       , par_on_success_action
       , par_on_success_step_id
       , par_on_fail_action
       , par_on_fail_step_id
       , par_server
       , par_database_name
       , par_database_user_name
       , par_retry_attempts
       , par_retry_interval
       , par_os_run_priority
       , par_output_file_name
       , 0
       , 0
       , 0
       , 0
       , 0
       , par_proxy_id
       , par_step_uid
  );
  
  --PERFORM aws_sqlserver_ext.sp_jobstep_create_proc (par_step_uid);

  returncode := var_retval;
  RETURN;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_add_jobstep(par_job_id integer, par_job_name character varying, par_step_id integer, par_step_name character varying, par_subsystem character varying, par_command text, par_additional_parameters text, par_cmdexec_success_code integer, par_on_success_action smallint, par_on_success_step_id integer, par_on_fail_action smallint, par_on_fail_step_id integer, par_server character varying, par_database_name character varying, par_database_user_name character varying, par_retry_attempts integer, par_retry_interval integer, par_os_run_priority integer, par_output_file_name character varying, par_flags integer, par_proxy_id integer, par_proxy_name character varying, INOUT par_step_uid character, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 393 (class 1255 OID 17095)
-- Name: sp_add_schedule(character varying, smallint, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, character varying, character, integer, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_add_schedule(par_schedule_name character varying, par_enabled smallint DEFAULT 1, par_freq_type integer DEFAULT 0, par_freq_interval integer DEFAULT 0, par_freq_subday_type integer DEFAULT 0, par_freq_subday_interval integer DEFAULT 0, par_freq_relative_interval integer DEFAULT 0, par_freq_recurrence_factor integer DEFAULT 0, par_active_start_date integer DEFAULT NULL::integer, par_active_end_date integer DEFAULT 99991231, par_active_start_time integer DEFAULT 0, par_active_end_time integer DEFAULT 235959, par_owner_login_name character varying DEFAULT NULL::character varying, INOUT par_schedule_uid character DEFAULT NULL::bpchar, INOUT par_schedule_id integer DEFAULT NULL::integer, par_originating_server character varying DEFAULT NULL::character varying, OUT returncode integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_retval INT;
  var_owner_sid CHAR(85);
  var_orig_server_id INT;
BEGIN
  /* Remove any leading/trailing spaces from parameters */
  SELECT LTRIM(RTRIM(par_schedule_name))
       , LTRIM(RTRIM(par_owner_login_name))
       , UPPER(LTRIM(RTRIM(par_originating_server)))
       , 0
    INTO par_schedule_name
       , par_owner_login_name
       , par_originating_server
       , par_schedule_id;

  /* Check schedule (frequency and owner) parameters */
  SELECT t.par_freq_interval
       , t.par_freq_subday_type
       , t.par_freq_subday_interval
       , t.par_freq_relative_interval
       , t.par_freq_recurrence_factor
       , t.par_active_start_date
       , t.par_active_start_time
       , t.par_active_end_date
       , t.par_active_end_time
       , t.returncode
    FROM aws_sqlserver_ext.sp_verify_schedule(
         NULL::integer /* @schedule_id  -- schedule_id does not exist for the new schedule */
       , par_schedule_name /* @name */
       , par_enabled /* @enabled */
       , par_freq_type /* @freq_type */
       , par_freq_interval /* @freq_interval */
       , par_freq_subday_type /* @freq_subday_type */
       , par_freq_subday_interval /* @freq_subday_interval */
       , par_freq_relative_interval /* @freq_relative_interval */
       , par_freq_recurrence_factor /* @freq_recurrence_factor */
       , par_active_start_date /* @active_start_date */
       , par_active_start_time /* @active_start_time */
       , par_active_end_date /* @active_end_date */
       , par_active_end_time /* @active_end_time */
       , var_owner_sid
       ) t
    INTO par_freq_interval
       , par_freq_subday_type
       , par_freq_subday_interval
       , par_freq_relative_interval
       , par_freq_recurrence_factor
       , par_active_start_date
       , par_active_start_time
       , par_active_end_date
       , par_active_end_time
       , var_retval /* @owner_sid */;

  IF (var_retval <> 0) THEN /* Failure */
    returncode := 1;
        RETURN;
    END IF;

  IF (par_schedule_uid IS NULL) 
  THEN /* Assign the GUID */
    /* uuid without extensions uuid-ossp (cheat) */
    SELECT uuid_in(md5(random()::text || clock_timestamp()::text)::cstring) INTO par_schedule_uid;
  END IF;
   
  var_orig_server_id := 0;
  var_owner_sid := uuid_in(md5(random()::text || clock_timestamp()::text)::cstring);


  INSERT 
    INTO aws_sqlserver_ext.sysschedules (
         schedule_uid
       , originating_server_id
       , name
       , owner_sid
       , enabled
       , freq_type
       , freq_interval
       , freq_subday_type
       , freq_subday_interval
       , freq_relative_interval
       , freq_recurrence_factor
       , active_start_date
       , active_end_date
       , active_start_time
       , active_end_time
   )
  VALUES (
         par_schedule_uid
       , var_orig_server_id
       , par_schedule_name
       , var_owner_sid
       , par_enabled
       , par_freq_type
       , par_freq_interval
       , par_freq_subday_type
       , par_freq_subday_interval
       , par_freq_relative_interval
       , par_freq_recurrence_factor
       , par_active_start_date
       , par_active_end_date
       , par_active_start_time
       , par_active_end_time
  );

  /* ZZZ */       
  SELECT 0 /* @@ERROR, */, LASTVAL()
    INTO var_retval, par_schedule_id;
    
  /* 0 means success */    
  returncode := var_retval;
  RETURN;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_add_schedule(par_schedule_name character varying, par_enabled smallint, par_freq_type integer, par_freq_interval integer, par_freq_subday_type integer, par_freq_subday_interval integer, par_freq_relative_interval integer, par_freq_recurrence_factor integer, par_active_start_date integer, par_active_end_date integer, par_active_start_time integer, par_active_end_time integer, par_owner_login_name character varying, INOUT par_schedule_uid character, INOUT par_schedule_id integer, par_originating_server character varying, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 394 (class 1255 OID 17097)
-- Name: sp_attach_schedule(integer, character varying, integer, character varying, smallint); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_attach_schedule(par_job_id integer DEFAULT NULL::integer, par_job_name character varying DEFAULT NULL::character varying, par_schedule_id integer DEFAULT NULL::integer, par_schedule_name character varying DEFAULT NULL::character varying, par_automatic_post smallint DEFAULT 1, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_retval INT;
  var_sched_owner_sid CHAR(85);
  var_job_owner_sid CHAR(85);
BEGIN
  /* Check that we can uniquely identify the job */
  SELECT t.par_job_name
       , t.par_job_id
       , t.par_owner_sid
       , t.returncode
    FROM aws_sqlserver_ext.sp_verify_job_identifiers(
         '@job_name'
       , '@job_id'
       , par_job_name /* @job_name */
       , par_job_id /* @job_id */
       , 'TEST' /* @sqlagent_starting_test */
       , var_job_owner_sid) t
    INTO par_job_name
       , par_job_id
       , var_job_owner_sid
       , var_retval;

  IF (var_retval <> 0) THEN /* Failure */
    returncode := 1;
    RETURN;
  END IF;
    
  /* Check that we can uniquely identify the schedule */
  SELECT t.par_schedule_name
       , t.par_schedule_id
       , t.par_owner_sid
       --, t.par_orig_server_id
       , t.returncode
    FROM aws_sqlserver_ext.sp_verify_schedule_identifiers(
         '@schedule_name'::character varying /* @name_of_name_parameter */
       , '@schedule_id'::character varying /* @name_of_id_parameter */
       , par_schedule_name /* @schedule_name */
       , par_schedule_id /* @schedule_id */
       , var_sched_owner_sid /* @owner_sid */
       , NULL::integer /* @orig_server_id */
       , NULL::integer) t
    INTO par_schedule_name
       , par_schedule_id
       , var_sched_owner_sid
       , var_retval /* @job_id_filter */;

  IF (var_retval <> 0) THEN /* Failure */
    returncode := 1;
    RETURN;
  END IF
    
  /* If the record doesn't already exist create it */;
  IF (
    NOT EXISTS (
      SELECT 1 
        FROM aws_sqlserver_ext.sysjobschedules
       WHERE (schedule_id = par_schedule_id) 
         AND (job_id = par_job_id))) 
  THEN
    INSERT 
      INTO aws_sqlserver_ext.sysjobschedules (schedule_id, job_id)
    VALUES (par_schedule_id, par_job_id);
    
    SELECT 0 INTO var_retval; /* @@ERROR */
  END IF;


  PERFORM aws_sqlserver_ext.sp_set_next_run (par_job_id, par_schedule_id);
  
  /* 0 means success */
  returncode := var_retval;
  RETURN;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_attach_schedule(par_job_id integer, par_job_name character varying, par_schedule_id integer, par_schedule_name character varying, par_automatic_post smallint, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 417 (class 1255 OID 17127)
-- Name: sp_aws_add_jobschedule(integer, integer); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_aws_add_jobschedule(par_job_id integer DEFAULT NULL::integer, par_schedule_id integer DEFAULT NULL::integer, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
  proc_name_mask VARCHAR(100) DEFAULT 'aws_sqlserver_ext_data.sql_agent$job_%s_step_%s';
  var_cron_expression VARCHAR(50); 
  var_job_cmd VARCHAR(255); 
  var_schedule_name VARCHAR(255);

  var_job_name VARCHAR(128);
  var_start_step_id INTEGER;
  var_notify_level_email INTEGER;
  var_notify_email_operator_id INTEGER;
  var_notify_email_operator_name VARCHAR(128);
  notify_email_sender VARCHAR(128);
  var_delete_level INTEGER;
BEGIN

  IF (EXISTS 
    (
      SELECT 1
        FROM aws_sqlserver_ext.sysjobschedules
       WHERE schedule_id = par_schedule_id
         AND job_id = par_job_id
    )
  ) 
  THEN

    SELECT cron_expression 
      FROM aws_sqlserver_ext.sp_schedule_to_cron(par_job_id, par_schedule_id) 
      INTO var_cron_expression;
      
    SELECT name 
      FROM aws_sqlserver_ext.sysschedules
     WHERE schedule_id = par_schedule_id 
      INTO var_schedule_name;

    SELECT name
         , start_step_id
         , COALESCE(notify_level_email,0)
         , COALESCE(notify_email_operator_id,0)
         , COALESCE(notify_email_operator_name,'')
         , COALESCE(delete_level,0) 
      FROM aws_sqlserver_ext.sysjobs
     WHERE job_id = par_job_id
      INTO var_job_name
         , var_start_step_id 
         , var_notify_level_email 
         , var_notify_email_operator_id 
         , var_notify_email_operator_name 
         , var_delete_level;
  
    var_job_cmd := FORMAT(proc_name_mask, par_job_id, '1');   
    notify_email_sender := 'aws_test_email_sender@dbbest.com';
    
    PERFORM aws_sqlserver_ext.awslambda_fn
    (
      aws_sqlserver_ext.get_service_setting
      (
        'JOB',
        'LAMBDA_ARN'
      ),
      JSON_BUILD_OBJECT
      (
        'mode', 'add_job',
        'parameters', JSON_BUILD_OBJECT
        (
          'vendor', 'postgresql',
          'job_name', var_schedule_name,
          'job_frequency', var_cron_expression,
          'job_cmd', var_job_cmd,
          'notify_level_email', var_notify_level_email,
          'delete_level', var_delete_level,
          'uid', par_job_id,
          'callback', 'aws_sqlserver_ext.sp_job_log',
          'notification', JSON_BUILD_OBJECT
          (
            'notify_email_sender', notify_email_sender,
            'notify_email_recipient', var_notify_email_operator_name
          )

        )
      )
    );

    returncode := 0;

  ELSE

    returncode := 1;
    RAISE 'Job not found' USING ERRCODE := '50000';

  END IF;

END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.sp_aws_add_jobschedule(par_job_id integer, par_schedule_id integer, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 418 (class 1255 OID 17128)
-- Name: sp_aws_del_jobschedule(integer, integer); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_aws_del_jobschedule(par_job_id integer DEFAULT NULL::integer, par_schedule_id integer DEFAULT NULL::integer, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_schedule_name VARCHAR(255);
BEGIN

  IF (EXISTS 
    (
        SELECT 1
          FROM aws_sqlserver_ext.sysjobschedules
        WHERE schedule_id = par_schedule_id
          AND job_id = par_job_id
    )
  )
  THEN

    SELECT name
      FROM aws_sqlserver_ext.sysschedules
     WHERE schedule_id = par_schedule_id
      INTO var_schedule_name;

    PERFORM aws_sqlserver_ext.awslambda_fn
    (
      aws_sqlserver_ext.get_service_setting
      (
        'JOB',
        'LAMBDA_ARN'
      ),
      JSON_BUILD_OBJECT
      (
        'mode', 'del_schedule',
        'parameters', JSON_BUILD_OBJECT
        (
          'schedule_name', var_schedule_name,
          'force_delete', 'TRUE'
        )
      )
    );

    returncode := 0;

  ELSE

    returncode := 1;
    RAISE 'Job not found' USING ERRCODE := '50000';

  END IF;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_aws_del_jobschedule(par_job_id integer, par_schedule_id integer, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 396 (class 1255 OID 17100)
-- Name: sp_delete_job(integer, character varying, character varying, smallint, smallint); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_delete_job(par_job_id integer DEFAULT NULL::integer, par_job_name character varying DEFAULT NULL::character varying, par_originating_server character varying DEFAULT NULL::character varying, par_delete_history smallint DEFAULT 1, par_delete_unused_schedule smallint DEFAULT 1, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_retval INT;
  var_category_id INT;
  var_job_owner_sid CHAR(85);
  var_err INT;
  var_schedule_id INT;
BEGIN
  IF ((par_job_id IS NOT NULL) OR (par_job_name IS NOT NULL)) 
  THEN
    SELECT t.par_job_name
         , t.par_job_id
         , t.par_owner_sid
         , t.returncode
      FROM aws_sqlserver_ext.sp_verify_job_identifiers(
           '@job_name'
         , '@job_id'
         , par_job_name
         , par_job_id
         , 'TEST'
         , var_job_owner_sid
         ) t
      INTO par_job_name
         , par_job_id
         , var_job_owner_sid
         , var_retval;
         
    IF (var_retval <> 0) THEN /* Failure */
      returncode := (1);
      RETURN;
    END IF;
  END IF;
  
  /* Get category to see if it is a misc. replication agent. @category_id will be */
  /* NULL if there is no @job_id. */
  
  SELECT category_id
    INTO var_category_id
    FROM aws_sqlserver_ext.sysjobs
   WHERE job_id = par_job_id;
   
  /* Do the delete (for a specific job) */
  IF (par_job_id IS NOT NULL) 
  THEN
    --CREATE TEMPORARY TABLE "#temp_schedules_to_delete" (schedule_id INT NOT NULL);
     
    -- Delete all traces of the job 
    -- BEGIN TRANSACTION 
    -- Get the schedules to delete before deleting records from sysjobschedules 



    --IF (par_delete_unused_schedule = 1) 
    --THEN
      -- ZZZ optimize 
      -- Get the list of schedules to delete 
      --INSERT INTO "#temp_schedules_to_delete"
      --SELECT DISTINCT schedule_id 
      --  FROM aws_sqlserver_ext.sysschedules
      -- WHERE schedule_id IN (SELECT schedule_id
      --                         FROM aws_sqlserver_ext.sysjobschedules
      --                         WHERE job_id = par_job_id);
      --INSERT INTO "#temp_schedules_to_delete"
      SELECT schedule_id
    	FROM aws_sqlserver_ext.sysjobschedules
       WHERE job_id = par_job_id
        INTO var_schedule_id;

    PERFORM aws_sqlserver_ext.sp_aws_del_jobschedule (par_job_id := par_job_id, par_schedule_id := var_schedule_id);  


--    END IF;


    --DELETE FROM aws_sqlserver_ext.sysschedules
    -- WHERE schedule_id IN (SELECT schedule_id FROM aws_sqlserver_ext.sysjobschedules WHERE job_id = par_job_id);
  
    DELETE FROM aws_sqlserver_ext.sysjobschedules
     WHERE job_id = par_job_id;
     
    DELETE FROM aws_sqlserver_ext.sysjobsteps
     WHERE job_id = par_job_id;
     
    DELETE FROM aws_sqlserver_ext.sysjobs
     WHERE job_id = par_job_id;
     
    SELECT 0 /* @@ERROR */ INTO var_err;
          
    /* Delete the schedule(s) if requested to and it isn't being used by other jobs */
    IF (par_delete_unused_schedule = 1) 
    THEN
      /* Now OK to delete the schedule */
      DELETE FROM aws_sqlserver_ext.sysschedules
       WHERE schedule_id = var_schedule_id; --IN (SELECT schedule_id FROM "#temp_schedules_to_delete");

      --DELETE FROM aws_sqlserver_ext.sysschedules
      -- WHERE schedule_id IN (SELECT schedule_id
      --                         FROM "#temp_schedules_to_delete" AS sdel
      --                        WHERE NOT EXISTS (SELECT *
      --                                            FROM aws_sqlserver_ext.sysjobschedules AS js
      --                                           WHERE js.schedule_id = sdel.schedule_id));
    END IF;
    
    /* Delete the job history if requested */
    IF (par_delete_history = 1)
    THEN
      DELETE FROM aws_sqlserver_ext.sysjobhistory
      WHERE job_id = par_job_id;
    END IF;

    /* All done */
    /* COMMIT TRANSACTION */
    --DROP TABLE "#temp_schedules_to_delete";
  END IF;
  
  /* 0 means success */
  returncode := 0;
  RETURN;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_delete_job(par_job_id integer, par_job_name character varying, par_originating_server character varying, par_delete_history smallint, par_delete_unused_schedule smallint, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 395 (class 1255 OID 17098)
-- Name: sp_delete_jobschedule(integer, character varying, character varying, integer, smallint); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_delete_jobschedule(par_job_id integer DEFAULT NULL::integer, par_job_name character varying DEFAULT NULL::character varying, par_name character varying DEFAULT NULL::character varying, par_keep_schedule integer DEFAULT 0, par_automatic_post smallint DEFAULT 1, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_retval INT;
  var_sched_count INT;
  var_schedule_id INT;
  var_job_owner_sid CHAR(85);
BEGIN
  /* Remove any leading/trailing spaces from parameters */
  SELECT LTRIM(RTRIM(par_name)) INTO par_name;
  
  /* Check that we can uniquely identify the job */
  SELECT t.par_job_name
       , t.par_job_id
       , t.par_owner_sid
       , t.returncode
    FROM aws_sqlserver_ext.sp_verify_job_identifiers(
         '@job_name'
       , '@job_id'
       , par_job_name
       , par_job_id
       , 'TEST'
       , var_job_owner_sid
       ) t
    INTO par_job_name
       , par_job_id
       , var_job_owner_sid
       , var_retval;

  IF (var_retval <> 0) THEN /* Failure */
    returncode := 1;
    RETURN;
  END IF;
   
  IF (LOWER(UPPER(par_name)) = LOWER('ALL')) 
  THEN
    SELECT - 1 INTO var_schedule_id;
    
    /* We use this in the call to sp_sqlagent_notify */
    /* Delete the schedule(s) if it isn't being used by other jobs */
    CREATE TEMPORARY TABLE "#temp_schedules_to_delete" (schedule_id INT NOT NULL)
    /* If user requests that the schedules be removed (the legacy behavoir) */
    /* make sure it isnt being used by other jobs */;

    IF (par_keep_schedule = 0) 
    THEN
      /* Get the list of schedules to delete */
      INSERT INTO "#temp_schedules_to_delete"
      SELECT DISTINCT schedule_id
        FROM aws_sqlserver_ext.sysschedules
       WHERE (schedule_id IN (SELECT schedule_id
                                FROM aws_sqlserver_ext.sysjobschedules
                               WHERE (job_id = par_job_id)));
      /* make sure no other jobs use these schedules */
      IF (EXISTS (SELECT *
                    FROM aws_sqlserver_ext.sysjobschedules
                   WHERE (job_id <> par_job_id) 
                     AND (schedule_id IN (SELECT schedule_id
                                            FROM "#temp_schedules_to_delete")))) 
      THEN /* Failure */
        RAISE 'One or more schedules were not deleted because they are being used by at least one other job. Use "sp_detach_schedule" to remove schedules from a job.' USING ERRCODE := '50000';
        returncode := 1;
        RETURN;
      END IF;
    END IF;
    
    /* OK to delete the jobschedule */
    DELETE FROM aws_sqlserver_ext.sysjobschedules
     WHERE (job_id = par_job_id);
     
    /* OK to delete the schedule - temp_schedules_to_delete is empty if @keep_schedule <> 0 */
    DELETE FROM aws_sqlserver_ext.sysschedules
     WHERE schedule_id IN (SELECT schedule_id FROM "#temp_schedules_to_delete");
  ELSE ---- IF (LOWER(UPPER(par_name)) = LOWER('ALL')) 

    -- Need to use sp_detach_schedule to remove this ambiguous schedule name
    IF(var_sched_count > 1) /* Failure */
    THEN
      RAISE 'More than one schedule named "%" is attached to job "%". Use "sp_detach_schedule" to remove schedules from a job.', par_name, par_job_name  USING ERRCODE := '50000';
      returncode := 1;
      RETURN;
    END IF;

    --If user requests that the schedule be removed (the legacy behavoir)
    --make sure it isnt being used by another job
    IF (par_keep_schedule = 0)
    THEN
      IF(EXISTS(SELECT *
                  FROM aws_sqlserver_ext.sysjobschedules
                 WHERE (schedule_id = var_schedule_id)
                   AND (job_id <> par_job_id)))
      THEN /* Failure */
        RAISE 'Schedule "%" was not deleted because it is being used by at least one other job. Use "sp_detach_schedule" to remove schedules from a job.', par_name USING ERRCODE := '50000';
        returncode := 1;
        RETURN;
      END IF;
    END IF;

    /* Delete the job schedule link first */
    DELETE FROM aws_sqlserver_ext.sysjobschedules
     WHERE (job_id = par_job_id) 
       AND (schedule_id = var_schedule_id);
       
    /* Delete schedule if required */
    IF (par_keep_schedule = 0) 
    THEN
      /* Now delete the schedule if required */
      DELETE FROM aws_sqlserver_ext.sysschedules
       WHERE (schedule_id = var_schedule_id);
    END IF;

    SELECT t.returncode 
    FROM aws_sqlserver_ext.sp_aws_del_jobschedule(par_job_id, var_schedule_id) t
    INTO var_retval;  
	

  END IF;
  
  /* Update the job's version/last-modified information */
  UPDATE aws_sqlserver_ext.sysjobs
     SET version_number = version_number + 1
       -- , date_modified = GETDATE() /
   WHERE job_id = par_job_id;

  DROP TABLE IF EXISTS "#temp_schedules_to_delete";
 
   
  /* 0 means success */ 
  returncode := var_retval;
  RETURN;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_delete_jobschedule(par_job_id integer, par_job_name character varying, par_name character varying, par_keep_schedule integer, par_automatic_post smallint, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 397 (class 1255 OID 17101)
-- Name: sp_delete_jobstep(integer, character varying, integer); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_delete_jobstep(par_job_id integer DEFAULT NULL::integer, par_job_name character varying DEFAULT NULL::character varying, par_step_id integer DEFAULT NULL::integer, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_retval INT;
  var_max_step_id INT;
  var_valid_range VARCHAR(50);
  var_job_owner_sid CHAR(85);
BEGIN
  SELECT t.par_job_name
       , t.par_job_id
       , t.par_owner_sid
       , t.returncode
    FROM aws_sqlserver_ext.sp_verify_job_identifiers(
         '@job_name'
       , '@job_id'
       , par_job_name
       , par_job_id
       , 'TEST'
       , var_job_owner_sid
       ) t
    INTO par_job_name
       , par_job_id
       , var_job_owner_sid
       , var_retval;

  IF (var_retval <> 0) THEN /* Failure */
    returncode := 1;
    RETURN;
  END IF;
    
  /* Get current maximum step id */
  SELECT COALESCE(MAX(step_id), 0)
    INTO var_max_step_id
    FROM aws_sqlserver_ext.sysjobsteps
   WHERE (job_id = par_job_id);
    
  /* Check step id */
  IF (par_step_id < 0) OR (par_step_id > var_max_step_id) 
  THEN
    SELECT CONCAT('0 (all steps) ..', CAST (var_max_step_id AS VARCHAR(1)))
      INTO var_valid_range;
     RAISE 'The specified "%" is invalid (valid values are: %).', 'step_id', var_valid_range USING ERRCODE := '50000';
     returncode := 1;
     RETURN;
        /* Failure */
    END IF;
    
    /* BEGIN TRANSACTION */
    /* Delete either the specified step or ALL the steps (if step id is 0) */
    IF (par_step_id = 0) 
    THEN
      DELETE FROM aws_sqlserver_ext.sysjobsteps
       WHERE (job_id = par_job_id);
    ELSE
      DELETE FROM aws_sqlserver_ext.sysjobsteps
       WHERE (job_id = par_job_id) AND (step_id = par_step_id);
    END IF;

    IF (par_step_id <> 0) 
    THEN
      /* Adjust step id's */
      UPDATE aws_sqlserver_ext.sysjobsteps
         SET step_id = step_id - 1
       WHERE (step_id > par_step_id) 
         AND (job_id = par_job_id);
         
      /* Clean up OnSuccess/OnFail references */
      UPDATE aws_sqlserver_ext.sysjobsteps
         SET on_success_step_id = on_success_step_id - 1
       WHERE (on_success_step_id > par_step_id) AND (job_id = par_job_id);
       
      UPDATE aws_sqlserver_ext.sysjobsteps
         SET on_fail_step_id = on_fail_step_id - 1
       WHERE (on_fail_step_id > par_step_id) AND (job_id = par_job_id);
       
      /* Quit With Success */        
      UPDATE aws_sqlserver_ext.sysjobsteps 
         SET on_success_step_id = 0
           , on_success_action = 1 
       WHERE (on_success_step_id = par_step_id) 
         AND (job_id = par_job_id);
        
      /* Quit With Failure */
      UPDATE aws_sqlserver_ext.sysjobsteps
         SET on_fail_step_id = 0
           , on_fail_action = 2
       WHERE (on_fail_step_id = par_step_id) AND (job_id = par_job_id);
    END IF;
    
    /* Update the job's version/last-modified information */
    UPDATE aws_sqlserver_ext.sysjobs
       SET version_number = version_number + 1
         --, date_modified = GETDATE() /
     WHERE (job_id = par_job_id);
     
    /* COMMIT TRANSACTION */
    
    /* Success */
    returncode := 0;
    RETURN;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_delete_jobstep(par_job_id integer, par_job_name character varying, par_step_id integer, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 398 (class 1255 OID 17102)
-- Name: sp_delete_schedule(integer, character varying, smallint, smallint); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_delete_schedule(par_schedule_id integer DEFAULT NULL::integer, par_schedule_name character varying DEFAULT NULL::character varying, par_force_delete smallint DEFAULT 0, par_automatic_post smallint DEFAULT 1, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_retval INT;
  var_job_count INT;
BEGIN
  /* check if there are jobs using this schedule */
  SELECT COUNT(*)
    INTO var_job_count
    FROM aws_sqlserver_ext.sysjobschedules
   WHERE (schedule_id = par_schedule_id);
   
  /* If we aren't force deleting the schedule make sure no jobs are using it */
  IF ((par_force_delete = 0) AND (var_job_count > 0)) 
  THEN /* Failure */
    RAISE 'The schedule was not deleted because it is being used by one or more jobs.' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;
  
  /* OK to delete the job - schedule link */
  DELETE FROM aws_sqlserver_ext.sysjobschedules
   WHERE schedule_id = par_schedule_id;
   
  /* OK to delete the schedule */
  DELETE FROM aws_sqlserver_ext.sysschedules
   WHERE schedule_id = par_schedule_id;
   
  /* 0 means success */
  returncode := var_retval;
  RETURN;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_delete_schedule(par_schedule_id integer, par_schedule_name character varying, par_force_delete smallint, par_automatic_post smallint, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 399 (class 1255 OID 17103)
-- Name: sp_detach_schedule(integer, character varying, integer, character varying, smallint, smallint); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_detach_schedule(par_job_id integer DEFAULT NULL::integer, par_job_name character varying DEFAULT NULL::character varying, par_schedule_id integer DEFAULT NULL::integer, par_schedule_name character varying DEFAULT NULL::character varying, par_delete_unused_schedule smallint DEFAULT 0, par_automatic_post smallint DEFAULT 1, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_retval INT;
  var_sched_owner_sid CHAR(85);
  var_job_owner_sid CHAR(85);
BEGIN
  /* Check that we can uniquely identify the job */
  SELECT t.par_job_name
       , t.par_job_id
       , t.par_owner_sid
       , t.returncode
    FROM aws_sqlserver_ext.sp_verify_job_identifiers(
         '@job_name'
       , '@job_id'
       , par_job_name
       , par_job_id
       , 'TEST'
       , var_job_owner_sid
       ) t
    INTO par_job_name
       , par_job_id
       , var_job_owner_sid
       , var_retval;

  IF (var_retval <> 0) THEN /* Failure */
    returncode := 1;
    RETURN;
  END IF;
    
  /* Check that we can uniquely identify the schedule */
  SELECT t.par_schedule_name
       , t.par_schedule_id
       , t.par_owner_sid
       , t.par_orig_server_id
       , t.returncode
    FROM aws_sqlserver_ext.sp_verify_schedule_identifiers(
         '@schedule_name' /* @name_of_name_parameter */
       , '@schedule_id' /* @name_of_id_parameter */
       , par_schedule_name /* @schedule_name */
       , par_schedule_id /* @schedule_id */
       , var_sched_owner_sid /* @owner_sid */
       , NULL /* @orig_server_id */
       , par_job_id
       ) t
    INTO par_schedule_name
       , par_schedule_id
       , var_sched_owner_sid
       , var_retval;
       -- job_id_filter

  IF (var_retval <> 0) THEN /* Failure */
    returncode := 1;
    RETURN;
  END IF;
    
  /* If the record doesn't exist raise an error */
  IF (NOT EXISTS (
    SELECT * 
      FROM aws_sqlserver_ext.sysjobschedules
     WHERE (schedule_id = par_schedule_id) 
       AND (job_id = par_job_id))) 
  THEN /* Failure */
    RAISE 'The specified schedule name "%s" is not associated with the job "%s".', par_schedule_name, par_job_name USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;
  
  SELECT t.returncode 
    FROM aws_sqlserver_ext.sp_aws_del_jobschedule(par_job_id, par_schedule_id) t
    INTO var_retval;  

  DELETE FROM aws_sqlserver_ext.sysjobschedules
   WHERE (job_id = par_job_id) 
     AND (schedule_id = par_schedule_id);
     
  SELECT /* @@ERROR */ 0 -- ZZZ
    INTO var_retval;
    
  /* delete the schedule if requested and it isn't referenced */
  IF (var_retval = 0 AND par_delete_unused_schedule = 1) 
  THEN
    IF (NOT EXISTS (
      SELECT * 
        FROM aws_sqlserver_ext.sysjobschedules
       WHERE (schedule_id = par_schedule_id))) 
    THEN
      DELETE FROM aws_sqlserver_ext.sysschedules
       WHERE (schedule_id = par_schedule_id);
    END IF;
  END IF;
  
  /* Update the job's version/last-modified information */
  /* 
  UPDATE aws_sqlserver_ext.sysjobs
     SET version_number = version_number + 1
       -- , date_modified = GETDATE()
   WHERE (job_id = par_job_id); 
  */

  -- PERFORM aws_sqlserver_ext.sp_delete_job (par_job_id := par_job_id);  

  /* 0 means success */   
  returncode := var_retval;
  RETURN;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_detach_schedule(par_job_id integer, par_job_name character varying, par_schedule_id integer, par_schedule_name character varying, par_delete_unused_schedule smallint, par_automatic_post smallint, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 400 (class 1255 OID 17104)
-- Name: sp_get_dbmail(); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_get_dbmail(OUT par_mail_id integer, OUT par_mail_data text) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_mailitem_id INTEGER;
  var_xml TEXT;
  var_rc INTEGER;
BEGIN

  SELECT mailitem_id
    INTO var_mailitem_id
    FROM aws_sqlserver_ext.sysmail_mailitems
   WHERE sent_status = 0
   ORDER BY mailitem_id ASC
   LIMIT 1;

  IF var_mailitem_id IS NULL THEN

    RAISE 'E-mail messages are missing.' USING ERRCODE := '50000';

    RETURN;

  END IF;

  UPDATE aws_sqlserver_ext.sysmail_mailitems
     SET sent_status = 1
   WHERE mailitem_id = var_mailitem_id;

  SELECT t.par_mail_data,
    t.returncode
  INTO var_xml, var_rc
  FROM aws_sqlserver_ext.sysmail_dbmail_json(var_mailitem_id) t; 

  IF var_rc <> 0 THEN

    RETURN;

  END IF;

  par_mail_id := var_mailitem_id;
  par_mail_data := var_xml;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_get_dbmail(OUT par_mail_id integer, OUT par_mail_data text) OWNER TO postgres;

--
-- TOC entry 445 (class 1255 OID 17154)
-- Name: sp_job_log(integer, integer, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_job_log(pid integer, pstatus integer, pmessage character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM aws_sqlserver_ext.update_job (pid, pmessage);

  -- INSERT INTO ms_test.jobs_log(id, t, status, message)
  -- VALUES (pid, CURRENT_TIMESTAMP, pstatus, pmessage);
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_job_log(pid integer, pstatus integer, pmessage character varying) OWNER TO postgres;

--
-- TOC entry 352 (class 1255 OID 17160)
-- Name: sp_jobstep_create_proc(); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_jobstep_create_proc() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
  retval INT;
  proc_name_mask VARCHAR(100);
  proc_name VARCHAR(100);
  proc_body_mask VARCHAR(200);
  command_text TEXT;
  proc_body TEXT;
  
BEGIN
  proc_name_mask := 'sql_agent$job_%s_step_%s';
  proc_body_mask := 'create or replace function aws_sqlserver_ext_data.%s() returns void as $$ begin %s end $$ language plpgsql;';

  SELECT format(proc_name_mask, job_id, step_id) 
       , command  
    FROM aws_sqlserver_ext.sysjobsteps 
   WHERE step_uid = NEW.step_uid
    INTO proc_name, command_text; 

  proc_body := format(proc_body_mask, proc_name, command_text);
  EXECUTE proc_body;
  
  RETURN NEW;
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.sp_jobstep_create_proc() OWNER TO postgres;

--
-- TOC entry 353 (class 1255 OID 17161)
-- Name: sp_jobstep_drop_proc(); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_jobstep_drop_proc() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
  retval INT;
  proc_name_mask VARCHAR(100);
  proc_name VARCHAR(100);
  drop_mask VARCHAR(200);
  drop_cmd TEXT;
BEGIN
  proc_name_mask := 'sql_agent$job_%s_step_%s';
  drop_mask := 'drop function aws_sqlserver_ext_data.%s();';

  SELECT format(proc_name_mask, job_id, step_id) 
    FROM aws_sqlserver_ext.sysjobsteps 
   WHERE step_uid = OLD.step_uid
    INTO proc_name; 

  drop_cmd := format(drop_mask, proc_name);
  EXECUTE drop_cmd;
  
  RETURN OLD;
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.sp_jobstep_drop_proc() OWNER TO postgres;

--
-- TOC entry 405 (class 1255 OID 17110)
-- Name: sp_schedule_to_cron(integer, integer); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_schedule_to_cron(par_job_id integer, par_schedule_id integer, OUT cron_expression character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_enabled INTEGER;
  var_freq_type INTEGER;
  var_freq_interval INTEGER;
  var_freq_subday_type INTEGER;
  var_freq_subday_interval INTEGER;
  var_freq_relative_interval INTEGER;
  var_freq_recurrence_factor INTEGER;
  var_active_start_date INTEGER;
  var_active_end_date INTEGER;
  var_active_start_time INTEGER;
  var_active_end_time INTEGER;

  var_next_run_date date;
  var_next_run_time time;
  var_next_run_dt timestamp;

  var_tmp_interval varchar(50);
  var_current_dt timestamp;
  var_next_dt timestamp;
BEGIN

  SELECT enabled
       , freq_type
       , freq_interval
       , freq_subday_type
       , freq_subday_interval
       , freq_relative_interval
       , freq_recurrence_factor
       , active_start_date
       , active_end_date
       , active_start_time
       , active_end_time
    FROM aws_sqlserver_ext.sysschedules
    INTO var_enabled
       , var_freq_type
       , var_freq_interval
       , var_freq_subday_type
       , var_freq_subday_interval
       , var_freq_relative_interval
       , var_freq_recurrence_factor
       , var_active_start_date
       , var_active_end_date
       , var_active_start_time
       , var_active_end_time
   WHERE schedule_id = par_schedule_id;

  /* if enabled = 0 return */
  CASE var_freq_type
    WHEN 1 THEN
      NULL;

    WHEN 4 THEN
    BEGIN
        cron_expression :=
        CASE
          /* WHEN var_freq_subday_type = 1 THEN var_freq_subday_interval::character varying || ' At the specified time'  -- start time */
          /* WHEN var_freq_subday_type = 2 THEN var_freq_subday_interval::character varying || ' second'  -- ADD var_freq_subday_interval SECOND */
          WHEN var_freq_subday_type = 4 THEN format('cron(*/%s * * * ? *)', var_freq_subday_interval::character varying) /* ADD var_freq_subday_interval MINUTE */
          WHEN var_freq_subday_type = 8 THEN format('cron(0 */%s * * ? *)', var_freq_subday_interval::character varying) /* ADD var_freq_subday_interval HOUR */
          ELSE ''
        END;
    END;

    WHEN 8 THEN
      NULL;

    WHEN 16 THEN
      NULL;

    WHEN 32 THEN
      NULL;

    WHEN 64 THEN
      NULL;

    WHEN 128 THEN
     NULL;
     
  END CASE;

 -- return cron_expression;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_schedule_to_cron(par_job_id integer, par_schedule_id integer, OUT cron_expression character varying) OWNER TO postgres;

--
-- TOC entry 401 (class 1255 OID 17105)
-- Name: sp_send_dbmail(character varying, text, text, text, character varying, text, character varying, character varying, character varying, text, text, character varying, smallint, character varying, smallint, integer, character varying, smallint, smallint, smallint, smallint, text, text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_send_dbmail(par_profile_name character varying DEFAULT NULL::character varying, par_recipients text DEFAULT NULL::text, par_copy_recipients text DEFAULT NULL::text, par_blind_copy_recipients text DEFAULT NULL::text, par_subject character varying DEFAULT NULL::character varying, par_body text DEFAULT NULL::text, par_body_format character varying DEFAULT NULL::character varying, par_importance character varying DEFAULT 'NORMAL'::character varying, par_sensitivity character varying DEFAULT 'NORMAL'::character varying, par_file_attachments text DEFAULT NULL::text, par_query text DEFAULT NULL::text, par_execute_query_database character varying DEFAULT NULL::character varying, par_attach_query_result_as_file smallint DEFAULT 0, par_query_attachment_filename character varying DEFAULT NULL::character varying, par_query_result_header smallint DEFAULT 1, par_query_result_width integer DEFAULT 256, par_query_result_separator character varying DEFAULT ' '::character varying, par_exclude_query_output smallint DEFAULT 0, par_append_query_error smallint DEFAULT 0, par_query_no_truncate smallint DEFAULT 0, par_query_result_no_padding smallint DEFAULT 0, OUT par_mailitem_id integer, par_from_address text DEFAULT NULL::text, par_reply_to text DEFAULT NULL::text, OUT returncode integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_profile_id INTEGER;
  var_rc INTEGER DEFAULT 0;
  var_mail_data TEXT;
  var_sent_result JSON;
  var_server_name VARCHAR(255);
BEGIN

  /* Get primary account if profile name is supplied */
  SELECT t.par_profileid, t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_profile_sp
    (
      NULL::integer,
      par_profile_name,
      0::SMALLINT,
      0::SMALLINT
    ) t
    INTO var_profile_id, var_rc;

  IF var_rc <> 0 THEN

    returncode := var_rc;
    RETURN;

  END IF;

  /* Attach results must be specified */
  IF par_attach_query_result_as_file IS NULL THEN

    RAISE 'Parameter "%" must be specified. This parameter cannot be NULL.', 'attach_query_result_as_file' USING ERRCODE := '50000';
    returncode := 2;
    RETURN;

  END IF;

  /* No output must be specified */
  IF par_exclude_query_output IS NULL THEN

    RAISE 'Parameter "%" must be specified. This parameter cannot be NULL.', 'exclude_query_output' USING ERRCODE := '50000';
    returncode := 3;
    RETURN;

  END IF;

  /* No header must be specified */
  IF par_query_result_header IS NULL THEN

    RAISE 'Parameter "%" must be specified. This parameter cannot be NULL.', 'query_result_header' USING ERRCODE := '50000';
    returncode := 4;
    RETURN;

  END IF;

  /* Check if query_result_separator is specifed */
  IF par_query_result_separator IS NULL OR LENGTH(par_query_result_separator) = 0 THEN

    RAISE 'Parameter "%" must be specified. This parameter cannot be NULL.', 'query_result_separator' USING ERRCODE := '50000';
    returncode := 5;
    RETURN;

  END IF;
  
  /* Echo error must be specified */
  IF par_append_query_error IS NULL THEN

    RAISE 'Parameter "%" must be specified. This parameter cannot be NULL.', 'append_query_error' USING ERRCODE := '50000';
    returncode := 6;
    RETURN;

  END IF;
  
  /* @body_format can be TEXT (default) or HTML */
  IF par_body_format IS NULL THEN

    par_body_format := 'TEXT';

  ELSE

    par_body_format := UPPER(par_body_format);

    IF par_body_format NOT IN ('TEXT', 'HTML') THEN

      RAISE 'Parameter mailformat does not support the value "%". The mail format must be TEXT or HTML.', par_body_format USING ERRCODE := '50000';
      returncode := 13;
      RETURN;

    END IF;
  END IF;
  
  /* Importance must be specified */
  IF par_importance IS NULL THEN

    RAISE 'Parameter "%" must be specified. This parameter cannot be NULL.', 'importance' USING ERRCODE := '50000';
    returncode := 15;
    RETURN;

  END IF;

  par_importance := UPPER(par_importance);
  
  /* Importance must be one of the predefined values */
  IF par_importance NOT IN ('LOW', 'NORMAL', 'HIGH') THEN

    RAISE 'Parameter importance does not support the value "%". Mail importance must be one of LOW, NORMAL, or HIGH.', par_importance USING ERRCODE := '50000';
    returncode := 16;
    RETURN;

  END IF;
  
  /* Sensitivity must be specified */
  IF par_sensitivity IS NULL 
  THEN
    RAISE 'Parameter "%" must be specified. This parameter cannot be NULL.', 'sensitivity' USING ERRCODE := '50000';
    returncode := 17;
    RETURN;
  END IF;
  par_sensitivity := UPPER(par_sensitivity);
  
  /* Sensitivity must be one of predefined values */
  IF par_sensitivity NOT IN ('NORMAL', 'PERSONAL', 'PRIVATE', 'CONFIDENTIAL') THEN

    RAISE 'Parameter sensitivity does not support the value "%". Mail sensitivity must be one of NORMAL, PERSONAL, PRIVATE, or CONFIDENTIAL.', par_sensitivity USING ERRCODE := '50000';
    returncode := 18;
    RETURN;

  END IF;
  
  /* Message body cannot be null. Atleast one of message, subject, query, */
  /* attachments must be specified. */
  IF (par_body IS NULL AND par_query IS NULL AND par_file_attachments IS NULL AND par_subject IS NULL)
    OR
    (
      (LENGTH(par_body) IS NULL OR LENGTH(par_body) <= 0) AND
      (LENGTH(par_query) IS NULL OR LENGTH(par_query) <= 0) AND
      (LENGTH(par_file_attachments) IS NULL OR LENGTH(par_file_attachments) <= 0) AND
      (LENGTH(par_subject) IS NULL OR LENGTH(par_subject) <= 0)
    ) THEN

    RAISE 'At least one of the following parameters must be specified. "%".', 'body, query, file_attachments, subject' USING ERRCODE := '50000';
    returncode := 19;
    RETURN;

  ELSE

    IF par_subject IS NULL OR LENGTH(par_subject) <= 0 THEN

      par_subject := 'Database Message';

    END IF;

  END IF;
  
  /* Recipients cannot be empty. Atleast one of the To, Cc, Bcc must be specified */
  IF (
    (par_recipients IS NULL AND par_copy_recipients IS NULL AND par_blind_copy_recipients IS NULL) OR
    (
      (LENGTH(par_recipients) IS NULL OR LENGTH(par_recipients) <= 0) AND
      (LENGTH(par_copy_recipients) IS NULL OR LENGTH(par_copy_recipients) <= 0) AND
      (LENGTH(par_blind_copy_recipients) IS NULL OR LENGTH(par_blind_copy_recipients) <= 0)
    )
  ) THEN

    RAISE 'At least one of the following parameters must be specified. "%".', 'recipients, copy_recipients, blind_copy_recipients' USING ERRCODE := '50000';
    returncode := 20;
    RETURN;

  END IF;

  --[sysmail_OutMailAttachmentEncodingMustBeValid] CHECK [attachment_encoding] IN ['UUENCODE', 'BINHEX', 'S/MIME', 'MIME']

  SELECT t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_addressparams_sp
    (
      par_address := par_recipients
    , par_parameter_name := 'par_recipients'
    ) t
    INTO var_rc;

  IF var_rc <> 0 THEN

    returncode := var_rc;
    RETURN;

  END IF;

  SELECT t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_addressparams_sp
    (
      par_address := par_copy_recipients
    , par_parameter_name := 'par_copy_recipients'
    ) t
    INTO var_rc;

  IF var_rc <> 0 THEN

    returncode := var_rc;
    RETURN;

  END IF;

  SELECT t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_addressparams_sp
    (
      par_address => par_blind_copy_recipients
    , par_parameter_name => 'par_blind_copy_recipients'
    ) t
    INTO var_rc;

  IF var_rc <> 0 THEN

    returncode := var_rc;
    RETURN;

  END IF;

  SELECT t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_addressparams_sp
    (
      par_address := par_reply_to
    , par_parameter_name := 'par_reply_to'
    ) t
    INTO var_rc;

  IF var_rc <> 0 THEN

    returncode := var_rc;
    RETURN;

  END IF;
  
  /* If query is not specified, attach results and no header cannot be true. */
  IF (par_query IS NULL OR LENGTH(par_query) <= 0) AND par_attach_query_result_as_file = 1 THEN

    RAISE 'Parameter [attach_query_result_as_file] cannot be 1 (true) when no value is specified for parameter [query]. A query must be specified to attach the results of the query.' USING ERRCODE := '50000';
    returncode := 21;
    RETURN;

  END IF;
  
  /* BEGIN TRAN @procName */
  /* SET @tranStartedBool = 1 */
  /* Store complete mail message for history/status purposes */
  
  INSERT 
    INTO aws_sqlserver_ext.sysmail_mailitems
    (
         profile_id
       , recipients
       , copy_recipients
       , blind_copy_recipients
       , subject
       , body
       , body_format
       , importance
       , sensitivity
       , file_attachments
       , attachment_encoding
       , query
       , execute_query_database
       , attach_query_result_as_file
       , query_result_header
       , query_result_width
       , query_result_separator
       , exclude_query_output
       , append_query_error
       , send_request_date
       , from_address
       , reply_to
    )
    VALUES
    (
         var_profile_id
       , par_recipients
       , par_copy_recipients
       , par_blind_copy_recipients
       , par_subject
       , par_body
       , par_body_format
       , par_importance
       , par_sensitivity
       , par_file_attachments
       , 'MIME'
       , par_query
       , par_execute_query_database
       , par_attach_query_result_as_file
       , par_query_result_header
       , par_query_result_width
       , par_query_result_separator
       , par_exclude_query_output
       , par_append_query_error
       , now()
       , par_from_address
       , par_reply_to
    );

  SELECT 0 /* @@ERROR, */
       , LASTVAL() /* SCOPE_IDENTITY() */
    INTO var_rc
       , par_mailitem_id;

  SELECT par_mail_data, par_server_name
  FROM aws_sqlserver_ext.sysmail_dbmail_json(par_mailitem_id)
  INTO var_mail_data, var_server_name;

  var_sent_result := aws_sqlserver_ext.awslambda_fn
  (
    var_server_name,
    var_mail_data::JSON
  );

  PERFORM aws_sqlserver_ext.sp_set_dbmail
  (
    par_mailitem_id,
    1::INTEGER,
    var_sent_result::TEXT
  );
  
  /* ExitProc: */
  /* Always delete query and attactment transfer records. */
  /* Note: Query results can also be returned in the sysmail_attachments_transfer table */
  /* DELETE sysmail_attachments_transfer WHERE uid = @temp_table_uid */
  /* DELETE sysmail_query_transfer WHERE uid = @temp_table_uid */
  /* Raise an error it the query execution fails */
  /* This will only be the case when @append_query_error is set to 0 (false) */
  /* IF( (@RetErrorMsg IS NOT NULL) AND (@exclude_query_output=0) ) */
  /* BEGIN */
  /* RAISERROR('Query execution failed: %s', -1, -1, @RetErrorMsg) */
  /* END */
  
  returncode := var_rc;
  RETURN;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_send_dbmail(par_profile_name character varying, par_recipients text, par_copy_recipients text, par_blind_copy_recipients text, par_subject character varying, par_body text, par_body_format character varying, par_importance character varying, par_sensitivity character varying, par_file_attachments text, par_query text, par_execute_query_database character varying, par_attach_query_result_as_file smallint, par_query_attachment_filename character varying, par_query_result_header smallint, par_query_result_width integer, par_query_result_separator character varying, par_exclude_query_output smallint, par_append_query_error smallint, par_query_no_truncate smallint, par_query_result_no_padding smallint, OUT par_mailitem_id integer, par_from_address text, par_reply_to text, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 402 (class 1255 OID 17107)
-- Name: sp_sequence_get_range(text, bigint); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_sequence_get_range(par_sequence_name text, par_range_size bigint, OUT par_range_first_value bigint, OUT par_range_last_value bigint, OUT par_range_cycle_count bigint, OUT par_sequence_increment bigint, OUT par_sequence_min_value bigint, OUT par_sequence_max_value bigint) RETURNS record
    LANGUAGE plpgsql
    AS $_$
declare 
  v_is_cycle character varying(3);
  v_current_value bigint;
begin  
  select s.minimum_value, s.maximum_value, s.increment, s.cycle_option 
    from information_schema.sequences s 
    where s.sequence_name = $1 
    into par_sequence_min_value, par_sequence_max_value, par_sequence_increment, v_is_cycle; 
    
  par_range_first_value := aws_sqlserver_ext.get_sequence_value(par_sequence_name);

  if par_range_first_value > par_sequence_min_value then 
    par_range_first_value := par_range_first_value + 1;
  end if;

  if v_is_cycle = 'YES' then 
    par_range_cycle_count := 0;
  end if;
    
  for i in 1..$2 loop
    select nextval(par_sequence_name) into v_current_value;
    if (v_is_cycle = 'YES') and (v_current_value = par_sequence_min_value) and (par_range_first_value <> v_current_value) then 
      par_range_cycle_count := par_range_cycle_count + 1;
    end if;  
  end loop;

  par_range_last_value := aws_sqlserver_ext.get_sequence_value(par_sequence_name);
end;
$_$;


ALTER FUNCTION aws_sqlserver_ext.sp_sequence_get_range(par_sequence_name text, par_range_size bigint, OUT par_range_first_value bigint, OUT par_range_last_value bigint, OUT par_range_cycle_count bigint, OUT par_sequence_increment bigint, OUT par_sequence_min_value bigint, OUT par_sequence_max_value bigint) OWNER TO postgres;

--
-- TOC entry 403 (class 1255 OID 17108)
-- Name: sp_set_dbmail(integer, integer, text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_set_dbmail(par_mail_id integer, par_sent_status integer, par_message text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  /* event_type
  3                           -- error
  2 AND @loggingLevelInt >= 2 -- warning with extended logging
  1 AND @loggingLevelInt >= 2 -- info with extended logging
  0 AND @loggingLevelInt >= 3 -- success with verbose logging
  */
  IF par_sent_status = 1 /* ok */ THEN

    UPDATE aws_sqlserver_ext.sysmail_mailitems
       SET sent_status = 2
         , sent_date = NOW()
     WHERE mailitem_id = par_mail_id;
     
     INSERT INTO aws_sqlserver_ext.sysmail_log (event_type, log_date, description, mailitem_id)
     VALUES (0, NOW(), par_message, par_mail_id);

  ELSE

    IF par_sent_status = 1 /* failed */ THEN

      UPDATE aws_sqlserver_ext.sysmail_mailitems
         SET sent_status = -1
           , sent_date = NOW()
       WHERE mailitem_id = par_mail_id;
       
      INSERT INTO aws_sqlserver_ext.sysmail_log (event_type, log_date, description, mailitem_id)
      VALUES (3, NOW(), par_message, par_mail_id);

    END IF;

  END IF;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_set_dbmail(par_mail_id integer, par_sent_status integer, par_message text) OWNER TO postgres;

--
-- TOC entry 404 (class 1255 OID 17109)
-- Name: sp_set_next_run(integer, integer); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_set_next_run(par_job_id integer, par_schedule_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_enabled INTEGER;
  var_freq_type INTEGER;
  var_freq_interval INTEGER;
  var_freq_subday_type INTEGER;
  var_freq_subday_interval INTEGER;
  var_freq_relative_interval INTEGER;
  var_freq_recurrence_factor INTEGER;
  var_active_start_date INTEGER;
  var_active_end_date INTEGER;
  var_active_start_time INTEGER;
  var_active_end_time INTEGER;

  var_next_run_date date;
  var_next_run_time time;
  var_next_run_dt timestamp;

  var_tmp_interval varchar(50);
  var_current_dt timestamp;
  var_next_dt timestamp;
BEGIN

  SELECT enabled
       , freq_type
       , freq_interval
       , freq_subday_type
       , freq_subday_interval
       , freq_relative_interval
       , freq_recurrence_factor
       , active_start_date
       , active_end_date
       , active_start_time
       , active_end_time
    FROM aws_sqlserver_ext.sysschedules
    INTO var_enabled
       , var_freq_type
       , var_freq_interval
       , var_freq_subday_type
       , var_freq_subday_interval
       , var_freq_relative_interval
       , var_freq_recurrence_factor
       , var_active_start_date
       , var_active_end_date
       , var_active_start_time
       , var_active_end_time
   WHERE schedule_id = par_schedule_id;

  SELECT next_run_date
       , next_run_time
    FROM aws_sqlserver_ext.sysjobschedules
    INTO var_next_run_date
       , var_next_run_time
   WHERE schedule_id = par_schedule_id
     AND job_id = par_job_id;

  /* if enabled = 0 return */
  CASE var_freq_type
    WHEN 1 THEN
      NULL;

    WHEN 4 THEN
    BEGIN
      /* NULL start date & time or now */
      /* start date + start time or now() */
      IF (var_next_run_date IS NULL OR var_next_run_time IS NULL)
      THEN
        var_current_dt := now()::timestamp;

        UPDATE aws_sqlserver_ext.sysjobschedules
           SET next_run_date = var_current_dt::date
             , next_run_time = var_current_dt::time
         WHERE schedule_id = par_schedule_id
           AND job_id = par_job_id;
        RETURN;
      ELSE
        var_tmp_interval :=
        CASE
          /* WHEN var_freq_subday_type = 1 THEN var_freq_subday_interval::character varying || ' At the specified time'  -- start time */
          WHEN var_freq_subday_type = 2 THEN var_freq_subday_interval::character varying || ' second'  /* ADD var_freq_subday_interval SECOND */
          WHEN var_freq_subday_type = 4 THEN var_freq_subday_interval::character varying || ' minute'  /* ADD var_freq_subday_interval MINUTE */
          WHEN var_freq_subday_type = 8 THEN var_freq_subday_interval::character varying || ' hour'    /* ADD var_freq_subday_interval HOUR */
          ELSE ''
        END;

        var_next_dt := (var_next_run_date::date + var_next_run_time::time)::timestamp + var_tmp_interval::INTERVAL;
        UPDATE aws_sqlserver_ext.sysjobschedules
           SET next_run_date = var_next_dt::date
             , next_run_time = var_next_dt::time
         WHERE schedule_id = par_schedule_id
           AND job_id = par_job_id;
        RETURN;
      END IF;
    END;

    WHEN 8 THEN
      NULL;

    WHEN 16 THEN
      NULL;

    WHEN 32 THEN
      NULL;

    WHEN 64 THEN
      NULL;

    WHEN 128 THEN
     NULL;
     
  END CASE;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_set_next_run(par_job_id integer, par_schedule_id integer) OWNER TO postgres;

--
-- TOC entry 407 (class 1255 OID 17113)
-- Name: sp_update_job(integer, character varying, character varying, smallint, character varying, integer, character varying, character varying, integer, integer, integer, integer, character varying, character varying, character varying, integer, smallint); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_update_job(par_job_id integer DEFAULT NULL::integer, par_job_name character varying DEFAULT NULL::character varying, par_new_name character varying DEFAULT NULL::character varying, par_enabled smallint DEFAULT NULL::smallint, par_description character varying DEFAULT NULL::character varying, par_start_step_id integer DEFAULT NULL::integer, par_category_name character varying DEFAULT NULL::character varying, par_owner_login_name character varying DEFAULT NULL::character varying, par_notify_level_eventlog integer DEFAULT NULL::integer, par_notify_level_email integer DEFAULT NULL::integer, par_notify_level_netsend integer DEFAULT NULL::integer, par_notify_level_page integer DEFAULT NULL::integer, par_notify_email_operator_name character varying DEFAULT NULL::character varying, par_notify_netsend_operator_name character varying DEFAULT NULL::character varying, par_notify_page_operator_name character varying DEFAULT NULL::character varying, par_delete_level integer DEFAULT NULL::integer, par_automatic_post smallint DEFAULT 1, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    var_retval INT;
    var_category_id INT;
    var_notify_email_operator_id INT;
    var_notify_netsend_operator_id INT;
    var_notify_page_operator_id INT;
    var_owner_sid CHAR(85);
    var_alert_id INT;
    var_cached_attribute_modified INT;
    var_is_sysadmin INT;
    var_current_owner VARCHAR(128);
    var_enable_only_used INT;
    var_x_new_name VARCHAR(128);
    var_x_enabled SMALLINT;
    var_x_description VARCHAR(512);
    var_x_start_step_id INT;
    var_x_category_name VARCHAR(128);
    var_x_category_id INT;
    var_x_owner_sid CHAR(85);
    var_x_notify_level_eventlog INT;
    var_x_notify_level_email INT;
    var_x_notify_level_netsend INT;
    var_x_notify_level_page INT;
    var_x_notify_email_operator_name VARCHAR(128);
    var_x_notify_netsnd_operator_name VARCHAR(128);
    var_x_notify_page_operator_name VARCHAR(128);
    var_x_delete_level INT;
    var_x_originating_server_id INT;
    var_x_master_server SMALLINT;
BEGIN
    /* Not updatable */
    /* Remove any leading/trailing spaces from parameters (except @owner_login_name) */
    SELECT
        LTRIM(RTRIM(par_job_name))
        INTO par_job_name;
    SELECT
        LTRIM(RTRIM(par_new_name))
        INTO par_new_name;
    SELECT
        LTRIM(RTRIM(par_description))
        INTO par_description;
    SELECT
        LTRIM(RTRIM(par_category_name))
        INTO par_category_name;
    SELECT
        LTRIM(RTRIM(par_notify_email_operator_name))
        INTO par_notify_email_operator_name;
    SELECT
        LTRIM(RTRIM(par_notify_netsend_operator_name))
        INTO par_notify_netsend_operator_name;
    SELECT
        LTRIM(RTRIM(par_notify_page_operator_name))
        INTO par_notify_page_operator_name
    /* Are we modifying an attribute which SQLServerAgent caches? */;

    IF ((par_new_name IS NOT NULL) OR (par_enabled IS NOT NULL) OR (par_start_step_id IS NOT NULL) OR (par_owner_login_name IS NOT NULL) OR (par_notify_level_eventlog IS NOT NULL) OR (par_notify_level_email IS NOT NULL) OR (par_notify_level_netsend IS NOT NULL) OR (par_notify_level_page IS NOT NULL) OR (par_notify_email_operator_name IS NOT NULL) OR (par_notify_netsend_operator_name IS NOT NULL) OR (par_notify_page_operator_name IS NOT NULL) OR (par_delete_level IS NOT NULL)) THEN
        SELECT
            1
            INTO var_cached_attribute_modified;
    ELSE
        SELECT
            0
            INTO var_cached_attribute_modified;
    END IF
    /* Is @enable the only parameter used beside jobname and jobid? */;

    IF ((par_enabled IS NOT NULL) AND (par_new_name IS NULL) AND (par_description IS NULL) AND (par_start_step_id IS NULL) AND (par_category_name IS NULL) AND (par_owner_login_name IS NULL) AND (par_notify_level_eventlog IS NULL) AND (par_notify_level_email IS NULL) AND (par_notify_level_netsend IS NULL) AND (par_notify_level_page IS NULL) AND (par_notify_email_operator_name IS NULL) AND (par_notify_netsend_operator_name IS NULL) AND (par_notify_page_operator_name IS NULL) AND (par_delete_level IS NULL)) THEN
        SELECT
            1
            INTO var_enable_only_used;
    ELSE
        SELECT
            0
            INTO var_enable_only_used;
    END IF;

    IF (par_new_name = '') THEN
        SELECT
            NULL
            INTO par_new_name;
    END IF
    /* Fill out the values for all non-supplied parameters from the existing values */;

    IF (par_new_name IS NULL) THEN
        SELECT
            var_x_new_name
            INTO par_new_name;
    END IF;

    IF (par_enabled IS NULL) THEN
        SELECT
            var_x_enabled
            INTO par_enabled;
    END IF;

    IF (par_description IS NULL) THEN
        SELECT
            var_x_description
            INTO par_description;
    END IF;

    IF (par_start_step_id IS NULL) THEN
        SELECT
            var_x_start_step_id
            INTO par_start_step_id;
    END IF;

    IF (par_category_name IS NULL) THEN
        SELECT
            var_x_category_name
            INTO par_category_name;
    END IF;

    IF (var_owner_sid IS NULL) THEN
        SELECT
            var_x_owner_sid
            INTO var_owner_sid;
    END IF;

    IF (par_notify_level_eventlog IS NULL) THEN
        SELECT
            var_x_notify_level_eventlog
            INTO par_notify_level_eventlog;
    END IF;

    IF (par_notify_level_email IS NULL) THEN
        SELECT
            var_x_notify_level_email
            INTO par_notify_level_email;
    END IF;

    IF (par_notify_level_netsend IS NULL) THEN
        SELECT
            var_x_notify_level_netsend
            INTO par_notify_level_netsend;
    END IF;

    IF (par_notify_level_page IS NULL) THEN
        SELECT
            var_x_notify_level_page
            INTO par_notify_level_page;
    END IF;

    IF (par_notify_email_operator_name IS NULL) THEN
        SELECT
            var_x_notify_email_operator_name
            INTO par_notify_email_operator_name;
    END IF;

    IF (par_notify_netsend_operator_name IS NULL) THEN
        SELECT
            var_x_notify_netsnd_operator_name
            INTO par_notify_netsend_operator_name;
    END IF;

    IF (par_notify_page_operator_name IS NULL) THEN
        SELECT
            var_x_notify_page_operator_name
            INTO par_notify_page_operator_name;
    END IF;

    IF (par_delete_level IS NULL) THEN
        SELECT
            var_x_delete_level
            INTO par_delete_level;
    END IF
    /* Turn [nullable] empty string parameters into NULLs */;

    IF (LOWER(par_description) = LOWER('')) THEN
        SELECT
            NULL
            INTO par_description;
    END IF;

    IF (par_category_name = '') THEN
        SELECT
            NULL
            INTO par_category_name;
    END IF;

    IF (par_notify_email_operator_name = '') THEN
        SELECT
            NULL
            INTO par_notify_email_operator_name;
    END IF;

    IF (par_notify_netsend_operator_name = '') THEN
        SELECT
            NULL
            INTO par_notify_netsend_operator_name;
    END IF;

    IF (par_notify_page_operator_name = '') THEN
        SELECT
            NULL
            INTO par_notify_page_operator_name;
    END IF
    /* Check new values */;
    SELECT
        t.par_owner_sid, t.par_notify_level_email, t.par_notify_level_netsend, t.par_notify_level_page, 
        t.par_category_id, t.par_notify_email_operator_id, t.par_notify_netsend_operator_id, t.par_notify_page_operator_id, t.par_originating_server, t.ReturnCode
        FROM aws_sqlserver_ext.sp_verify_job(par_job_id, par_new_name, par_enabled, par_start_step_id, par_category_name, var_owner_sid, par_notify_level_eventlog, par_notify_level_email, par_notify_level_netsend, par_notify_level_page, par_notify_email_operator_name, par_notify_netsend_operator_name, par_notify_page_operator_name, par_delete_level, var_category_id, var_notify_email_operator_id, var_notify_netsend_operator_id, var_notify_page_operator_id, NULL) t
        INTO var_owner_sid, par_notify_level_email, par_notify_level_netsend, par_notify_level_page, var_category_id, var_notify_email_operator_id, var_notify_netsend_operator_id, var_notify_page_operator_id, var_retval;

    IF (var_retval <> 0) THEN
        ReturnCode := (1);
        RETURN;
    END IF
    /* Failure */
    /* BEGIN TRANSACTION */
    /* If the job is being re-assigned, modify sysjobsteps.database_user_name as necessary */;

    IF (par_owner_login_name IS NOT NULL) THEN
        IF (EXISTS (SELECT
            1
            FROM aws_sqlserver_ext.sysjobsteps
            WHERE (job_id = par_job_id) AND (LOWER(subsystem) = LOWER('TSQL')))) THEN
            /* The job is being re-assigned to an non-SA */
            UPDATE aws_sqlserver_ext.sysjobsteps
            SET database_user_name = NULL
                WHERE (job_id = par_job_id) AND (LOWER(subsystem) = LOWER('TSQL'));
        END IF;
    END IF;
    UPDATE aws_sqlserver_ext.sysjobs
    SET name = par_new_name, enabled = par_enabled, description = par_description, start_step_id = par_start_step_id, category_id = var_category_id
    /* Returned from sp_verify_job */, owner_sid = var_owner_sid, notify_level_eventlog = par_notify_level_eventlog, notify_level_email = par_notify_level_email, notify_level_netsend = par_notify_level_netsend, notify_level_page = par_notify_level_page, notify_email_operator_id = var_notify_email_operator_id
    /* Returned from sp_verify_job */, notify_netsend_operator_id = var_notify_netsend_operator_id
    /* Returned from sp_verify_job */, notify_page_operator_id = var_notify_page_operator_id
    /* Returned from sp_verify_job */, delete_level = par_delete_level, version_number = version_number + 1
    /* ,  -- Update the job's version */
    /* date_modified              = GETDATE()            -- Update the job's last-modified information */
        WHERE (job_id = par_job_id);
    SELECT
        0
        INTO var_retval
    /* @@error */
    /* COMMIT TRANSACTION */;
    ReturnCode := (var_retval);
    RETURN
    /* 0 means success */;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_update_job(par_job_id integer, par_job_name character varying, par_new_name character varying, par_enabled smallint, par_description character varying, par_start_step_id integer, par_category_name character varying, par_owner_login_name character varying, par_notify_level_eventlog integer, par_notify_level_email integer, par_notify_level_netsend integer, par_notify_level_page integer, par_notify_email_operator_name character varying, par_notify_netsend_operator_name character varying, par_notify_page_operator_name character varying, par_delete_level integer, par_automatic_post smallint, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 406 (class 1255 OID 17111)
-- Name: sp_update_jobschedule(integer, character varying, character varying, character varying, smallint, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, smallint); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_update_jobschedule(par_job_id integer DEFAULT NULL::integer, par_job_name character varying DEFAULT NULL::character varying, par_name character varying DEFAULT NULL::character varying, par_new_name character varying DEFAULT NULL::character varying, par_enabled smallint DEFAULT NULL::smallint, par_freq_type integer DEFAULT NULL::integer, par_freq_interval integer DEFAULT NULL::integer, par_freq_subday_type integer DEFAULT NULL::integer, par_freq_subday_interval integer DEFAULT NULL::integer, par_freq_relative_interval integer DEFAULT NULL::integer, par_freq_recurrence_factor integer DEFAULT NULL::integer, par_active_start_date integer DEFAULT NULL::integer, par_active_end_date integer DEFAULT NULL::integer, par_active_start_time integer DEFAULT NULL::integer, par_active_end_time integer DEFAULT NULL::integer, par_automatic_post smallint DEFAULT 1, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    var_retval INT;
    var_sched_count INT;
    var_schedule_id INT;
    var_job_owner_sid CHAR(85);
    var_enable_only_used INT;
    var_x_name VARCHAR(128);
    var_x_enabled SMALLINT;
    var_x_freq_type INT;
    var_x_freq_interval INT;
    var_x_freq_subday_type INT;
    var_x_freq_subday_interval INT;
    var_x_freq_relative_interval INT;
    var_x_freq_recurrence_factor INT;
    var_x_active_start_date INT;
    var_x_active_end_date INT;
    var_x_active_start_time INT;
    var_x_active_end_time INT;
    var_owner_sid CHAR(85);
BEGIN
    /* Remove any leading/trailing spaces from parameters */
    SELECT
        LTRIM(RTRIM(par_name))
        INTO par_name;
    SELECT
        LTRIM(RTRIM(par_new_name))
        INTO par_new_name
    /* Turn [nullable] empty string parameters into NULLs */;

    IF (par_new_name = '') THEN
        SELECT
            NULL
            INTO par_new_name;
    END IF
    /* Check that we can uniquely identify the job */;
    SELECT
        t.par_job_name, t.par_job_id, t.par_owner_sid, t.ReturnCode
        FROM aws_sqlserver_ext.sp_verify_job_identifiers('@job_name', '@job_id', par_job_name, par_job_id, 'TEST', var_job_owner_sid) t
        INTO par_job_name, par_job_id, var_job_owner_sid, var_retval;

    IF (var_retval <> 0) THEN
        ReturnCode := (1);
        RETURN;
    END IF
    /* Failure */
    /* Is @enable the only parameter used beside jobname and jobid? */;

    IF ((par_enabled IS NOT NULL) AND (par_name IS NULL) AND (par_new_name IS NULL) AND (par_freq_type IS NULL) AND (par_freq_interval IS NULL) AND (par_freq_subday_type IS NULL) AND (par_freq_subday_interval IS NULL) AND (par_freq_relative_interval IS NULL) AND (par_freq_recurrence_factor IS NULL) AND (par_active_start_date IS NULL) AND (par_active_end_date IS NULL) AND (par_active_start_time IS NULL) AND (par_active_end_time IS NULL)) THEN
        SELECT
            1
            INTO var_enable_only_used;
    ELSE
        SELECT
            0
            INTO var_enable_only_used;
    END IF;
    
    IF (par_new_name IS NULL) THEN
        SELECT
            var_x_name
            INTO par_new_name;
    END IF;

    IF (par_enabled IS NULL) THEN
        SELECT
            var_x_enabled
            INTO par_enabled;
    END IF;

    IF (par_freq_type IS NULL) THEN
        SELECT
            var_x_freq_type
            INTO par_freq_type;
    END IF;

    IF (par_freq_interval IS NULL) THEN
        SELECT
            var_x_freq_interval
            INTO par_freq_interval;
    END IF;

    IF (par_freq_subday_type IS NULL) THEN
        SELECT
            var_x_freq_subday_type
            INTO par_freq_subday_type;
    END IF;

    IF (par_freq_subday_interval IS NULL) THEN
        SELECT
            var_x_freq_subday_interval
            INTO par_freq_subday_interval;
    END IF;

    IF (par_freq_relative_interval IS NULL) THEN
        SELECT
            var_x_freq_relative_interval
            INTO par_freq_relative_interval;
    END IF;

    IF (par_freq_recurrence_factor IS NULL) THEN
        SELECT
            var_x_freq_recurrence_factor
            INTO par_freq_recurrence_factor;
    END IF;

    IF (par_active_start_date IS NULL) THEN
        SELECT
            var_x_active_start_date
            INTO par_active_start_date;
    END IF;

    IF (par_active_end_date IS NULL) THEN
        SELECT
            var_x_active_end_date
            INTO par_active_end_date;
    END IF;

    IF (par_active_start_time IS NULL) THEN
        SELECT
            var_x_active_start_time
            INTO par_active_start_time;
    END IF;

    IF (par_active_end_time IS NULL) THEN
        SELECT
            var_x_active_end_time
            INTO par_active_end_time;
    END IF
    /* Check schedule (frequency and owner) parameters */;
    SELECT
        t.par_freq_interval, t.par_freq_subday_type, t.par_freq_subday_interval, t.par_freq_relative_interval, t.par_freq_recurrence_factor, t.par_active_start_date, t.par_active_start_time, 
        t.par_active_end_date, t.par_active_end_time, t.ReturnCode
        FROM aws_sqlserver_ext.sp_verify_schedule(var_schedule_id
        /* @schedule_id */, par_new_name
        /* @name */, par_enabled
        /* @enabled */, par_freq_type
        /* @freq_type */, par_freq_interval
        /* @freq_interval */, par_freq_subday_type
        /* @freq_subday_type */, par_freq_subday_interval
        /* @freq_subday_interval */, par_freq_relative_interval
        /* @freq_relative_interval */, par_freq_recurrence_factor
        /* @freq_recurrence_factor */, par_active_start_date
        /* @active_start_date */, par_active_start_time
        /* @active_start_time */, par_active_end_date
        /* @active_end_date */, par_active_end_time
        /* @active_end_time */, var_owner_sid) t
        INTO par_freq_interval, par_freq_subday_type, par_freq_subday_interval, par_freq_relative_interval, par_freq_recurrence_factor, par_active_start_date, par_active_start_time, par_active_end_date, par_active_end_time, var_retval /* @owner_sid */;

    IF (var_retval <> 0) THEN
        ReturnCode := (1);
        RETURN;
    END IF
    /* Failure */
    /* Update the JobSchedule */;
    UPDATE aws_sqlserver_ext.sysschedules
    SET name = par_new_name, enabled = par_enabled, freq_type = par_freq_type, freq_interval = par_freq_interval, freq_subday_type = par_freq_subday_type, freq_subday_interval = par_freq_subday_interval, freq_relative_interval = par_freq_relative_interval, freq_recurrence_factor = par_freq_recurrence_factor, active_start_date = par_active_start_date, active_end_date = par_active_end_date, active_start_time = par_active_start_time, active_end_time = par_active_end_time
    /* date_modified          = GETDATE(), */, version_number = version_number + 1
        WHERE (schedule_id = var_schedule_id);
    SELECT
        0
        INTO var_retval
    /* @@error */
    /* Update the job's version/last-modified information */;
    UPDATE aws_sqlserver_ext.sysjobs
    SET version_number = version_number + 1
    /* date_modified = GETDATE() */
        WHERE (job_id = par_job_id);
    ReturnCode := (var_retval);
    RETURN
    /* 0 means success */;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_update_jobschedule(par_job_id integer, par_job_name character varying, par_name character varying, par_new_name character varying, par_enabled smallint, par_freq_type integer, par_freq_interval integer, par_freq_subday_type integer, par_freq_subday_interval integer, par_freq_relative_interval integer, par_freq_recurrence_factor integer, par_active_start_date integer, par_active_end_date integer, par_active_start_time integer, par_active_end_time integer, par_automatic_post smallint, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 408 (class 1255 OID 17115)
-- Name: sp_update_jobstep(integer, character varying, integer, character varying, character varying, text, text, integer, smallint, integer, smallint, integer, character varying, character varying, character varying, integer, integer, integer, character varying, integer, integer, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_update_jobstep(par_job_id integer DEFAULT NULL::integer, par_job_name character varying DEFAULT NULL::character varying, par_step_id integer DEFAULT NULL::integer, par_step_name character varying DEFAULT NULL::character varying, par_subsystem character varying DEFAULT NULL::character varying, par_command text DEFAULT NULL::text, par_additional_parameters text DEFAULT NULL::text, par_cmdexec_success_code integer DEFAULT NULL::integer, par_on_success_action smallint DEFAULT NULL::smallint, par_on_success_step_id integer DEFAULT NULL::integer, par_on_fail_action smallint DEFAULT NULL::smallint, par_on_fail_step_id integer DEFAULT NULL::integer, par_server character varying DEFAULT NULL::character varying, par_database_name character varying DEFAULT NULL::character varying, par_database_user_name character varying DEFAULT NULL::character varying, par_retry_attempts integer DEFAULT NULL::integer, par_retry_interval integer DEFAULT NULL::integer, par_os_run_priority integer DEFAULT NULL::integer, par_output_file_name character varying DEFAULT NULL::character varying, par_flags integer DEFAULT NULL::integer, par_proxy_id integer DEFAULT NULL::integer, par_proxy_name character varying DEFAULT NULL::character varying, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    var_retval INT;
    var_os_run_priority_code INT;
    var_step_id_as_char VARCHAR(10);
    var_new_step_name VARCHAR(128);
    var_x_step_name VARCHAR(128);
    var_x_subsystem VARCHAR(40);
    var_x_command TEXT;
    var_x_flags INT;
    var_x_cmdexec_success_code INT;
    var_x_on_success_action SMALLINT;
    var_x_on_success_step_id INT;
    var_x_on_fail_action SMALLINT;
    var_x_on_fail_step_id INT;
    var_x_server VARCHAR(128);
    var_x_database_name VARCHAR(128);
    var_x_database_user_name VARCHAR(128);
    var_x_retry_attempts INT;
    var_x_retry_interval INT;
    var_x_os_run_priority INT;
    var_x_output_file_name VARCHAR(200);
    var_x_proxy_id INT;
    var_x_last_run_outcome SMALLINT;
    var_x_last_run_duration INT;
    var_x_last_run_retries INT;
    var_x_last_run_date INT;
    var_x_last_run_time INT;
    var_new_proxy_id INT;
    var_subsystem_id INT;
    var_auto_proxy_name VARCHAR(128);
    var_job_owner_sid CHAR(85);
    var_step_uid CHAR(85);
BEGIN
    SELECT NULL INTO var_new_proxy_id;
    /* Remove any leading/trailing spaces from parameters */
    SELECT LTRIM(RTRIM(par_step_name)) INTO par_step_name;
    SELECT LTRIM(RTRIM(par_subsystem)) INTO par_subsystem;
    SELECT LTRIM(RTRIM(par_command)) INTO par_command;
    SELECT LTRIM(RTRIM(par_server)) INTO par_server;
    SELECT LTRIM(RTRIM(par_database_name)) INTO par_database_name;
    SELECT LTRIM(RTRIM(par_database_user_name)) INTO par_database_user_name;
    SELECT LTRIM(RTRIM(par_output_file_name)) INTO par_output_file_name;
    SELECT LTRIM(RTRIM(par_proxy_name)) INTO par_proxy_name;
    /* Make sure Dts is translated into new subsystem's name SSIS */
    /* IF (@subsystem IS NOT NULL AND UPPER(@subsystem collate SQL_Latin1_General_CP1_CS_AS) = N'DTS') */
    /* BEGIN */
    /* SET @subsystem = N'SSIS' */
    /* END */
    SELECT
        t.par_job_name, t.par_job_id, t.par_owner_sid, t.ReturnCode
        FROM aws_sqlserver_ext.sp_verify_job_identifiers('@job_name'
        /* @name_of_name_parameter */, '@job_id'
        /* @name_of_id_parameter */, par_job_name
        /* @job_name */, par_job_id
        /* @job_id */, 'TEST'
        /* @sqlagent_starting_test */, var_job_owner_sid)
        INTO par_job_name, par_job_id, var_job_owner_sid, var_retval
    /* @owner_sid */;

    IF (var_retval <> 0) THEN
        ReturnCode := (1);
        RETURN;
    END IF;
    /* Failure */
    /* Check that the step exists */

    IF (NOT EXISTS (SELECT
        *
        FROM aws_sqlserver_ext.sysjobsteps
        WHERE (job_id = par_job_id) AND (step_id = par_step_id))) THEN
        SELECT
            CAST (par_step_id AS VARCHAR(10))
            INTO var_step_id_as_char;
        RAISE 'Error %, severity %, state % was raised. Message: %. Argument: %. Argument: %', '50000', 0, 0, 'The specified %s ("%s") does not exist.', '@step_id', var_step_id_as_char USING ERRCODE := '50000';
        ReturnCode := (1);
        RETURN;
        /* Failure */
    END IF;
    /* Set the x_ (existing) variables */
    SELECT
        step_name, subsystem, command, flags, cmdexec_success_code, on_success_action, on_success_step_id, on_fail_action, on_fail_step_id, server, database_name, database_user_name, retry_attempts, retry_interval, os_run_priority, output_file_name, proxy_id, last_run_outcome, last_run_duration, last_run_retries, last_run_date, last_run_time
        INTO var_x_step_name, var_x_subsystem, var_x_command, var_x_flags, var_x_cmdexec_success_code, var_x_on_success_action, var_x_on_success_step_id, var_x_on_fail_action, var_x_on_fail_step_id, var_x_server, var_x_database_name, var_x_database_user_name, var_x_retry_attempts, var_x_retry_interval, var_x_os_run_priority, var_x_output_file_name, var_x_proxy_id, var_x_last_run_outcome, var_x_last_run_duration, var_x_last_run_retries, var_x_last_run_date, var_x_last_run_time
        FROM aws_sqlserver_ext.sysjobsteps
        WHERE (job_id = par_job_id) AND (step_id = par_step_id);

    IF ((par_step_name IS NOT NULL) AND (par_step_name <> var_x_step_name)) THEN
        SELECT
            par_step_name
            INTO var_new_step_name;
    END IF;
    /* Fill out the values for all non-supplied parameters from the existing values */

    IF (par_step_name IS NULL) THEN
        SELECT var_x_step_name INTO par_step_name;
    END IF;

    IF (par_subsystem IS NULL) THEN
        SELECT var_x_subsystem INTO par_subsystem;
    END IF;

    IF (par_command IS NULL) THEN
        SELECT var_x_command INTO par_command;
    END IF;

    IF (par_flags IS NULL) THEN
        SELECT var_x_flags INTO par_flags;
    END IF;

    IF (par_cmdexec_success_code IS NULL) THEN
        SELECT var_x_cmdexec_success_code INTO par_cmdexec_success_code;
    END IF;

    IF (par_on_success_action IS NULL) THEN
        SELECT var_x_on_success_action INTO par_on_success_action;
    END IF;

    IF (par_on_success_step_id IS NULL) THEN
        SELECT var_x_on_success_step_id INTO par_on_success_step_id;
    END IF;

    IF (par_on_fail_action IS NULL) THEN
        SELECT var_x_on_fail_action INTO par_on_fail_action;
    END IF;

    IF (par_on_fail_step_id IS NULL) THEN
        SELECT var_x_on_fail_step_id INTO par_on_fail_step_id;
    END IF;

    IF (par_server IS NULL) THEN
        SELECT var_x_server INTO par_server;
    END IF;

    IF (par_database_name IS NULL) THEN
        SELECT var_x_database_name INTO par_database_name;
    END IF;

    IF (par_database_user_name IS NULL) THEN
        SELECT var_x_database_user_name INTO par_database_user_name;
    END IF;

    IF (par_retry_attempts IS NULL) THEN
        SELECT var_x_retry_attempts INTO par_retry_attempts;
    END IF;

    IF (par_retry_interval IS NULL) THEN
        SELECT var_x_retry_interval INTO par_retry_interval;
    END IF;

    IF (par_os_run_priority IS NULL) THEN
        SELECT var_x_os_run_priority INTO par_os_run_priority;
    END IF;

    IF (par_output_file_name IS NULL) THEN
        SELECT var_x_output_file_name INTO par_output_file_name;
    END IF;

    IF (par_proxy_id IS NULL) THEN
        SELECT var_x_proxy_id INTO var_new_proxy_id;
    END IF;
    /* if an empty proxy_name is supplied the proxy is removed */

    IF par_proxy_name = '' THEN
        SELECT NULL INTO var_new_proxy_id;
    END IF;
    /* Turn [nullable] empty string parameters into NULLs */

    IF (LOWER(par_command) = LOWER('')) THEN
        SELECT NULL INTO par_command;
    END IF;

    IF (par_server = '') THEN
        SELECT NULL INTO par_server;
    END IF;

    IF (par_database_name = '') THEN
        SELECT NULL INTO par_database_name;
    END IF;

    IF (par_database_user_name = '') THEN
        SELECT NULL INTO par_database_user_name;
    END IF;

    IF (LOWER(par_output_file_name) = LOWER('')) THEN
        SELECT NULL INTO par_output_file_name;
    END IF
    /* Check new values */;
    SELECT
        t.par_database_name, t.par_database_user_name, t.ReturnCode
        FROM aws_sqlserver_ext.sp_verify_jobstep(par_job_id, par_step_id, var_new_step_name, par_subsystem, par_command, par_server, par_on_success_action, par_on_success_step_id, par_on_fail_action, par_on_fail_step_id, par_os_run_priority, par_database_name, par_database_user_name, par_flags, par_output_file_name, var_new_proxy_id) t
        INTO par_database_name, par_database_user_name, var_retval;

    IF (var_retval <> 0) THEN
        ReturnCode := (1);
        RETURN;
    END IF
    /* Failure */
    /* Update the job's version/last-modified information */;
    UPDATE aws_sqlserver_ext.sysjobs
    SET version_number = version_number + 1
    /* date_modified = GETDATE() */
        WHERE (job_id = par_job_id)
    /* Update the step */;
    UPDATE aws_sqlserver_ext.sysjobsteps
    SET step_name = par_step_name, subsystem = par_subsystem, command = par_command, flags = par_flags, additional_parameters = par_additional_parameters, cmdexec_success_code = par_cmdexec_success_code, on_success_action = par_on_success_action, on_success_step_id = par_on_success_step_id, on_fail_action = par_on_fail_action, on_fail_step_id = par_on_fail_step_id, server = par_server, database_name = par_database_name, database_user_name = par_database_user_name, retry_attempts = par_retry_attempts, retry_interval = par_retry_interval, os_run_priority = par_os_run_priority, output_file_name = par_output_file_name, last_run_outcome = var_x_last_run_outcome, last_run_duration = var_x_last_run_duration, last_run_retries = var_x_last_run_retries, last_run_date = var_x_last_run_date, last_run_time = var_x_last_run_time, proxy_id = var_new_proxy_id
        WHERE (job_id = par_job_id) AND (step_id = par_step_id);

    SELECT step_uid
    FROM aws_sqlserver_ext.sysjobsteps
    WHERE job_id = par_job_id AND step_id = par_step_id
    INTO var_step_uid;

    -- PERFORM aws_sqlserver_ext.sp_jobstep_create_proc (var_step_uid);

    ReturnCode := (0);
    RETURN
    /* Success */;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_update_jobstep(par_job_id integer, par_job_name character varying, par_step_id integer, par_step_name character varying, par_subsystem character varying, par_command text, par_additional_parameters text, par_cmdexec_success_code integer, par_on_success_action smallint, par_on_success_step_id integer, par_on_fail_action smallint, par_on_fail_step_id integer, par_server character varying, par_database_name character varying, par_database_user_name character varying, par_retry_attempts integer, par_retry_interval integer, par_os_run_priority integer, par_output_file_name character varying, par_flags integer, par_proxy_id integer, par_proxy_name character varying, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 409 (class 1255 OID 17117)
-- Name: sp_update_schedule(integer, character varying, character varying, smallint, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, character varying, smallint); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_update_schedule(par_schedule_id integer DEFAULT NULL::integer, par_name character varying DEFAULT NULL::character varying, par_new_name character varying DEFAULT NULL::character varying, par_enabled smallint DEFAULT NULL::smallint, par_freq_type integer DEFAULT NULL::integer, par_freq_interval integer DEFAULT NULL::integer, par_freq_subday_type integer DEFAULT NULL::integer, par_freq_subday_interval integer DEFAULT NULL::integer, par_freq_relative_interval integer DEFAULT NULL::integer, par_freq_recurrence_factor integer DEFAULT NULL::integer, par_active_start_date integer DEFAULT NULL::integer, par_active_end_date integer DEFAULT NULL::integer, par_active_start_time integer DEFAULT NULL::integer, par_active_end_time integer DEFAULT NULL::integer, par_owner_login_name character varying DEFAULT NULL::character varying, par_automatic_post smallint DEFAULT 1, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    var_retval INT;
    var_owner_sid CHAR(85);
    var_cur_owner_sid CHAR(85);
    var_x_name VARCHAR(128);
    var_enable_only_used INT;
    var_x_enabled SMALLINT;
    var_x_freq_type INT;
    var_x_freq_interval INT;
    var_x_freq_subday_type INT;
    var_x_freq_subday_interval INT;
    var_x_freq_relative_interval INT;
    var_x_freq_recurrence_factor INT;
    var_x_active_start_date INT;
    var_x_active_end_date INT;
    var_x_active_start_time INT;
    var_x_active_end_time INT;
    var_schedule_uid CHAR(38);
BEGIN
    /* Remove any leading/trailing spaces from parameters */
    SELECT
        LTRIM(RTRIM(par_name))
        INTO par_name;
    SELECT
        LTRIM(RTRIM(par_new_name))
        INTO par_new_name;
    SELECT
        LTRIM(RTRIM(par_owner_login_name))
        INTO par_owner_login_name
    /* Turn [nullable] empty string parameters into NULLs */;

    IF (par_new_name = '') THEN
        SELECT
            NULL
            INTO par_new_name;
    END IF
    /* Check that we can uniquely identify the schedule. This only returns a schedule that is visible to this user */;
    SELECT
        t.par_schedule_name, t.par_schedule_id, t.par_owner_sid, t.par_orig_server_id, t.ReturnCode
        FROM aws_sqlserver_ext.sp_verify_schedule_identifiers('@name'
        /* @name_of_name_parameter */, '@schedule_id'
        /* @name_of_id_parameter */, par_name
        /* @schedule_name */, par_schedule_id
        /* @schedule_id */, var_cur_owner_sid
        /* @owner_sid */, NULL
        /* @orig_server_id */, NULL) t
        INTO par_name, par_schedule_id, var_cur_owner_sid, var_retval
    /* @job_id_filter */;

    IF (var_retval <> 0) THEN
        ReturnCode := (1);
        RETURN;
    END IF
    /* Failure */
    /* Is @enable the only parameter used beside jobname and jobid? */;

    IF ((par_enabled IS NOT NULL) AND (par_new_name IS NULL) AND (par_freq_type IS NULL) AND (par_freq_interval IS NULL) AND (par_freq_subday_type IS NULL) AND (par_freq_subday_interval IS NULL) AND (par_freq_relative_interval IS NULL) AND (par_freq_recurrence_factor IS NULL) AND (par_active_start_date IS NULL) AND (par_active_end_date IS NULL) AND (par_active_start_time IS NULL) AND (par_active_end_time IS NULL) AND (par_owner_login_name IS NULL)) THEN
        SELECT
            1
            INTO var_enable_only_used;
    ELSE
        SELECT
            0
            INTO var_enable_only_used;
    END IF
    /* If the param @owner_login_name is null or doesn't get resolved by SUSER_SID() set it to the current owner of the schedule */;

    IF (var_owner_sid IS NULL) THEN
        SELECT
            var_cur_owner_sid
            INTO var_owner_sid;
    END IF
    /* Set the x_ (existing) variables */;
    SELECT
        name, enabled, freq_type, freq_interval, freq_subday_type, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_date, active_end_date, active_start_time, active_end_time
        INTO var_x_name, var_x_enabled, var_x_freq_type, var_x_freq_interval, var_x_freq_subday_type, var_x_freq_subday_interval, var_x_freq_relative_interval, var_x_freq_recurrence_factor, var_x_active_start_date, var_x_active_end_date, var_x_active_start_time, var_x_active_end_time
        FROM aws_sqlserver_ext.sysschedules
        WHERE (schedule_id = par_schedule_id)
    /* Fill out the values for all non-supplied parameters from the existing values */;

    IF (par_new_name IS NULL) THEN
        SELECT
            var_x_name
            INTO par_new_name;
    END IF;

    IF (par_enabled IS NULL) THEN
        SELECT
            var_x_enabled
            INTO par_enabled;
    END IF;

    IF (par_freq_type IS NULL) THEN
        SELECT
            var_x_freq_type
            INTO par_freq_type;
    END IF;

    IF (par_freq_interval IS NULL) THEN
        SELECT
            var_x_freq_interval
            INTO par_freq_interval;
    END IF;

    IF (par_freq_subday_type IS NULL) THEN
        SELECT
            var_x_freq_subday_type
            INTO par_freq_subday_type;
    END IF;

    IF (par_freq_subday_interval IS NULL) THEN
        SELECT
            var_x_freq_subday_interval
            INTO par_freq_subday_interval;
    END IF;

    IF (par_freq_relative_interval IS NULL) THEN
        SELECT
            var_x_freq_relative_interval
            INTO par_freq_relative_interval;
    END IF;

    IF (par_freq_recurrence_factor IS NULL) THEN
        SELECT
            var_x_freq_recurrence_factor
            INTO par_freq_recurrence_factor;
    END IF;

    IF (par_active_start_date IS NULL) THEN
        SELECT
            var_x_active_start_date
            INTO par_active_start_date;
    END IF;

    IF (par_active_end_date IS NULL) THEN
        SELECT
            var_x_active_end_date
            INTO par_active_end_date;
    END IF;

    IF (par_active_start_time IS NULL) THEN
        SELECT
            var_x_active_start_time
            INTO par_active_start_time;
    END IF;

    IF (par_active_end_time IS NULL) THEN
        SELECT
            var_x_active_end_time
            INTO par_active_end_time;
    END IF
    /* Check schedule (frequency and owner) parameters */;
    SELECT
        t.par_freq_interval, t.par_freq_subday_type, t.par_freq_subday_interval, t.par_freq_relative_interval, t.par_freq_recurrence_factor, t.par_active_start_date, 
        t.par_active_start_time, t.par_active_end_date, t.par_active_end_time, t.ReturnCode
        FROM aws_sqlserver_ext.sp_verify_schedule(par_schedule_id
        /* @schedule_id */, par_new_name
        /* @name */, par_enabled
        /* @enabled */, par_freq_type
        /* @freq_type */, par_freq_interval
        /* @freq_interval */, par_freq_subday_type
        /* @freq_subday_type */, par_freq_subday_interval
        /* @freq_subday_interval */, par_freq_relative_interval
        /* @freq_relative_interval */, par_freq_recurrence_factor
        /* @freq_recurrence_factor */, par_active_start_date
        /* @active_start_date */, par_active_start_time
        /* @active_start_time */, par_active_end_date
        /* @active_end_date */, par_active_end_time
        /* @active_end_time */, var_owner_sid) t
        INTO par_freq_interval, par_freq_subday_type, par_freq_subday_interval, par_freq_relative_interval, par_freq_recurrence_factor, par_active_start_date, par_active_start_time, par_active_end_date, par_active_end_time, var_retval /* @owner_sid */;

    IF (var_retval <> 0) THEN
        ReturnCode := (1);
        RETURN;
    END IF
    /* Failure */
    /* Update the sysschedules table */;
    UPDATE aws_sqlserver_ext.sysschedules
    SET name = par_new_name, owner_sid = var_owner_sid, enabled = par_enabled, freq_type = par_freq_type, freq_interval = par_freq_interval, freq_subday_type = par_freq_subday_type, freq_subday_interval = par_freq_subday_interval, freq_relative_interval = par_freq_relative_interval, freq_recurrence_factor = par_freq_recurrence_factor, active_start_date = par_active_start_date, active_end_date = par_active_end_date, active_start_time = par_active_start_time, active_end_time = par_active_end_time
    /* date_modified          = GETDATE(), */, version_number = version_number + 1
        WHERE (schedule_id = par_schedule_id);
    SELECT
        0
        INTO var_retval;
    
    ReturnCode := (var_retval);
    RETURN
    /* 0 means success */;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_update_schedule(par_schedule_id integer, par_name character varying, par_new_name character varying, par_enabled smallint, par_freq_type integer, par_freq_interval integer, par_freq_subday_type integer, par_freq_subday_interval integer, par_freq_relative_interval integer, par_freq_recurrence_factor integer, par_active_start_date integer, par_active_end_date integer, par_active_start_time integer, par_active_end_time integer, par_owner_login_name character varying, par_automatic_post smallint, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 411 (class 1255 OID 17121)
-- Name: sp_verify_job(integer, character varying, smallint, integer, character varying, character, integer, integer, integer, integer, character varying, character varying, character varying, integer, integer, integer, integer, integer, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_verify_job(par_job_id integer, par_name character varying, par_enabled smallint, par_start_step_id integer, par_category_name character varying, INOUT par_owner_sid character, par_notify_level_eventlog integer, INOUT par_notify_level_email integer, INOUT par_notify_level_netsend integer, INOUT par_notify_level_page integer, par_notify_email_operator_name character varying, par_notify_netsend_operator_name character varying, par_notify_page_operator_name character varying, par_delete_level integer, INOUT par_category_id integer, INOUT par_notify_email_operator_id integer, INOUT par_notify_netsend_operator_id integer, INOUT par_notify_page_operator_id integer, INOUT par_originating_server character varying, OUT returncode integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_job_type INT;
  var_retval INT;
  var_current_date INT;
  var_res_valid_range VARCHAR(200);
  var_max_step_id INT;
  var_valid_range VARCHAR(50);
BEGIN
  /* Remove any leading/trailing spaces from parameters */
  SELECT LTRIM(RTRIM(par_name)) INTO par_name;
  SELECT LTRIM(RTRIM(par_category_name)) INTO par_category_name;
  SELECT UPPER(LTRIM(RTRIM(par_originating_server))) INTO par_originating_server;
    
  IF (
    EXISTS (
      SELECT * 
        FROM aws_sqlserver_ext.sysjobs AS job
       WHERE (name = par_name)
      /* AND (job_id <> ISNULL(@job_id, 0x911)))) -- When adding a new job @job_id is NULL */
    )
  ) 
  THEN /* Failure */
    RAISE 'The specified % ("%") already exists.', 'par_name', par_name USING ERRCODE := '50000';
      returncode := 1;
      RETURN;
  END IF;
    
  /* Check enabled state */
  IF (par_enabled <> 0) AND (par_enabled <> 1) THEN /* Failure */
    RAISE 'The specified "%" is invalid (valid values are: %).', 'par_enabled', '0, 1' USING ERRCODE := '50000';
      returncode := 1;
      RETURN;
  END IF;
  
  /* Check start step */

  IF (par_job_id IS NULL) THEN /* New job */
    IF (par_start_step_id <> 1) THEN /* Failure */
      RAISE 'The specified "%" is invalid (valid values are: %).', 'par_start_step_id', '1' USING ERRCODE := '50000';
        returncode := 1;
        RETURN;
    END IF;
  ELSE /* Existing job */
    /* Get current maximum step id */
    SELECT COALESCE(MAX(step_id), 0)
      INTO var_max_step_id
      FROM aws_sqlserver_ext.sysjobsteps
     WHERE (job_id = par_job_id);

    IF (par_start_step_id < 1) OR (par_start_step_id > var_max_step_id + 1) THEN /* Failure */
      SELECT '1..' || CAST (var_max_step_id + 1 AS VARCHAR(1))
        INTO var_valid_range;
      RAISE 'The specified "%" is invalid (valid values are: %).', 'par_start_step_id', var_valid_range USING ERRCODE := '50000';
      returncode := 1;
      RETURN;
    END IF;
  END IF;
  
  /* Get the category_id, handling any special-cases as appropriate */
  SELECT NULL INTO par_category_id;

  IF (par_category_name = '[DEFAULT]') /* User wants to revert to the default job category */
  THEN
    SELECT 
      CASE COALESCE(var_job_type, 1)
        WHEN 1 THEN 0 /* [Uncategorized (Local)] */
        WHEN 2 THEN 2 /* [Uncategorized (Multi-Server)] */
      END
      INTO par_category_id;
  ELSE
    SELECT 0 INTO par_category_id;
  END IF;
  
  returncode := (0); /* Success */
  RETURN;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_verify_job(par_job_id integer, par_name character varying, par_enabled smallint, par_start_step_id integer, par_category_name character varying, INOUT par_owner_sid character, par_notify_level_eventlog integer, INOUT par_notify_level_email integer, INOUT par_notify_level_netsend integer, INOUT par_notify_level_page integer, par_notify_email_operator_name character varying, par_notify_netsend_operator_name character varying, par_notify_page_operator_name character varying, par_delete_level integer, INOUT par_category_id integer, INOUT par_notify_email_operator_id integer, INOUT par_notify_netsend_operator_id integer, INOUT par_notify_page_operator_id integer, INOUT par_originating_server character varying, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 336 (class 1255 OID 17119)
-- Name: sp_verify_job_date(integer, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_verify_job_date(par_date integer, par_date_name character varying DEFAULT 'date'::character varying, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
  /* Remove any leading/trailing spaces from parameters */
  SELECT LTRIM(RTRIM(par_date_name)) INTO par_date_name;
  
  /* Success */
  returncode := 0;
  RETURN;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_verify_job_date(par_date integer, par_date_name character varying, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 410 (class 1255 OID 17120)
-- Name: sp_verify_job_identifiers(character varying, character varying, character varying, integer, character varying, character); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_verify_job_identifiers(par_name_of_name_parameter character varying, par_name_of_id_parameter character varying, INOUT par_job_name character varying, INOUT par_job_id integer, par_sqlagent_starting_test character varying DEFAULT 'TEST'::character varying, INOUT par_owner_sid character DEFAULT NULL::bpchar, OUT returncode integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_retval INT;
  var_job_id_as_char VARCHAR(36);
BEGIN
  /* Remove any leading/trailing spaces from parameters */
  SELECT LTRIM(RTRIM(par_name_of_name_parameter)) INTO par_name_of_name_parameter;
  SELECT LTRIM(RTRIM(par_name_of_id_parameter)) INTO par_name_of_id_parameter;
  SELECT LTRIM(RTRIM(par_job_name)) INTO par_job_name;

  IF (par_job_name = '') 
  THEN 
    SELECT NULL INTO par_job_name;
  END IF;

  IF ((par_job_name IS NULL) AND (par_job_id IS NULL)) OR ((par_job_name IS NOT NULL) AND (par_job_id IS NOT NULL)) 
  THEN /* Failure */
    RAISE 'Supply either % or % to identify the job.', par_name_of_id_parameter, par_name_of_name_parameter USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;

  /* Check job id */
  IF (par_job_id IS NOT NULL) 
  THEN
    SELECT name
         , owner_sid
      INTO par_job_name
         , par_owner_sid
      FROM aws_sqlserver_ext.sysjobs
     WHERE (job_id = par_job_id);
 
    /* the view would take care of all the permissions issues. */
    IF (par_job_name IS NULL) 
    THEN /* Failure */
      SELECT CAST (par_job_id AS VARCHAR(36))
        INTO var_job_id_as_char;
      
      RAISE 'The specified % ("%") does not exist.', 'job_id', var_job_id_as_char USING ERRCODE := '50000';
      returncode := 1;
      RETURN;
    END IF;
  ELSE
    /* Check job name */
    IF (par_job_name IS NOT NULL) 
    THEN
      /* Check if the job name is ambiguous */
      IF (SELECT COUNT(*) FROM aws_sqlserver_ext.sysjobs WHERE name = par_job_name) > 1
      THEN /* Failure */
        RAISE 'There are two or more jobs named "%". Specify % instead of % to uniquely identify the job.', par_job_name, par_name_of_id_parameter, par_name_of_name_parameter USING ERRCODE := '50000';
        returncode := 1;
        RETURN;
      END IF;
      
      /* The name is not ambiguous, so get the corresponding job_id (if the job exists) */      
      SELECT job_id
           , owner_sid
        INTO par_job_id
           , par_owner_sid
        FROM aws_sqlserver_ext.sysjobs
       WHERE (name = par_job_name);
       
      /* the view would take care of all the permissions issues. */
      IF (par_job_id IS NULL) 
      THEN /* Failure */
        RAISE 'The specified % ("%") does not exist.', 'job_name', par_job_name USING ERRCODE := '50000';
        returncode := 1;
        RETURN;
      END IF;
    END IF;
  END IF;

  /* Success */  
  returncode := 0;
  RETURN;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_verify_job_identifiers(par_name_of_name_parameter character varying, par_name_of_id_parameter character varying, INOUT par_job_name character varying, INOUT par_job_id integer, par_sqlagent_starting_test character varying, INOUT par_owner_sid character, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 413 (class 1255 OID 17123)
-- Name: sp_verify_job_time(integer, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_verify_job_time(par_time integer, par_time_name character varying DEFAULT 'time'::character varying, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_hour INT;
  var_minute INT;
  var_second INT;
BEGIN
  /* Remove any leading/trailing spaces from parameters */
  SELECT LTRIM(RTRIM(par_time_name)) INTO par_time_name;

  IF ((par_time < 0) OR (par_time > 235959)) 
  THEN
    RAISE 'The specified "%" is invalid (valid values are: %).', par_time_name, '000000..235959' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;
  
  SELECT (par_time / 10000) INTO var_hour;
  SELECT (par_time % 10000) / 100 INTO var_minute;
  SELECT (par_time % 100) INTO var_second;
   
  /* Check hour range */
  IF (var_hour > 23) THEN
    RAISE 'The "%" supplied has an invalid %.', par_time_name, 'hour' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;
  
  /* Check minute range */
  IF (var_minute > 59) THEN
    RAISE 'The "%" supplied has an invalid %.', par_time_name, 'minute' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;

  /* Check second range */
  IF (var_second > 59) THEN
     RAISE 'The "%" supplied has an invalid %.', par_time_name, 'second' USING ERRCODE := '50000';
     returncode := 1;
     RETURN;
  END IF;
  
  returncode := 0;
  RETURN;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_verify_job_time(par_time integer, par_time_name character varying, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 412 (class 1255 OID 17122)
-- Name: sp_verify_jobstep(integer, integer, character varying, character varying, text, character varying, smallint, integer, smallint, integer, integer, integer, character varying, integer); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_verify_jobstep(par_job_id integer, par_step_id integer, par_step_name character varying, par_subsystem character varying, par_command text, par_server character varying, par_on_success_action smallint, par_on_success_step_id integer, par_on_fail_action smallint, par_on_fail_step_id integer, par_os_run_priority integer, par_flags integer, par_output_file_name character varying, par_proxy_id integer, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_max_step_id INT;
  var_retval INT;
  var_valid_values VARCHAR(50);
  var_database_name_temp VARCHAR(258);
  var_database_user_name_temp VARCHAR(256);
  var_temp_command TEXT;
  var_iPos INT;
  var_create_count INT;
  var_destroy_count INT;
  var_is_olap_subsystem SMALLINT;
  var_owner_sid CHAR(85);
  var_owner_name VARCHAR(128);
BEGIN
  /* Remove any leading/trailing spaces from parameters */
  SELECT LTRIM(RTRIM(par_subsystem)) INTO par_subsystem;
  SELECT LTRIM(RTRIM(par_server)) INTO par_server;
  SELECT LTRIM(RTRIM(par_output_file_name)) INTO par_output_file_name;
  
  /* Get current maximum step id */
  SELECT COALESCE(MAX(step_id), 0)
    INTO var_max_step_id
    FROM aws_sqlserver_ext.sysjobsteps
   WHERE (job_id = par_job_id);
   
  /* Check step id */
  IF (par_step_id < 1) OR (par_step_id > var_max_step_id + 1)  /* Failure */
  THEN
    SELECT '1..' || CAST (var_max_step_id + 1 AS VARCHAR(1)) INTO var_valid_values;
      RAISE 'The specified "%" is invalid (valid values are: %).', '@step_id', var_valid_values USING ERRCODE := '50000';
      returncode := 1;
      RETURN;
  END IF;
  
  /* Check step name */
  IF (
    EXISTS (
      SELECT *
        FROM aws_sqlserver_ext.sysjobsteps
       WHERE (job_id = par_job_id) AND (step_name = par_step_name)
    )
  ) 
  THEN /* Failure */
    RAISE 'The specified % ("%") already exists.', 'step_name', par_step_name USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;
  
  /* Check on-success action/step */
  IF (par_on_success_action <> 1) /* Quit Qith Success */
    AND (par_on_success_action <> 2) /* Quit Qith Failure */
    AND (par_on_success_action <> 3) /* Goto Next Step */
    AND (par_on_success_action <> 4) /* Goto Step */
  THEN /* Failure */
    RAISE 'The specified "%" is invalid (valid values are: %).', 'on_success_action', '1, 2, 3, 4' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;

  IF (par_on_success_action = 4) AND ((par_on_success_step_id < 1) OR (par_on_success_step_id = par_step_id)) 
  THEN /* Failure */
    RAISE 'The specified "%" is invalid (valid values are greater than 0 but excluding %ld).', 'on_success_step', par_step_id USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;
  
  /* Check on-fail action/step */
  IF (par_on_fail_action <> 1) /* Quit With Success */
    AND (par_on_fail_action <> 2) /* Quit With Failure */
    AND (par_on_fail_action <> 3) /* Goto Next Step */
    AND (par_on_fail_action <> 4) /* Goto Step */
  THEN /* Failure */
    RAISE 'The specified "%" is invalid (valid values are: %).', 'on_failure_action', '1, 2, 3, 4' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;

  IF (par_on_fail_action = 4) AND ((par_on_fail_step_id < 1) OR (par_on_fail_step_id = par_step_id)) 
  THEN /* Failure */
    RAISE 'The specified "%" is invalid (valid values are greater than 0 but excluding %).', 'on_failure_step', par_step_id USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;
  
  /* Warn the user about forward references */
  IF ((par_on_success_action = 4) AND (par_on_success_step_id > var_max_step_id)) 
  THEN
    RAISE 'Warning: Non-existent step referenced by %.', 'on_success_step_id' USING ERRCODE := '50000';
  END IF;

  IF ((par_on_fail_action = 4) AND (par_on_fail_step_id > var_max_step_id)) 
  THEN
    RAISE 'Warning: Non-existent step referenced by %.', '@on_fail_step_id' USING ERRCODE := '50000';
  END IF;
  
  /* Check run priority: must be a valid value to pass to SetThreadPriority: */
  /* [-15 = IDLE, -1 = BELOW_NORMAL, 0 = NORMAL, 1 = ABOVE_NORMAL, 15 = TIME_CRITICAL] */
  IF (par_os_run_priority NOT IN (- 15, - 1, 0, 1, 15)) 
  THEN /* Failure */
    RAISE 'The specified "%" is invalid (valid values are: %).', '@os_run_priority', '-15, -1, 0, 1, 15' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;
  
  /* Check flags */
  IF ((par_flags < 0) OR (par_flags > 114)) THEN /* Failure */
    RAISE 'The specified "%" is invalid (valid values are: %).', '@flags', '0..114' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;

  IF (LOWER(UPPER(par_subsystem)) <> LOWER('TSQL')) THEN /* Failure */
    RAISE 'The specified "%" is invalid (valid values are: %).', '@subsystem', 'TSQL' USING ERRCODE := '50000';
    returncode := (1);
    RETURN;
  END IF;
  
  /* Success */
  returncode := 0;
  RETURN;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_verify_jobstep(par_job_id integer, par_step_id integer, par_step_name character varying, par_subsystem character varying, par_command text, par_server character varying, par_on_success_action smallint, par_on_success_step_id integer, par_on_fail_action smallint, par_on_fail_step_id integer, par_os_run_priority integer, par_flags integer, par_output_file_name character varying, par_proxy_id integer, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 416 (class 1255 OID 17125)
-- Name: sp_verify_schedule(integer, character varying, smallint, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, character); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_verify_schedule(par_schedule_id integer, par_name character varying, par_enabled smallint, par_freq_type integer, INOUT par_freq_interval integer, INOUT par_freq_subday_type integer, INOUT par_freq_subday_interval integer, INOUT par_freq_relative_interval integer, INOUT par_freq_recurrence_factor integer, INOUT par_active_start_date integer, INOUT par_active_start_time integer, INOUT par_active_end_date integer, INOUT par_active_end_time integer, par_owner_sid character, OUT returncode integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_return_code INT;
  var_isAdmin INT;
BEGIN
  /* Remove any leading/trailing spaces from parameters */
  SELECT LTRIM(RTRIM(par_name)) INTO par_name;
  
  /* Make sure that NULL input/output parameters - if NULL - are initialized to 0 */
  SELECT COALESCE(par_freq_interval, 0) INTO par_freq_interval;
  SELECT COALESCE(par_freq_subday_type, 0) INTO par_freq_subday_type;
  SELECT COALESCE(par_freq_subday_interval, 0) INTO par_freq_subday_interval;
  SELECT COALESCE(par_freq_relative_interval, 0) INTO par_freq_relative_interval;
  SELECT COALESCE(par_freq_recurrence_factor, 0) INTO par_freq_recurrence_factor;
  SELECT COALESCE(par_active_start_date, 0) INTO par_active_start_date;
  SELECT COALESCE(par_active_start_time, 0) INTO par_active_start_time;
  SELECT COALESCE(par_active_end_date, 0) INTO par_active_end_date;
  SELECT COALESCE(par_active_end_time, 0) INTO par_active_end_time;
  
  /* Verify name (we disallow schedules called 'ALL' since this has special meaning in sp_delete_jobschedules) */
  SELECT 0 INTO var_isAdmin;

  IF (
    EXISTS (
      SELECT * 
        FROM aws_sqlserver_ext.sysschedules
       WHERE (name = par_name)
    )
  ) 
  THEN /* Failure */
    RAISE 'The specified % ("%") already exists.', 'par_name', par_name USING ERRCODE := '50000';
      returncode := 1;
      RETURN;
  END IF;

  IF (UPPER(par_name) = 'ALL') 
  THEN /* Failure */
    RAISE 'The specified "%" is invalid.', 'name' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;
  
  /* Verify enabled state */
  IF (par_enabled <> 0) AND (par_enabled <> 1) 
  THEN /* Failure */
    RAISE 'The specified "%" is invalid (valid values are: %).', '@enabled', '0, 1' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;
  
  /* Verify frequency type */
  IF (par_freq_type = 2) /* OnDemand is no longer supported */
  THEN /* Failure */
    RAISE 'Frequency Type 0x2 (OnDemand) is no longer supported.' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;

  IF (par_freq_type NOT IN (1, 4, 8, 16, 32, 64, 128)) 
  THEN /* Failure */
    RAISE 'The specified "%" is invalid (valid values are: %).', 'freq_type', '1, 4, 8, 16, 32, 64, 128' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;

  /* Verify frequency sub-day type */
  IF (par_freq_subday_type <> 0) AND (par_freq_subday_type NOT IN (1, 2, 4, 8)) 
  THEN /* Failure */
    RAISE 'The specified "%" is invalid (valid values are: %).', 'freq_subday_type', '1, 2, 4, 8' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;
  
  /* Default active start/end date/times (if not supplied, or supplied as NULLs or 0) */
  IF (par_active_start_date = 0) 
  THEN
    SELECT date_part('year', NOW()::TIMESTAMP) * 10000 + date_part('month', NOW()::TIMESTAMP) * 100 + date_part('day', NOW()::TIMESTAMP)
      INTO par_active_start_date;
  END IF;
  
  /* This is an ISO format: "yyyymmdd" */
  IF (par_active_end_date = 0) 
  THEN
    /* December 31st 9999 */
    SELECT 99991231 INTO par_active_end_date;
  END IF;
    
  IF (par_active_start_time = 0) 
  THEN 
    /* 12:00:00 am */
    SELECT 000000 INTO par_active_start_time;
  END IF;

  IF (par_active_end_time = 0) 
  THEN
    /* 11:59:59 pm */
    SELECT 235959 INTO par_active_end_time;
  END IF;
    
  /* Verify active start/end dates */
  IF (par_active_end_date = 0) 
  THEN
    SELECT 99991231 INTO par_active_end_date;
  END IF;

  SELECT t.returncode
    FROM aws_sqlserver_ext.sp_verify_job_date(par_active_end_date, 'active_end_date') t
    INTO var_return_code;

  IF (var_return_code <> 0) 
  THEN /* Failure */
    returncode := 1;
    RETURN;
  END IF;
  
  SELECT t.returncode
    FROM aws_sqlserver_ext.sp_verify_job_date(par_active_start_date, '@active_start_date') t
    INTO var_return_code;

  IF (var_return_code <> 0) 
  THEN /* Failure */
    returncode := 1;
    RETURN;
  END IF;

  IF (par_active_end_date < par_active_start_date) 
  THEN /* Failure */
    RAISE '% cannot be before %.', 'active_end_date', 'active_start_date' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;
  
  SELECT t.returncode
    FROM aws_sqlserver_ext.sp_verify_job_time(par_active_end_time, '@active_end_time') t
    INTO var_return_code;

  IF (var_return_code <> 0) 
  THEN /* Failure */
    returncode := 1;
    RETURN;
  END IF;
  
  SELECT t.returncode
    FROM aws_sqlserver_ext.sp_verify_job_time(par_active_start_time, '@active_start_time') t
    INTO var_return_code;

  IF (var_return_code <> 0) 
  THEN /* Failure */
    returncode := 1;
    RETURN;
  END IF;
    
  IF (par_active_start_time = par_active_end_time AND (par_freq_subday_type IN (2, 4, 8))) 
  THEN /* Failure */
    RAISE 'The specified "%" is invalid (valid values are: %).', 'active_end_time', 'before or after active_start_time' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;

  IF ((par_freq_type = 1) /* FREQTYPE_ONETIME */
    OR (par_freq_type = 64) /* FREQTYPE_AUTOSTART */
    OR (par_freq_type = 128)) /* FREQTYPE_ONIDLE */
  THEN /* Set standard defaults for non-required parameters */
    SELECT 0 INTO par_freq_interval;
    SELECT 0 INTO par_freq_subday_type;
    SELECT 0 INTO par_freq_subday_interval;
    SELECT 0 INTO par_freq_relative_interval;
    SELECT 0 INTO par_freq_recurrence_factor;
    /* Success */
    returncode := 0;
    RETURN;
  END IF;

  IF (par_freq_subday_type = 0) /* FREQSUBTYPE_ONCE */ 
  THEN
    SELECT 1 INTO par_freq_subday_type;
  END IF;

  IF ((par_freq_subday_type <> 1) /* FREQSUBTYPE_ONCE */
    AND (par_freq_subday_type <> 2) /* FREQSUBTYPE_SECOND */
    AND (par_freq_subday_type <> 4) /* FREQSUBTYPE_MINUTE */
    AND (par_freq_subday_type <> 8)) /* FREQSUBTYPE_HOUR */
  THEN /* Failure */
    RAISE 'The schedule for this job is invalid (reason: The specified @freq_subday_type is invalid (valid values are: 0x1, 0x2, 0x4, 0x8).).' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;

  IF ((par_freq_subday_type <> 1) AND (par_freq_subday_interval < 1)) /* FREQSUBTYPE_ONCE and less than 1 interval */
    OR ((par_freq_subday_type = 2) AND (par_freq_subday_interval < 10)) /* FREQSUBTYPE_SECOND and less than 10 seconds (see MIN_SCHEDULE_GRANULARITY in SqlAgent source code) */
  THEN /* Failure */
    RAISE 'The schedule for this job is invalid (reason: The specified @freq_subday_interval is invalid).' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;

  IF (par_freq_type = 4) /* FREQTYPE_DAILY */
  THEN
    SELECT 0 INTO par_freq_recurrence_factor;
    
    IF (par_freq_interval < 1) THEN /* Failure */
      RAISE 'The schedule for this job is invalid (reason: @freq_interval must be at least 1 for a daily job.).' USING ERRCODE := '50000';
      returncode := 1;
      RETURN;
    END IF;
  END IF;

  IF (par_freq_type = 8) /* FREQTYPE_WEEKLY */
  THEN
    IF (par_freq_interval < 1) OR (par_freq_interval > 127) /* (2^7)-1 [freq_interval is a bitmap (Sun=1..Sat=64)] */
    THEN /* Failure */
      RAISE 'The schedule for this job is invalid (reason: @freq_interval must be a valid day of the week bitmask [Sunday = 1 .. Saturday = 64] for a weekly job.).' USING ERRCODE := '50000';
      returncode := 1;
      RETURN;
    END IF;
  END IF;

  IF (par_freq_type = 16) /* FREQTYPE_MONTHLY */
  THEN
    IF (par_freq_interval < 1) OR (par_freq_interval > 31) 
    THEN /* Failure */
      RAISE 'The schedule for this job is invalid (reason: @freq_interval must be between 1 and 31 for a monthly job.).' USING ERRCODE := '50000';
      returncode := 1;
      RETURN;
    END IF;
  END IF;

  IF (par_freq_type = 32) /* FREQTYPE_MONTHLYRELATIVE */
  THEN
    IF (par_freq_relative_interval <> 1) /* RELINT_1ST */
      AND (par_freq_relative_interval <> 2) /* RELINT_2ND */
      AND (par_freq_relative_interval <> 4) /* RELINT_3RD */
      AND (par_freq_relative_interval <> 8) /* RELINT_4TH */
      AND (par_freq_relative_interval <> 16) /* RELINT_LAST */
    THEN /* Failure */
      RAISE 'The schedule for this job is invalid (reason: @freq_relative_interval must be one of 1st (0x1), 2nd (0x2), 3rd [0x4], 4th (0x8) or Last (0x10).).' USING ERRCODE := '50000';
      returncode := 1;
      RETURN;
    END IF;
  END IF;

  IF (par_freq_type = 32) /* FREQTYPE_MONTHLYRELATIVE */
  THEN
    IF (par_freq_interval <> 1) /* RELATIVE_SUN */
      AND (par_freq_interval <> 2) /* RELATIVE_MON */
      AND (par_freq_interval <> 3) /* RELATIVE_TUE */
      AND (par_freq_interval <> 4) /* RELATIVE_WED */
      AND (par_freq_interval <> 5) /* RELATIVE_THU */
      AND (par_freq_interval <> 6) /* RELATIVE_FRI */
      AND (par_freq_interval <> 7) /* RELATIVE_SAT */
      AND (par_freq_interval <> 8) /* RELATIVE_DAY */
      AND (par_freq_interval <> 9) /* RELATIVE_WEEKDAY */
      AND (par_freq_interval <> 10) /* RELATIVE_WEEKENDDAY */
    THEN /* Failure */
      RAISE 'The schedule for this job is invalid (reason: @freq_interval must be between 1 and 10 (1 = Sunday .. 7 = Saturday, 8 = Day, 9 = Weekday, 10 = Weekend-day) for a monthly-relative job.).' USING ERRCODE := '50000';
      returncode := 1;
      RETURN;
    END IF;
  END IF;

  IF ((par_freq_type = 8) /* FREQTYPE_WEEKLY */
    OR (par_freq_type = 16) /* FREQTYPE_MONTHLY */
    OR (par_freq_type = 32)) /* FREQTYPE_MONTHLYRELATIVE */
    AND (par_freq_recurrence_factor < 1) 
  THEN /* Failure */
    RAISE 'The schedule for this job is invalid (reason: @freq_recurrence_factor must be at least 1.).' USING ERRCODE := '50000';
      returncode := 1;
      RETURN;
  END IF;
  /* Success */
  returncode := 0;
  RETURN;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_verify_schedule(par_schedule_id integer, par_name character varying, par_enabled smallint, par_freq_type integer, INOUT par_freq_interval integer, INOUT par_freq_subday_type integer, INOUT par_freq_subday_interval integer, INOUT par_freq_relative_interval integer, INOUT par_freq_recurrence_factor integer, INOUT par_active_start_date integer, INOUT par_active_start_time integer, INOUT par_active_end_date integer, INOUT par_active_end_time integer, par_owner_sid character, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 415 (class 1255 OID 17124)
-- Name: sp_verify_schedule_identifiers(character varying, character varying, character varying, integer, character, integer, integer); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_verify_schedule_identifiers(par_name_of_name_parameter character varying, par_name_of_id_parameter character varying, INOUT par_schedule_name character varying, INOUT par_schedule_id integer, INOUT par_owner_sid character, INOUT par_orig_server_id integer, par_job_id_filter integer DEFAULT NULL::integer, OUT returncode integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_retval INT;
  var_schedule_id_as_char VARCHAR(36);
  var_sch_name_count INT;
BEGIN
  /* Remove any leading/trailing spaces from parameters */
  SELECT LTRIM(RTRIM(par_name_of_name_parameter)) INTO par_name_of_name_parameter;
  SELECT LTRIM(RTRIM(par_name_of_id_parameter)) INTO par_name_of_id_parameter;
  SELECT LTRIM(RTRIM(par_schedule_name)) INTO par_schedule_name;
  SELECT 0 INTO var_sch_name_count;

  IF (par_schedule_name = '') 
  THEN
    SELECT NULL INTO par_schedule_name;
  END IF;

  IF ((par_schedule_name IS NULL) AND (par_schedule_id IS NULL)) OR ((par_schedule_name IS NOT NULL) AND (par_schedule_id IS NOT NULL)) 
  THEN /* Failure */
    RAISE 'Supply either % or % to identify the schedule.', par_name_of_id_parameter, par_name_of_name_parameter USING ERRCODE := '50000';
    returncode := 1;
    RETURN;
  END IF;

  /* Check schedule id */
  IF (par_schedule_id IS NOT NULL) 
  THEN
    /* Look at all schedules */
    SELECT name
         , owner_sid
         , originating_server_id
      INTO par_schedule_name
         , par_owner_sid
         , par_orig_server_id
      FROM aws_sqlserver_ext.sysschedules
     WHERE (schedule_id = par_schedule_id);

    IF (par_schedule_name IS NULL) 
    THEN /* Failure */
      SELECT CAST (par_schedule_id AS VARCHAR(36))
        INTO var_schedule_id_as_char;
        
      RAISE 'The specified % ("%") does not exist.', 'schedule_id', var_schedule_id_as_char USING ERRCODE := '50000';
      returncode := 1;
      RETURN;
    END IF;
  ELSE 
    IF (par_schedule_name IS NOT NULL)
    THEN
      /* Check if the schedule name is ambiguous */
      IF (SELECT COUNT(*) FROM aws_sqlserver_ext.sysschedules WHERE name = par_schedule_name) > 1 
      THEN /* Failure */
        RAISE 'There are two or more sysschedules named "%". Specify % instead of % to uniquely identify the sysschedules.', par_job_name, par_name_of_id_parameter, par_name_of_name_parameter USING ERRCODE := '50000';
        returncode := 1;
        RETURN;
      END IF;
    
      /* The name is not ambiguous, so get the corresponding job_id (if the job exists) */
      SELECT schedule_id
           , owner_sid
        INTO par_schedule_id, par_owner_sid
        FROM aws_sqlserver_ext.sysschedules
       WHERE (name = par_schedule_name);
     
      /* the view would take care of all the permissions issues. */
      IF (par_schedule_id IS NULL) 
      THEN /* Failure */
        RAISE 'The specified % ("%") does not exist.', 'par_schedule_name', par_schedule_name USING ERRCODE := '50000';
        returncode := 1;
        RETURN;
      END IF;
    END IF;
  END IF;
  
  /* Success */
  returncode := 0;
  RETURN;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sp_verify_schedule_identifiers(par_name_of_name_parameter character varying, par_name_of_id_parameter character varying, INOUT par_schedule_name character varying, INOUT par_schedule_id integer, INOUT par_owner_sid character, INOUT par_orig_server_id integer, par_job_id_filter integer, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 355 (class 1255 OID 17353)
-- Name: sp_xml_preparedocument(text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_xml_preparedocument(xmldocument text, OUT dochandle bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
DECLARE                       
   XmlDocument$data XML;
BEGIN
     /*Create temporary structure for xmldocument saving*/
     CREATE TEMPORARY SEQUENCE IF NOT EXISTS aws_sqlserver_ext$seq_openmxl_id MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 INCREMENT BY 1 CACHE 5;
     
     CREATE TEMPORARY TABLE IF NOT EXISTS aws_sqlserver_ext$openxml
          (DocID BigInt NOT NULL DEFAULT NEXTVAL('aws_sqlserver_ext$seq_openmxl_id'),
           XmlData XML not NULL,
           CONSTRAINT pk_aws_sqlserver_ext$doc_id PRIMARY KEY(DocID)
          ) ON COMMIT PRESERVE ROWS;

     IF xml_is_well_formed(XmlDocument) THEN
       XmlDocument$data := XmlDocument::XML;      
     ELSE
       RAISE EXCEPTION '%','The XML parse error occurred';
     END IF;
     
     INSERT INTO aws_sqlserver_ext$openxml(XmlData)
          VALUES (XmlDocument$data)
       RETURNING DocID INTO DocHandle;	
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.sp_xml_preparedocument(xmldocument text, OUT dochandle bigint) OWNER TO postgres;

--
-- TOC entry 356 (class 1255 OID 17354)
-- Name: sp_xml_removedocument(bigint); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sp_xml_removedocument(dochandle bigint) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
  lt_error_text TEXT := 'Could not find prepared statement with handle '||CASE 
                                                                            WHEN DocHandle IS NULL THEN 'null'
                                                                              ELSE DocHandle::TEXT
                                                                           END;
BEGIN
	DELETE FROM aws_sqlserver_ext$openxml t
	 WHERE t.DocID = DocHandle;
	
	IF NOT FOUND THEN
	     RAISE EXCEPTION '%', lt_error_text;  
	END IF;

	EXCEPTION
	  WHEN SQLSTATE '42P01' THEN 
	      RAISE EXCEPTION '%',lt_error_text;
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.sp_xml_removedocument(dochandle bigint) OWNER TO postgres;

--
-- TOC entry 351 (class 1255 OID 17159)
-- Name: stash_row_deltas(); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.stash_row_deltas() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE 
  TabInserted VARCHAR(100);
  TabDeleted VARCHAR(100);
BEGIN
  TabInserted := 'inserted_' || TG_TABLE_NAME;
  TabDeleted := 'deleted_' || TG_TABLE_NAME;

  IF TG_OP = 'INSERT' THEN
	EXECUTE 'INSERT INTO ' || TabInserted || ' SELECT * FROM (SELECT $1.*) AS t' USING NEW;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
	EXECUTE 'INSERT INTO ' || TabInserted || ' SELECT * FROM (SELECT $1.*) AS t' USING NEW;  
    EXECUTE 'INSERT INTO ' || TabDeleted || ' SELECT * FROM (SELECT $1.*) AS t' USING OLD;  	
    RETURN NEW;	
  ELSE 
	EXECUTE 'INSERT INTO ' || TabDeleted || ' SELECT * FROM (SELECT $1.*) AS t' USING OLD;  
    RETURN OLD;	      
  END IF;
END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.stash_row_deltas() OWNER TO postgres;

--
-- TOC entry 419 (class 1255 OID 17129)
-- Name: strpos3(text, text, integer); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.strpos3(p_str text, p_substr text, p_loc integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_loc int := case when p_loc > 0 then p_loc else 1 end;
	v_cnt int := length(p_str) - v_loc + 1;
BEGIN
/***************************************************************
EXTENSION PACK function STRPOS3(x)
***************************************************************/
	if v_cnt > 0 then
		return case when 0!= strpos(substr(p_str, v_loc, v_cnt), p_substr)
		            then strpos(substr(p_str, v_loc, v_cnt), p_substr) + v_loc - 1
			          else strpos(substr(p_str, v_loc, v_cnt), p_substr)
		       end;
	else
		return 0;
	end if;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.strpos3(p_str text, p_substr text, p_loc integer) OWNER TO postgres;

--
-- TOC entry 420 (class 1255 OID 17130)
-- Name: sysmail_add_account_sp(character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer, character varying, character varying, smallint, smallint); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_add_account_sp(par_account_name character varying, par_email_address character varying, par_display_name character varying DEFAULT NULL::character varying, par_replyto_address character varying DEFAULT NULL::character varying, par_description character varying DEFAULT NULL::character varying, par_mailserver_name character varying DEFAULT NULL::character varying, par_mailserver_type character varying DEFAULT 'SMTP'::character varying, par_port integer DEFAULT 25, par_username character varying DEFAULT NULL::character varying, par_password character varying DEFAULT NULL::character varying, par_use_default_credentials smallint DEFAULT 0, par_enable_ssl smallint DEFAULT 0, OUT par_account_id integer, OUT returncode integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_rc INTEGER;
BEGIN

  SELECT t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_addressparams_sp
    (
      par_address => par_replyto_address,
      par_parameter_name => '@replyto_address'
    ) t
    INTO var_rc;

  IF var_rc <> 0 THEN

    returncode := var_rc;
    RETURN;

  END IF;

  IF par_mailserver_name IS NULL THEN /* Failure */

    RAISE '% is not a valid mailserver_name', par_mailserver_name USING ERRCODE := '50000';
    returncode := 1;
    RETURN;

  END IF;

  IF par_mailserver_type IS NULL THEN /* Failure */

    RAISE '% is not a valid mailserver_type', par_mailserver_type USING ERRCODE := '50000';
    returncode := 1;
    RETURN;

  END IF;

  INSERT 
    INTO aws_sqlserver_ext.sysmail_account
    (
      name
    , description
    , email_address
    , display_name
    , replyto_address       
    )
  VALUES
  (
    par_account_name
  , par_description
  , par_email_address
  , par_display_name
  , par_replyto_address
  );
  
  SELECT account_id
    INTO par_account_id
    FROM aws_sqlserver_ext.sysmail_account
   WHERE name = par_account_name;

  returncode := 0;
  RETURN;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_add_account_sp(par_account_name character varying, par_email_address character varying, par_display_name character varying, par_replyto_address character varying, par_description character varying, par_mailserver_name character varying, par_mailserver_type character varying, par_port integer, par_username character varying, par_password character varying, par_use_default_credentials smallint, par_enable_ssl smallint, OUT par_account_id integer, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 422 (class 1255 OID 17132)
-- Name: sysmail_add_profile_sp(character varying, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_add_profile_sp(par_profile_name character varying, par_description character varying DEFAULT NULL::character varying, OUT par_profile_id integer, OUT returncode integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
BEGIN
  /* insert new profile record, rely on primary key constraint to error out */
  INSERT INTO aws_sqlserver_ext.sysmail_profile (name, description)
  VALUES (par_profile_name, par_description);

  /* fetch back profile_id */
  SELECT profile_id
    INTO par_profile_id
    FROM aws_sqlserver_ext.sysmail_profile
   WHERE name = par_profile_name;
   
  returncode := 0;
  RETURN;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_add_profile_sp(par_profile_name character varying, par_description character varying, OUT par_profile_id integer, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 421 (class 1255 OID 17131)
-- Name: sysmail_add_profileaccount_sp(integer, character varying, integer, character varying, integer); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_add_profileaccount_sp(par_profile_id integer DEFAULT NULL::integer, par_profile_name character varying DEFAULT NULL::character varying, par_account_id integer DEFAULT NULL::integer, par_account_name character varying DEFAULT NULL::character varying, par_sequence_number integer DEFAULT NULL::integer, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_rc INTEGER;
  var_profileid INTEGER;
  var_accountid INTEGER;
BEGIN

  SELECT t.par_profileid, t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_profile_sp
    (
      par_profile_id,
      par_profile_name,
      0::SMALLINT,
      0::SMALLINT
    ) t
    INTO var_profileid, var_rc;

  IF var_rc <> 0 THEN

    returncode := 1;
    RETURN;

  END IF;

  SELECT t.par_accountid, t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_account_sp
    (
      par_account_id,
      par_account_name,
      0::SMALLINT,
      0::SMALLINT
    ) t
    INTO var_accountid, var_rc;

  IF var_rc <> 0 THEN

    returncode := 2;
    RETURN;

  END IF;

  /* insert new account record, rely on primary key constraint to error out */
  INSERT INTO aws_sqlserver_ext.sysmail_profileaccount (profile_id, account_id, sequence_number)
  VALUES (var_profileid, var_accountid, par_sequence_number);
  
  returncode := 0;
  RETURN;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_add_profileaccount_sp(par_profile_id integer, par_profile_name character varying, par_account_id integer, par_account_name character varying, par_sequence_number integer, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 423 (class 1255 OID 17133)
-- Name: sysmail_dbmail_json(integer); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_dbmail_json(par_mail_id integer, OUT par_mail_data text, OUT par_server_name character varying, OUT returncode integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_r VARCHAR(2);
  var_t1 VARCHAR(2) DEFAULT '';
  var_t2 VARCHAR(4) DEFAULT '';
  var_t3 VARCHAR(6) DEFAULT '';
  var_t4 VARCHAR(8) DEFAULT '';
  var_xml TEXT DEFAULT '';
  var_source VARCHAR(255);
  var_profile_id INTEGER;
  var_recipients TEXT;
  var_copy_recipients TEXT;
  var_blind_copy_recipients TEXT;
  var_subject VARCHAR(255);
  var_body_format VARCHAR(20);
  var_body TEXT;
  var_from_address TEXT;
  var_reply_to TEXT;
  var_importance VARCHAR(6);
  var_sensitivity VARCHAR(12);
  var_mailitem_id INTEGER;
BEGIN

  SELECT mailitem_id
       , profile_id
       , recipients
       , copy_recipients
       , blind_copy_recipients
       , subject
       , UPPER(body_format)
       , body
       , importance
       , sensitivity
        /* @file_attachments = file_attachments, */
        /* @attachment_encoding = attachment_encoding, */
        /* @query = query, */
        /* @execute_query_database = execute_query_database, */
        /* @attach_query_result_as_file = attach_query_result_as_file, */
        /* @query_result_header = query_result_header, */
        /* @query_result_width = query_result_width, */
        /* @query_result_separator = query_result_separator, */
        /* @exclude_query_output = exclude_query_output, */
        /* @append_query_error = append_query_error, */
        , from_address
        , reply_to
    INTO var_mailitem_id
       , var_profile_id
       , var_recipients
       , var_copy_recipients
       , var_blind_copy_recipients
       , var_subject
       , var_body_format
       , var_body
       , var_importance
       , var_sensitivity
       , var_from_address
       , var_reply_to
    FROM aws_sqlserver_ext.sysmail_mailitems
   WHERE mailitem_id = par_mail_id
   ORDER BY mailitem_id ASC NULLS FIRST
   LIMIT 1;

  IF var_mailitem_id IS NULL THEN

    RAISE 'E-mail messages are missing.' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;

  END IF;

  SELECT CASE
           WHEN LENGTH(a.display_name) = 0 THEN a.email_address
           ELSE CONCAT(a.display_name, ' <', a.email_address, '>')
         END
    INTO var_source
    FROM aws_sqlserver_ext.sysmail_profile AS p
   INNER JOIN aws_sqlserver_ext.sysmail_profileaccount AS pa
      ON pa.profile_id = p.profile_id
   INNER JOIN aws_sqlserver_ext.sysmail_account AS a
      ON a.account_id = pa.account_id
   WHERE p.profile_id = var_profile_id
   LIMIT 1;

  SELECT servername
    INTO par_server_name
    FROM aws_sqlserver_ext.sysmail_server
   WHERE account_id = 0
     AND servertype = 'AWSLAMBDA'
   LIMIT 1;

  IF par_server_name IS NULL THEN

    RAISE 'ARN are missing.' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;

  END IF;

  var_xml := CONCAT(var_xml, '{', var_r);
  var_xml := CONCAT(var_xml, var_t1, '"service": "ses",', var_r);
  var_xml := CONCAT(var_xml, var_t1, '"args": {', var_r);
  /* set source */
  var_xml := CONCAT(var_xml, var_t2, '"source": "', var_source, '",', var_r);
  /* recipients */
  var_xml := CONCAT(var_xml, var_t2, '"recipients": [', var_r);
  var_xml := CONCAT(var_xml, var_t3, '"', var_recipients, '"', var_r);     /* !!!!!!!!!! */
  /* SET @xml = CONCAT(@xml, @t3, '"address": "sample <sample@sample.info>",', @r);    !!!!!!!!!! */
  /* SET @xml = CONCAT(@xml, @t3, '"address": "sample@sample.info"', @r);    !!!!!!!!!! */
  var_xml := CONCAT(var_xml, var_t2, '],', var_r);
  
  /* copy_recipients */
  var_xml := CONCAT(var_xml, var_t2, '"copyrecipients": [', var_r);

  IF var_copy_recipients IS NOT NULL AND LENGTH(var_copy_recipients) > 0 THEN

    var_xml := CONCAT(var_xml, var_t3, '"', var_copy_recipients, '",', var_r);         /* !!!!!!!!!! */
    /* SET @xml = CONCAT(@xml, @t3, '"address": "sample <sample@sample.info>",', @r);    !!!!!!!!!! */
    /* SET @xml = CONCAT(@xml, @t3, '"address": "sample@sample.info"', @r);    !!!!!!!!!! */

  END IF;

  var_xml := CONCAT(var_xml, var_t2, '],', var_r);

  /* blind_copy_recipients */
  var_xml := CONCAT(var_xml, var_t2, '"blindcopyrecipients": [', var_r);

  IF var_blind_copy_recipients IS NOT NULL AND LENGTH(var_blind_copy_recipients) > 0 THEN

    var_xml := CONCAT(var_xml, var_t3, '"', var_blind_copy_recipients, '",', var_r);         /* !!!!!!!!!! */
    /* SET @xml = CONCAT(@xml, @t3, '"address": "sample <sample@sample.info>",', @r);   -- !!!!!!!!!! */
    /* SET @xml = CONCAT(@xml, @t3, '"address": "sample@sample.info"', @r);   -- !!!!!!!!!! */

  END IF;

  var_xml := CONCAT(var_xml, var_t2, '],', var_r);

  var_xml := CONCAT(var_xml, var_t2, '"importance": "', var_importance, '",', var_r);
  var_xml := CONCAT(var_xml, var_t2, '"sensitivity": "', var_sensitivity, '",', var_r);
  var_xml := CONCAT(var_xml, var_t2, '"subject": "', var_subject, '",', var_r);
  var_xml := CONCAT(var_xml, var_t2, '"format": "', var_body_format, '",', var_r);
  var_xml := CONCAT(var_xml, var_t2, '"body": {', var_r);
  var_xml := CONCAT(var_xml, var_t3, '"data": "', var_body, '"', var_r);
  var_xml := CONCAT(var_xml, var_t2, '}', var_r);
  var_xml := CONCAT(var_xml, var_t1, '}', var_r);
  var_xml := CONCAT(var_xml, '}');
  
  par_mail_data := var_xml;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_dbmail_json(par_mail_id integer, OUT par_mail_data text, OUT par_server_name character varying, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 424 (class 1255 OID 17134)
-- Name: sysmail_dbmail_xml(integer); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_dbmail_xml(par_mail_id integer, OUT par_mail_data text, OUT returncode integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_r VARCHAR(2); /* DEFAULT aws_sqlserver_ext.CHAR(10) || aws_sqlserver_ext.CHAR(13);*/
  var_t1 VARCHAR(2) DEFAULT ''; --'  ';
  var_t2 VARCHAR(4) DEFAULT ''; --'    ';
  var_t3 VARCHAR(6) DEFAULT ''; --'      ';
  var_t4 VARCHAR(8) DEFAULT ''; --'        ';
  var_xml TEXT DEFAULT '';
  var_source VARCHAR(255);
  var_profile_id INT;
  var_recipients TEXT;
  var_copy_recipients TEXT;
  var_blind_copy_recipients TEXT;
  var_subject VARCHAR(255);
  var_body_format VARCHAR(20);
  var_body TEXT;
  var_from_address TEXT;
  var_reply_to TEXT;
  var_importance VARCHAR(6);
  var_sensitivity VARCHAR(12);
  var_mailitem_id INTEGER;
BEGIN

  SELECT mailitem_id
       , profile_id
       , recipients
       , copy_recipients
       , blind_copy_recipients
       , subject
       , UPPER(body_format)
       , body
       , importance
       , sensitivity
        /* @file_attachments = file_attachments, */
        /* @attachment_encoding = attachment_encoding, */
        /* @query = query, */
        /* @execute_query_database = execute_query_database, */
        /* @attach_query_result_as_file = attach_query_result_as_file, */
        /* @query_result_header = query_result_header, */
        /* @query_result_width = query_result_width, */
        /* @query_result_separator = query_result_separator, */
        /* @exclude_query_output = exclude_query_output, */
        /* @append_query_error = append_query_error, */, from_address, reply_to
    INTO var_mailitem_id
       , var_profile_id
       , var_recipients
       , var_copy_recipients
       , var_blind_copy_recipients
       , var_subject
       , var_body_format
       , var_body
       , var_importance
       , var_sensitivity
       , var_from_address
       , var_reply_to
    FROM aws_sqlserver_ext.sysmail_mailitems
   WHERE mailitem_id = par_mail_id /* sent_status = 0 */
   ORDER BY mailitem_id ASC NULLS FIRST
   LIMIT 1;

  IF var_mailitem_id IS NULL THEN

    RAISE 'E-mail messages are missing.' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;

  END IF;

  SELECT CASE
           WHEN LENGTH(a.display_name) = 0 THEN a.email_address
           ELSE CONCAT(a.display_name, ' <', a.email_address, '>')
         END
    INTO var_source
    FROM aws_sqlserver_ext.sysmail_profile AS p
   INNER JOIN aws_sqlserver_ext.sysmail_profileaccount AS pa
      ON pa.profile_id = p.profile_id
   INNER JOIN aws_sqlserver_ext.sysmail_account AS a
      ON a.account_id = pa.account_id
   WHERE p.profile_id = var_profile_id
   LIMIT 1;
   
  var_xml := CONCAT(var_xml, '<mail>', var_r);
  /* set source */
  var_xml := CONCAT(var_xml, var_t1, '<source>', var_source, '</source>', var_r);
  /* set destination */
  var_xml := CONCAT(var_xml, var_t1, '<destination>', var_r);
  var_xml := CONCAT(var_xml, var_t2, '<to_addresses>', var_r);
  var_xml := CONCAT(var_xml, var_t3, '<address>', var_recipients, '</address>', var_r);
  /* SET @xml = CONCAT(@xml, @t3, '<address>', @destination2, '</address>', @r); */
  var_xml := CONCAT(var_xml, var_t2, '</to_addresses>', var_r);
  var_xml := CONCAT(var_xml, var_t1, '</destination>', var_r);
  /* set message */
  var_xml := CONCAT(var_xml, var_t1, '<message>', var_r);
  var_xml := CONCAT(var_xml, var_t2, '<subject>', var_r);
  var_xml := CONCAT(var_xml, var_t3, '<data>', var_subject, '</data>', var_r);
  var_xml := CONCAT(var_xml, var_t3, '<charset>UTF-8</charset>', var_r);
  var_xml := CONCAT(var_xml, var_t2, '</subject>', var_r);
  var_xml := CONCAT(var_xml, var_t2, '<body>', var_r);

  IF LOWER(var_body_format) = LOWER('TEXT') THEN

    var_xml := CONCAT(var_xml, var_t3, '<text>', var_r);
    var_xml := CONCAT(var_xml, var_t4, '<data>', var_body, '</data>', var_r);
    var_xml := CONCAT(var_xml, var_t4, '<charset>UTF-8</charset>', var_r);
    var_xml := CONCAT(var_xml, var_t3, '</text>', var_r);
  /* 'HTML' */

  ELSE

    var_xml := CONCAT(var_xml, var_t3, '<html>', var_r);
    var_xml := CONCAT(var_xml, var_t4, '<data>', var_body, '</data>', var_r);
    var_xml := CONCAT(var_xml, var_t4, '<charset>UTF-8</charset>', var_r);
    var_xml := CONCAT(var_xml, var_t3, '</html>', var_r);

  END IF;

  var_xml := CONCAT(var_xml, var_t2, '</body>', var_r);
  var_xml := CONCAT(var_xml, var_t1, '</message>', var_r);
  /* reply to */
  var_xml := CONCAT(var_xml, var_t1, '<reply_to_addresses>', var_r);
  var_xml := CONCAT(var_xml, var_t2, '<address>', var_source, '</address>', var_r);
  /* SET @xml = CONCAT(@xml, @t2, '<address>',@reply_to_addresses2,'</address>', @r); */
  var_xml := CONCAT(var_xml, var_t1, '</reply_to_addresses>', var_r);
  var_xml := CONCAT(var_xml, '</mail>');
  
  par_mail_data := var_xml;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_dbmail_xml(par_mail_id integer, OUT par_mail_data text, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 425 (class 1255 OID 17135)
-- Name: sysmail_delete_account_sp(integer, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_delete_account_sp(par_account_id integer DEFAULT NULL::integer, par_account_name character varying DEFAULT NULL::character varying, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_rc INTEGER;
  var_accountid INTEGER;
  var_credential_name CHARACTER VARYING(128);
BEGIN

  SELECT t.par_accountid, t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_account_sp
  (
    par_account_id,
    par_account_name,
    0::SMALLINT,
    0::SMALLINT
  ) t
    INTO var_accountid, var_rc;

  IF var_rc <> 0 THEN

    returncode := 1;
    RETURN;

  END IF;
  
  DELETE 
    FROM aws_sqlserver_ext.sysmail_account
   WHERE account_id = var_accountid;
   
  returncode := 0;
  RETURN;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_delete_account_sp(par_account_id integer, par_account_name character varying, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 426 (class 1255 OID 17136)
-- Name: sysmail_delete_mailitems_sp(timestamp without time zone, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_delete_mailitems_sp(par_sent_before timestamp without time zone DEFAULT NULL::timestamp without time zone, par_sent_status character varying DEFAULT NULL::character varying, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  vsentstatus TEXT;
BEGIN

  vsentstatus := TRIM(par_sent_status);

  IF vsentstatus = '' THEN

    vsentstatus := NULL;

  END IF;

  IF vsentstatus IS NOT NULL AND LOWER(vsentstatus) NOT IN ('unsent', 'sent', 'failed', 'retrying') THEN /* Failure */

    RAISE 'The specified "%" is invalid (valid values are: %).', 'sent_status', 'unsent, sent, failed, retrying' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;

  END IF;

  IF par_sent_before IS NULL AND vsentstatus IS NULL THEN /* Failure */

    RAISE 'Either % or % parameter needs to be supplied', 'sent_before', 'sent_status' USING ERRCODE := '50000';
    returncode := 1;
    RETURN;

  END IF;
  
  DELETE 
    FROM aws_sqlserver_ext.sysmail_mailitems
   WHERE (par_sent_before IS NULL OR send_request_date < par_sent_before) 
     AND (vsentstatus IS NULL OR sent_status = vsentstatus);

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_delete_mailitems_sp(par_sent_before timestamp without time zone, par_sent_status character varying, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 428 (class 1255 OID 17138)
-- Name: sysmail_delete_profile_sp(integer, character varying, smallint); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_delete_profile_sp(par_profile_id integer DEFAULT NULL::integer, par_profile_name character varying DEFAULT NULL::character varying, par_force_delete smallint DEFAULT 1, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_rc INTEGER;
  var_profileid INTEGER;
BEGIN
  SELECT t.par_profileid, t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_profile_sp
  (
    par_profile_id,
    par_profile_name,
    0::SMALLINT,
    0::SMALLINT
  ) t
    INTO var_profileid, var_rc;

  IF var_rc <> 0 THEN

    returncode := 1;
    RETURN;

  END IF;

  IF (
    EXISTS 
    (
      SELECT 1 
        FROM aws_sqlserver_ext.sysmail_mailitems m
       WHERE m.profile_id = var_profileid
         AND m.sent_status IN (0,3)
    )
    AND par_force_delete <> 1
  ) 
  THEN

    IF par_profile_name IS NULL THEN

      SELECT name INTO par_profile_name
        FROM aws_sqlserver_ext.sysmail_profile
       WHERE profile_id = var_profileid;

    END IF;
    
    RAISE 'Deleting profile %s failed because there are some unsent emails associated with this profile, use force_delete option to force the deletion of the profile.', par_profile_name USING ERRCODE := '50000';
    
    returncode := 1;
    RETURN;

  END IF;
  
  UPDATE aws_sqlserver_ext.sysmail_mailitems
     SET sent_status = 2
       , sent_date = NOW()
   WHERE profile_id = var_profileid 
     AND sent_status <> 1;
   
  DELETE FROM aws_sqlserver_ext.sysmail_profile
   WHERE profile_id = var_profileid;
   
  returncode := 0;
  RETURN;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_delete_profile_sp(par_profile_id integer, par_profile_name character varying, par_force_delete smallint, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 427 (class 1255 OID 17137)
-- Name: sysmail_delete_profileaccount_sp(integer, character varying, integer, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_delete_profileaccount_sp(par_profile_id integer DEFAULT NULL::integer, par_profile_name character varying DEFAULT NULL::character varying, par_account_id integer DEFAULT NULL::integer, par_account_name character varying DEFAULT NULL::character varying, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_rc INTEGER;
  var_profileid INTEGER;
  var_accountid INTEGER;
BEGIN

  SELECT t.par_profileid, t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_profile_sp
  (
    par_profile_id,
    par_profile_name,
    1::SMALLINT,
    0::SMALLINT
  ) t
    INTO var_profileid, var_rc;

  IF var_rc <> 0 THEN

    returncode := 1;
    RETURN;

  END IF;

  SELECT t.par_accountid, t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_account_sp
    (
      par_account_id,
      par_account_name,
      1::SMALLINT,
      0::SMALLINT
    ) t
    INTO var_accountid, var_rc;

  IF var_rc <> 0 THEN

    returncode := 2;
    RETURN;

  END IF;

  IF var_profileid IS NOT NULL AND var_accountid IS NOT NULL /* both parameters supplied for deletion */ THEN

    DELETE 
      FROM aws_sqlserver_ext.sysmail_profileaccount
     WHERE profile_id = var_profileid 
       AND account_id = var_accountid;

  ELSE

    IF var_profileid IS NOT NULL /* profile id is supplied */ THEN

      DELETE 
        FROM aws_sqlserver_ext.sysmail_profileaccount
       WHERE profile_id = var_profileid;

    ELSE

      IF var_accountid IS NOT NULL /* account id is supplied */ THEN

        DELETE 
          FROM aws_sqlserver_ext.sysmail_profileaccount
         WHERE account_id = var_accountid;

      ELSE /* no parameters are supplied for deletion */

        RAISE 'Either % or % parameter needs to be supplied', 'profile', 'account' USING ERRCODE := '50000';
        returncode := 3;
        RETURN;

      END IF;

    END IF;

  END IF;
  
  returncode := 0;
  RETURN;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_delete_profileaccount_sp(par_profile_id integer, par_profile_name character varying, par_account_id integer, par_account_name character varying, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 429 (class 1255 OID 17139)
-- Name: sysmail_help_account_sp(integer, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_help_account_sp(par_account_id integer DEFAULT NULL::integer, par_account_name character varying DEFAULT NULL::character varying, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
  var_rc INTEGER;
  var_accountid INTEGER;
  curs1 REFCURSOR;

  var_c_account_id INTEGER;
  var_c_name VARCHAR(128);
  var_c_description VARCHAR(256);
  var_c_email_address VARCHAR(128);
  var_c_display_name VARCHAR(128);
  var_c_replyto_address VARCHAR(128);

  var_c_servertype VARCHAR(128);-- NOT NULL
  var_c_servername VARCHAR(128);-- NOT NULL
BEGIN

  SELECT t.par_accountid, t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_account_sp
    (
      par_account_id,
      par_account_name,
      1::SMALLINT,
      0::SMALLINT
    ) t
    INTO var_accountid, var_rc;

  IF var_rc <> 0 THEN

    returncode := 1;
    RETURN;

  END IF;
  
  IF var_accountid IS NOT NULL THEN

    OPEN curs1 FOR EXECUTE 
      'SELECT a.account_id, a.name, a.description, a.email_address, a.display_name, a.replyto_address
            , s.servertype, s.servername          
         FROM aws_sqlserver_ext.sysmail_account AS a 
         JOIN aws_sqlserver_ext.sysmail_server AS s
           ON s.account_id = a.account_id
        WHERE a.account_id = $1' USING var_accountid;

  ELSE

    OPEN curs1 FOR EXECUTE 
      'SELECT a.account_id, a.name, a.description, a.email_address, a.display_name, a.replyto_address
            , s.servertype, s.servername          
         FROM aws_sqlserver_ext.sysmail_account AS a 
         JOIN aws_sqlserver_ext.sysmail_server AS s
           ON s.account_id = a.account_id';

  END IF;

  LOOP

    FETCH curs1 INTO var_c_account_id, var_c_name, var_c_description, var_c_email_address, var_c_display_name, var_c_replyto_address, var_c_servertype, var_c_servername;         
    EXIT WHEN NOT FOUND;
    RAISE NOTICE '%', '|--------------------------------------------------------------------------------------------|';
    RAISE NOTICE '%', '| ' || RPAD('ID                  :' || var_c_account_id::character varying, 90) || ' |';
    RAISE NOTICE '%', '| ' || RPAD('Account Name        :' || var_c_name, 90) || ' | ';
    RAISE NOTICE '%', '| ' || RPAD('Account Description :' || COALESCE(var_c_description,' '), 90) || ' | ';
    RAISE NOTICE '%', '| ' || RPAD('E-mail Address      :' || var_c_email_address, 90) || ' | ';
    RAISE NOTICE '%', '| ' || RPAD('Display Name        :' || COALESCE(var_c_display_name,' '), 90) || ' | ';
    RAISE NOTICE '%', '| ' || RPAD('Reply-to Address    :' || COALESCE(var_c_replyto_address,' '), 90) || ' | ';
    RAISE NOTICE '%', '| ' || RPAD('Server Type         :' || COALESCE(var_c_servertype,' '), 90) || ' | ';
    RAISE NOTICE '%', '| ' || RPAD('Server Name         :' || COALESCE(var_c_servername,' '), 90) || ' | ';
    RAISE NOTICE '%', '|--------------------------------------------------------------------------------------------|';

  END LOOP;          
    
  returncode := 0;
  RETURN;

END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_help_account_sp(par_account_id integer, par_account_name character varying, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 431 (class 1255 OID 17141)
-- Name: sysmail_help_profile_sp(integer, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_help_profile_sp(par_profile_id integer DEFAULT NULL::integer, par_profile_name character varying DEFAULT NULL::character varying, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
  var_rc INTEGER;
  var_profileid INTEGER;
  curs1 REFCURSOR;

  var_c_profile_id INTEGER;
  var_c_name CHARACTER VARYING(128);
  var_c_description CHARACTER VARYING;
BEGIN

  SELECT t.par_profileid, t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_profile_sp
    (
      par_profile_id,
      par_profile_name,
      1::SMALLINT,
      0::SMALLINT
    ) t
    INTO var_profileid, var_rc;

  IF var_rc <> 0 THEN

    returncode := 1;
    RETURN;

  END IF;

  RAISE NOTICE '%', '|-------|--------------------------------|----------------------------------------------------| ';    
  RAISE NOTICE '%', '|  ID   |        Profile Name            |                Profile Description                 | ';
  RAISE NOTICE '%', '|-------|--------------------------------|----------------------------------------------------| ';    
  
  IF var_profileid IS NOT NULL THEN

    OPEN curs1 FOR EXECUTE 'SELECT profile_id, name, description FROM aws_sqlserver_ext.sysmail_profile WHERE profile_id = $1' USING var_profileid;

    LOOP

      FETCH curs1 INTO var_c_profile_id, var_c_name, var_c_description;         
      EXIT WHEN NOT FOUND;
      RAISE NOTICE '%', '| ' || LPAD(var_c_profile_id::TEXT, 5) || ' | ' || LPAD(var_c_name, 30) || ' | ' || LPAD(COALESCE(var_c_description,' '), 50) || ' | ';

    END LOOP;

  ELSE

    OPEN curs1 FOR EXECUTE 'SELECT profile_id, name, description FROM aws_sqlserver_ext.sysmail_profile';

    LOOP

      FETCH curs1 INTO var_c_profile_id, var_c_name, var_c_description;
      EXIT WHEN NOT FOUND;
      RAISE NOTICE '%', '| ' || LPAD(var_c_profile_id::TEXT, 5) || ' | ' || LPAD(var_c_name, 30) || ' | ' || LPAD(COALESCE(var_c_description,' '), 50) || ' | ';

    END LOOP;

  END IF;
    
  returncode := 0;
  RETURN;

END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_help_profile_sp(par_profile_id integer, par_profile_name character varying, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 430 (class 1255 OID 17140)
-- Name: sysmail_help_profileaccount_sp(integer, character varying, integer, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_help_profileaccount_sp(par_profile_id integer DEFAULT NULL::integer, par_profile_name character varying DEFAULT NULL::character varying, par_account_id integer DEFAULT NULL::integer, par_account_name character varying DEFAULT NULL::character varying, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
  var_rc INTEGER;
  var_profileid INTEGER;
  var_accountid INTEGER;
  curs1 refcursor;
  
  var_c_account_id INTEGER;        -- NOT NULL
  var_c_account_name VARCHAR(128); -- NOT NULL
  var_c_profile_id INTEGER;        -- NOT NULL
  var_c_profile_name VARCHAR(128); -- NOT NULL
  var_c_sequence_number INTEGER;   -- NULL  
BEGIN

  SELECT t.par_profileid, t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_profile_sp(par_profile_id, par_profile_name, 1::smallint, 0::smallint) t
    INTO var_profileid, var_rc;

  IF var_rc <> 0 THEN

    returncode := 1;
    RETURN;

  END IF;

  SELECT t.par_accountid, t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_account_sp(par_account_id, par_account_name, 1::smallint, 0::smallint) t
    INTO var_accountid, var_rc;

  IF var_rc <> 0 THEN

    returncode := 2;
    RETURN;

  END IF;

  RAISE NOTICE '%', '|--------|----------------------|-------|----------------------|------------|';
  RAISE NOTICE '%', '| Acc ID |     Account Name     | Pr ID |     Profile Name     |   Seq #    |';
  RAISE NOTICE '%', '|--------|----------------------|-------|----------------------|------------|';


  IF var_profileid IS NOT NULL AND var_accountid IS NOT NULL THEN

    OPEN curs1 FOR EXECUTE 
      'SELECT a.account_id, a.name AS account_name
            , p.profile_id, p.name AS profile_name
            , pa.sequence_number
         FROM aws_sqlserver_ext.sysmail_profileaccount AS pa
         JOIN aws_sqlserver_ext.sysmail_profile AS p ON p.profile_id = pa.profile_id
         JOIN aws_sqlserver_ext.sysmail_account AS a ON a.account_id = pa.account_id
        WHERE pa.profile_id = $1
          AND pa.account_id = $2' USING var_profileid, var_accountid;

  ELSE

    IF var_profileid IS NOT NULL THEN

      OPEN curs1 FOR EXECUTE 
        'SELECT a.account_id, a.name AS account_name
              , p.profile_id, p.name AS profile_name
              , pa.sequence_number
           FROM aws_sqlserver_ext.sysmail_profileaccount AS pa
           JOIN aws_sqlserver_ext.sysmail_profile AS p ON p.profile_id = pa.profile_id
           JOIN aws_sqlserver_ext.sysmail_account AS a ON a.account_id = pa.account_id
          WHERE pa.profile_id = $1' USING var_profileid;

    ELSE

      IF var_accountid IS NOT NULL THEN

        OPEN curs1 FOR EXECUTE 
          'SELECT a.account_id, a.name AS account_name
                , p.profile_id, p.name AS profile_name
                , pa.sequence_number
             FROM aws_sqlserver_ext.sysmail_profileaccount AS pa
             JOIN aws_sqlserver_ext.sysmail_profile AS p ON p.profile_id = pa.profile_id
             JOIN aws_sqlserver_ext.sysmail_account AS a ON a.account_id = pa.account_id
            WHERE pa.account_id = $1' USING var_accountid;

      ELSE

        OPEN curs1 FOR EXECUTE 
          'SELECT a.account_id, a.name AS account_name
                , p.profile_id, p.name AS profile_name
                , pa.sequence_number
             FROM aws_sqlserver_ext.sysmail_profileaccount AS pa
             JOIN aws_sqlserver_ext.sysmail_profile AS p ON p.profile_id = pa.profile_id
             JOIN aws_sqlserver_ext.sysmail_account AS a ON a.account_id = pa.account_id';

      END IF;

    END IF;

  END IF;
  
  LOOP

    FETCH curs1 INTO var_c_account_id, var_c_account_name, var_c_profile_id, var_c_profile_name, var_c_sequence_number;
    EXIT WHEN NOT FOUND;
    RAISE NOTICE '%', '| '
      || LPAD(var_c_account_id::character varying, 6) || ' | '
      || LPAD(var_c_account_name, 20) || ' | '
      || LPAD(var_c_profile_id::character varying, 5) || ' | '
      || LPAD(var_c_profile_name, 20) || ' | '
      || LPAD(COALESCE(var_c_sequence_number::character varying,' '), 10) || ' | ';

  END LOOP;          

  returncode := 0;
  RETURN;

END;
$_$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_help_profileaccount_sp(par_profile_id integer, par_profile_name character varying, par_account_id integer, par_account_name character varying, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 432 (class 1255 OID 17142)
-- Name: sysmail_set_arn_sp(character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_set_arn_sp(par_mailserver_name character varying DEFAULT NULL::character varying, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN

  IF par_mailserver_name IS NULL THEN /* Failure */

    RAISE '% is not a valid mailserver_name', par_mailserver_name USING ERRCODE := '50000';
    returncode := 1;
    RETURN;

  END IF;

  DELETE FROM aws_sqlserver_ext.sysmail_server;

  INSERT INTO aws_sqlserver_ext.sysmail_server
  (
    account_id
  , servertype
  , servername
  ) 
  VALUES
  (
    0
  , 'AWSLAMBDA'
  , par_mailserver_name
  );

  returncode := 0;
  RETURN;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_set_arn_sp(par_mailserver_name character varying, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 433 (class 1255 OID 17143)
-- Name: sysmail_update_account_sp(integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer, character varying, character varying, smallint, smallint, integer, smallint); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_update_account_sp(par_account_id integer DEFAULT NULL::integer, par_account_name character varying DEFAULT NULL::character varying, par_email_address character varying DEFAULT NULL::character varying, par_display_name character varying DEFAULT NULL::character varying, par_replyto_address character varying DEFAULT NULL::character varying, par_description character varying DEFAULT NULL::character varying, par_mailserver_name character varying DEFAULT NULL::character varying, par_mailserver_type character varying DEFAULT NULL::character varying, par_port integer DEFAULT NULL::integer, par_username character varying DEFAULT NULL::character varying, par_password character varying DEFAULT NULL::character varying, par_use_default_credentials smallint DEFAULT NULL::smallint, par_enable_ssl smallint DEFAULT NULL::smallint, par_timeout integer DEFAULT NULL::integer, par_no_credential_change smallint DEFAULT NULL::smallint, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_rc INTEGER;
  var_accountid INTEGER;
BEGIN

  SELECT t.par_accountid, t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_account_sp
    (
      par_account_id,
      par_account_name,
      0::SMALLINT,
      1::SMALLINT
    ) t
    INTO var_accountid, var_rc;

  IF var_rc <> 0 THEN

    returncode := 1;
    RETURN;

  END IF;

  IF par_email_address IS NULL THEN

    SELECT email_address
      INTO par_email_address
      FROM aws_sqlserver_ext.sysmail_account
     WHERE account_id = var_accountid;

  END IF;

  IF par_display_name IS NULL THEN

    SELECT display_name
      INTO par_display_name
      FROM aws_sqlserver_ext.sysmail_account
     WHERE account_id = var_accountid;

  END IF;

  IF par_replyto_address IS NULL THEN

    SELECT replyto_address
      INTO par_replyto_address
      FROM aws_sqlserver_ext.sysmail_account
     WHERE account_id = var_accountid;

  END IF;

  IF par_description IS NULL THEN

    SELECT description
      INTO par_description
      FROM aws_sqlserver_ext.sysmail_account
     WHERE account_id = var_accountid;

  END IF;
  
  /* update account table */
  IF par_account_name IS NOT NULL THEN

    IF par_email_address IS NOT NULL THEN

      UPDATE aws_sqlserver_ext.sysmail_account
         SET name = par_account_name
           , description = par_description
           , email_address = par_email_address
           , display_name = par_display_name
           , replyto_address = par_replyto_address
       WHERE account_id = var_accountid;

    ELSE

      UPDATE aws_sqlserver_ext.sysmail_account
         SET name = par_account_name
           , description = par_description
           , display_name = par_display_name
           , replyto_address = par_replyto_address
       WHERE account_id = var_accountid;

    END IF;

  ELSE

    IF par_email_address IS NOT NULL THEN

      UPDATE aws_sqlserver_ext.sysmail_account
         SET description = par_description
           , email_address = par_email_address
           , display_name = par_display_name
           , replyto_address = par_replyto_address
       WHERE account_id = var_accountid;

    ELSE

      UPDATE aws_sqlserver_ext.sysmail_account
         SET description = par_description
           , display_name = par_display_name
           , replyto_address = par_replyto_address
       WHERE account_id = var_accountid;

    END IF;

  END IF;

  returncode := 0;
  RETURN;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_update_account_sp(par_account_id integer, par_account_name character varying, par_email_address character varying, par_display_name character varying, par_replyto_address character varying, par_description character varying, par_mailserver_name character varying, par_mailserver_type character varying, par_port integer, par_username character varying, par_password character varying, par_use_default_credentials smallint, par_enable_ssl smallint, par_timeout integer, par_no_credential_change smallint, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 435 (class 1255 OID 17145)
-- Name: sysmail_update_profile_sp(integer, character varying, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_update_profile_sp(par_profile_id integer DEFAULT NULL::integer, par_profile_name character varying DEFAULT NULL::character varying, par_description character varying DEFAULT NULL::character varying, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_rc INTEGER;
  var_profileid INTEGER;
BEGIN

  SELECT t.par_profileid, t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_profile_sp
    (
      par_profile_id,
      par_profile_name,
      0::SMALLINT,
      1::SMALLINT
    ) t
    INTO var_profileid, var_rc;

  IF var_rc <> 0 THEN

    returncode := 1;
    RETURN;

  END IF;

  IF par_profile_name IS NOT NULL AND par_description IS NOT NULL THEN

    UPDATE aws_sqlserver_ext.sysmail_profile
       SET name = par_profile_name
         , description = par_description
     WHERE profile_id = var_profileid;

  ELSE

    IF par_profile_name IS NOT NULL THEN

      UPDATE aws_sqlserver_ext.sysmail_profile
         SET name = par_profile_name
       WHERE profile_id = var_profileid;

    ELSE

      IF par_description IS NOT NULL THEN

        UPDATE aws_sqlserver_ext.sysmail_profile
           SET description = par_description
         WHERE profile_id = var_profileid;

      ELSE

        RAISE 'Either par_profile_name or par_description parameter needs to be specified for update' USING ERRCODE := '50000';
        returncode := 1;
        RETURN;

      END IF;

    END IF;

  END IF;
  
  returncode := 0;
  RETURN;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_update_profile_sp(par_profile_id integer, par_profile_name character varying, par_description character varying, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 434 (class 1255 OID 17144)
-- Name: sysmail_update_profileaccount_sp(integer, character varying, integer, character varying, integer); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_update_profileaccount_sp(par_profile_id integer DEFAULT NULL::integer, par_profile_name character varying DEFAULT NULL::character varying, par_account_id integer DEFAULT NULL::integer, par_account_name character varying DEFAULT NULL::character varying, par_sequence_number integer DEFAULT NULL::integer, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_rc INTEGER;
  var_profileid INTEGER;
  var_accountid INTEGER;
BEGIN

  SELECT t.par_profileid, t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_profile_sp
    (
      par_profile_id,
      par_profile_name,
      0::SMALLINT,
      0::SMALLINT
    ) t
    INTO var_profileid, var_rc;

  IF var_rc <> 0 THEN

    returncode := 1;
    RETURN;

  END IF;

  SELECT t.par_accountid, t.returncode
    FROM aws_sqlserver_ext.sysmail_verify_account_sp
    (
      par_account_id,
      par_account_name,
      0::SMALLINT,
      0::SMALLINT
    ) t
    INTO var_accountid, var_rc;

  IF var_rc <> 0 THEN

    returncode := 2;
    RETURN;

  END IF;

  IF par_sequence_number IS NULL THEN

    RAISE 'Account sequence number must be supplied for update' USING ERRCODE := '50000';
    returncode := 3;
    RETURN;

  END IF;
  
  UPDATE aws_sqlserver_ext.sysmail_profileaccount
     SET sequence_number = par_sequence_number
   WHERE profile_id = var_profileid 
     AND account_id = var_accountid;
     
  returncode := 0;
  RETURN;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_update_profileaccount_sp(par_profile_id integer, par_profile_name character varying, par_account_id integer, par_account_name character varying, par_sequence_number integer, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 437 (class 1255 OID 17146)
-- Name: sysmail_verify_account_sp(integer, character varying, smallint, smallint); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_verify_account_sp(par_account_id integer, par_account_name character varying, par_allow_both_nulls smallint, par_allow_id_name_mismatch smallint, OUT par_accountid integer, OUT returncode integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
BEGIN

  /* at least one parameter must be supplied */
  IF par_allow_both_nulls = 0 THEN

    IF par_account_id IS NULL AND par_account_name IS NULL THEN

      RAISE 'Both % parameters (id and name) cannot be NULL', 'account' USING ERRCODE := '50000';
      returncode := 1;
      RETURN;

    END IF;

  END IF;

  /* use both parameters */
  IF (par_allow_id_name_mismatch = 0) AND (par_account_id IS NOT NULL AND par_account_name IS NOT NULL) THEN

    SELECT account_id
      INTO par_accountid
      FROM aws_sqlserver_ext.sysmail_account
     WHERE account_id = par_account_id
     AND name = par_account_name;

    IF par_accountid IS NULL /* id and name do not match */ THEN

      RAISE 'Both % parameters (id and name) do not point to the same object', 'account' USING ERRCODE := '50000';
      returncode := 2;
      RETURN;

    END IF;

  ELSE

    IF par_account_id IS NOT NULL /* use id */ THEN

      SELECT account_id
        INTO par_accountid
        FROM aws_sqlserver_ext.sysmail_account
       WHERE account_id = par_account_id;
    
      IF par_accountid IS NULL /* id is invalid */ THEN

        RAISE '% id is not valid', 'account' USING ERRCODE := '50000';
        returncode := 3;
        RETURN;

      END IF;

    ELSE

      IF par_account_name IS NOT NULL /* use name */ THEN

        SELECT account_id
          INTO par_accountid
          FROM aws_sqlserver_ext.sysmail_account
         WHERE name = par_account_name;

        IF par_accountid IS NULL /* name is invalid */ THEN

          RAISE '% name is not valid', 'account' USING ERRCODE := '50000';
          returncode := 4;
          RETURN;

        END IF;

      END IF;

    END IF;

  END IF;

  /* SUCCESS */  
  returncode := 0;
  RETURN;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_verify_account_sp(par_account_id integer, par_account_name character varying, par_allow_both_nulls smallint, par_allow_id_name_mismatch smallint, OUT par_accountid integer, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 438 (class 1255 OID 17147)
-- Name: sysmail_verify_addressparams_sp(text, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_verify_addressparams_sp(par_address text, par_parameter_name character varying, OUT returncode integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_commaIndex INTEGER;
BEGIN

  IF par_address IS NOT NULL AND LOWER(par_address) != LOWER('') THEN

    var_commaIndex := STRPOS(par_address, ',');

    IF var_commaIndex > 0 THEN

      RAISE 'The specified "%" cannot use commas (,) to separate addresses: "%". To continue, use semicolons (;) to separate addresses.', par_parameter_name, par_address USING ERRCODE := '50000';
      returncode := 1;
      RETURN;

    END IF;

  END IF;
  
  returncode := 0;
  RETURN;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_verify_addressparams_sp(par_address text, par_parameter_name character varying, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 439 (class 1255 OID 17148)
-- Name: sysmail_verify_profile_sp(integer, character varying, smallint, smallint); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.sysmail_verify_profile_sp(par_profile_id integer, par_profile_name character varying, par_allow_both_nulls smallint, par_allow_id_name_mismatch smallint, OUT par_profileid integer, OUT returncode integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
BEGIN

  IF par_allow_both_nulls = 0
  THEN /* at least one parameter must be supplied */

    IF par_profile_id IS NULL AND par_profile_name IS NULL THEN

      RAISE 'Both % parameters (id and name) cannot be NULL', 'profile' USING ERRCODE := '50000';
      returncode := 1;
      RETURN;

    END IF;

  END IF;

  /* use both parameters */
  IF (par_allow_id_name_mismatch = 0) AND (par_profile_id IS NOT NULL AND par_profile_name IS NOT NULL) THEN

    SELECT profile_id
      INTO par_profileid
      FROM aws_sqlserver_ext.sysmail_profile
     WHERE profile_id = par_profile_id
     AND name = par_profile_name;

    IF (par_profileid IS NULL) /* id and name do not match */
    THEN

      RAISE 'Both % parameters (id and name) do not point to the same object', 'profile' USING ERRCODE := '50000';
      returncode := 2;
      RETURN;

    END IF;

  ELSE 

    IF par_profile_id IS NOT NULL /* use id */ THEN

      SELECT profile_id
        INTO par_profileid
        FROM aws_sqlserver_ext.sysmail_profile
       WHERE profile_id = par_profile_id;

      IF par_profileid IS NULL /* id is invalid */ THEN

        RAISE '% id is not valid', 'profile' USING ERRCODE := '50000';
        returncode := 3;
        RETURN;

      END IF;

    ELSE

      IF par_profile_name IS NOT NULL /* use name */ THEN

        SELECT profile_id
          INTO par_profileid
          FROM aws_sqlserver_ext.sysmail_profile
         WHERE name = par_profile_name;

        IF par_profileid IS NULL /* name is invalid */ THEN

          RAISE '% name is not valid', 'profile' USING ERRCODE := '50000';
          returncode := 4;
          RETURN;

        END IF;

      END IF;

    END IF;

  END IF;
  
  returncode := 0;
  RETURN;

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.sysmail_verify_profile_sp(par_profile_id integer, par_profile_name character varying, par_allow_both_nulls smallint, par_allow_id_name_mismatch smallint, OUT par_profileid integer, OUT returncode integer) OWNER TO postgres;

--
-- TOC entry 378 (class 1255 OID 17043)
-- Name: timefromparts(numeric, numeric, numeric, numeric, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.timefromparts(p_hour numeric, p_minute numeric, p_seconds numeric, p_fractions numeric, p_precision numeric) RETURNS time without time zone
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
    v_fractions VARCHAR;
    v_precision SMALLINT;
    v_err_message VARCHAR;
    v_calc_seconds NUMERIC;
BEGIN
    v_fractions := floor(p_fractions)::INTEGER::VARCHAR;
    v_precision := p_precision::SMALLINT;

    IF (scale(p_precision) > 0) THEN
        RAISE most_specific_type_mismatch;
    ELSIF ((p_hour NOT BETWEEN 0 AND 23) OR
           (p_minute NOT BETWEEN 0 AND 59) OR
           (p_seconds NOT BETWEEN 0 AND 59) OR
           (p_fractions NOT BETWEEN 0 AND 9999999) OR
           (p_fractions != 0 AND char_length(v_fractions) > p_precision))
    THEN
        RAISE invalid_datetime_format;
    ELSIF (v_precision NOT BETWEEN 0 AND 7) THEN
        RAISE numeric_value_out_of_range;
    END IF;

    v_calc_seconds := format('%s.%s',
                             floor(p_seconds)::SMALLINT,
                             substring(rpad(lpad(v_fractions, v_precision, '0'), 7, '0'), 1, 6))::NUMERIC;

    RETURN make_time(floor(p_hour)::SMALLINT,
                     floor(p_minute)::SMALLINT,
                     v_calc_seconds);
EXCEPTION
    WHEN most_specific_type_mismatch THEN
        RAISE USING MESSAGE := 'Scale argument is not valid. Valid expressions for data type DATETIME2 scale argument are integer constants and integer constant expressions.',
                    DETAIL := 'Use of incorrect "precision" parameter value during conversion process.',
                    HINT := 'Change "precision" parameter to the proper value and try again.';

    WHEN invalid_parameter_value THEN
        RAISE USING MESSAGE := format('Specified scale %s is invalid.', v_precision),
                    DETAIL := 'Use of incorrect "precision" parameter value during conversion process.',
                    HINT := 'Change "precision" parameter to the proper value and try again.';

    WHEN invalid_datetime_format THEN
        RAISE USING MESSAGE := 'Cannot construct data type time, some of the arguments have values which are not valid.',
                    DETAIL := 'Possible use of incorrect value of time part (which lies outside of valid range).',
                    HINT := 'Check each input argument belongs to the valid range and try again.';

    WHEN numeric_value_out_of_range THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
        v_err_message := upper(split_part(v_err_message, ' ', 1));

        RAISE USING MESSAGE := format('Error while trying to cast to %s data type.', v_err_message),
                    DETAIL := format('Source value is out of %s data type range.', v_err_message),
                    HINT := format('Correct the source value you are trying to cast to %s data type and try again.',
                                   v_err_message);
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.timefromparts(p_hour numeric, p_minute numeric, p_seconds numeric, p_fractions numeric, p_precision numeric) OWNER TO postgres;

--
-- TOC entry 3895 (class 0 OID 0)
-- Dependencies: 378
-- Name: FUNCTION timefromparts(p_hour numeric, p_minute numeric, p_seconds numeric, p_fractions numeric, p_precision numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.timefromparts(p_hour numeric, p_minute numeric, p_seconds numeric, p_fractions numeric, p_precision numeric) IS 'This function returns a fully initialized TIME value, constructed from separate time parts.';


--
-- TOC entry 379 (class 1255 OID 17044)
-- Name: timefromparts(text, text, text, text, text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.timefromparts(p_hour text, p_minute text, p_seconds text, p_fractions text, p_precision text) RETURNS time without time zone
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
    v_err_message VARCHAR;
BEGIN
    RETURN aws_sqlserver_ext.timefromparts(p_hour::NUMERIC, p_minute::NUMERIC,
                                           p_seconds::NUMERIC, p_fractions::NUMERIC,
                                           p_precision::NUMERIC);
EXCEPTION
    WHEN invalid_text_representation THEN
        GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
        v_err_message := substring(lower(v_err_message), 'numeric\:\s\"(.*)\"');

        RAISE USING MESSAGE := format('Error while trying to convert "%s" value to NUMERIC data type.', v_err_message),
                    DETAIL := 'Supplied string value contains illegal characters.',
                    HINT := 'Correct supplied value, remove all illegal characters and try again.';
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.timefromparts(p_hour text, p_minute text, p_seconds text, p_fractions text, p_precision text) OWNER TO postgres;

--
-- TOC entry 3896 (class 0 OID 0)
-- Dependencies: 379
-- Name: FUNCTION timefromparts(p_hour text, p_minute text, p_seconds text, p_fractions text, p_precision text); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.timefromparts(p_hour text, p_minute text, p_seconds text, p_fractions text, p_precision text) IS 'This function returns a fully initialized TIME value, constructed from separate time parts.';


--
-- TOC entry 440 (class 1255 OID 17149)
-- Name: tomsbit(numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.tomsbit(in_str numeric) RETURNS smallint
    LANGUAGE plpgsql
    AS $$
BEGIN
  CASE
    WHEN in_str < 0 OR in_str > 0 THEN RETURN 1;
    ELSE RETURN 0;
  END CASE;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.tomsbit(in_str numeric) OWNER TO postgres;

--
-- TOC entry 441 (class 1255 OID 17150)
-- Name: tomsbit(character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.tomsbit(in_str character varying) RETURNS smallint
    LANGUAGE plpgsql
    AS $$
BEGIN
  CASE
    WHEN LOWER(in_str) = 'true' OR in_str = '1' THEN RETURN 1;
    WHEN LOWER(in_str) = 'false' OR in_str = '0' THEN RETURN 0;
    ELSE RETURN 0;
  END CASE;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.tomsbit(in_str character varying) OWNER TO postgres;

--
-- TOC entry 357 (class 1255 OID 17061)
-- Name: try_conv_date_to_string(text, date, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.try_conv_date_to_string(p_datatype text, p_dateval date, p_style numeric DEFAULT 20) RETURNS text
    LANGUAGE plpgsql STRICT
    AS $$
BEGIN
    RETURN aws_sqlserver_ext.conv_date_to_string(p_datatype,
                                                 p_dateval,
                                                 p_style);
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.try_conv_date_to_string(p_datatype text, p_dateval date, p_style numeric) OWNER TO postgres;

--
-- TOC entry 3897 (class 0 OID 0)
-- Dependencies: 357
-- Name: FUNCTION try_conv_date_to_string(p_datatype text, p_dateval date, p_style numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.try_conv_date_to_string(p_datatype text, p_dateval date, p_style numeric) IS 'This function converts the DATE value into a character string, according to specified style (conversion mask). 
If the conversion not successful, the function returns NULL.';


--
-- TOC entry 358 (class 1255 OID 17062)
-- Name: try_conv_datetime_to_string(text, text, timestamp without time zone, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.try_conv_datetime_to_string(p_datatype text, p_src_datatype text, p_datetimeval timestamp without time zone, p_style numeric DEFAULT '-1'::integer) RETURNS text
    LANGUAGE plpgsql STRICT
    AS $$
BEGIN
    RETURN aws_sqlserver_ext.conv_datetime_to_string(p_datatype,
                                                     p_src_datatype,
                                                     p_datetimeval,
                                                     p_style);
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.try_conv_datetime_to_string(p_datatype text, p_src_datatype text, p_datetimeval timestamp without time zone, p_style numeric) OWNER TO postgres;

--
-- TOC entry 3898 (class 0 OID 0)
-- Dependencies: 358
-- Name: FUNCTION try_conv_datetime_to_string(p_datatype text, p_src_datatype text, p_datetimeval timestamp without time zone, p_style numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.try_conv_datetime_to_string(p_datatype text, p_src_datatype text, p_datetimeval timestamp without time zone, p_style numeric) IS 'This function converts the DATETIME value into a character string, according to specified style (conversion mask). 
If the conversion not successful, the function returns NULL.';


--
-- TOC entry 360 (class 1255 OID 17064)
-- Name: try_conv_string_to_date(text, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.try_conv_string_to_date(p_datestring text, p_style numeric DEFAULT 0) RETURNS date
    LANGUAGE plpgsql STRICT
    AS $$
BEGIN
    RETURN aws_sqlserver_ext.conv_string_to_date(p_datestring,
                                                 p_style);
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.try_conv_string_to_date(p_datestring text, p_style numeric) OWNER TO postgres;

--
-- TOC entry 3899 (class 0 OID 0)
-- Dependencies: 360
-- Name: FUNCTION try_conv_string_to_date(p_datestring text, p_style numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.try_conv_string_to_date(p_datestring text, p_style numeric) IS 'This function parses the TEXT string and converts it into a DATE value, according to specified style (conversion mask). 
If the conversion not successful, the function returns NULL.';


--
-- TOC entry 361 (class 1255 OID 17065)
-- Name: try_conv_string_to_datetime(text, text, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.try_conv_string_to_datetime(p_datatype text, p_datetimestring text, p_style numeric DEFAULT 0) RETURNS timestamp without time zone
    LANGUAGE plpgsql STRICT
    AS $$
BEGIN
    RETURN aws_sqlserver_ext.conv_string_to_datetime(p_datatype,
                                                     p_datetimestring ,
                                                     p_style);
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.try_conv_string_to_datetime(p_datatype text, p_datetimestring text, p_style numeric) OWNER TO postgres;

--
-- TOC entry 3900 (class 0 OID 0)
-- Dependencies: 361
-- Name: FUNCTION try_conv_string_to_datetime(p_datatype text, p_datetimestring text, p_style numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.try_conv_string_to_datetime(p_datatype text, p_datetimestring text, p_style numeric) IS 'This function parses the TEXT string and converts it into a DATETIME value, according to specified style (conversion mask). 
If the conversion not successfull, the function returns NULL.';


--
-- TOC entry 362 (class 1255 OID 17066)
-- Name: try_conv_string_to_time(text, text, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.try_conv_string_to_time(p_datatype text, p_timestring text, p_style numeric DEFAULT 0) RETURNS time without time zone
    LANGUAGE plpgsql STRICT
    AS $$
BEGIN
    RETURN aws_sqlserver_ext.conv_string_to_time(p_datatype,
                                                 p_timestring,
                                                 p_style);
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.try_conv_string_to_time(p_datatype text, p_timestring text, p_style numeric) OWNER TO postgres;

--
-- TOC entry 3901 (class 0 OID 0)
-- Dependencies: 362
-- Name: FUNCTION try_conv_string_to_time(p_datatype text, p_timestring text, p_style numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.try_conv_string_to_time(p_datatype text, p_timestring text, p_style numeric) IS 'This function parses the TEXT string and converts it into a TIME value, according to specified style (conversion mask). 
If the conversion not successfull, the function returns NULL.';


--
-- TOC entry 359 (class 1255 OID 17063)
-- Name: try_conv_time_to_string(text, text, time without time zone, numeric); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.try_conv_time_to_string(p_datatype text, p_src_datatype text, p_timeval time without time zone, p_style numeric DEFAULT 25) RETURNS text
    LANGUAGE plpgsql STRICT
    AS $$
BEGIN
    RETURN aws_sqlserver_ext.conv_time_to_string(p_datatype,
                                                 p_src_datatype,
                                                 p_timeval,
                                                 p_style);
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.try_conv_time_to_string(p_datatype text, p_src_datatype text, p_timeval time without time zone, p_style numeric) OWNER TO postgres;

--
-- TOC entry 3902 (class 0 OID 0)
-- Dependencies: 359
-- Name: FUNCTION try_conv_time_to_string(p_datatype text, p_src_datatype text, p_timeval time without time zone, p_style numeric); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.try_conv_time_to_string(p_datatype text, p_src_datatype text, p_timeval time without time zone, p_style numeric) IS 'This function converts the TIME value into a character string, according to specified style (conversion mask). 
If the conversion not successful, the function returns NULL.';


--
-- TOC entry 366 (class 1255 OID 17073)
-- Name: try_parse_to_date(text, text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.try_parse_to_date(p_datestring text, p_culture text DEFAULT NULL::text) RETURNS date
    LANGUAGE plpgsql STRICT
    AS $$
BEGIN
    RETURN aws_sqlserver_ext.parse_to_date(p_datestring,
                                           p_culture);
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.try_parse_to_date(p_datestring text, p_culture text) OWNER TO postgres;

--
-- TOC entry 3903 (class 0 OID 0)
-- Dependencies: 366
-- Name: FUNCTION try_parse_to_date(p_datestring text, p_culture text); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.try_parse_to_date(p_datestring text, p_culture text) IS 'This function parses the TEXT string and translate it into a DATE value, according to specified culture (conversion mask). 
If the conversion not successful, the function returns NULL.';


--
-- TOC entry 367 (class 1255 OID 17074)
-- Name: try_parse_to_datetime(text, text, text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.try_parse_to_datetime(p_datatype text, p_datetimestring text, p_culture text DEFAULT ''::text) RETURNS timestamp without time zone
    LANGUAGE plpgsql STRICT
    AS $$
BEGIN
    RETURN aws_sqlserver_ext.try_parse_to_datetime(p_datatype,
                                                   p_datestring,
                                                   p_culture);
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.try_parse_to_datetime(p_datatype text, p_datetimestring text, p_culture text) OWNER TO postgres;

--
-- TOC entry 3904 (class 0 OID 0)
-- Dependencies: 367
-- Name: FUNCTION try_parse_to_datetime(p_datatype text, p_datetimestring text, p_culture text); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.try_parse_to_datetime(p_datatype text, p_datetimestring text, p_culture text) IS 'This function parses the TEXT string and translate it into a DATETIME value, according to specified culture (conversion mask). 
If the conversion not successful, the function returns NULL.';


--
-- TOC entry 374 (class 1255 OID 17075)
-- Name: try_parse_to_time(text, text, text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.try_parse_to_time(p_datatype text, p_srctimestring text, p_culture text DEFAULT ''::text) RETURNS timestamp without time zone
    LANGUAGE plpgsql STRICT
    AS $$
BEGIN
    RETURN aws_sqlserver_ext.parse_to_time(p_datatype,
                                           p_srctimestring,
                                           p_culture);
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$;


ALTER FUNCTION aws_sqlserver_ext.try_parse_to_time(p_datatype text, p_srctimestring text, p_culture text) OWNER TO postgres;

--
-- TOC entry 3905 (class 0 OID 0)
-- Dependencies: 374
-- Name: FUNCTION try_parse_to_time(p_datatype text, p_srctimestring text, p_culture text); Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON FUNCTION aws_sqlserver_ext.try_parse_to_time(p_datatype text, p_srctimestring text, p_culture text) IS 'This function parses the TEXT string and translate it into a TIME value, according to specified culture (conversion mask). 
If the conversion not successful, the function returns NULL.';


--
-- TOC entry 442 (class 1255 OID 17151)
-- Name: update_job(integer, character varying); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.update_job(p_job integer, p_error_message character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  var_enabled smallint;
  var_freq_type integer;
  var_freq_interval integer;
  var_freq_subday_type integer;
  var_freq_subday_interval integer;
  var_freq_relative_interval integer;
  var_freq_recurrence_factor integer;
  var_tmp_interval varchar(50);
  var_job_id integer;
  var_schedule_id integer;
  var_job_step_id integer;
  var_step_id integer;
  var_step_name VARCHAR(128);
BEGIN
  /*
  var_job_step_id := p_job;

  SELECT jst.job_id, jsc.schedule_id, jst.step_name, jst.step_id 
    FROM aws_sqlserver_ext.sysjobsteps jst
   INNER JOIN aws_sqlserver_ext.sysjobschedules jsc
      ON jsc.job_id = jst.job_id
    INTO var_job_id, var_schedule_id, var_step_name, var_step_id  
   WHERE jst.job_step_id = var_job_step_id;
  */
  INSERT 
    INTO aws_sqlserver_ext.sysjobhistory (
         job_id
       , step_id
       , step_name
       , sql_message_id
       , sql_severity
       , message
       , run_status
       , run_date
       , run_time
       , run_duration
       , operator_id_emailed
       , operator_id_netsent
       , operator_id_paged
       , retries_attempted
       , server)
  VALUES (
         p_job
       , 0 -- var_step_id
       , ''--var_step_name
       , 0
       , 0
       , p_error_message
       , 0
       , now()::date
       , now()::time
       , 0
       , 0
       , 0
       , 0
       , 0
       , ''::character varying);
  
  -- PERFORM aws_sqlserver_ext.sp_set_next_run (var_job_id, var_schedule_id);

END;
$$;


ALTER FUNCTION aws_sqlserver_ext.update_job(p_job integer, p_error_message character varying) OWNER TO postgres;

--
-- TOC entry 436 (class 1255 OID 17356)
-- Name: waitfor_delay(text); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.waitfor_delay(time_to_pass text) RETURNS void
    LANGUAGE sql
    AS $_$
  SELECT pg_sleep(EXTRACT(HOUR FROM $1::time)*60*60 +
                  EXTRACT(MINUTE FROM $1::time)*60 +
                  TRUNC(EXTRACT(SECOND FROM $1::time)) +
                  aws_sqlserver_ext.round_fractseconds(
                                                        (
                                                          EXTRACT(MILLISECONDS FROM $1::time)
                                                          - TRUNC(EXTRACT(SECOND FROM $1::time)) * 1000
                                                        )::numeric
                                                      )/1000::numeric);
$_$;


ALTER FUNCTION aws_sqlserver_ext.waitfor_delay(time_to_pass text) OWNER TO postgres;

--
-- TOC entry 414 (class 1255 OID 17355)
-- Name: waitfor_delay(timestamp without time zone); Type: FUNCTION; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE FUNCTION aws_sqlserver_ext.waitfor_delay(time_to_pass timestamp without time zone) RETURNS void
    LANGUAGE sql
    AS $_$
  SELECT pg_sleep(EXTRACT(HOUR FROM $1::time)*60*60 +
                  EXTRACT(MINUTE FROM $1::time)*60 +
                  TRUNC(EXTRACT(SECOND FROM $1::time)) +
                  aws_sqlserver_ext.round_fractseconds(
                                                        (
                                                          EXTRACT(MILLISECONDS FROM $1::time)
                                                          - TRUNC(EXTRACT(SECOND FROM $1::time)) * 1000
                                                        )::numeric
                                                      )/1000::numeric);
$_$;


ALTER FUNCTION aws_sqlserver_ext.waitfor_delay(time_to_pass timestamp without time zone) OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 17164)
-- Name: information_schema_check_constraints; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.information_schema_check_constraints AS
 SELECT current_database() AS constraint_catalog,
    s.nspname AS constraint_schema,
    c.conname AS constraint_name,
    pg_get_constraintdef(c.oid) AS check_clause
   FROM (pg_constraint c
     JOIN pg_namespace s ON ((s.oid = c.connamespace)))
  WHERE ((s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name])) AND (c.contype = 'c'::"char"));


ALTER TABLE aws_sqlserver_ext.information_schema_check_constraints OWNER TO postgres;

--
-- TOC entry 244 (class 1259 OID 17169)
-- Name: information_schema_columns; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.information_schema_columns AS
 SELECT current_database() AS table_catalog,
    s.nspname AS table_schema,
    c.relname AS table_name,
    a.attname AS column_name,
    a.attnum AS ordinal_position,
    pg_get_expr(d.adbin, d.adrelid) AS column_default,
        CASE
            WHEN a.attnotnull THEN 'NO'::character varying(3)
            ELSE 'YES'::character varying(3)
        END AS is_nullable,
    format_type(t.oid, NULL::integer) AS data_type,
    a.attlen AS character_maximum_length,
    a.attlen AS character_octet_length,
    NULL::integer AS numeric_precision,
    NULL::integer AS numeric_precision_radix,
    NULL::integer AS numeric_scale,
    NULL::integer AS datetime_precision,
    NULL::character varying(128) AS character_set_catalog,
    NULL::character varying(128) AS character_set_schema,
    NULL::character varying(128) AS character_set_name,
    NULL::character varying(128) AS collation_catalog,
    NULL::character varying(128) AS collation_schema,
    coll.collname AS collation_name,
    NULL::character varying(128) AS domain_catalog,
    NULL::character varying(128) AS domain_schema,
        CASE t.typtype
            WHEN 'd'::"char" THEN (t.typname)::character varying(128)
            ELSE NULL::character varying(128)
        END AS domain_name
   FROM (((((pg_attribute a
     JOIN pg_class c ON (((c.oid = a.attrelid) AND (c.relkind = 'r'::"char"))))
     LEFT JOIN pg_attrdef d ON (((d.adrelid = c.oid) AND (d.adnum = a.attnum))))
     JOIN pg_namespace s ON ((s.oid = c.relnamespace)))
     JOIN pg_type t ON ((t.oid = a.atttypid)))
     LEFT JOIN pg_collation coll ON ((coll.oid = t.typcollation)))
  WHERE (s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name]));


ALTER TABLE aws_sqlserver_ext.information_schema_columns OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 17174)
-- Name: information_schema_constraint_column_usage; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.information_schema_constraint_column_usage AS
 SELECT current_database() AS table_catalog,
    s.nspname AS table_schema,
    t.relname AS table_name,
    a.attname AS column_name,
    current_database() AS constraint_catalog,
    s.nspname AS constraint_schema,
    c.conname AS constraint_name
   FROM (((pg_constraint c
     JOIN pg_namespace s ON ((s.oid = c.connamespace)))
     JOIN pg_class t ON ((t.oid = c.conrelid)))
     JOIN pg_attribute a ON (((a.attrelid = c.conrelid) AND (a.attnum = ANY (c.conkey)))))
  WHERE (s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name]));


ALTER TABLE aws_sqlserver_ext.information_schema_constraint_column_usage OWNER TO postgres;

--
-- TOC entry 246 (class 1259 OID 17179)
-- Name: information_schema_constraint_table_usage; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.information_schema_constraint_table_usage AS
 SELECT current_database() AS table_catalog,
    s.nspname AS table_schema,
    t.relname AS table_name,
    current_database() AS constraint_catalog,
    s.nspname AS constraint_schema,
    c.conname AS constraint_name
   FROM ((pg_constraint c
     JOIN pg_namespace s ON ((s.oid = c.connamespace)))
     JOIN pg_class t ON ((t.oid = c.conrelid)))
  WHERE (s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name]));


ALTER TABLE aws_sqlserver_ext.information_schema_constraint_table_usage OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 17184)
-- Name: information_schema_key_column_usage; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.information_schema_key_column_usage AS
 SELECT current_database() AS constraint_catalog,
    s.nspname AS constraint_schema,
    c.conname AS constraint_name,
    current_database() AS table_catalog,
    s.nspname AS table_schema,
    t.relname AS table_name,
    a.attname AS column_name,
    a.attnum AS ordinal_position
   FROM (((pg_constraint c
     JOIN pg_attribute a ON (((a.attrelid = c.conrelid) AND (a.attnum = ANY (c.conkey)))))
     JOIN pg_namespace s ON ((s.oid = c.connamespace)))
     JOIN pg_class t ON ((t.oid = c.conrelid)))
  WHERE ((s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name])) AND (c.contype = 'p'::"char"));


ALTER TABLE aws_sqlserver_ext.information_schema_key_column_usage OWNER TO postgres;

--
-- TOC entry 248 (class 1259 OID 17189)
-- Name: information_schema_referential_constraints; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.information_schema_referential_constraints AS
 SELECT current_database() AS constraint_catalog,
    s.nspname AS constraint_schema,
    c.conname AS constraint_name,
    current_database() AS unique_constraint_catalog,
    ( SELECT pk.conname
           FROM pg_constraint pk
          WHERE ((pk.conrelid = c.confrelid) AND (pk.contype = 'p'::"char"))
         LIMIT 1) AS conname,
    'SIMPLE'::character varying(7) AS match_option,
        CASE c.confupdtype
            WHEN 'a'::"char" THEN 'NO_ACTION'::text
            WHEN 'r'::"char" THEN 'NO_ACTION'::text
            WHEN 'c'::"char" THEN 'CASCADE'::text
            WHEN 'n'::"char" THEN 'SET_NULL'::text
            WHEN 'd'::"char" THEN 'SET_DEFAULT'::text
            ELSE NULL::text
        END AS update_rule,
        CASE c.confdeltype
            WHEN 'a'::"char" THEN 'NO_ACTION'::text
            WHEN 'r'::"char" THEN 'NO_ACTION'::text
            WHEN 'c'::"char" THEN 'CASCADE'::text
            WHEN 'n'::"char" THEN 'SET_NULL'::text
            WHEN 'd'::"char" THEN 'SET_DEFAULT'::text
            ELSE NULL::text
        END AS delete_rule
   FROM (pg_constraint c
     JOIN pg_namespace s ON ((s.oid = c.connamespace)))
  WHERE ((s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name])) AND (c.contype = 'f'::"char"));


ALTER TABLE aws_sqlserver_ext.information_schema_referential_constraints OWNER TO postgres;

--
-- TOC entry 249 (class 1259 OID 17194)
-- Name: information_schema_routines; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.information_schema_routines AS
 SELECT current_database() AS specific_catalog,
    s.nspname AS specific_schema,
    p.proname AS specific_name,
    current_database() AS routine_catalog,
    s.nspname AS routine_schema,
    p.proname AS routine_name,
        CASE format_type(p.prorettype, NULL::integer)
            WHEN 'void'::text THEN 'PROCEDURE'::character varying(20)
            ELSE 'FUNCTION'::character varying(20)
        END AS routine_type,
    NULL::character varying(128) AS module_catalog,
    NULL::character varying(128) AS module_schema,
    NULL::character varying(128) AS module_name,
    NULL::character varying(128) AS udt_catalog,
    NULL::character varying(128) AS udt_schema,
    NULL::character varying(128) AS udt_name,
        CASE format_type(p.prorettype, NULL::integer)
            WHEN 'void'::text THEN (NULL::character varying(128))::text
            ELSE format_type(p.prorettype, NULL::integer)
        END AS data_type,
    t.typlen AS character_maximum_length,
    t.typlen AS character_octet_length,
    NULL::character varying(128) AS collation_catalog,
    NULL::character varying(128) AS collation_schema,
    c.collname,
    NULL::character varying(128) AS character_set_catalog,
    NULL::character varying(128) AS character_set_schema,
    ( SELECT pg_encoding_to_char(pg_database.encoding) AS pg_encoding_to_char
           FROM pg_database
          WHERE (pg_database.datname = current_database())) AS character_set_name,
    NULL::smallint AS numeric_precision,
    NULL::smallint AS numeric_precision_radix,
    NULL::smallint AS numeric_scale,
    NULL::smallint AS datetime_precision,
    NULL::character varying(30) AS interval_type,
    NULL::smallint AS interval_precision,
    NULL::character varying(128) AS type_udt_catalog,
    NULL::character varying(128) AS type_udt_schema,
    NULL::character varying(128) AS type_udt_name,
    NULL::character varying(128) AS scope_catalog,
    NULL::character varying(128) AS scope_schema,
    NULL::character varying(128) AS scope_name,
    NULL::bigint AS maximum_cardinality,
    NULL::character varying(128) AS dtd_identifier,
    'SQL'::character varying(30) AS routine_body,
    pg_get_functiondef(p.oid) AS routine_definition,
    NULL::character varying(128) AS external_name,
    NULL::character varying(30) AS external_language,
    NULL::character varying(30) AS parameter_style,
        CASE p.provolatile
            WHEN 'i'::"char" THEN 'YES'::text
            ELSE 'NO'::text
        END AS is_deterministic,
        CASE format_type(p.prorettype, NULL::integer)
            WHEN 'void'::text THEN 'MODIFIES'::character varying(30)
            ELSE 'READS'::character varying
        END AS sql_data_access,
        CASE
            WHEN p.proisstrict THEN 'NO'::character varying(10)
            ELSE NULL::character varying(10)
        END AS is_null_call,
    NULL::character varying(128) AS sql_path,
    'YES'::character varying(10) AS schema_level_routine,
    0 AS max_dynamic_result_sets,
    'NO'::character varying(10) AS is_user_defined_cast,
    'NO'::character varying(10) AS is_implicitly_invocable,
    NULL::timestamp without time zone AS created,
    NULL::timestamp without time zone AS last_altered
   FROM (((pg_proc p
     JOIN pg_namespace s ON ((s.oid = p.pronamespace)))
     JOIN pg_type t ON ((t.oid = p.prorettype)))
     LEFT JOIN pg_collation c ON ((c.oid = t.typcollation)))
  WHERE ((s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name])) AND pg_function_is_visible(p.oid));


ALTER TABLE aws_sqlserver_ext.information_schema_routines OWNER TO postgres;

--
-- TOC entry 250 (class 1259 OID 17199)
-- Name: information_schema_schemata; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.information_schema_schemata AS
 SELECT current_database() AS catalog_name,
    s.nspname AS schema_name,
    a.rolname AS schema_owner,
    NULL::character varying(6) AS default_character_set_catalog,
    NULL::character varying(6) AS default_character_set_schema,
    ( SELECT pg_encoding_to_char(pg_database.encoding) AS pg_encoding_to_char
           FROM pg_database
          WHERE (pg_database.datname = current_database())) AS default_character_set_name
   FROM (pg_namespace s
     JOIN pg_authid a ON ((a.oid = s.nspowner)))
  WHERE (has_schema_privilege((s.nspname)::text, 'USAGE'::text) AND (s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name])));


ALTER TABLE aws_sqlserver_ext.information_schema_schemata OWNER TO postgres;

--
-- TOC entry 251 (class 1259 OID 17204)
-- Name: information_schema_table_constraints; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.information_schema_table_constraints AS
 SELECT current_database() AS constraint_catalog,
    s.nspname AS constraint_schema,
    c.conname AS constraint_name,
    current_database() AS table_catalog,
    s.nspname AS table_schema,
    t.relname AS table_name,
        CASE c.contype
            WHEN 'c'::"char" THEN 'CHECK'::text
            WHEN 'f'::"char" THEN 'FOREIGN KEY'::text
            WHEN 'p'::"char" THEN 'PRIMARY KEY'::text
            WHEN 'u'::"char" THEN 'UNIQUE'::text
            ELSE 'OTHER'::text
        END AS constraint_type,
    'NO'::character varying(2) AS is_deferrable,
    'NO'::character varying(2) AS initially_deferred
   FROM ((pg_constraint c
     JOIN pg_namespace s ON ((s.oid = c.connamespace)))
     JOIN pg_class t ON ((t.oid = c.conrelid)))
  WHERE (s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name]));


ALTER TABLE aws_sqlserver_ext.information_schema_table_constraints OWNER TO postgres;

--
-- TOC entry 252 (class 1259 OID 17209)
-- Name: information_schema_tables; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.information_schema_tables AS
 SELECT current_database() AS table_catalog,
    s.nspname AS table_schema,
    t.tablename AS table_name,
    'BASE TABLE'::text AS table_type
   FROM ((pg_tables t
     JOIN pg_namespace s ON ((s.nspname = t.schemaname)))
     JOIN pg_class c ON (((c.relname = t.tablename) AND (c.relnamespace = s.oid))))
  WHERE (s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name]))
UNION ALL
 SELECT current_database() AS table_catalog,
    s.nspname AS table_schema,
    v.viewname AS table_name,
    'VIEW'::text AS table_type
   FROM ((pg_views v
     JOIN pg_namespace s ON ((s.nspname = v.schemaname)))
     JOIN pg_class c ON (((c.relname = v.viewname) AND (c.relnamespace = s.oid))))
  WHERE (s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name]));


ALTER TABLE aws_sqlserver_ext.information_schema_tables OWNER TO postgres;

--
-- TOC entry 253 (class 1259 OID 17214)
-- Name: information_schema_views; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.information_schema_views AS
 SELECT current_database() AS table_catalog,
    s.nspname AS table_schema,
    v.viewname AS table_name,
    v.definition AS view_definition,
    'NONE'::character varying(7) AS check_option,
    'NO'::character varying(2) AS is_updatable
   FROM ((pg_views v
     JOIN pg_namespace s ON ((s.nspname = v.schemaname)))
     JOIN pg_class c ON (((c.relname = v.viewname) AND (c.relnamespace = s.oid))))
  WHERE (s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name]));


ALTER TABLE aws_sqlserver_ext.information_schema_views OWNER TO postgres;

--
-- TOC entry 269 (class 1259 OID 17293)
-- Name: sys_all_columns; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_all_columns AS
 SELECT c.oid AS object_id,
    a.attname AS name,
    a.attnum AS column_id,
    t.oid AS system_type_id,
    t.oid AS user_type_id,
    a.attlen AS max_length,
    NULL::integer AS "precision",
    NULL::integer AS scale,
    coll.collname AS collation_name,
        CASE
            WHEN a.attnotnull THEN 0
            ELSE 1
        END AS is_nullable,
    0 AS is_ansi_padded,
    0 AS is_rowguidcol,
    0 AS is_identity,
    0 AS is_computed,
    0 AS is_filestream,
    0 AS is_replicated,
    0 AS is_non_sql_subscribed,
    0 AS is_merge_published,
    0 AS is_dts_replicated,
    0 AS is_xml_document,
    0 AS xml_collection_id,
    COALESCE(d.oid, (0)::oid) AS default_object_id,
    COALESCE(( SELECT pg_constraint.oid
           FROM pg_constraint
          WHERE ((pg_constraint.conrelid = t.oid) AND (pg_constraint.contype = 'c'::"char") AND (a.attnum = ANY (pg_constraint.conkey)))
         LIMIT 1), (0)::oid) AS rule_object_id,
    0 AS is_sparse,
    0 AS is_column_set,
    0 AS generated_always_type,
    'NOT_APPLICABLE'::character varying(60) AS generated_always_type_desc,
    NULL::integer AS encryption_type,
    NULL::character varying(64) AS encryption_type_desc,
    NULL::character varying AS encryption_algorithm_name,
    NULL::integer AS column_encryption_key_id,
    NULL::character varying AS column_encryption_key_database_name,
    0 AS is_hidden,
    0 AS is_masked
   FROM (((((pg_attribute a
     JOIN pg_class c ON ((c.oid = a.attrelid)))
     JOIN pg_type t ON ((t.oid = a.atttypid)))
     JOIN pg_namespace s ON ((s.oid = c.relnamespace)))
     LEFT JOIN pg_attrdef d ON (((c.oid = d.adrelid) AND (a.attnum = d.adnum))))
     LEFT JOIN pg_collation coll ON ((coll.oid = t.typcollation)))
  WHERE ((NOT a.attisdropped) AND (c.relkind = ANY (ARRAY['r'::"char", 'v'::"char", 'm'::"char", 'f'::"char", 'p'::"char"])) AND has_column_privilege(((quote_ident((s.nspname)::text) || '.'::text) || quote_ident((c.relname)::text)), (a.attname)::text, 'SELECT,INSERT,UPDATE,REFERENCES'::text));


ALTER TABLE aws_sqlserver_ext.sys_all_columns OWNER TO postgres;

--
-- TOC entry 268 (class 1259 OID 17288)
-- Name: sys_all_views; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_all_views AS
 SELECT t.relname AS name,
    t.oid AS object_id,
    NULL::integer AS principal_id,
    s.oid AS schema_id,
    0 AS parent_object_id,
    'V'::character varying(2) AS type,
    'VIEW'::character varying(60) AS type_desc,
    NULL::timestamp without time zone AS create_date,
    NULL::timestamp without time zone AS modify_date,
    0 AS is_ms_shipped,
    0 AS is_published,
    0 AS is_schema_published,
    0 AS with_check_option,
    0 AS is_date_correlation_view,
    0 AS is_tracked_by_cdc
   FROM (pg_class t
     JOIN pg_namespace s ON ((s.oid = t.relnamespace)))
  WHERE ((t.relkind = 'v'::"char") AND has_table_privilege(((quote_ident((s.nspname)::text) || '.'::text) || quote_ident((t.relname)::text)), 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER'::text));


ALTER TABLE aws_sqlserver_ext.sys_all_views OWNER TO postgres;

--
-- TOC entry 262 (class 1259 OID 17258)
-- Name: sys_foreign_keys; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_foreign_keys AS
 SELECT c.conname AS name,
    c.oid AS object_id,
    NULL::integer AS principal_id,
    s.oid AS schema_id,
    c.conrelid AS parent_object_id,
    'F'::character varying(2) AS type,
    'FOREIGN_KEY_CONSTRAINT'::character varying(60) AS type_desc,
    NULL::timestamp without time zone AS create_date,
    NULL::timestamp without time zone AS modify_date,
    0 AS is_ms_shipped,
    0 AS is_published,
    0 AS is_schema_published,
    c.confrelid AS referenced_object_id,
    c.confkey AS key_index_id,
    0 AS is_disabled,
    0 AS is_not_for_replication,
    0 AS is_not_trusted,
        CASE c.confdeltype
            WHEN 'a'::"char" THEN 0
            WHEN 'r'::"char" THEN 0
            WHEN 'c'::"char" THEN 1
            WHEN 'n'::"char" THEN 2
            WHEN 'd'::"char" THEN 3
            ELSE NULL::integer
        END AS delete_referential_action,
        CASE c.confdeltype
            WHEN 'a'::"char" THEN 'NO_ACTION'::text
            WHEN 'r'::"char" THEN 'NO_ACTION'::text
            WHEN 'c'::"char" THEN 'CASCADE'::text
            WHEN 'n'::"char" THEN 'SET_NULL'::text
            WHEN 'd'::"char" THEN 'SET_DEFAULT'::text
            ELSE NULL::text
        END AS delete_referential_action_desc,
        CASE c.confupdtype
            WHEN 'a'::"char" THEN 0
            WHEN 'r'::"char" THEN 0
            WHEN 'c'::"char" THEN 1
            WHEN 'n'::"char" THEN 2
            WHEN 'd'::"char" THEN 3
            ELSE NULL::integer
        END AS update_referential_action,
        CASE c.confupdtype
            WHEN 'a'::"char" THEN 'NO_ACTION'::text
            WHEN 'r'::"char" THEN 'NO_ACTION'::text
            WHEN 'c'::"char" THEN 'CASCADE'::text
            WHEN 'n'::"char" THEN 'SET_NULL'::text
            WHEN 'd'::"char" THEN 'SET_DEFAULT'::text
            ELSE NULL::text
        END AS update_referential_action_desc,
    1 AS is_system_named
   FROM (pg_constraint c
     JOIN pg_namespace s ON ((s.oid = c.connamespace)))
  WHERE ((c.contype = 'f'::"char") AND (s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name])));


ALTER TABLE aws_sqlserver_ext.sys_foreign_keys OWNER TO postgres;

--
-- TOC entry 261 (class 1259 OID 17253)
-- Name: sys_key_constraints; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_key_constraints AS
 SELECT c.conname AS name,
    c.oid AS object_id,
    NULL::integer AS principal_id,
    s.oid AS schema_id,
    c.conrelid AS parent_object_id,
        CASE c.contype
            WHEN 'p'::"char" THEN 'PK'::character varying(2)
            WHEN 'u'::"char" THEN 'UQ'::character varying(2)
            ELSE NULL::character varying
        END AS type,
        CASE c.contype
            WHEN 'p'::"char" THEN 'PRIMARY_KEY_CONSTRAINT'::character varying(60)
            WHEN 'u'::"char" THEN 'UNIQUE_CONSTRAINT'::character varying(60)
            ELSE NULL::character varying
        END AS type_desc,
    NULL::timestamp without time zone AS create_date,
    NULL::timestamp without time zone AS modify_date,
    c.conindid AS unique_index_id,
    0 AS is_ms_shipped,
    0 AS is_published,
    0 AS is_schema_published
   FROM (pg_constraint c
     JOIN pg_namespace s ON ((s.oid = c.connamespace)))
  WHERE (c.contype = 'p'::"char");


ALTER TABLE aws_sqlserver_ext.sys_key_constraints OWNER TO postgres;

--
-- TOC entry 265 (class 1259 OID 17273)
-- Name: sys_procedures; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_procedures AS
 SELECT p.proname AS name,
    p.oid AS object_id,
    NULL::integer AS principal_id,
    s.oid AS schema_id,
    0 AS parent_object_id,
        CASE format_type(p.prorettype, NULL::integer)
            WHEN 'void'::text THEN 'P'::character varying(2)
            ELSE
            CASE format_type(p.prorettype, NULL::integer)
                WHEN 'trigger'::text THEN 'TR'::character varying(2)
                ELSE 'FN'::character varying(2)
            END
        END AS type,
        CASE format_type(p.prorettype, NULL::integer)
            WHEN 'void'::text THEN 'SQL_STORED_PROCEDURE'::character varying(60)
            ELSE
            CASE format_type(p.prorettype, NULL::integer)
                WHEN 'trigger'::text THEN 'SQL_TRIGGER'::character varying(60)
                ELSE 'SQL_SCALAR_FUNCTION'::character varying(60)
            END
        END AS type_desc,
    NULL::timestamp without time zone AS create_date,
    NULL::timestamp without time zone AS modify_date,
    0 AS is_ms_shipped,
    0 AS is_published,
    0 AS is_schema_published
   FROM (pg_proc p
     JOIN pg_namespace s ON ((s.oid = p.pronamespace)))
  WHERE ((s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name])) AND pg_function_is_visible(p.oid));


ALTER TABLE aws_sqlserver_ext.sys_procedures OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 17228)
-- Name: sys_tables; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_tables AS
 SELECT t.relname AS name,
    t.oid AS object_id,
    NULL::integer AS principal_id,
    s.oid AS schema_id,
    0 AS parent_object_id,
    'U'::character varying(2) AS type,
    'USER_TABLE'::character varying(60) AS type_desc,
    NULL::timestamp without time zone AS create_date,
    NULL::timestamp without time zone AS modify_date,
    0 AS is_ms_shipped,
    0 AS is_published,
    0 AS is_schema_published,
        CASE t.reltoastrelid
            WHEN 0 THEN 0
            ELSE 1
        END AS lob_data_space_id,
    NULL::integer AS filestream_data_space_id,
    t.relnatts AS max_column_id_used,
    0 AS lock_on_bulk_load,
    1 AS uses_ansi_nulls,
    0 AS is_replicated,
    0 AS has_replication_filter,
    0 AS is_merge_published,
    0 AS is_sync_tran_subscribed,
    0 AS has_unchecked_assembly_data,
    0 AS text_in_row_limit,
    0 AS large_value_types_out_of_row,
    0 AS is_tracked_by_cdc,
    0 AS lock_escalation,
    'TABLE'::character varying(60) AS lock_escalation_desc,
    0 AS is_filetable,
    0 AS durability,
    'SCHEMA_AND_DATA'::character varying(60) AS durability_desc,
    0 AS is_memory_optimized,
        CASE t.relpersistence
            WHEN 't'::"char" THEN 2
            ELSE 0
        END AS temporal_type,
        CASE t.relpersistence
            WHEN 't'::"char" THEN 'SYSTEM_VERSIONED_TEMPORAL_TABLE'::text
            ELSE 'NON_TEMPORAL_TABLE'::text
        END AS temporal_type_desc,
    NULL::integer AS history_table_id,
    0 AS is_remote_data_archive_enabled,
    0 AS is_external
   FROM (pg_class t
     JOIN pg_namespace s ON ((s.oid = t.relnamespace)))
  WHERE ((t.relpersistence = ANY (ARRAY['p'::"char", 'u'::"char", 't'::"char"])) AND (t.relkind = 'r'::"char") AND has_table_privilege(((quote_ident((s.nspname)::text) || '.'::text) || quote_ident((t.relname)::text)), 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER'::text) AND (s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name])));


ALTER TABLE aws_sqlserver_ext.sys_tables OWNER TO postgres;

--
-- TOC entry 270 (class 1259 OID 17298)
-- Name: sys_all_objects; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_all_objects AS
 SELECT t.name,
    t.object_id,
    t.principal_id,
    t.schema_id,
    t.parent_object_id,
    'U'::text AS type,
    'USER_TABLE'::text AS type_desc,
    t.create_date,
    t.modify_date,
    t.is_ms_shipped,
    t.is_published,
    t.is_schema_published
   FROM aws_sqlserver_ext.sys_tables t
UNION ALL
 SELECT v.name,
    v.object_id,
    v.principal_id,
    v.schema_id,
    v.parent_object_id,
    'V'::text AS type,
    'VIEW'::text AS type_desc,
    v.create_date,
    v.modify_date,
    v.is_ms_shipped,
    v.is_published,
    v.is_schema_published
   FROM aws_sqlserver_ext.sys_all_views v
UNION ALL
 SELECT f.name,
    f.object_id,
    f.principal_id,
    f.schema_id,
    f.parent_object_id,
    'F'::text AS type,
    'FOREIGN_KEY_CONSTRAINT'::text AS type_desc,
    f.create_date,
    f.modify_date,
    f.is_ms_shipped,
    f.is_published,
    f.is_schema_published
   FROM aws_sqlserver_ext.sys_foreign_keys f
UNION ALL
 SELECT p.name,
    p.object_id,
    p.principal_id,
    p.schema_id,
    p.parent_object_id,
    'PK'::text AS type,
    'PRIMARY_KEY_CONSTRAINT'::text AS type_desc,
    p.create_date,
    p.modify_date,
    p.is_ms_shipped,
    p.is_published,
    p.is_schema_published
   FROM aws_sqlserver_ext.sys_key_constraints p
UNION ALL
 SELECT pr.name,
    pr.object_id,
    pr.principal_id,
    pr.schema_id,
    pr.parent_object_id,
    pr.type,
    pr.type_desc,
    pr.create_date,
    pr.modify_date,
    pr.is_ms_shipped,
    pr.is_published,
    pr.is_schema_published
   FROM aws_sqlserver_ext.sys_procedures pr
UNION ALL
 SELECT p.relname AS name,
    p.oid AS object_id,
    NULL::integer AS principal_id,
    s.oid AS schema_id,
    0 AS parent_object_id,
    'SO'::character varying(2) AS type,
    'SEQUENCE_OBJECT'::character varying(60) AS type_desc,
    NULL::timestamp without time zone AS create_date,
    NULL::timestamp without time zone AS modify_date,
    0 AS is_ms_shipped,
    0 AS is_published,
    0 AS is_schema_published
   FROM (pg_class p
     JOIN pg_namespace s ON ((s.oid = p.relnamespace)))
  WHERE (p.relkind = 'S'::"char");


ALTER TABLE aws_sqlserver_ext.sys_all_objects OWNER TO postgres;

--
-- TOC entry 259 (class 1259 OID 17243)
-- Name: sys_columns; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_columns AS
 SELECT c.oid AS object_id,
    a.attname AS name,
    a.attnum AS column_id,
    t.oid AS system_type_id,
    t.oid AS user_type_id,
    a.attlen AS max_length,
    NULL::integer AS "precision",
    NULL::integer AS scale,
    coll.collname AS collation_name,
        CASE
            WHEN a.attnotnull THEN 0
            ELSE 1
        END AS is_nullable,
    0 AS is_ansi_padded,
    0 AS is_rowguidcol,
    0 AS is_identity,
    0 AS is_computed,
    0 AS is_filestream,
    0 AS is_replicated,
    0 AS is_non_sql_subscribed,
    0 AS is_merge_published,
    0 AS is_dts_replicated,
    0 AS is_xml_document,
    0 AS xml_collection_id,
    COALESCE(d.oid, (0)::oid) AS default_object_id,
    COALESCE(( SELECT pg_constraint.oid
           FROM pg_constraint
          WHERE ((pg_constraint.conrelid = t.oid) AND (pg_constraint.contype = 'c'::"char") AND (a.attnum = ANY (pg_constraint.conkey)))
         LIMIT 1), (0)::oid) AS rule_object_id,
    0 AS is_sparse,
    0 AS is_column_set,
    0 AS generated_always_type,
    'NOT_APPLICABLE'::character varying(60) AS generated_always_type_desc,
    NULL::integer AS encryption_type,
    NULL::character varying(64) AS encryption_type_desc,
    NULL::character varying AS encryption_algorithm_name,
    NULL::integer AS column_encryption_key_id,
    NULL::character varying AS column_encryption_key_database_name,
    0 AS is_hidden,
    0 AS is_masked
   FROM (((((pg_attribute a
     JOIN pg_class c ON ((c.oid = a.attrelid)))
     JOIN pg_type t ON ((t.oid = a.atttypid)))
     JOIN pg_namespace s ON ((s.oid = c.relnamespace)))
     LEFT JOIN pg_attrdef d ON (((c.oid = d.adrelid) AND (a.attnum = d.adnum))))
     LEFT JOIN pg_collation coll ON ((coll.oid = t.typcollation)))
  WHERE ((NOT a.attisdropped) AND (c.relkind = ANY (ARRAY['r'::"char", 'v'::"char", 'm'::"char", 'f'::"char", 'p'::"char"])) AND (s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name])) AND has_column_privilege(((quote_ident((s.nspname)::text) || '.'::text) || quote_ident((c.relname)::text)), (a.attname)::text, 'SELECT,INSERT,UPDATE,REFERENCES'::text));


ALTER TABLE aws_sqlserver_ext.sys_columns OWNER TO postgres;

--
-- TOC entry 254 (class 1259 OID 17219)
-- Name: sys_databases; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_databases AS
 SELECT d.datname AS name,
    d.oid AS database_id,
    NULL::integer AS source_database_id,
    NULL::character varying(85) AS owner_sid,
    NULL::integer AS compatibility_level,
    d.datcollate AS collation_name,
    0 AS user_access,
    NULL::character varying(60) AS user_access_desc,
    0 AS is_read_only,
    0 AS is_auto_close_on,
    0 AS is_auto_shrink_on,
    0 AS state,
    'ONLINE'::character varying(60) AS state_desc,
    0 AS is_in_standby,
    0 AS is_cleanly_shutdown,
    0 AS is_supplemental_logging_enabled,
    0 AS snapshot_isolation_state,
    NULL::character varying(60) AS snapshot_isolation_state_desc,
    0 AS is_read_committed_snapshot_on,
    1 AS recovery_model,
    'FULL'::character varying(60) AS recovery_model_desc,
    0 AS page_verify_option,
    NULL::character varying(60) AS page_verify_option_desc,
    1 AS is_auto_create_stats_on,
    0 AS is_auto_update_stats_on,
    0 AS is_auto_update_stats_async_on,
    0 AS is_ansi_null_default_on,
    0 AS is_ansi_nulls_on,
    0 AS is_ansi_padding_on,
    0 AS is_ansi_warnings_on,
    0 AS is_arithabort_on,
    0 AS is_concat_null_yields_null_on,
    0 AS is_numeric_roundabort_on,
    0 AS is_quoted_identifier_on,
    0 AS is_recursive_triggers_on,
    0 AS is_cursor_close_on_commit_on,
    0 AS is_local_cursor_default,
    0 AS is_fulltext_enabled,
    0 AS is_trustworthy_on,
    0 AS is_db_chaining_on,
    0 AS is_parameterization_forced,
    0 AS is_master_key_encrypted_by_server,
    0 AS is_published,
    0 AS is_subscribed,
    0 AS is_merge_published,
    0 AS is_distributor,
    0 AS is_sync_with_backup,
    NULL::oid AS service_broker_guid,
    0 AS is_broker_enabled,
    0 AS log_reuse_wait,
    'NOTHING'::character varying(60) AS log_reuse_wait_desc,
    0 AS is_date_correlation_on,
    0 AS is_cdc_enabled,
    0 AS is_encrypted,
    0 AS is_honor_broker_priority_on,
    NULL::oid AS replica_id,
    NULL::oid AS group_database_id,
    NULL::oid AS default_language_lcid,
    NULL::character varying(128) AS default_language_name,
    NULL::oid AS default_fulltext_language_lcid,
    NULL::character varying(128) AS default_fulltext_language_name,
    NULL::integer AS is_nested_triggers_on,
    NULL::integer AS is_transform_noise_words_on,
    NULL::integer AS two_digit_year_cutoff,
    0 AS containment,
    'NONE'::character varying(60) AS containment_desc,
    0 AS target_recovery_time_in_seconds,
    0 AS is_federation_member,
    0 AS is_memory_optimized_elevate_to_snapshot_on,
    0 AS is_auto_create_stats_incremental_on,
    0 AS is_query_store_on,
    NULL::integer AS resource_pool_id
   FROM pg_database d;


ALTER TABLE aws_sqlserver_ext.sys_databases OWNER TO postgres;

--
-- TOC entry 263 (class 1259 OID 17263)
-- Name: sys_foreign_key_columns; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_foreign_key_columns AS
 SELECT DISTINCT c.oid AS constraint_object_id,
    c.confkey AS constraint_column_id,
    c.conrelid AS parent_object_id,
    a_con.attnum AS parent_column_id,
    c.confrelid AS referenced_object_id,
    a_conf.attnum AS referenced_column_id
   FROM ((pg_constraint c
     JOIN pg_attribute a_con ON (((a_con.attrelid = c.conrelid) AND (a_con.attnum = ANY (c.conkey)))))
     JOIN pg_attribute a_conf ON (((a_conf.attrelid = c.confrelid) AND (a_conf.attnum = ANY (c.confkey)))))
  WHERE (c.contype = 'f'::"char");


ALTER TABLE aws_sqlserver_ext.sys_foreign_key_columns OWNER TO postgres;

--
-- TOC entry 264 (class 1259 OID 17268)
-- Name: sys_identity_columns; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_identity_columns AS
 SELECT aws_sqlserver_ext.get_id_by_name(((c.oid)::text || (a.attname)::text)) AS object_id,
    a.attname AS name,
    a.attnum AS column_id,
    t.oid AS system_type_id,
    t.oid AS user_type_id,
    a.attlen AS max_length,
    NULL::integer AS "precision",
    NULL::integer AS scale,
    coll.collname AS collation_name,
        CASE
            WHEN a.attnotnull THEN 0
            ELSE 1
        END AS is_nullable,
    0 AS is_ansi_padded,
    0 AS is_rowguidcol,
    1 AS is_identity,
    0 AS is_computed,
    0 AS is_filestream,
    0 AS is_replicated,
    0 AS is_non_sql_subscribed,
    0 AS is_merge_published,
    0 AS is_dts_replicated,
    0 AS is_xml_document,
    0 AS xml_collection_id,
    COALESCE(d.oid, (0)::oid) AS default_object_id,
    COALESCE(( SELECT pg_constraint.oid
           FROM pg_constraint
          WHERE ((pg_constraint.conrelid = t.oid) AND (pg_constraint.contype = 'c'::"char") AND (a.attnum = ANY (pg_constraint.conkey)))
         LIMIT 1), (0)::oid) AS rule_object_id,
    0 AS is_sparse,
    0 AS is_column_set,
    0 AS generated_always_type,
    'NOT_APPLICABLE'::character varying(60) AS generated_always_type_desc,
    NULL::integer AS encryption_type,
    NULL::character varying(64) AS encryption_type_desc,
    NULL::character varying AS encryption_algorithm_name,
    NULL::integer AS column_encryption_key_id,
    NULL::character varying AS column_encryption_key_database_name,
    0 AS is_hidden,
    0 AS is_masked,
    NULL::bigint AS seed_value,
    NULL::bigint AS increment_value,
    aws_sqlserver_ext.get_sequence_value((pg_get_serial_sequence(((quote_ident((s.nspname)::text) || '.'::text) || quote_ident((c.relname)::text)), (a.attname)::text))::character varying) AS last_value
   FROM (((((pg_attribute a
     LEFT JOIN pg_attrdef d ON (((a.attrelid = d.adrelid) AND (a.attnum = d.adnum))))
     JOIN pg_class c ON ((c.oid = a.attrelid)))
     JOIN pg_namespace s ON ((s.oid = c.relnamespace)))
     LEFT JOIN pg_type t ON ((t.oid = a.atttypid)))
     LEFT JOIN pg_collation coll ON ((coll.oid = t.typcollation)))
  WHERE ((NOT a.attisdropped) AND (pg_get_serial_sequence(((quote_ident((s.nspname)::text) || '.'::text) || quote_ident((c.relname)::text)), (a.attname)::text) IS NOT NULL) AND (s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name])) AND has_sequence_privilege(pg_get_serial_sequence(((quote_ident((s.nspname)::text) || '.'::text) || quote_ident((c.relname)::text)), (a.attname)::text), 'USAGE,SELECT,UPDATE'::text));


ALTER TABLE aws_sqlserver_ext.sys_identity_columns OWNER TO postgres;

--
-- TOC entry 260 (class 1259 OID 17248)
-- Name: sys_indexes; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_indexes AS
 SELECT i.indrelid AS object_id,
    c.relname AS name,
        CASE
            WHEN i.indisclustered THEN 1
            ELSE 2
        END AS type,
        CASE
            WHEN i.indisclustered THEN 'CLUSTERED'::character varying(60)
            ELSE 'NONCLUSTERED'::character varying(60)
        END AS type_desc,
        CASE
            WHEN i.indisunique THEN 1
            ELSE 0
        END AS is_unique,
    c.reltablespace AS data_space_id,
    0 AS ignore_dup_key,
        CASE
            WHEN i.indisprimary THEN 1
            ELSE 0
        END AS is_primary_key,
        CASE
            WHEN (constr.oid IS NULL) THEN 0
            ELSE 1
        END AS is_unique_constraint,
    0 AS fill_factor,
        CASE
            WHEN (i.indpred IS NULL) THEN 0
            ELSE 1
        END AS is_padded,
        CASE
            WHEN i.indisready THEN 0
            ELSE 1
        END AS is_disabled,
    0 AS is_hypothetical,
    1 AS allow_row_locks,
    1 AS allow_page_locks,
    0 AS has_filter,
    NULL::character varying AS filter_definition,
    0 AS auto_created
   FROM (((pg_class c
     JOIN pg_namespace s ON ((s.oid = c.relnamespace)))
     JOIN pg_index i ON ((i.indexrelid = c.oid)))
     LEFT JOIN pg_constraint constr ON ((constr.conindid = c.oid)))
  WHERE ((c.relkind = 'i'::"char") AND i.indislive AND (s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name])));


ALTER TABLE aws_sqlserver_ext.sys_indexes OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 232 (class 1259 OID 16911)
-- Name: sys_languages; Type: TABLE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE TABLE aws_sqlserver_ext.sys_languages (
    lang_id smallint NOT NULL,
    lang_name_pg character varying(30),
    lang_alias_pg character varying(30),
    lang_name_mssql character varying(30),
    lang_alias_mssql character varying(30),
    territory character varying(50),
    spec_culture character varying(10),
    lang_data_jsonb jsonb
);


ALTER TABLE aws_sqlserver_ext.sys_languages OWNER TO postgres;

--
-- TOC entry 3906 (class 0 OID 0)
-- Dependencies: 232
-- Name: TABLE sys_languages; Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON TABLE aws_sqlserver_ext.sys_languages IS 'This table contains complete info about languages present in the instance of MS SQL Server.';


--
-- TOC entry 3907 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN sys_languages.lang_id; Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON COLUMN aws_sqlserver_ext.sys_languages.lang_id IS 'Unique language ID.';


--
-- TOC entry 3908 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN sys_languages.lang_name_pg; Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON COLUMN aws_sqlserver_ext.sys_languages.lang_name_pg IS 'Official language name, for example, English.';


--
-- TOC entry 3909 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN sys_languages.lang_alias_pg; Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON COLUMN aws_sqlserver_ext.sys_languages.lang_alias_pg IS 'Alternative language name, for example, English (Belgium).';


--
-- TOC entry 3910 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN sys_languages.lang_name_mssql; Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON COLUMN aws_sqlserver_ext.sys_languages.lang_name_mssql IS 'Official language name, for example, FranГ§ais.';


--
-- TOC entry 3911 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN sys_languages.lang_alias_mssql; Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON COLUMN aws_sqlserver_ext.sys_languages.lang_alias_mssql IS 'Alternative language name, for example, French.';


--
-- TOC entry 3912 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN sys_languages.territory; Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON COLUMN aws_sqlserver_ext.sys_languages.territory IS 'Territory on which the language is spoken, for example, France.';


--
-- TOC entry 3913 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN sys_languages.spec_culture; Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON COLUMN aws_sqlserver_ext.sys_languages.spec_culture IS 'Specific culture abbreviation, for example, fr-FR.';


--
-- TOC entry 3914 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN sys_languages.lang_data_jsonb; Type: COMMENT; Schema: aws_sqlserver_ext; Owner: postgres
--

COMMENT ON COLUMN aws_sqlserver_ext.sys_languages.lang_data_jsonb IS 'Language metadata, such as date format, first date of the week, month names etc.';


--
-- TOC entry 258 (class 1259 OID 17238)
-- Name: sys_views; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_views AS
 SELECT t.relname AS name,
    t.oid AS object_id,
    NULL::integer AS principal_id,
    s.oid AS schema_id,
    0 AS parent_object_id,
    'V'::character varying(2) AS type,
    'VIEW'::character varying(60) AS type_desc,
    NULL::timestamp without time zone AS create_date,
    NULL::timestamp without time zone AS modify_date,
    0 AS is_ms_shipped,
    0 AS is_published,
    0 AS is_schema_published,
    0 AS with_check_option,
    0 AS is_date_correlation_view,
    0 AS is_tracked_by_cdc
   FROM (pg_class t
     JOIN pg_namespace s ON ((s.oid = t.relnamespace)))
  WHERE ((t.relkind = 'v'::"char") AND has_table_privilege(((quote_ident((s.nspname)::text) || '.'::text) || quote_ident((t.relname)::text)), 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER'::text) AND (s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name])));


ALTER TABLE aws_sqlserver_ext.sys_views OWNER TO postgres;

--
-- TOC entry 267 (class 1259 OID 17283)
-- Name: sys_objects; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_objects AS
 SELECT t.name,
    t.object_id,
    t.principal_id,
    t.schema_id,
    t.parent_object_id,
    'U'::text AS type,
    'USER_TABLE'::text AS type_desc,
    t.create_date,
    t.modify_date,
    t.is_ms_shipped,
    t.is_published,
    t.is_schema_published
   FROM aws_sqlserver_ext.sys_tables t
UNION ALL
 SELECT v.name,
    v.object_id,
    v.principal_id,
    v.schema_id,
    v.parent_object_id,
    'V'::text AS type,
    'VIEW'::text AS type_desc,
    v.create_date,
    v.modify_date,
    v.is_ms_shipped,
    v.is_published,
    v.is_schema_published
   FROM aws_sqlserver_ext.sys_views v
UNION ALL
 SELECT f.name,
    f.object_id,
    f.principal_id,
    f.schema_id,
    f.parent_object_id,
    'F'::text AS type,
    'FOREIGN_KEY_CONSTRAINT'::text AS type_desc,
    f.create_date,
    f.modify_date,
    f.is_ms_shipped,
    f.is_published,
    f.is_schema_published
   FROM aws_sqlserver_ext.sys_foreign_keys f
UNION ALL
 SELECT p.name,
    p.object_id,
    p.principal_id,
    p.schema_id,
    p.parent_object_id,
    'PK'::text AS type,
    'PRIMARY_KEY_CONSTRAINT'::text AS type_desc,
    p.create_date,
    p.modify_date,
    p.is_ms_shipped,
    p.is_published,
    p.is_schema_published
   FROM aws_sqlserver_ext.sys_key_constraints p
UNION ALL
 SELECT pr.name,
    pr.object_id,
    pr.principal_id,
    pr.schema_id,
    pr.parent_object_id,
    pr.type,
    pr.type_desc,
    pr.create_date,
    pr.modify_date,
    pr.is_ms_shipped,
    pr.is_published,
    pr.is_schema_published
   FROM aws_sqlserver_ext.sys_procedures pr
UNION ALL
 SELECT p.relname AS name,
    p.oid AS object_id,
    NULL::integer AS principal_id,
    s.oid AS schema_id,
    0 AS parent_object_id,
    'SO'::character varying(2) AS type,
    'SEQUENCE_OBJECT'::character varying(60) AS type_desc,
    NULL::timestamp without time zone AS create_date,
    NULL::timestamp without time zone AS modify_date,
    0 AS is_ms_shipped,
    0 AS is_published,
    0 AS is_schema_published
   FROM (pg_class p
     JOIN pg_namespace s ON ((s.oid = p.relnamespace)))
  WHERE ((s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name])) AND (p.relkind = 'S'::"char"));


ALTER TABLE aws_sqlserver_ext.sys_objects OWNER TO postgres;

--
-- TOC entry 255 (class 1259 OID 17224)
-- Name: sys_schemas; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_schemas AS
 SELECT pg_namespace.nspname AS name,
    pg_namespace.oid AS schema_id,
    pg_namespace.oid AS principal_id
   FROM pg_namespace
  WHERE (pg_namespace.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name]));


ALTER TABLE aws_sqlserver_ext.sys_schemas OWNER TO postgres;

--
-- TOC entry 266 (class 1259 OID 17278)
-- Name: sys_sql_modules; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_sql_modules AS
 SELECT p.oid AS object_id,
    pg_get_functiondef(p.oid) AS definition,
    1 AS uses_ansi_nulls,
    1 AS uses_quoted_identifier,
    0 AS is_schema_bound,
    0 AS uses_database_collation,
    0 AS is_recompiled,
        CASE
            WHEN p.proisstrict THEN 1
            ELSE 0
        END AS null_on_null_input,
    NULL::integer AS execute_as_principal_id,
    0 AS uses_native_compilation
   FROM (((pg_proc p
     JOIN pg_namespace s ON ((s.oid = p.pronamespace)))
     JOIN pg_type t ON ((t.oid = p.prorettype)))
     LEFT JOIN pg_collation c ON ((c.oid = t.typcollation)))
  WHERE ((s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name])) AND pg_function_is_visible(p.oid));


ALTER TABLE aws_sqlserver_ext.sys_sql_modules OWNER TO postgres;

--
-- TOC entry 271 (class 1259 OID 17303)
-- Name: sys_sysforeignkeys; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_sysforeignkeys AS
 SELECT c.conname AS name,
    c.oid AS object_id,
    c.conrelid AS fkeyid,
    c.confrelid AS rkeyid,
    a_con.attnum AS fkey,
    a_conf.attnum AS rkey,
    a_conf.attnum AS keyno
   FROM (((pg_constraint c
     JOIN pg_namespace s ON ((s.oid = c.connamespace)))
     JOIN pg_attribute a_con ON (((a_con.attrelid = c.conrelid) AND (a_con.attnum = ANY (c.conkey)))))
     JOIN pg_attribute a_conf ON (((a_conf.attrelid = c.confrelid) AND (a_conf.attnum = ANY (c.confkey)))))
  WHERE ((c.contype = 'f'::"char") AND (s.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name])));


ALTER TABLE aws_sqlserver_ext.sys_sysforeignkeys OWNER TO postgres;

--
-- TOC entry 272 (class 1259 OID 17308)
-- Name: sys_sysindexes; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_sysindexes AS
 SELECT i.object_id AS id,
    NULL::integer AS status,
    NULL::oid AS first,
    i.type AS indid,
    NULL::oid AS root,
    0 AS minlen,
    1 AS keycnt,
    0 AS groupid,
    0 AS dpages,
    0 AS reserved,
    0 AS used,
    0 AS rowcnt,
    0 AS rowmodctr,
    0 AS reserved3,
    0 AS reserved4,
    0 AS xmaxlen,
    NULL::integer AS maxirow,
    0 AS origfillfactor,
    0 AS statversion,
    0 AS reserved2,
    NULL::integer AS firstiam,
    0 AS impid,
    0 AS lockflags,
    0 AS pgmodctr,
    NULL::bytea AS keys,
    i.name,
    NULL::bytea AS statblob,
    800 AS maxlen,
    0 AS rows
   FROM aws_sqlserver_ext.sys_indexes i;


ALTER TABLE aws_sqlserver_ext.sys_sysindexes OWNER TO postgres;

--
-- TOC entry 273 (class 1259 OID 17313)
-- Name: sys_sysobjects; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_sysobjects AS
 SELECT s.name,
    s.object_id AS id,
    s.type AS xtype,
    s.schema_id AS uid,
    0 AS info,
    0 AS status,
    0 AS base_schema_ver,
    0 AS replinfo,
    s.parent_object_id AS parent_obj,
    s.create_date AS crdate,
    0 AS ftcatid,
    0 AS schema_ver,
    0 AS stats_schema_ver,
    s.type,
    0 AS userstat,
    0 AS sysstat,
    0 AS indexdel,
    s.modify_date AS refdate,
    0 AS version,
    0 AS deltrig,
    0 AS instrig,
    0 AS updtrig,
    0 AS seltrig,
    0 AS category,
    0 AS cache
   FROM aws_sqlserver_ext.sys_objects s;


ALTER TABLE aws_sqlserver_ext.sys_sysobjects OWNER TO postgres;

--
-- TOC entry 274 (class 1259 OID 17317)
-- Name: sys_sysprocesses; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_sysprocesses AS
 SELECT a.pid AS spid,
    NULL::integer AS kpid,
    COALESCE(blocking_activity.pid, 0) AS blocked,
    NULL::bytea AS waittype,
    0 AS waittime,
    a.wait_event_type AS lastwaittype,
    NULL::text AS waitresource,
    a.datid AS dbid,
    a.usesysid AS uid,
    0 AS cpu,
    0 AS physical_io,
    0 AS memusage,
    a.backend_start AS login_time,
    a.query_start AS last_batch,
    0 AS ecid,
    0 AS open_tran,
    a.state AS status,
    NULL::bytea AS sid,
    a.client_hostname AS hostname,
    a.application_name AS program_name,
    NULL::character varying(10) AS hostprocess,
    a.query AS cmd,
    NULL::character varying(128) AS nt_domain,
    NULL::character varying(128) AS nt_username,
    NULL::character varying(12) AS net_address,
    NULL::character varying(12) AS net_library,
    a.usename AS loginname,
    NULL::bytea AS context_info,
    NULL::bytea AS sql_handle,
    0 AS stmt_start,
    0 AS stmt_end,
    0 AS request_id
   FROM (((pg_stat_activity a
     LEFT JOIN pg_locks blocked_locks ON ((a.pid = blocked_locks.pid)))
     LEFT JOIN pg_locks blocking_locks ON (((blocking_locks.locktype = blocked_locks.locktype) AND (NOT (blocking_locks.database IS DISTINCT FROM blocked_locks.database)) AND (NOT (blocking_locks.relation IS DISTINCT FROM blocked_locks.relation)) AND (NOT (blocking_locks.page IS DISTINCT FROM blocked_locks.page)) AND (NOT (blocking_locks.tuple IS DISTINCT FROM blocked_locks.tuple)) AND (NOT (blocking_locks.virtualxid IS DISTINCT FROM blocked_locks.virtualxid)) AND (NOT (blocking_locks.transactionid IS DISTINCT FROM blocked_locks.transactionid)) AND (NOT (blocking_locks.classid IS DISTINCT FROM blocked_locks.classid)) AND (NOT (blocking_locks.objid IS DISTINCT FROM blocked_locks.objid)) AND (NOT (blocking_locks.objsubid IS DISTINCT FROM blocked_locks.objsubid)) AND (blocking_locks.pid <> blocked_locks.pid))))
     LEFT JOIN pg_stat_activity blocking_activity ON ((blocking_activity.pid = blocking_locks.pid)));


ALTER TABLE aws_sqlserver_ext.sys_sysprocesses OWNER TO postgres;

--
-- TOC entry 275 (class 1259 OID 17322)
-- Name: sys_system_objects; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_system_objects AS
 SELECT o.name,
    o.object_id,
    o.principal_id,
    o.schema_id,
    o.parent_object_id,
    o.type,
    o.type_desc,
    o.create_date,
    o.modify_date,
    o.is_ms_shipped,
    o.is_published,
    o.is_schema_published,
    s.oid,
    s.nspname,
    s.nspowner,
    s.nspacl
   FROM (aws_sqlserver_ext.sys_all_objects o
     JOIN pg_namespace s ON ((s.oid = o.schema_id)))
  WHERE (s.nspname = ANY (ARRAY['information_schema'::name, 'pg_catalog'::name]));


ALTER TABLE aws_sqlserver_ext.sys_system_objects OWNER TO postgres;

--
-- TOC entry 257 (class 1259 OID 17233)
-- Name: sys_types; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sys_types AS
 SELECT format_type(t.oid, NULL::integer) AS name,
    t.oid AS system_type_id,
    t.oid AS user_type_id,
    s.oid AS schema_id,
    NULL::integer AS principal_id,
    t.typlen AS max_length,
    0 AS "precision",
    0 AS scale,
    c.collname AS collation_name,
        CASE
            WHEN t.typnotnull THEN 0
            ELSE 1
        END AS is_nullable,
        CASE t.typcategory
            WHEN 'U'::"char" THEN 1
            ELSE 0
        END AS is_user_defined,
    0 AS is_assembly_type,
    0 AS default_object_id,
    0 AS rule_object_id,
    0 AS is_table_type
   FROM ((pg_type t
     JOIN pg_namespace s ON ((s.oid = t.typnamespace)))
     LEFT JOIN pg_collation c ON ((c.oid = t.typcollation)));


ALTER TABLE aws_sqlserver_ext.sys_types OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 16890)
-- Name: sysjobhistory; Type: TABLE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE TABLE aws_sqlserver_ext.sysjobhistory (
    instance_id bigint NOT NULL,
    job_id integer NOT NULL,
    step_id integer NOT NULL,
    step_name character varying(128) NOT NULL,
    sql_message_id integer NOT NULL,
    sql_severity integer NOT NULL,
    message character varying(4000),
    run_status integer NOT NULL,
    run_date date,
    run_time time without time zone,
    run_duration integer NOT NULL,
    operator_id_emailed integer NOT NULL,
    operator_id_netsent integer NOT NULL,
    operator_id_paged integer NOT NULL,
    retries_attempted integer NOT NULL,
    server character varying(128) NOT NULL
);


ALTER TABLE aws_sqlserver_ext.sysjobhistory OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 16880)
-- Name: sysjobhistory_seq; Type: SEQUENCE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE SEQUENCE aws_sqlserver_ext.sysjobhistory_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE aws_sqlserver_ext.sysjobhistory_seq OWNER TO postgres;

--
-- TOC entry 3915 (class 0 OID 0)
-- Dependencies: 218
-- Name: sysjobhistory_seq; Type: SEQUENCE OWNED BY; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER SEQUENCE aws_sqlserver_ext.sysjobhistory_seq OWNED BY aws_sqlserver_ext.sysjobhistory.instance_id;


--
-- TOC entry 230 (class 1259 OID 16899)
-- Name: sysjobs; Type: TABLE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE TABLE aws_sqlserver_ext.sysjobs (
    job_id bigint NOT NULL,
    originating_server_id integer NOT NULL,
    name character varying(128) NOT NULL,
    enabled smallint NOT NULL,
    description character varying(512),
    start_step_id integer NOT NULL,
    category_id integer NOT NULL,
    owner_sid character(85) NOT NULL,
    notify_level_eventlog integer NOT NULL,
    notify_level_email integer NOT NULL,
    notify_level_netsend integer NOT NULL,
    notify_level_page integer NOT NULL,
    notify_email_operator_id integer NOT NULL,
    notify_email_operator_name character varying(128),
    notify_netsend_operator_id integer NOT NULL,
    notify_page_operator_id integer NOT NULL,
    delete_level integer NOT NULL,
    version_number integer NOT NULL
);


ALTER TABLE aws_sqlserver_ext.sysjobs OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16881)
-- Name: sysjobs_seq; Type: SEQUENCE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE SEQUENCE aws_sqlserver_ext.sysjobs_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE aws_sqlserver_ext.sysjobs_seq OWNER TO postgres;

--
-- TOC entry 3916 (class 0 OID 0)
-- Dependencies: 219
-- Name: sysjobs_seq; Type: SEQUENCE OWNED BY; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER SEQUENCE aws_sqlserver_ext.sysjobs_seq OWNED BY aws_sqlserver_ext.sysjobs.job_id;


--
-- TOC entry 229 (class 1259 OID 16896)
-- Name: sysjobschedules; Type: TABLE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE TABLE aws_sqlserver_ext.sysjobschedules (
    schedule_id integer,
    job_id integer,
    next_run_date date,
    next_run_time time without time zone
);


ALTER TABLE aws_sqlserver_ext.sysjobschedules OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 16905)
-- Name: sysjobsteps; Type: TABLE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE TABLE aws_sqlserver_ext.sysjobsteps (
    job_step_id bigint NOT NULL,
    job_id integer NOT NULL,
    step_id integer NOT NULL,
    step_name character varying(128) NOT NULL,
    subsystem character varying(40) NOT NULL,
    command text,
    flags integer NOT NULL,
    additional_parameters text,
    cmdexec_success_code integer NOT NULL,
    on_success_action smallint NOT NULL,
    on_success_step_id integer NOT NULL,
    on_fail_action smallint NOT NULL,
    on_fail_step_id integer NOT NULL,
    server character varying(128),
    database_name character varying(128),
    database_user_name character varying(128),
    retry_attempts integer NOT NULL,
    retry_interval integer NOT NULL,
    os_run_priority integer NOT NULL,
    output_file_name character varying(200),
    last_run_outcome integer NOT NULL,
    last_run_duration integer NOT NULL,
    last_run_retries integer NOT NULL,
    last_run_date integer NOT NULL,
    last_run_time integer NOT NULL,
    proxy_id integer,
    step_uid character(38)
);


ALTER TABLE aws_sqlserver_ext.sysjobsteps OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 16882)
-- Name: sysjobsteps_seq; Type: SEQUENCE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE SEQUENCE aws_sqlserver_ext.sysjobsteps_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE aws_sqlserver_ext.sysjobsteps_seq OWNER TO postgres;

--
-- TOC entry 3917 (class 0 OID 0)
-- Dependencies: 220
-- Name: sysjobsteps_seq; Type: SEQUENCE OWNED BY; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER SEQUENCE aws_sqlserver_ext.sysjobsteps_seq OWNED BY aws_sqlserver_ext.sysjobsteps.job_step_id;


--
-- TOC entry 233 (class 1259 OID 16916)
-- Name: sysmail_account; Type: TABLE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE TABLE aws_sqlserver_ext.sysmail_account (
    account_id bigint NOT NULL,
    name character varying(128) NOT NULL,
    description character varying(256),
    email_address character varying(128) NOT NULL,
    display_name character varying(128),
    replyto_address character varying(128)
);


ALTER TABLE aws_sqlserver_ext.sysmail_account OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16883)
-- Name: sysmail_account_seq; Type: SEQUENCE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE SEQUENCE aws_sqlserver_ext.sysmail_account_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE aws_sqlserver_ext.sysmail_account_seq OWNER TO postgres;

--
-- TOC entry 3918 (class 0 OID 0)
-- Dependencies: 221
-- Name: sysmail_account_seq; Type: SEQUENCE OWNED BY; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER SEQUENCE aws_sqlserver_ext.sysmail_account_seq OWNED BY aws_sqlserver_ext.sysmail_account.account_id;


--
-- TOC entry 236 (class 1259 OID 16934)
-- Name: sysmail_mailitems; Type: TABLE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE TABLE aws_sqlserver_ext.sysmail_mailitems (
    mailitem_id bigint NOT NULL,
    profile_id integer NOT NULL,
    recipients text,
    copy_recipients text,
    blind_copy_recipients text,
    subject character varying(255),
    from_address text,
    reply_to text,
    body text,
    body_format character varying(20),
    importance character varying(6),
    sensitivity character varying(12),
    file_attachments text,
    attachment_encoding character varying(20),
    query text,
    execute_query_database character varying(128),
    attach_query_result_as_file smallint,
    query_result_header smallint,
    query_result_width integer,
    query_result_separator character varying(1),
    exclude_query_output smallint,
    append_query_error smallint,
    sent_account_id integer,
    sent_status smallint DEFAULT 0,
    sent_date timestamp without time zone,
    send_request_date timestamp without time zone NOT NULL
);


ALTER TABLE aws_sqlserver_ext.sysmail_mailitems OWNER TO postgres;

--
-- TOC entry 276 (class 1259 OID 17327)
-- Name: sysmail_allitems; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sysmail_allitems AS
 SELECT sa.mailitem_id,
    sa.profile_id,
    sa.recipients,
    sa.copy_recipients,
    sa.blind_copy_recipients,
    sa.subject,
    sa.body,
    sa.body_format,
    sa.importance,
    sa.sensitivity,
    sa.file_attachments,
    sa.attachment_encoding,
    sa.query,
    sa.execute_query_database,
    sa.attach_query_result_as_file,
    sa.query_result_header,
    sa.query_result_width,
    sa.query_result_separator,
    sa.exclude_query_output,
    sa.append_query_error,
    sa.sent_account_id,
        CASE sa.sent_status
            WHEN 0 THEN 'unsent'::text
            WHEN 1 THEN 'sent'::text
            WHEN 3 THEN 'retrying'::text
            ELSE 'failed'::text
        END AS sent_status,
    sa.sent_date
   FROM aws_sqlserver_ext.sysmail_mailitems sa;


ALTER TABLE aws_sqlserver_ext.sysmail_allitems OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 16922)
-- Name: sysmail_attachments; Type: TABLE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE TABLE aws_sqlserver_ext.sysmail_attachments (
    attachment_id bigint NOT NULL,
    mailitem_id integer NOT NULL,
    filename character varying(260) NOT NULL,
    filesize integer NOT NULL,
    attachment bytea
);


ALTER TABLE aws_sqlserver_ext.sysmail_attachments OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 16884)
-- Name: sysmail_attachments_seq; Type: SEQUENCE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE SEQUENCE aws_sqlserver_ext.sysmail_attachments_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE aws_sqlserver_ext.sysmail_attachments_seq OWNER TO postgres;

--
-- TOC entry 3919 (class 0 OID 0)
-- Dependencies: 222
-- Name: sysmail_attachments_seq; Type: SEQUENCE OWNED BY; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER SEQUENCE aws_sqlserver_ext.sysmail_attachments_seq OWNED BY aws_sqlserver_ext.sysmail_attachments.attachment_id;


--
-- TOC entry 277 (class 1259 OID 17332)
-- Name: sysmail_faileditems; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sysmail_faileditems AS
 SELECT sa.mailitem_id,
    sa.profile_id,
    sa.recipients,
    sa.copy_recipients,
    sa.blind_copy_recipients,
    sa.subject,
    sa.body,
    sa.body_format,
    sa.importance,
    sa.sensitivity,
    sa.file_attachments,
    sa.attachment_encoding,
    sa.query,
    sa.execute_query_database,
    sa.attach_query_result_as_file,
    sa.query_result_header,
    sa.query_result_width,
    sa.query_result_separator,
    sa.exclude_query_output,
    sa.append_query_error,
    sa.sent_account_id,
    sa.sent_status,
    sa.sent_date
   FROM aws_sqlserver_ext.sysmail_allitems sa
  WHERE (lower(sa.sent_status) = lower('failed'::text));


ALTER TABLE aws_sqlserver_ext.sysmail_faileditems OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 16928)
-- Name: sysmail_log; Type: TABLE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE TABLE aws_sqlserver_ext.sysmail_log (
    log_id bigint NOT NULL,
    event_type integer NOT NULL,
    log_date timestamp without time zone NOT NULL,
    description text,
    mailitem_id integer
);


ALTER TABLE aws_sqlserver_ext.sysmail_log OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16885)
-- Name: sysmail_log_seq; Type: SEQUENCE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE SEQUENCE aws_sqlserver_ext.sysmail_log_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE aws_sqlserver_ext.sysmail_log_seq OWNER TO postgres;

--
-- TOC entry 3920 (class 0 OID 0)
-- Dependencies: 223
-- Name: sysmail_log_seq; Type: SEQUENCE OWNED BY; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER SEQUENCE aws_sqlserver_ext.sysmail_log_seq OWNED BY aws_sqlserver_ext.sysmail_log.log_id;


--
-- TOC entry 278 (class 1259 OID 17337)
-- Name: sysmail_mailattachments; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sysmail_mailattachments AS
 SELECT sa.attachment_id,
    sa.mailitem_id,
    sa.filename,
    sa.filesize,
    sa.attachment
   FROM (aws_sqlserver_ext.sysmail_attachments sa
     JOIN aws_sqlserver_ext.sysmail_mailitems sm ON ((sa.mailitem_id = sm.mailitem_id)));


ALTER TABLE aws_sqlserver_ext.sysmail_mailattachments OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 16886)
-- Name: sysmail_mailitems_seq; Type: SEQUENCE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE SEQUENCE aws_sqlserver_ext.sysmail_mailitems_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE aws_sqlserver_ext.sysmail_mailitems_seq OWNER TO postgres;

--
-- TOC entry 3921 (class 0 OID 0)
-- Dependencies: 224
-- Name: sysmail_mailitems_seq; Type: SEQUENCE OWNED BY; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER SEQUENCE aws_sqlserver_ext.sysmail_mailitems_seq OWNED BY aws_sqlserver_ext.sysmail_mailitems.mailitem_id;


--
-- TOC entry 238 (class 1259 OID 16944)
-- Name: sysmail_profile; Type: TABLE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE TABLE aws_sqlserver_ext.sysmail_profile (
    profile_id bigint NOT NULL,
    name character varying(128) NOT NULL,
    description character varying(256)
);


ALTER TABLE aws_sqlserver_ext.sysmail_profile OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 16887)
-- Name: sysmail_profile_seq; Type: SEQUENCE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE SEQUENCE aws_sqlserver_ext.sysmail_profile_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE aws_sqlserver_ext.sysmail_profile_seq OWNER TO postgres;

--
-- TOC entry 3922 (class 0 OID 0)
-- Dependencies: 225
-- Name: sysmail_profile_seq; Type: SEQUENCE OWNED BY; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER SEQUENCE aws_sqlserver_ext.sysmail_profile_seq OWNED BY aws_sqlserver_ext.sysmail_profile.profile_id;


--
-- TOC entry 237 (class 1259 OID 16941)
-- Name: sysmail_profileaccount; Type: TABLE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE TABLE aws_sqlserver_ext.sysmail_profileaccount (
    profile_id integer NOT NULL,
    account_id integer NOT NULL,
    sequence_number integer
);


ALTER TABLE aws_sqlserver_ext.sysmail_profileaccount OWNER TO postgres;

--
-- TOC entry 279 (class 1259 OID 17342)
-- Name: sysmail_sentitems; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sysmail_sentitems AS
 SELECT sa.mailitem_id,
    sa.profile_id,
    sa.recipients,
    sa.copy_recipients,
    sa.blind_copy_recipients,
    sa.subject,
    sa.body,
    sa.body_format,
    sa.importance,
    sa.sensitivity,
    sa.file_attachments,
    sa.attachment_encoding,
    sa.query,
    sa.execute_query_database,
    sa.attach_query_result_as_file,
    sa.query_result_header,
    sa.query_result_width,
    sa.query_result_separator,
    sa.exclude_query_output,
    sa.append_query_error,
    sa.sent_account_id,
    sa.sent_status,
    sa.sent_date
   FROM aws_sqlserver_ext.sysmail_allitems sa
  WHERE (lower(sa.sent_status) = lower('sent'::text));


ALTER TABLE aws_sqlserver_ext.sysmail_sentitems OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 16948)
-- Name: sysmail_server; Type: TABLE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE TABLE aws_sqlserver_ext.sysmail_server (
    account_id integer NOT NULL,
    servertype character varying(128) NOT NULL,
    servername character varying(128) NOT NULL
);


ALTER TABLE aws_sqlserver_ext.sysmail_server OWNER TO postgres;

--
-- TOC entry 280 (class 1259 OID 17347)
-- Name: sysmail_unsentitems; Type: VIEW; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE VIEW aws_sqlserver_ext.sysmail_unsentitems AS
 SELECT sa.mailitem_id,
    sa.profile_id,
    sa.recipients,
    sa.copy_recipients,
    sa.blind_copy_recipients,
    sa.subject,
    sa.body,
    sa.body_format,
    sa.importance,
    sa.sensitivity,
    sa.file_attachments,
    sa.attachment_encoding,
    sa.query,
    sa.execute_query_database,
    sa.attach_query_result_as_file,
    sa.query_result_header,
    sa.query_result_width,
    sa.query_result_separator,
    sa.exclude_query_output,
    sa.append_query_error,
    sa.sent_account_id,
    sa.sent_status,
    sa.sent_date
   FROM aws_sqlserver_ext.sysmail_allitems sa
  WHERE ((lower(sa.sent_status) = lower('unsent'::text)) OR (lower(sa.sent_status) = lower('retrying'::text)));


ALTER TABLE aws_sqlserver_ext.sysmail_unsentitems OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 16951)
-- Name: sysschedules; Type: TABLE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE TABLE aws_sqlserver_ext.sysschedules (
    schedule_id bigint NOT NULL,
    schedule_uid character(38) NOT NULL,
    originating_server_id integer NOT NULL,
    name character varying(128) NOT NULL,
    owner_sid character(85) NOT NULL,
    enabled integer NOT NULL,
    freq_type integer NOT NULL,
    freq_interval integer NOT NULL,
    freq_subday_type integer NOT NULL,
    freq_subday_interval integer NOT NULL,
    freq_relative_interval integer NOT NULL,
    freq_recurrence_factor integer NOT NULL,
    active_start_date integer NOT NULL,
    active_end_date integer NOT NULL,
    active_start_time integer NOT NULL,
    active_end_time integer NOT NULL,
    version_number integer DEFAULT 1 NOT NULL
);


ALTER TABLE aws_sqlserver_ext.sysschedules OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 16888)
-- Name: sysschedules_seq; Type: SEQUENCE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE SEQUENCE aws_sqlserver_ext.sysschedules_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE aws_sqlserver_ext.sysschedules_seq OWNER TO postgres;

--
-- TOC entry 3923 (class 0 OID 0)
-- Dependencies: 226
-- Name: sysschedules_seq; Type: SEQUENCE OWNED BY; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER SEQUENCE aws_sqlserver_ext.sysschedules_seq OWNED BY aws_sqlserver_ext.sysschedules.schedule_id;


--
-- TOC entry 241 (class 1259 OID 16956)
-- Name: versions; Type: TABLE; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE TABLE aws_sqlserver_ext.versions (
    extpackcomponentname character varying(256) NOT NULL,
    componentversion character varying(256)
);


ALTER TABLE aws_sqlserver_ext.versions OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 16889)
-- Name: inc_seq_rowversion; Type: SEQUENCE; Schema: aws_sqlserver_ext_data; Owner: postgres
--

CREATE SEQUENCE aws_sqlserver_ext_data.inc_seq_rowversion
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE aws_sqlserver_ext_data.inc_seq_rowversion OWNER TO postgres;

--
-- TOC entry 242 (class 1259 OID 16961)
-- Name: service_settings; Type: TABLE; Schema: aws_sqlserver_ext_data; Owner: postgres
--

CREATE TABLE aws_sqlserver_ext_data.service_settings (
    service character varying(50) NOT NULL,
    setting character varying(100) NOT NULL,
    value character varying
);


ALTER TABLE aws_sqlserver_ext_data.service_settings OWNER TO postgres;

--
-- TOC entry 3924 (class 0 OID 0)
-- Dependencies: 242
-- Name: TABLE service_settings; Type: COMMENT; Schema: aws_sqlserver_ext_data; Owner: postgres
--

COMMENT ON TABLE aws_sqlserver_ext_data.service_settings IS 'Settings for Extension Pack services';


--
-- TOC entry 3925 (class 0 OID 0)
-- Dependencies: 242
-- Name: COLUMN service_settings.service; Type: COMMENT; Schema: aws_sqlserver_ext_data; Owner: postgres
--

COMMENT ON COLUMN aws_sqlserver_ext_data.service_settings.service IS 'Service name';


--
-- TOC entry 3926 (class 0 OID 0)
-- Dependencies: 242
-- Name: COLUMN service_settings.setting; Type: COMMENT; Schema: aws_sqlserver_ext_data; Owner: postgres
--

COMMENT ON COLUMN aws_sqlserver_ext_data.service_settings.setting IS 'Setting name';


--
-- TOC entry 3927 (class 0 OID 0)
-- Dependencies: 242
-- Name: COLUMN service_settings.value; Type: COMMENT; Schema: aws_sqlserver_ext_data; Owner: postgres
--

COMMENT ON COLUMN aws_sqlserver_ext_data.service_settings.value IS 'Setting value';


--
-- TOC entry 3607 (class 2604 OID 16893)
-- Name: sysjobhistory instance_id; Type: DEFAULT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysjobhistory ALTER COLUMN instance_id SET DEFAULT nextval('aws_sqlserver_ext.sysjobhistory_seq'::regclass);


--
-- TOC entry 3608 (class 2604 OID 16902)
-- Name: sysjobs job_id; Type: DEFAULT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysjobs ALTER COLUMN job_id SET DEFAULT nextval('aws_sqlserver_ext.sysjobs_seq'::regclass);


--
-- TOC entry 3609 (class 2604 OID 16908)
-- Name: sysjobsteps job_step_id; Type: DEFAULT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysjobsteps ALTER COLUMN job_step_id SET DEFAULT nextval('aws_sqlserver_ext.sysjobsteps_seq'::regclass);


--
-- TOC entry 3610 (class 2604 OID 16919)
-- Name: sysmail_account account_id; Type: DEFAULT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysmail_account ALTER COLUMN account_id SET DEFAULT nextval('aws_sqlserver_ext.sysmail_account_seq'::regclass);


--
-- TOC entry 3611 (class 2604 OID 16925)
-- Name: sysmail_attachments attachment_id; Type: DEFAULT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysmail_attachments ALTER COLUMN attachment_id SET DEFAULT nextval('aws_sqlserver_ext.sysmail_attachments_seq'::regclass);


--
-- TOC entry 3612 (class 2604 OID 16931)
-- Name: sysmail_log log_id; Type: DEFAULT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysmail_log ALTER COLUMN log_id SET DEFAULT nextval('aws_sqlserver_ext.sysmail_log_seq'::regclass);


--
-- TOC entry 3613 (class 2604 OID 16937)
-- Name: sysmail_mailitems mailitem_id; Type: DEFAULT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysmail_mailitems ALTER COLUMN mailitem_id SET DEFAULT nextval('aws_sqlserver_ext.sysmail_mailitems_seq'::regclass);


--
-- TOC entry 3615 (class 2604 OID 16947)
-- Name: sysmail_profile profile_id; Type: DEFAULT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysmail_profile ALTER COLUMN profile_id SET DEFAULT nextval('aws_sqlserver_ext.sysmail_profile_seq'::regclass);


--
-- TOC entry 3616 (class 2604 OID 16954)
-- Name: sysschedules schedule_id; Type: DEFAULT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysschedules ALTER COLUMN schedule_id SET DEFAULT nextval('aws_sqlserver_ext.sysschedules_seq'::regclass);


--
-- TOC entry 3849 (class 0 OID 16911)
-- Dependencies: 232
-- Data for Name: sys_languages; Type: TABLE DATA; Schema: aws_sqlserver_ext; Owner: postgres
--

INSERT INTO aws_sqlserver_ext.sys_languages VALUES (1, 'ENGLISH', 'ENGLISH (AUSTRALIA)', NULL, NULL, 'AUSTRALIA', 'EN-AU', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (2, 'ENGLISH', 'ENGLISH (BELGIUM)', NULL, NULL, 'BELGIUM', 'EN-BE', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (3, 'ENGLISH', 'ENGLISH (BELIZE)', NULL, NULL, 'BELIZE', 'EN-BZ', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "MDY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (4, 'ENGLISH', 'ENGLISH (BOTSWANA)', NULL, NULL, 'BOTSWANA', 'EN-BW', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (5, 'ENGLISH', 'ENGLISH (CAMEROON)', NULL, NULL, 'CAMEROON', 'EN-CM', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (6, 'ENGLISH', 'ENGLISH (CANADA)', NULL, NULL, 'CANADA', 'EN-CA', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "YMD", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (7, 'ENGLISH', 'ENGLISH (ERITREA)', NULL, NULL, 'ERITREA', 'EN-ER', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (8, 'ENGLISH', 'ENGLISH (INDIA)', NULL, NULL, 'INDIA', 'EN-IN', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (9, 'ENGLISH', 'ENGLISH (IRELAND)', NULL, NULL, 'IRELAND', 'EN-IE', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (10, 'ENGLISH', 'ENGLISH (JAMAICA)', NULL, NULL, 'JAMAICA', 'EN-IM', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (11, 'ENGLISH', 'ENGLISH (KENYA)', NULL, NULL, 'KENYA', 'EN-KE', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (12, 'ENGLISH', 'ENGLISH (MALAYSIA)', NULL, NULL, 'MALAYSIA', 'EN-MY', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (13, 'ENGLISH', 'ENGLISH (MALTA)', NULL, NULL, 'MALTA', 'EN-MT', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (14, 'ENGLISH', 'ENGLISH (NEW ZEALAND)', NULL, NULL, 'NEW ZEALAND', 'EN-NZ', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (15, 'ENGLISH', 'ENGLISH (NIGERIA)', NULL, NULL, 'NIGERIA', 'EN-NG', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (16, 'ENGLISH', 'ENGLISH (PAKISTAN)', NULL, NULL, 'PAKISTAN', 'EN-PK', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (17, 'ENGLISH', 'ENGLISH (PHILIPPINES)', NULL, NULL, 'PHILIPPINES', 'EN-PH', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "MDY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (18, 'ENGLISH', 'ENGLISH (PUERTO RICO)', NULL, NULL, 'PUERTO RICO', 'EN-PR', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "MDY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (19, 'ENGLISH', 'ENGLISH (SINGAPORE)', NULL, NULL, 'SINGAPORE', 'EN-SG', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (20, 'ENGLISH', 'ENGLISH (SOUTH AFRICA)', NULL, NULL, 'SOUTH AFRICA', 'EN-ZA', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "YMD", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (21, 'ENGLISH', 'ENGLISH (TRINIDAD & TOBAGO)', NULL, NULL, 'TRINIDAD & TOBAGO', 'EN-TT', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (22, 'ENGLISH', 'ENGLISH (GREAT BRITAIN)', 'BRITISH', 'BRITISH ENGLISH', 'GREAT BRITAIN', 'EN-GB', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (23, 'ENGLISH', 'ENGLISH (UNITED KINGDOM)', NULL, NULL, 'UNITED KINGDOM', 'EN-UK', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (24, 'ENGLISH', 'ENGLISH (ENGLAND)', NULL, NULL, 'ENGLAND', 'EN-EN', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (25, 'ENGLISH', 'ENGLISH (UNITED STATES)', 'US_ENGLISH', 'ENGLISH', 'UNITED STATES', 'EN-US', '{"date_first": 7, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "MDY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (26, 'ENGLISH', 'ENGLISH (ZIMBABWE)', NULL, NULL, 'ZIMBABWE', 'EN-ZW', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (27, 'GERMAN', 'GERMAN (AUSTRIA)', NULL, NULL, 'AUSTRIA', 'DE-AT', '{"date_first": 1, "days_names": ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"], "date_format": "DMY", "months_names": ["Januar", "Februar", "MГ¤rz", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "MГ¤r", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (28, 'GERMAN', 'GERMAN (BELGIUM)', NULL, NULL, 'BELGIUM', 'DE-BE', '{"date_first": 1, "days_names": ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"], "date_format": "DMY", "months_names": ["Januar", "Februar", "MГ¤rz", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "MГ¤r", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (29, 'GERMAN', 'GERMAN (GERMANY)', 'DEUTSCH', 'GERMAN', 'GERMANY', 'DE-DE', '{"date_first": 1, "days_names": ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"], "date_format": "DMY", "months_names": ["Januar", "Februar", "MГ¤rz", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["Jan", "Feb", "MГ¤r", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (30, 'GERMAN', 'GERMAN (LIECHTENSTEIN)', NULL, NULL, 'LIECHTENSTEIN', 'DE-LI', '{"date_first": 1, "days_names": ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"], "date_format": "DMY", "months_names": ["Januar", "Februar", "MГ¤rz", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "MГ¤r", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (31, 'GERMAN', 'GERMAN (LUXEMBOURG)', NULL, NULL, 'LUXEMBOURG', 'DE-LU', '{"date_first": 1, "days_names": ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"], "date_format": "DMY", "months_names": ["Januar", "Februar", "MГ¤rz", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "MГ¤r", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (32, 'GERMAN', 'GERMAN (SWITZERLAND)', NULL, NULL, 'SWITZERLAND', 'DE-CH', '{"date_first": 1, "days_names": ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"], "date_format": "DMY", "months_names": ["Januar", "Februar", "MГ¤rz", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "MГ¤r", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (33, 'FRENCH', 'FRENCH (ALGERIA)', NULL, NULL, 'ALGERIA', 'FR-DZ', '{"date_first": 1, "days_names": ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"], "date_format": "DMY", "months_names": ["janvier", "fГ©vrier", "mars", "avril", "mai", "juin", "juillet", "aoГ»t", "septembre", "octobre", "novembre", "dГ©cembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["janv", "fГ©vr", "mars", "avr", "mai", "juin", "juil", "aoГ»t", "sept", "oct", "nov", "dГ©c"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (34, 'FRENCH', 'FRENCH (BELGIUM)', NULL, NULL, 'BELGIUM', 'FR-BE', '{"date_first": 1, "days_names": ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"], "date_format": "DMY", "months_names": ["janvier", "fГ©vrier", "mars", "avril", "mai", "juin", "juillet", "aoГ»t", "septembre", "octobre", "novembre", "dГ©cembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["janv", "fГ©vr", "mars", "avr", "mai", "juin", "juil", "aoГ»t", "sept", "oct", "nov", "dГ©c"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (35, 'FRENCH', 'FRENCH (CAMEROON)', NULL, NULL, 'CAMEROON', 'FR-CM', '{"date_first": 1, "days_names": ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"], "date_format": "DMY", "months_names": ["janvier", "fГ©vrier", "mars", "avril", "mai", "juin", "juillet", "aoГ»t", "septembre", "octobre", "novembre", "dГ©cembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["janv", "fГ©vr", "mars", "avr", "mai", "juin", "juil", "aoГ»t", "sept", "oct", "nov", "dГ©c"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (36, 'FRENCH', 'FRENCH (CANADA)', NULL, NULL, 'CANADA', 'FR-CA', '{"date_first": 1, "days_names": ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"], "date_format": "YMD", "months_names": ["janvier", "fГ©vrier", "mars", "avril", "mai", "juin", "juillet", "aoГ»t", "septembre", "octobre", "novembre", "dГ©cembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["janv", "fГ©vr", "mars", "avr", "mai", "juin", "juil", "aoГ»t", "sept", "oct", "nov", "dГ©c"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (37, 'FRENCH', 'FRENCH (FRANCE)', 'FRANГ‡AIS', 'FRENCH', 'FRANCE', 'FR-FR', '{"date_first": 1, "days_names": ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"], "date_format": "DMY", "months_names": ["janvier", "fГ©vrier", "mars", "avril", "mai", "juin", "juillet", "aoГ»t", "septembre", "octobre", "novembre", "dГ©cembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["janv", "fГ©vr", "mars", "avr", "mai", "juin", "juil", "aoГ»t", "sept", "oct", "nov", "dГ©c"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (38, 'FRENCH', 'FRENCH (HAITI)', NULL, NULL, 'HAITI', 'FR-HT', '{"date_first": 1, "days_names": ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"], "date_format": "DMY", "months_names": ["janvier", "fГ©vrier", "mars", "avril", "mai", "juin", "juillet", "aoГ»t", "septembre", "octobre", "novembre", "dГ©cembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["janv", "fГ©vr", "mars", "avr", "mai", "juin", "juil", "aoГ»t", "sept", "oct", "nov", "dГ©c"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (39, 'FRENCH', 'FRENCH (LUXEMBOURG)', NULL, NULL, 'LUXEMBOURG', 'FR-LU', '{"date_first": 1, "days_names": ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"], "date_format": "DMY", "months_names": ["janvier", "fГ©vrier", "mars", "avril", "mai", "juin", "juillet", "aoГ»t", "septembre", "octobre", "novembre", "dГ©cembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["janv", "fГ©vr", "mars", "avr", "mai", "juin", "juil", "aoГ»t", "sept", "oct", "nov", "dГ©c"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (40, 'FRENCH', 'FRENCH (MALI)', NULL, NULL, 'MALI', 'FR-ML', '{"date_first": 1, "days_names": ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"], "date_format": "DMY", "months_names": ["janvier", "fГ©vrier", "mars", "avril", "mai", "juin", "juillet", "aoГ»t", "septembre", "octobre", "novembre", "dГ©cembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["janv", "fГ©vr", "mars", "avr", "mai", "juin", "juil", "aoГ»t", "sept", "oct", "nov", "dГ©c"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (41, 'FRENCH', 'FRENCH (MONACO)', NULL, NULL, 'MONACO', 'FR-MC', '{"date_first": 1, "days_names": ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"], "date_format": "DMY", "months_names": ["janvier", "fГ©vrier", "mars", "avril", "mai", "juin", "juillet", "aoГ»t", "septembre", "octobre", "novembre", "dГ©cembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["janv", "fГ©vr", "mars", "avr", "mai", "juin", "juil", "aoГ»t", "sept", "oct", "nov", "dГ©c"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (42, 'FRENCH', 'FRENCH (MOROCCO)', NULL, NULL, 'MOROCCO', 'FR-MA', '{"date_first": 1, "days_names": ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"], "date_format": "DMY", "months_names": ["janvier", "fГ©vrier", "mars", "avril", "mai", "juin", "juillet", "aoГ»t", "septembre", "octobre", "novembre", "dГ©cembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["janv", "fГ©vr", "mars", "avr", "mai", "juin", "juil", "aoГ»t", "sept", "oct", "nov", "dГ©c"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (43, 'FRENCH', 'FRENCH (SENEGAL)', NULL, NULL, 'SENEGAL', 'FR-SN', '{"date_first": 1, "days_names": ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"], "date_format": "DMY", "months_names": ["janvier", "fГ©vrier", "mars", "avril", "mai", "juin", "juillet", "aoГ»t", "septembre", "octobre", "novembre", "dГ©cembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["janv", "fГ©vr", "mars", "avr", "mai", "juin", "juil", "aoГ»t", "sept", "oct", "nov", "dГ©c"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (44, 'FRENCH', 'FRENCH (SWITZERLAND)', NULL, NULL, 'SWITZERLAND', 'FR-CH', '{"date_first": 1, "days_names": ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"], "date_format": "DMY", "months_names": ["janvier", "fГ©vrier", "mars", "avril", "mai", "juin", "juillet", "aoГ»t", "septembre", "octobre", "novembre", "dГ©cembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["janv", "fГ©vr", "mars", "avr", "mai", "juin", "juil", "aoГ»t", "sept", "oct", "nov", "dГ©c"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (45, 'FRENCH', 'FRENCH (SYRIA)', NULL, NULL, 'SYRIA', 'FR-SY', '{"date_first": 1, "days_names": ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"], "date_format": "DMY", "months_names": ["janvier", "fГ©vrier", "mars", "avril", "mai", "juin", "juillet", "aoГ»t", "septembre", "octobre", "novembre", "dГ©cembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["janv", "fГ©vr", "mars", "avr", "mai", "juin", "juil", "aoГ»t", "sept", "oct", "nov", "dГ©c"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (46, 'FRENCH', 'FRENCH (TUNISIA)', NULL, NULL, 'TUNISIA', 'FR-TN', '{"date_first": 1, "days_names": ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"], "date_format": "DMY", "months_names": ["janvier", "fГ©vrier", "mars", "avril", "mai", "juin", "juillet", "aoГ»t", "septembre", "octobre", "novembre", "dГ©cembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["janv", "fГ©vr", "mars", "avr", "mai", "juin", "juil", "aoГ»t", "sept", "oct", "nov", "dГ©c"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (47, 'JAPANESE', 'JAPANESE (JAPAN)', 'ж—Ґжњ¬иЄћ', 'JAPANESE', 'JAPAN', 'JA-JP', '{"date_first": 7, "days_names": ["жњ€ж›њж—Ґ", "зЃ«ж›њж—Ґ", "ж°ґж›њж—Ґ", "жњЁж›њж—Ґ", "й‡‘ж›њж—Ґ", "ењџж›њж—Ґ", "ж—Ґж›њж—Ґ"], "date_format": "YMD", "months_names": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (48, 'DANISH', 'DANISH (DENMARK)', 'DANSK', 'DANISH', 'DENMARK', 'DA-DK', '{"date_first": 1, "days_names": ["mandag", "tirsdag", "onsdag", "torsdag", "fredag", "lГёrdag", "sГёndag"], "date_format": "DMY", "months_names": ["januar", "februar", "marts", "april", "maj", "juni", "juli", "august", "september", "oktober", "november", "december"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["jan", "feb", "mar", "apr", "maj", "jun", "jul", "aug", "sep", "okt", "nov", "dec"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (49, 'DANISH', 'DANISH (GREENLAND)', NULL, NULL, 'GREENLAND', 'DA-GL', '{"date_first": 1, "days_names": ["mandag", "tirsdag", "onsdag", "torsdag", "fredag", "lГёrdag", "sГёndag"], "date_format": "DMY", "months_names": ["januar", "februar", "marts", "april", "maj", "juni", "juli", "august", "september", "oktober", "november", "december"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["jan", "feb", "mar", "apr", "maj", "jun", "jul", "aug", "sep", "okt", "nov", "dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (50, 'SPANISH', 'SPANISH (ARGENTINA)', NULL, NULL, 'ARGENTINA', 'ES-AR', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (51, 'SPANISH', 'SPANISH (BOLIVIA)', NULL, NULL, 'BOLIVIA', 'ES-BO', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (52, 'SPANISH', 'SPANISH (CHILE)', NULL, NULL, 'CHILE', 'ES-CL', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (53, 'SPANISH', 'SPANISH (COLOMBIA)', NULL, NULL, 'COLOMBIA', 'ES-CO', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (54, 'SPANISH', 'SPANISH (COSTA RICA)', NULL, NULL, 'COSTA RICA', 'ES-CR', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (55, 'SPANISH', 'SPANISH (CUBA)', NULL, NULL, 'CUBA', 'ES-CU', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (56, 'SPANISH', 'SPANISH (DOMINICAN REPUBLIC)', NULL, NULL, 'DOMINICAN REPUBLIC', 'ES-DO', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (57, 'SPANISH', 'SPANISH (ECUADOR)', NULL, NULL, 'ECUADOR', 'ES-EC', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (58, 'SPANISH', 'SPANISH (EL SALVADOR)', NULL, NULL, 'EL SALVADOR', 'ES-SV', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (59, 'SPANISH', 'SPANISH (GUATEMALA)', NULL, NULL, 'GUATEMALA', 'ES-GT', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (60, 'SPANISH', 'SPANISH (HONDURASALA)', NULL, NULL, 'HONDURAS', 'ES-HN', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (61, 'SPANISH', 'SPANISH (MEXICO)', NULL, NULL, 'MEXICO', 'ES-MX', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (62, 'SPANISH', 'SPANISH (NICARAGUA)', NULL, NULL, 'NICARAGUA', 'ES-NI', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (63, 'SPANISH', 'SPANISH (PANAMA)', NULL, NULL, 'PANAMA', 'ES-PA', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (64, 'SPANISH', 'SPANISH (PARAGUAY)', NULL, NULL, 'PARAGUAY', 'ES-PY', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (65, 'SPANISH', 'SPANISH (PERU)', NULL, NULL, 'PERU', 'ES-PE', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (66, 'SPANISH', 'SPANISH (PHILIPPINES)', NULL, NULL, 'PHILIPPINES', 'ES-PH', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "MDY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (67, 'SPANISH', 'SPANISH (PUERTO RICO)', NULL, NULL, 'PUERTO RICO', 'ES-PR', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (68, 'SPANISH', 'SPANISH (SPAIN)', 'ESPAГ‘OL', 'SPANISH', 'SPAIN', 'ES-ES', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (69, 'SPANISH', 'SPANISH (UNITED STATES)', NULL, NULL, 'UNITED STATES', 'ES-US', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "MDY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (70, 'SPANISH', 'SPANISH (URUGUAY)', NULL, NULL, 'URUGUAY', 'ES-UY', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (71, 'SPANISH', 'SPANISH (VENEZUELA)', NULL, NULL, 'VENEZUELA', 'ES-VE', '{"date_first": 1, "days_names": ["Lunes", "Martes", "MiГ©rcoles", "Jueves", "Viernes", "SГЎbado", "Domingo"], "date_format": "DMY", "months_names": ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (72, 'ITALIAN', 'ITALIAN (ITALY)', 'ITALIANO', 'ITALIAN', 'ITALY', 'IT-IT', '{"date_first": 1, "days_names": ["lunedГ¬", "martedГ¬", "mercoledГ¬", "giovedГ¬", "venerdГ¬", "sabato", "domenica"], "date_format": "DMY", "months_names": ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["gen", "feb", "mar", "apr", "mag", "giu", "lug", "ago", "set", "ott", "nov", "dic"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (73, 'ITALIAN', 'ITALIAN (SWITZERLAND)', NULL, NULL, 'SWITZERLAND', 'IT-CH', '{"date_first": 1, "days_names": ["lunedГ¬", "martedГ¬", "mercoledГ¬", "giovedГ¬", "venerdГ¬", "sabato", "domenica"], "date_format": "DMY", "months_names": ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["gen", "feb", "mar", "apr", "mag", "giu", "lug", "ago", "set", "ott", "nov", "dic"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (74, 'DUTCH', 'DUTCH (BELGIUM)', NULL, NULL, 'BELGIUM', 'NL-BE', '{"date_first": 1, "days_names": ["maandag", "dinsdag", "woensdag", "donderdag", "vrijdag", "zaterdag", "zondag"], "date_format": "DMY", "months_names": ["januari", "februari", "maart", "april", "mei", "juni", "juli", "augustus", "september", "oktober", "november", "december"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["jan", "feb", "mrt", "apr", "mei", "jun", "jul", "aug", "sep", "okt", "nov", "dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (75, 'DUTCH', 'DUTCH (NETHERLANDS)', 'NEDERLANDS', 'DUTCH', 'NETHERLANDS', 'NL-NL', '{"date_first": 1, "days_names": ["maandag", "dinsdag", "woensdag", "donderdag", "vrijdag", "zaterdag", "zondag"], "date_format": "DMY", "months_names": ["januari", "februari", "maart", "april", "mei", "juni", "juli", "augustus", "september", "oktober", "november", "december"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["jan", "feb", "mrt", "apr", "mei", "jun", "jul", "aug", "sep", "okt", "nov", "dec"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (76, 'NORWEGIAN', 'NORWEGIAN (NORWAY)', NULL, NULL, 'NORWAY', 'NO-NO', '{"date_first": 1, "days_names": ["mandag", "tirsdag", "onsdag", "torsdag", "fredag", "lГёrdag", "sГёndag"], "date_format": "DMY", "months_names": ["januar", "februar", "mars", "april", "mai", "juni", "juli", "august", "september", "oktober", "november", "desember"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["jan", "feb", "mar", "apr", "mai", "jun", "jul", "aug", "sep", "okt", "nov", "des"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (77, 'NORWEGIAN (MS SQL)', 'NORWEGIAN NYNORSK (NORWAY)', 'NORSK', 'NORWEGIAN', 'NORWAY', 'NN-NO', '{"date_first": 1, "days_names": ["mandag", "tirsdag", "onsdag", "torsdag", "fredag", "lГёrdag", "sГёndag"], "date_format": "DMY", "months_names": ["januar", "februar", "mars", "april", "mai", "juni", "juli", "august", "september", "oktober", "november", "desember"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["jan", "feb", "mar", "apr", "mai", "jun", "jul", "aug", "sep", "okt", "nov", "des"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (87, 'ROMANIAN', 'ROMANIAN (MOLDOVA)', NULL, NULL, 'MOLDOVA', 'RO-MD', '{"date_first": 1, "days_names": ["luni", "marЕЈi", "miercuri", "joi", "vineri", "sГ®mbДѓtДѓ", "duminicДѓ"], "date_format": "DMY", "months_names": ["ianuarie", "februarie", "martie", "aprilie", "mai", "iunie", "iulie", "august", "septembrie", "octombrie", "noiembrie", "decembrie"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Ian", "Feb", "Mar", "Apr", "Mai", "Iun", "Iul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (78, 'PORTUGUESE', 'PORTUGUESE (BRAZIL)', 'PORTUGUESE', 'BRAZILIAN', 'BRAZIL', 'PT-BR', '{"date_first": 7, "days_names": ["segunda-feira", "terГ§a-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sГЎbado", "domingo"], "date_format": "DMY", "months_names": ["janeiro", "fevereiro", "marГ§o", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (79, 'PORTUGUESE', 'PORTUGUESE (PORTUGAL)', 'PORTUGUГЉS', 'PORTUGUESE', 'PORTUGAL', 'PT-PT', '{"date_first": 7, "days_names": ["segunda-feira", "terГ§a-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sГЎbado", "domingo"], "date_format": "DMY", "months_names": ["janeiro", "fevereiro", "marГ§o", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (80, 'FINNISH', 'FINNISH (FINLAND)', NULL, NULL, 'FINLAND', 'FI-FI', '{"date_first": 1, "days_names": ["maanantai", "tiistai", "keskiviikko", "torstai", "perjantai", "lauantai", "sunnuntai"], "date_format": "DMY", "months_names": ["tammikuuta", "helmikuuta", "maaliskuuta", "huhtikuuta", "toukokuuta", "kesГ¤kuuta", "heinГ¤kuuta", "elokuuta", "syyskuuta", "lokakuuta", "marraskuuta", "joulukuuta"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["tammi", "helmi", "maalis", "huhti", "touko", "kesГ¤", "heinГ¤", "elo", "syys", "loka", "marras", "joulu"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (81, 'FINNISH (MS SQL)', 'FINNISH (FINLAND)', 'SUOMI', 'FINNISH', 'FINLAND', 'FI', '{"date_first": 1, "days_names": ["maanantai", "tiistai", "keskiviikko", "torstai", "perjantai", "lauantai", "sunnuntai"], "date_format": "DMY", "months_names": ["tammikuuta", "helmikuuta", "maaliskuuta", "huhtikuuta", "toukokuuta", "kesГ¤kuuta", "heinГ¤kuuta", "elokuuta", "syyskuuta", "lokakuuta", "marraskuuta", "joulukuuta"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["tammi", "helmi", "maalis", "huhti", "touko", "kesГ¤", "heinГ¤", "elo", "syys", "loka", "marras", "joulu"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (82, 'SWEDISH', 'SWEDISH (FINLAND)', NULL, NULL, 'FINLAND', 'SV-FI', '{"date_first": 1, "days_names": ["mГҐndag", "tisdag", "onsdag", "torsdag", "fredag", "lГ¶rdag", "sГ¶ndag"], "date_format": "DMY", "months_names": ["januari", "februari", "mars", "april", "maj", "juni", "juli", "augusti", "september", "oktober", "november", "december"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["jan", "feb", "mar", "apr", "maj", "jun", "jul", "aug", "sep", "okt", "nov", "dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (83, 'SWEDISH', 'SWEDISH (SWEDEN)', 'SVENSKA', 'SWEDISH', 'SWEDEN', 'SV-SE', '{"date_first": 1, "days_names": ["mГҐndag", "tisdag", "onsdag", "torsdag", "fredag", "lГ¶rdag", "sГ¶ndag"], "date_format": "YMD", "months_names": ["januari", "februari", "mars", "april", "maj", "juni", "juli", "augusti", "september", "oktober", "november", "december"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["jan", "feb", "mar", "apr", "maj", "jun", "jul", "aug", "sep", "okt", "nov", "dec"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (84, 'CZECH', 'CZECH (CZECH REPUBLIC)', 'ДЊEЕ TINA', 'CZECH', 'CZECHIA', 'CS-CZ', '{"date_first": 1, "days_names": ["pondД›lГ­", "ГєterГЅ", "stЕ™eda", "ДЌtvrtek", "pГЎtek", "sobota", "nedД›le"], "date_format": "DMY", "months_names": ["leden", "Гєnor", "bЕ™ezen", "duben", "kvД›ten", "ДЌerven", "ДЌervenec", "srpen", "zГЎЕ™Г­", "Е™Г­jen", "listopad", "prosinec"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (85, 'HUNGARIAN', 'HUNGARIAN (HUNGARY)', 'MAGYAR', 'HUNGARIAN', 'HUNGARY', 'HU-HU', '{"date_first": 1, "days_names": ["hГ©tfЕ‘", "kedd", "szerda", "csГјtГ¶rtГ¶k", "pГ©ntek", "szombat", "vasГЎrnap"], "date_format": "YMD", "months_names": ["januГЎr", "februГЎr", "mГЎrcius", "ГЎprilis", "mГЎjus", "jГєnius", "jГєlius", "augusztus", "szeptember", "oktГіber", "november", "december"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (86, 'POLISH', 'POLISH (POLAND)', 'POLSKI', 'POLISH', 'POLAND', 'PL-PL', '{"date_first": 1, "days_names": ["poniedziaЕ‚ek", "wtorek", "Е›roda", "czwartek", "piД…tek", "sobota", "niedziela"], "date_format": "DMY", "months_names": ["styczeЕ„", "luty", "marzec", "kwiecieЕ„", "maj", "czerwiec", "lipiec", "sierpieЕ„", "wrzesieЕ„", "paЕєdziernik", "listopad", "grudzieЕ„"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (88, 'ROMANIAN', 'ROMANIAN (ROMANIA)', 'ROMГ‚NД‚', 'ROMANIAN', 'ROMANIA', 'RO-RO', '{"date_first": 1, "days_names": ["luni", "marЕЈi", "miercuri", "joi", "vineri", "sГ®mbДѓtДѓ", "duminicДѓ"], "date_format": "DMY", "months_names": ["ianuarie", "februarie", "martie", "aprilie", "mai", "iunie", "iulie", "august", "septembrie", "octombrie", "noiembrie", "decembrie"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["Ian", "Feb", "Mar", "Apr", "Mai", "Iun", "Iul", "Aug", "Sep", "Oct", "Nov", "Dec"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (89, 'CROATIAN', 'CROATIAN (CROATIA)', 'HRVATSKI', 'CROATIAN', 'CROATIA', 'HR-HR', '{"date_first": 1, "days_names": ["ponedjeljak", "utorak", "srijeda", "ДЌetvrtak", "petak", "subota", "nedjelja"], "date_format": "DMY", "months_names": ["sijeДЌanj", "veljaДЌa", "oЕѕujak", "travanj", "svibanj", "lipanj", "srpanj", "kolovoz", "rujan", "listopad", "studeni", "prosinac"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["sij", "vel", "oЕѕu", "tra", "svi", "lip", "srp", "kol", "ruj", "lis", "stu", "pro"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (90, 'SLOVAK', 'SLOVAK (SLOVAKIA)', 'SLOVENДЊINA', 'SLOVAK', 'SLOVAKIA', 'SK-SK', '{"date_first": 1, "days_names": ["pondelok", "utorok", "streda", "ЕЎtvrtok", "piatok", "sobota", "nedeДѕa"], "date_format": "DMY", "months_names": ["januГЎr", "februГЎr", "marec", "aprГ­l", "mГЎj", "jГєn", "jГєl", "august", "september", "oktГіber", "november", "december"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (91, 'SLOVENIAN', 'SLOVENIAN (SLOVENIA)', 'SLOVENSKI', 'SLOVENIAN', 'SLOVENIA', 'SL-SI', '{"date_first": 1, "days_names": ["ponedeljek", "torek", "sreda", "ДЌetrtek", "petek", "sobota", "nedelja"], "date_format": "DMY", "months_names": ["januar", "februar", "marec", "april", "maj", "junij", "julij", "avgust", "september", "oktober", "november", "december"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["jan", "feb", "mar", "apr", "maj", "jun", "jul", "avg", "sept", "okt", "nov", "dec"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (92, 'GREEK', 'GREEK (GREECE)', 'О•О›О›О—ОќО™ОљО†', 'GREEK', 'GREECE', 'EL-GR', '{"date_first": 1, "days_names": ["О”ОµП…П„О­ПЃО±", "О¤ПЃОЇП„О·", "О¤ОµП„О¬ПЃП„О·", "О О­ОјПЂП„О·", "О О±ПЃО±ПѓОєОµП…О®", "ОЈО¬ОІОІО±П„Ої", "ОљП…ПЃО№О±ОєО®"], "date_format": "DMY", "months_names": ["О™О±ОЅОїП…О±ПЃОЇОїП…", "О¦ОµОІПЃОїП…О±ПЃОЇОїП…", "ОњО±ПЃП„ОЇОїП…", "О‘ПЂПЃО№О»ОЇОїП…", "ОњО±_ОїП…", "О™ОїП…ОЅОЇОїП…", "О™ОїП…О»ОЇОїП…", "О‘П…ОіОїПЌПѓП„ОїП…", "ОЈОµПЂП„ОµОјОІПЃОЇОїП…", "ОџОєП„П‰ОІПЃОЇОїП…", "ОќОїОµОјОІПЃОЇОїП…", "О”ОµОєОµОјОІПЃОЇОїП…"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["О™О±ОЅ", "О¦ОµОІ", "ОњО±ПЃ", "О‘ПЂПЃ", "ОњО±ПЉ", "О™ОїП…ОЅ", "О™ОїП…О»", "О‘П…Оі", "ОЈОµПЂ", "ОџОєП„", "ОќОїОµ", "О”ОµОє"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (93, 'BULGARIAN', 'BULGARIAN (BULGARIA)', 'Р‘РЄР›Р“РђР РЎРљР', 'BULGARIAN', 'BULGARIA', 'BG-BG', '{"date_first": 1, "days_names": ["РїРѕРЅРµРґРµР»РЅРёРє", "РІС‚РѕСЂРЅРёРє", "СЃСЂСЏРґР°", "С‡РµС‚РІСЉСЂС‚СЉРє", "РїРµС‚СЉРє", "СЃСЉР±РѕС‚Р°", "РЅРµРґРµР»СЏ"], "date_format": "DMY", "months_names": ["СЏРЅСѓР°СЂРё", "С„РµРІСЂСѓР°СЂРё", "РјР°СЂС‚", "Р°РїСЂРёР»", "РјР°Р№", "СЋРЅРё", "СЋР»Рё", "Р°РІРіСѓСЃС‚", "СЃРµРїС‚РµРјРІСЂРё", "РѕРєС‚РѕРјРІСЂРё", "РЅРѕРµРјРІСЂРё", "РґРµРєРµРјРІСЂРё"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["СЏРЅСѓР°СЂРё", "С„РµРІСЂСѓР°СЂРё", "РјР°СЂС‚", "Р°РїСЂРёР»", "РјР°Р№", "СЋРЅРё", "СЋР»Рё", "Р°РІРіСѓСЃС‚", "СЃРµРїС‚РµРјРІСЂРё", "РѕРєС‚РѕРјРІСЂРё", "РЅРѕРµРјРІСЂРё", "РґРµРєРµРјРІСЂРё"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (94, 'RUSSIAN', 'RUSSIAN (BELARUS)', NULL, NULL, 'BELARUS', 'RU-BY', '{"date_first": 1, "days_names": ["РїРѕРЅРµРґРµР»СЊРЅРёРє", "РІС‚РѕСЂРЅРёРє", "СЃСЂРµРґР°", "С‡РµС‚РІРµСЂРі", "РїСЏС‚РЅРёС†Р°", "СЃСѓР±Р±РѕС‚Р°", "РІРѕСЃРєСЂРµСЃРµРЅСЊРµ"], "date_format": "DMY", "months_names": ["РЇРЅРІР°СЂСЊ", "Р¤РµРІСЂР°Р»СЊ", "РњР°СЂС‚", "РђРїСЂРµР»СЊ", "РњР°Р№", "РСЋРЅСЊ", "РСЋР»СЊ", "РђРІРіСѓСЃС‚", "РЎРµРЅС‚СЏР±СЂСЊ", "РћРєС‚СЏР±СЂСЊ", "РќРѕСЏР±СЂСЊ", "Р”РµРєР°Р±СЂСЊ"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["СЏРЅРІ", "С„РµРІ", "РјР°СЂ", "Р°РїСЂ", "РјР°Р№", "РёСЋРЅ", "РёСЋР»", "Р°РІРі", "СЃРµРЅ", "РѕРєС‚", "РЅРѕСЏ", "РґРµРє"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (95, 'RUSSIAN', 'RUSSIAN (KAZAKHSTAN)', NULL, NULL, 'KAZAKHSTAN', 'RU-KZ', '{"date_first": 1, "days_names": ["РїРѕРЅРµРґРµР»СЊРЅРёРє", "РІС‚РѕСЂРЅРёРє", "СЃСЂРµРґР°", "С‡РµС‚РІРµСЂРі", "РїСЏС‚РЅРёС†Р°", "СЃСѓР±Р±РѕС‚Р°", "РІРѕСЃРєСЂРµСЃРµРЅСЊРµ"], "date_format": "DMY", "months_names": ["РЇРЅРІР°СЂСЊ", "Р¤РµРІСЂР°Р»СЊ", "РњР°СЂС‚", "РђРїСЂРµР»СЊ", "РњР°Р№", "РСЋРЅСЊ", "РСЋР»СЊ", "РђРІРіСѓСЃС‚", "РЎРµРЅС‚СЏР±СЂСЊ", "РћРєС‚СЏР±СЂСЊ", "РќРѕСЏР±СЂСЊ", "Р”РµРєР°Р±СЂСЊ"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["СЏРЅРІ", "С„РµРІ", "РјР°СЂ", "Р°РїСЂ", "РјР°Р№", "РёСЋРЅ", "РёСЋР»", "Р°РІРі", "СЃРµРЅ", "РѕРєС‚", "РЅРѕСЏ", "РґРµРє"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (96, 'RUSSIAN', 'RUSSIAN (KYRGYZSTAN)', NULL, NULL, 'KYRGYZSTAN', 'RU-KG', '{"date_first": 1, "days_names": ["РїРѕРЅРµРґРµР»СЊРЅРёРє", "РІС‚РѕСЂРЅРёРє", "СЃСЂРµРґР°", "С‡РµС‚РІРµСЂРі", "РїСЏС‚РЅРёС†Р°", "СЃСѓР±Р±РѕС‚Р°", "РІРѕСЃРєСЂРµСЃРµРЅСЊРµ"], "date_format": "DMY", "months_names": ["РЇРЅРІР°СЂСЊ", "Р¤РµРІСЂР°Р»СЊ", "РњР°СЂС‚", "РђРїСЂРµР»СЊ", "РњР°Р№", "РСЋРЅСЊ", "РСЋР»СЊ", "РђРІРіСѓСЃС‚", "РЎРµРЅС‚СЏР±СЂСЊ", "РћРєС‚СЏР±СЂСЊ", "РќРѕСЏР±СЂСЊ", "Р”РµРєР°Р±СЂСЊ"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["СЏРЅРІ", "С„РµРІ", "РјР°СЂ", "Р°РїСЂ", "РјР°Р№", "РёСЋРЅ", "РёСЋР»", "Р°РІРі", "СЃРµРЅ", "РѕРєС‚", "РЅРѕСЏ", "РґРµРє"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (97, 'RUSSIAN', 'RUSSIAN (MOLDOVA)', NULL, NULL, 'MOLDOVA', 'RU-MD', '{"date_first": 1, "days_names": ["РїРѕРЅРµРґРµР»СЊРЅРёРє", "РІС‚РѕСЂРЅРёРє", "СЃСЂРµРґР°", "С‡РµС‚РІРµСЂРі", "РїСЏС‚РЅРёС†Р°", "СЃСѓР±Р±РѕС‚Р°", "РІРѕСЃРєСЂРµСЃРµРЅСЊРµ"], "date_format": "DMY", "months_names": ["РЇРЅРІР°СЂСЊ", "Р¤РµРІСЂР°Р»СЊ", "РњР°СЂС‚", "РђРїСЂРµР»СЊ", "РњР°Р№", "РСЋРЅСЊ", "РСЋР»СЊ", "РђРІРіСѓСЃС‚", "РЎРµРЅС‚СЏР±СЂСЊ", "РћРєС‚СЏР±СЂСЊ", "РќРѕСЏР±СЂСЊ", "Р”РµРєР°Р±СЂСЊ"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["СЏРЅРІ", "С„РµРІ", "РјР°СЂ", "Р°РїСЂ", "РјР°Р№", "РёСЋРЅ", "РёСЋР»", "Р°РІРі", "СЃРµРЅ", "РѕРєС‚", "РЅРѕСЏ", "РґРµРє"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (98, 'RUSSIAN', 'RUSSIAN (RUSSIA)', 'Р РЈРЎРЎРљРР™', 'RUSSIAN', 'RUSSIA', 'RU-RU', '{"date_first": 1, "days_names": ["РїРѕРЅРµРґРµР»СЊРЅРёРє", "РІС‚РѕСЂРЅРёРє", "СЃСЂРµРґР°", "С‡РµС‚РІРµСЂРі", "РїСЏС‚РЅРёС†Р°", "СЃСѓР±Р±РѕС‚Р°", "РІРѕСЃРєСЂРµСЃРµРЅСЊРµ"], "date_format": "DMY", "months_names": ["РЇРЅРІР°СЂСЊ", "Р¤РµРІСЂР°Р»СЊ", "РњР°СЂС‚", "РђРїСЂРµР»СЊ", "РњР°Р№", "РСЋРЅСЊ", "РСЋР»СЊ", "РђРІРіСѓСЃС‚", "РЎРµРЅС‚СЏР±СЂСЊ", "РћРєС‚СЏР±СЂСЊ", "РќРѕСЏР±СЂСЊ", "Р”РµРєР°Р±СЂСЊ"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["СЏРЅРІ", "С„РµРІ", "РјР°СЂ", "Р°РїСЂ", "РјР°Р№", "РёСЋРЅ", "РёСЋР»", "Р°РІРі", "СЃРµРЅ", "РѕРєС‚", "РЅРѕСЏ", "РґРµРє"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (99, 'RUSSIAN', 'RUSSIAN (UKRAINE)', NULL, NULL, 'UKRAINE', 'RU-UA', '{"date_first": 1, "days_names": ["РїРѕРЅРµРґРµР»СЊРЅРёРє", "РІС‚РѕСЂРЅРёРє", "СЃСЂРµРґР°", "С‡РµС‚РІРµСЂРі", "РїСЏС‚РЅРёС†Р°", "СЃСѓР±Р±РѕС‚Р°", "РІРѕСЃРєСЂРµСЃРµРЅСЊРµ"], "date_format": "DMY", "months_names": ["РЇРЅРІР°СЂСЊ", "Р¤РµРІСЂР°Р»СЊ", "РњР°СЂС‚", "РђРїСЂРµР»СЊ", "РњР°Р№", "РСЋРЅСЊ", "РСЋР»СЊ", "РђРІРіСѓСЃС‚", "РЎРµРЅС‚СЏР±СЂСЊ", "РћРєС‚СЏР±СЂСЊ", "РќРѕСЏР±СЂСЊ", "Р”РµРєР°Р±СЂСЊ"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["СЏРЅРІ", "С„РµРІ", "РјР°СЂ", "Р°РїСЂ", "РјР°Р№", "РёСЋРЅ", "РёСЋР»", "Р°РІРі", "СЃРµРЅ", "РѕРєС‚", "РЅРѕСЏ", "РґРµРє"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (100, 'UKRAINIAN', 'UKRAINIAN (UKRAINE)', 'РЈРљР РђР‡РќРЎР¬РљРђ', 'UKRAINIAN', 'UKRAINE', 'UK-UA', '{"date_first": 1, "days_names": ["РїРѕРЅРµРґС–Р»РѕРє", "РІС–РІС‚РѕСЂРѕРє", "СЃРµСЂРµРґР°", "С‡РµС‚РІРµСЂ", "РївЂ™СЏС‚РЅРёС†СЏ", "СЃСѓР±РѕС‚Р°", "РЅРµРґС–Р»СЏ"], "date_format": "DMY", "months_names": ["РЎС–С‡РµРЅСЊ", "Р›СЋС‚РёР№", "Р‘РµСЂРµР·РµРЅСЊ", "РљРІС–С‚РµРЅСЊ", "РўСЂР°РІРµРЅСЊ", "Р§РµСЂРІРµРЅСЊ", "Р›РёРїРµРЅСЊ", "РЎРµСЂРїРµРЅСЊ", "Р’РµСЂРµСЃРµРЅСЊ", "Р–РѕРІС‚РµРЅСЊ", "Р›РёСЃС‚РѕРїР°Рґ", "Р“СЂСѓРґРµРЅСЊ"], "days_shortnames": ["РїРЅ", "РІС‚", "СЃСЂ", "С‡С‚", "РїС‚", "СЃР±", "РЅРґ"], "months_shortnames": ["СЃС–С‡", "Р»СЋС‚", "Р±РµСЂРµР·", "РєРІС–С‚", "С‚СЂР°РІ", "С‡РµСЂРІ", "Р»РёРї", "СЃРµСЂРї", "РІРµСЂРµСЃ", "Р¶РѕРІС‚", "Р»РёСЃС‚РѕРї", "РіСЂСѓРґ"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (101, 'TURKISH', 'TURKISH (TURKEY)', 'TГњRKГ‡E', 'TURKISH', 'TURKEY', 'TR-TR', '{"date_first": 1, "days_names": ["Pazartesi", "SalД±", "Г‡arЕџamba", "PerЕџembe", "Cuma", "Cumartesi", "Pazar"], "date_format": "DMY", "months_names": ["Ocak", "Ећubat", "Mart", "Nisan", "MayД±s", "Haziran", "Temmuz", "AДџustos", "EylГјl", "Ekim", "KasД±m", "AralД±k"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["Oca", "Ећub", "Mar", "Nis", "May", "Haz", "Tem", "AДџu", "Eyl", "Eki", "Kas", "Ara"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (102, 'ESTONIAN', 'ESTONIAN (ESTONIA)', 'EESTI', 'ESTONIAN', 'ESTONIA', 'ET-EE', '{"date_first": 1, "days_names": ["esmaspГ¤ev", "teisipГ¤ev", "kolmapГ¤ev", "neljapГ¤ev", "reede", "laupГ¤ev", "pГјhapГ¤ev"], "date_format": "DMY", "months_names": ["jaanuar", "veebruar", "mГ¤rts", "aprill", "mai", "juuni", "juuli", "august", "september", "oktoober", "november", "detsember"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["jaan", "veebr", "mГ¤rts", "apr", "mai", "juuni", "juuli", "aug", "sept", "okt", "nov", "dets"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (103, 'LATVIAN', 'LATVIAN (LATVIA)', 'LATVIEЕ U', 'LATVIAN', 'LATVIA', 'LV-LV', '{"date_first": 1, "days_names": ["pirmdiena", "otrdiena", "treЕЎdiena", "ceturtdiena", "piektdiena", "sestdiena", "svД“tdiena"], "date_format": "YMD", "months_names": ["janvДЃris", "februДЃris", "marts", "aprД«lis", "maijs", "jЕ«nijs", "jЕ«lijs", "augusts", "septembris", "oktobris", "novembris", "decembris"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["jan", "feb", "mar", "apr", "mai", "jЕ«n", "jЕ«l", "aug", "sep", "okt", "nov", "dec"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (114, 'ARABIC', 'ARABIC (IRAQ)', NULL, NULL, 'IRAQ', 'AR-IQ', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (104, 'LITHUANIAN', 'LITHUANIAN (LITHUANIA)', 'LIETUVIЕІ', 'LITHUANIAN', 'LITHUANIA', 'LT-LT', '{"date_first": 1, "days_names": ["pirmadienis", "antradienis", "treДЌiadienis", "ketvirtadienis", "penktadienis", "ЕЎeЕЎtadienis", "sekmadienis"], "date_format": "YMD", "months_names": ["sausis", "vasaris", "kovas", "balandis", "geguЕѕД—", "birЕѕelis", "liepa", "rugpjЕ«tis", "rugsД—jis", "spalis", "lapkritis", "gruodis"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["sau", "vas", "kov", "bal", "geg", "bir", "lie", "rgp", "rgs", "spl", "lap", "grd"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (105, 'CHINESE (TRADITIONAL)', 'CHINESE (TRADITIONAL, CHINA)', 'з№Ѓй«”дё­ж–‡', 'TRADITIONAL CHINESE', 'CHINA', 'ZH-TW', '{"date_first": 7, "days_names": ["жџжњџдёЂ", "жџжњџдєЊ", "жџжњџдё‰", "жџжњџе››", "жџжњџдє”", "жџжњџе…­", "жџжњџж—Ґ"], "date_format": "YMD", "months_names": ["дёЂжњ€", "дєЊжњ€", "дё‰жњ€", "е››жњ€", "дє”жњ€", "е…­жњ€", "дёѓжњ€", "е…«жњ€", "д№ќжњ€", "еЌЃжњ€", "еЌЃдёЂжњ€", "еЌЃдєЊжњ€"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (106, 'KOREAN', 'KOREAN (NORTH KOREA)', NULL, NULL, 'NORTH KOREA', 'KO-KP', '{"date_first": 7, "days_names": ["м›”мљ”мќј", "н™”мљ”мќј", "м€мљ”мќј", "лЄ©мљ”мќј", "кё€мљ”мќј", "н† мљ”мќј", "мќјмљ”мќј"], "date_format": "YMD", "months_names": ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (107, 'KOREAN', 'KOREAN (SOUTH KOREA)', 'н•њкµ­м–ґ', 'KOREAN', 'KOREA', 'KO-KR', '{"date_first": 7, "days_names": ["м›”мљ”мќј", "н™”мљ”мќј", "м€мљ”мќј", "лЄ©мљ”мќј", "кё€мљ”мќј", "н† мљ”мќј", "мќјмљ”мќј"], "date_format": "YMD", "months_names": ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (108, 'CHINESE (SIMPLIFIED)', 'CHINESE (SIMPLIFIED, CHINA)', 'з®ЂдЅ“дё­ж–‡', 'SIMPLIFIED CHINESE', 'CHINA', 'ZH-CN', '{"date_first": 7, "days_names": ["жџжњџдёЂ", "жџжњџдєЊ", "жџжњџдё‰", "жџжњџе››", "жџжњџдє”", "жџжњџе…­", "жџжњџж—Ґ"], "date_format": "YMD", "months_names": ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"], "days_extrashortnames": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (109, 'ARABIC (MS SQL)', 'ARABIC (ARABIC)', 'GENERAL ARABIC', 'GENERAL ARABIC', 'ARABIC', 'AR', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (110, 'ARABIC', 'ARABIC (ALGERIA)', NULL, NULL, 'ALGERIA', 'AR-DZ', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (111, 'ARABIC', 'ARABIC (BAHRAIN)', NULL, NULL, 'BAHRAIN', 'AR-BH', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (112, 'ARABIC', 'ARABIC (EGYPT)', NULL, NULL, 'EGYPT', 'AR-EG', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (113, 'ARABIC', 'ARABIC (ERITREA)', NULL, NULL, 'ERITREA', 'AR-ER', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (115, 'ARABIC', 'ARABIC (ISRAEL)', NULL, NULL, 'ISRAEL', 'AR-IL', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (116, 'ARABIC', 'ARABIC (JORDAN)', NULL, NULL, 'JORDAN', 'AR-JO', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (117, 'ARABIC', 'ARABIC (KUWAIT)', NULL, NULL, 'KUWAIT', 'AR-KW', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (118, 'ARABIC', 'ARABIC (LEBANON)', NULL, NULL, 'LEBANON', 'AR-LB', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (119, 'ARABIC', 'ARABIC (LIBYA)', NULL, NULL, 'LIBYA', 'AR-LY', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (120, 'ARABIC', 'ARABIC (MOROCCO)', NULL, NULL, 'MOROCCO', 'AR-MA', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (121, 'ARABIC', 'ARABIC (OMAN)', NULL, NULL, 'OMAN', 'AR-OM', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (122, 'ARABIC', 'ARABIC (QATAR)', NULL, NULL, 'QATAR', 'AR-QA', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (123, 'ARABIC', 'ARABIC (SAUDI ARABIA)', 'ARABIC', 'ARABIC', 'SAUDI ARABIA', 'AR-SA', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (124, 'ARABIC', 'ARABIC (SOMALIA)', NULL, NULL, 'SOMALIA', 'AR-SO', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (125, 'ARABIC', 'ARABIC (SYRIA)', NULL, NULL, 'SYRIA', 'AR-SY', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (126, 'ARABIC', 'ARABIC (TUNISIA)', NULL, NULL, 'TUNISIA', 'AR-TN', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (127, 'ARABIC', 'ARABIC (UNITED ARAB EMIRATES)', NULL, NULL, 'UNITED ARAB EMIRATES', 'AR-AE', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (128, 'ARABIC', 'ARABIC (YEMEN)', NULL, NULL, 'YEMEN', 'AR-YE', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Muharram", "Safar", "Rabie I", "Rabie II", "Jumada I", "Jumada II", "Rajab", "Shaaban", "Ramadan", "Shawwal", "Thou Alqadah", "Thou Alhajja"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_shortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (129, 'THAI', 'THAI (THAILAND)', 'а№„аё—аёў', 'THAI', 'THAILAND', 'TH-TH', '{"date_first": 7, "days_names": ["аё€аё±аё™аё—аёЈа№Њ", "аё­аё±аё‡аё„аёІаёЈ", "аёћаёёаё", "аёћаё¤аё«аё±аёЄаёљаё”аёµ", "аёЁаёёаёЃаёЈа№Њ", "а№ЂаёЄаёІаёЈа№Њ", "аё­аёІаё—аёґаё•аёўа№Њ"], "date_format": "DMY", "months_names": ["аёЎаёЃаёЈаёІаё„аёЎ", "аёЃаёёаёЎаё аёІаёћаё±аё™аёа№Њ", "аёЎаёµаё™аёІаё„аёЎ", "а№ЂаёЎаё©аёІаёўаё™", "аёћаё¤аё©аё аёІаё„аёЎ", "аёЎаёґаё–аёёаё™аёІаёўаё™", "аёЃаёЈаёЃаёЋаёІаё„аёЎ", "аёЄаёґаё‡аё«аёІаё„аёЎ", "аёЃаё±аё™аёўаёІаёўаё™", "аё•аёёаёҐаёІаё„аёЎ", "аёћаё¤аёЁаё€аёґаёЃаёІаёўаё™", "аёаё±аё™аё§аёІаё„аёЎ"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["аёЎ.аё„.", "аёЃ.аёћ.", "аёЎаёµ.аё„.", "а№ЂаёЎ.аёў.", "аёћ.аё„.", "аёЎаёґ.аёў.", "аёЃ.аё„.", "аёЄ.аё„.", "аёЃ.аёў.", "аё•.аё„.", "аёћ.аёў.", "аё.аё„."], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');
INSERT INTO aws_sqlserver_ext.sys_languages VALUES (130, 'HIJRI', 'HIJRI (ISLAMIC)', 'HIJRI', 'ISLAMIC', 'ISLAMIC', 'HI-IS', '{"date_first": 1, "days_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "date_format": "DMY", "months_names": ["Щ…Ш­Ш±Щ…", "ШµЩЃШ±", "Ш±ШЁЩЉШ№ Ш§Щ„Ш§Щ€Щ„", "Ш±ШЁЩЉШ№ Ш§Щ„Ш«Ш§Щ†ЩЉ", "Ш¬Щ…Ш§ШЇЩ‰ Ш§Щ„Ш§Щ€Щ„Щ‰", "Ш¬Щ…Ш§ШЇЩ‰ Ш§Щ„Ш«Ш§Щ†ЩЉШ©", "Ш±Ш¬ШЁ", "ШґШ№ШЁШ§Щ†", "Ш±Щ…Ш¶Ш§Щ†", "ШґЩ€Ш§Щ„", "Ш°Щ€ Ш§Щ„Щ‚Ш№ШЇШ©", "Ш°Щ€ Ш§Щ„Ш­Ш¬Ш©"], "days_shortnames": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], "months_extranames": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "months_shortnames": ["Щ…Ш­Ш±Щ…", "ШµЩЃШ±", "Ш±ШЁЩЉШ№ Ш§Щ„Ш§Щ€Щ„", "Ш±ШЁЩЉШ№ Ш§Щ„Ш«Ш§Щ†ЩЉ", "Ш¬Щ…Ш§ШЇЩ‰ Ш§Щ„Ш§Щ€Щ„Щ‰", "Ш¬Щ…Ш§ШЇЩ‰ Ш§Щ„Ш«Ш§Щ†ЩЉШ©", "Ш±Ш¬ШЁ", "ШґШ№ШЁШ§Щ†", "Ш±Щ…Ш¶Ш§Щ†", "ШґЩ€Ш§Щ„", "Ш°Щ€ Ш§Щ„Щ‚Ш№ШЇШ©", "Ш°Щ€ Ш§Щ„Ш­Ш¬Ш©"], "months_extrashortnames": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]}');


--
-- TOC entry 3845 (class 0 OID 16890)
-- Dependencies: 228
-- Data for Name: sysjobhistory; Type: TABLE DATA; Schema: aws_sqlserver_ext; Owner: postgres
--



--
-- TOC entry 3847 (class 0 OID 16899)
-- Dependencies: 230
-- Data for Name: sysjobs; Type: TABLE DATA; Schema: aws_sqlserver_ext; Owner: postgres
--



--
-- TOC entry 3846 (class 0 OID 16896)
-- Dependencies: 229
-- Data for Name: sysjobschedules; Type: TABLE DATA; Schema: aws_sqlserver_ext; Owner: postgres
--



--
-- TOC entry 3848 (class 0 OID 16905)
-- Dependencies: 231
-- Data for Name: sysjobsteps; Type: TABLE DATA; Schema: aws_sqlserver_ext; Owner: postgres
--



--
-- TOC entry 3850 (class 0 OID 16916)
-- Dependencies: 233
-- Data for Name: sysmail_account; Type: TABLE DATA; Schema: aws_sqlserver_ext; Owner: postgres
--



--
-- TOC entry 3851 (class 0 OID 16922)
-- Dependencies: 234
-- Data for Name: sysmail_attachments; Type: TABLE DATA; Schema: aws_sqlserver_ext; Owner: postgres
--



--
-- TOC entry 3852 (class 0 OID 16928)
-- Dependencies: 235
-- Data for Name: sysmail_log; Type: TABLE DATA; Schema: aws_sqlserver_ext; Owner: postgres
--



--
-- TOC entry 3853 (class 0 OID 16934)
-- Dependencies: 236
-- Data for Name: sysmail_mailitems; Type: TABLE DATA; Schema: aws_sqlserver_ext; Owner: postgres
--



--
-- TOC entry 3855 (class 0 OID 16944)
-- Dependencies: 238
-- Data for Name: sysmail_profile; Type: TABLE DATA; Schema: aws_sqlserver_ext; Owner: postgres
--



--
-- TOC entry 3854 (class 0 OID 16941)
-- Dependencies: 237
-- Data for Name: sysmail_profileaccount; Type: TABLE DATA; Schema: aws_sqlserver_ext; Owner: postgres
--



--
-- TOC entry 3856 (class 0 OID 16948)
-- Dependencies: 239
-- Data for Name: sysmail_server; Type: TABLE DATA; Schema: aws_sqlserver_ext; Owner: postgres
--



--
-- TOC entry 3857 (class 0 OID 16951)
-- Dependencies: 240
-- Data for Name: sysschedules; Type: TABLE DATA; Schema: aws_sqlserver_ext; Owner: postgres
--



--
-- TOC entry 3858 (class 0 OID 16956)
-- Dependencies: 241
-- Data for Name: versions; Type: TABLE DATA; Schema: aws_sqlserver_ext; Owner: postgres
--

INSERT INTO aws_sqlserver_ext.versions VALUES ('SQL', '1.0.650');


--
-- TOC entry 3859 (class 0 OID 16961)
-- Dependencies: 242
-- Data for Name: service_settings; Type: TABLE DATA; Schema: aws_sqlserver_ext_data; Owner: postgres
--



--
-- TOC entry 3928 (class 0 OID 0)
-- Dependencies: 218
-- Name: sysjobhistory_seq; Type: SEQUENCE SET; Schema: aws_sqlserver_ext; Owner: postgres
--

SELECT pg_catalog.setval('aws_sqlserver_ext.sysjobhistory_seq', 1, false);


--
-- TOC entry 3929 (class 0 OID 0)
-- Dependencies: 219
-- Name: sysjobs_seq; Type: SEQUENCE SET; Schema: aws_sqlserver_ext; Owner: postgres
--

SELECT pg_catalog.setval('aws_sqlserver_ext.sysjobs_seq', 1, false);


--
-- TOC entry 3930 (class 0 OID 0)
-- Dependencies: 220
-- Name: sysjobsteps_seq; Type: SEQUENCE SET; Schema: aws_sqlserver_ext; Owner: postgres
--

SELECT pg_catalog.setval('aws_sqlserver_ext.sysjobsteps_seq', 1, false);


--
-- TOC entry 3931 (class 0 OID 0)
-- Dependencies: 221
-- Name: sysmail_account_seq; Type: SEQUENCE SET; Schema: aws_sqlserver_ext; Owner: postgres
--

SELECT pg_catalog.setval('aws_sqlserver_ext.sysmail_account_seq', 1, false);


--
-- TOC entry 3932 (class 0 OID 0)
-- Dependencies: 222
-- Name: sysmail_attachments_seq; Type: SEQUENCE SET; Schema: aws_sqlserver_ext; Owner: postgres
--

SELECT pg_catalog.setval('aws_sqlserver_ext.sysmail_attachments_seq', 1, false);


--
-- TOC entry 3933 (class 0 OID 0)
-- Dependencies: 223
-- Name: sysmail_log_seq; Type: SEQUENCE SET; Schema: aws_sqlserver_ext; Owner: postgres
--

SELECT pg_catalog.setval('aws_sqlserver_ext.sysmail_log_seq', 1, false);


--
-- TOC entry 3934 (class 0 OID 0)
-- Dependencies: 224
-- Name: sysmail_mailitems_seq; Type: SEQUENCE SET; Schema: aws_sqlserver_ext; Owner: postgres
--

SELECT pg_catalog.setval('aws_sqlserver_ext.sysmail_mailitems_seq', 1, false);


--
-- TOC entry 3935 (class 0 OID 0)
-- Dependencies: 225
-- Name: sysmail_profile_seq; Type: SEQUENCE SET; Schema: aws_sqlserver_ext; Owner: postgres
--

SELECT pg_catalog.setval('aws_sqlserver_ext.sysmail_profile_seq', 1, false);


--
-- TOC entry 3936 (class 0 OID 0)
-- Dependencies: 226
-- Name: sysschedules_seq; Type: SEQUENCE SET; Schema: aws_sqlserver_ext; Owner: postgres
--

SELECT pg_catalog.setval('aws_sqlserver_ext.sysschedules_seq', 1, false);


--
-- TOC entry 3937 (class 0 OID 0)
-- Dependencies: 227
-- Name: inc_seq_rowversion; Type: SEQUENCE SET; Schema: aws_sqlserver_ext_data; Owner: postgres
--

SELECT pg_catalog.setval('aws_sqlserver_ext_data.inc_seq_rowversion', 1, false);


--
-- TOC entry 3626 (class 2606 OID 16973)
-- Name: sys_languages pk_sys_lang_id; Type: CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sys_languages
    ADD CONSTRAINT pk_sys_lang_id PRIMARY KEY (lang_id);


--
-- TOC entry 3619 (class 2606 OID 16967)
-- Name: sysjobhistory pk_sysjobhistory; Type: CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysjobhistory
    ADD CONSTRAINT pk_sysjobhistory PRIMARY KEY (instance_id);


--
-- TOC entry 3621 (class 2606 OID 16969)
-- Name: sysjobs pk_sysjobs; Type: CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysjobs
    ADD CONSTRAINT pk_sysjobs PRIMARY KEY (job_id);


--
-- TOC entry 3623 (class 2606 OID 16971)
-- Name: sysjobsteps pk_sysjobsteps; Type: CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysjobsteps
    ADD CONSTRAINT pk_sysjobsteps PRIMARY KEY (job_step_id);


--
-- TOC entry 3629 (class 2606 OID 16975)
-- Name: sysmail_account pk_sysmail_account; Type: CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysmail_account
    ADD CONSTRAINT pk_sysmail_account PRIMARY KEY (account_id);


--
-- TOC entry 3633 (class 2606 OID 16977)
-- Name: sysmail_attachments pk_sysmail_attachments; Type: CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysmail_attachments
    ADD CONSTRAINT pk_sysmail_attachments PRIMARY KEY (attachment_id);


--
-- TOC entry 3635 (class 2606 OID 16979)
-- Name: sysmail_log pk_sysmail_log; Type: CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysmail_log
    ADD CONSTRAINT pk_sysmail_log PRIMARY KEY (log_id);


--
-- TOC entry 3637 (class 2606 OID 16981)
-- Name: sysmail_mailitems pk_sysmail_mailitems; Type: CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysmail_mailitems
    ADD CONSTRAINT pk_sysmail_mailitems PRIMARY KEY (mailitem_id);


--
-- TOC entry 3641 (class 2606 OID 16985)
-- Name: sysmail_profile pk_sysmail_profile; Type: CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysmail_profile
    ADD CONSTRAINT pk_sysmail_profile PRIMARY KEY (profile_id);


--
-- TOC entry 3639 (class 2606 OID 16983)
-- Name: sysmail_profileaccount pk_sysmail_profileaccount; Type: CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysmail_profileaccount
    ADD CONSTRAINT pk_sysmail_profileaccount PRIMARY KEY (profile_id, account_id);


--
-- TOC entry 3645 (class 2606 OID 16987)
-- Name: sysschedules pk_sysschedules; Type: CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysschedules
    ADD CONSTRAINT pk_sysschedules PRIMARY KEY (schedule_id);


--
-- TOC entry 3647 (class 2606 OID 16989)
-- Name: versions pk_versions_component_name; Type: CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.versions
    ADD CONSTRAINT pk_versions_component_name PRIMARY KEY (extpackcomponentname);


--
-- TOC entry 3631 (class 2606 OID 16991)
-- Name: sysmail_account sysmail_account_namemustbeunique; Type: CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysmail_account
    ADD CONSTRAINT sysmail_account_namemustbeunique UNIQUE (name);


--
-- TOC entry 3643 (class 2606 OID 16993)
-- Name: sysmail_profile sysmail_profile_namemustbeunique; Type: CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysmail_profile
    ADD CONSTRAINT sysmail_profile_namemustbeunique UNIQUE (name);


--
-- TOC entry 3649 (class 2606 OID 17020)
-- Name: service_settings p_service_settings; Type: CONSTRAINT; Schema: aws_sqlserver_ext_data; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext_data.service_settings
    ADD CONSTRAINT p_service_settings PRIMARY KEY (service, setting);


--
-- TOC entry 3624 (class 1259 OID 17021)
-- Name: lang_name_territory_pg_idx; Type: INDEX; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE UNIQUE INDEX lang_name_territory_pg_idx ON aws_sqlserver_ext.sys_languages USING btree (lang_name_pg, territory);


--
-- TOC entry 3627 (class 1259 OID 17022)
-- Name: spec_culture_idx; Type: INDEX; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE UNIQUE INDEX spec_culture_idx ON aws_sqlserver_ext.sys_languages USING btree (spec_culture);


--
-- TOC entry 3656 (class 2620 OID 17162)
-- Name: sysjobsteps tr_sysjobsteps_aiud; Type: TRIGGER; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE TRIGGER tr_sysjobsteps_aiud AFTER INSERT OR UPDATE ON aws_sqlserver_ext.sysjobsteps FOR EACH ROW EXECUTE FUNCTION aws_sqlserver_ext.sp_jobstep_create_proc();


--
-- TOC entry 3655 (class 2620 OID 17163)
-- Name: sysjobsteps tr_sysjobsteps_bd; Type: TRIGGER; Schema: aws_sqlserver_ext; Owner: postgres
--

CREATE TRIGGER tr_sysjobsteps_bd BEFORE DELETE ON aws_sqlserver_ext.sysjobsteps FOR EACH ROW EXECUTE FUNCTION aws_sqlserver_ext.sp_jobstep_drop_proc();


--
-- TOC entry 3653 (class 2606 OID 16994)
-- Name: sysmail_log fk_log_mailitems_mailitem_id; Type: FK CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysmail_log
    ADD CONSTRAINT fk_log_mailitems_mailitem_id FOREIGN KEY (mailitem_id) REFERENCES aws_sqlserver_ext.sysmail_mailitems(mailitem_id) ON DELETE CASCADE;


--
-- TOC entry 3650 (class 2606 OID 16999)
-- Name: sysjobschedules fk_sysjobschedules_job_id; Type: FK CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysjobschedules
    ADD CONSTRAINT fk_sysjobschedules_job_id FOREIGN KEY (job_id) REFERENCES aws_sqlserver_ext.sysjobs(job_id);


--
-- TOC entry 3651 (class 2606 OID 17004)
-- Name: sysjobschedules fk_sysjobschedules_schedule_id; Type: FK CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysjobschedules
    ADD CONSTRAINT fk_sysjobschedules_schedule_id FOREIGN KEY (schedule_id) REFERENCES aws_sqlserver_ext.sysschedules(schedule_id);


--
-- TOC entry 3652 (class 2606 OID 17009)
-- Name: sysmail_attachments fk_sysmail_mailitems_mailitem_id; Type: FK CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysmail_attachments
    ADD CONSTRAINT fk_sysmail_mailitems_mailitem_id FOREIGN KEY (mailitem_id) REFERENCES aws_sqlserver_ext.sysmail_mailitems(mailitem_id) ON DELETE CASCADE;


--
-- TOC entry 3654 (class 2606 OID 17014)
-- Name: sysmail_profileaccount fk_sysmail_profileaccount_account_id; Type: FK CONSTRAINT; Schema: aws_sqlserver_ext; Owner: postgres
--

ALTER TABLE ONLY aws_sqlserver_ext.sysmail_profileaccount
    ADD CONSTRAINT fk_sysmail_profileaccount_account_id FOREIGN KEY (account_id) REFERENCES aws_sqlserver_ext.sysmail_account(account_id) ON DELETE CASCADE;


-- Completed on 2022-09-14 21:57:06

--
-- PostgreSQL database dump complete
--



-- ------------ Write CREATE-DATABASE-stage scripts -----------

CREATE SCHEMA IF NOT EXISTS audit;

CREATE SCHEMA IF NOT EXISTS dbo;

CREATE SCHEMA IF NOT EXISTS meta;

CREATE SCHEMA IF NOT EXISTS staging;

CREATE SCHEMA IF NOT EXISTS upload;

CREATE SCHEMA IF NOT EXISTS uts;

DROP TRIGGER IF EXISTS tr_dimdate_biu
ON dbo.dimdate;

-- ------------ Write DROP-FUNCTION-stage scripts -----------

DROP ROUTINE IF EXISTS dbo.fn_tr_dimdate_biu();

DROP ROUTINE IF EXISTS meta.ufn_convertdectostr(IN NUMERIC);

DROP ROUTINE IF EXISTS meta.ufn_getconfigvalue(IN VARCHAR);

DROP ROUTINE IF EXISTS meta.ufn_getlastdate();

-- ------------ Write DROP-PROCEDURE-stage scripts -----------

DROP ROUTINE IF EXISTS audit.sp_auditerror(IN INTEGER, IN VARCHAR, IN NUMERIC);

DROP ROUTINE IF EXISTS audit.sp_auditfinish(IN INTEGER, IN INTEGER, IN TEXT, INOUT int);

DROP ROUTINE IF EXISTS audit.sp_auditstart(IN VARCHAR, IN TEXT, IN VARCHAR, INOUT INTEGER, INOUT int);

DROP ROUTINE IF EXISTS audit.sp_print(IN TEXT, IN NUMERIC, INOUT int);

DROP ROUTINE IF EXISTS dbo.sp_filldimdate(IN TIMESTAMP WITHOUT TIME ZONE, IN TIMESTAMP WITHOUT TIME ZONE, IN VARCHAR, IN VARCHAR, IN NUMERIC, INOUT refcursor, INOUT refcursor);

DROP ROUTINE IF EXISTS dbo.sp_fillfactincome(INOUT VARCHAR, INOUT int);

DROP ROUTINE IF EXISTS dbo.sp_runbatch(INOUT VARCHAR, INOUT int);

DROP ROUTINE IF EXISTS dbo.sp_runtransform(INOUT VARCHAR, INOUT int);

DROP ROUTINE IF EXISTS meta.sp_initdatabase(IN NUMERIC);

DROP ROUTINE IF EXISTS upload.upl_cbrusdrate(IN TIMESTAMP WITHOUT TIME ZONE, IN TIMESTAMP WITHOUT TIME ZONE, INOUT TEXT, INOUT int);

DROP ROUTINE IF EXISTS upload.upl_incomebook(IN VARCHAR, IN VARCHAR, INOUT VARCHAR, INOUT int);

DROP ROUTINE IF EXISTS upload.upl_loadxmlfromfile(IN VARCHAR, INOUT VARCHAR);

DROP ROUTINE IF EXISTS uts.usp_unittest(IN NUMERIC, IN INTEGER, IN VARCHAR, INOUT refcursor);


-- ------------ Write DROP-VIEW-stage scripts -----------

DROP VIEW IF EXISTS dbo.vw_quarterincome;

-- ------------ Write DROP-TABLE-stage scripts -----------

DROP TABLE IF EXISTS audit.logprocedures;

DROP TABLE IF EXISTS dbo.dimbatch;

DROP TABLE IF EXISTS dbo.dimdate;

DROP TABLE IF EXISTS dbo.dimexchrateusd;

DROP TABLE IF EXISTS dbo.factincome;

DROP TABLE IF EXISTS dbo.factincomehistory;

DROP TABLE IF EXISTS meta.configapp;

DROP TABLE IF EXISTS staging.dimincome;

DROP TABLE IF EXISTS staging.factincomehistory;

DROP TABLE IF EXISTS upload.cbrusdrate;

DROP TABLE IF EXISTS upload.currencyperiod;

DROP TABLE IF EXISTS upload.incomebook;

DROP TABLE IF EXISTS uts.resultunittest;

-- ------------ Write DROP-DATABASE-stage scripts -----------


-- ------------ Write CREATE-TABLE-stage scripts -----------
DROP TABLE IF EXISTS uts.resultunittest;

CREATE TABLE uts."GroupType" (
    "Code" character varying(20) NOT NULL,
    "Name" character varying(100) NOT NULL
);


CREATE TABLE audit.logprocedures(
    logid BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY,
    mainid BIGINT,
    parentid BIGINT,
    starttime TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT clock_timestamp(),
    endtime TIMESTAMP WITHOUT TIME ZONE,
    duration INTEGER,
    rowcount INTEGER,
    sys_user_name VARCHAR(256) NOT NULL,
    sys_host_name VARCHAR(100) NOT NULL,
    sys_app_name VARCHAR(128) NOT NULL,
    spid INTEGER NOT NULL,
    spname VARCHAR(512),
    spparams TEXT,
    spinfo TEXT,
    errormessage VARCHAR(2048),
    transactioncount INTEGER
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE dbo.dimbatch(
    batchid INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
    dateid INTEGER,
    createdate TIMESTAMP WITHOUT TIME ZONE
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE dbo.dimdate(
    dateid INTEGER NOT NULL,
    fulldatealternatekey DATE NOT NULL,
    daynumberofyear SMALLINT NOT NULL,
    daynumberofmonth SMALLINT NOT NULL,
    daynumberofquarter SMALLINT NOT NULL,
    monthnumberofyear SMALLINT NOT NULL,
    monthnumberofquarter SMALLINT NOT NULL,
    calendarquarter SMALLINT NOT NULL,
    calendaryear SMALLINT NOT NULL,
    dayname VARCHAR(14) NOT NULL,
    monthname VARCHAR(14) NOT NULL,
    lastofmonth DATE NOT NULL,
    firstofquarter DATE NOT NULL,
    lastofquarter DATE NOT NULL,
    englishdayname VARCHAR(30),
    englishmonthname VARCHAR(30),
    simplerussiandate VARCHAR(4000)
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE dbo.dimexchrateusd(
    dateid INTEGER NOT NULL,
    batchid INTEGER,
    exchangerates NUMERIC(19,4) NOT NULL,
    createdate TIMESTAMP WITHOUT TIME ZONE
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE dbo.factincome(
    id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
    dateid INTEGER,
    batchid INTEGER,
    incomevalue NUMERIC(19,4),
    createdate TIMESTAMP WITHOUT TIME ZONE
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE dbo.factincomehistory(
    id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
    dateid INTEGER,
    batchid INTEGER,
    incomeusd NUMERIC(19,4),
    naturalkey UUID,
    versionkey UUID,
    exchangedateid INTEGER,
    exchangevalue NUMERIC(19,4),
    exchangerate NUMERIC(19,4),
    endbatchid INTEGER,
    createdate TIMESTAMP WITHOUT TIME ZONE,
    changedate TIMESTAMP WITHOUT TIME ZONE
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE meta.configapp(
    parameter VARCHAR(128) NOT NULL,
    strvalue VARCHAR(256)
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE staging.dimincome(
    id INTEGER,
    dateid INTEGER,
    batchid INTEGER,
    incomeusd NUMERIC(19,4),
    naturalkey UUID,
    exchangedata INTEGER,
    exchangevalue NUMERIC(19,4),
    exchangerate NUMERIC(19,4),
    createdate TIMESTAMP WITHOUT TIME ZONE,
    changedate TIMESTAMP WITHOUT TIME ZONE
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE staging.factincomehistory(
    id INTEGER,
    dateid INTEGER,
    batchid INTEGER,
    incomeusd NUMERIC(19,4),
    naturalkey UUID,
    versionkey UUID,
    exchangedateid INTEGER,
    exchangevalue NUMERIC(19,4),
    exchangerate NUMERIC(19,4),
    endbatchid INTEGER
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE upload.cbrusdrate(
    id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
    date TIMESTAMP WITHOUT TIME ZONE,
    exchangerates NUMERIC(19,4)
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE upload.currencyperiod(
    id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
    batchid INTEGER NOT NULL,
    dateid_start INTEGER NOT NULL,
    dateid_end INTEGER NOT NULL,
    createdate TIMESTAMP WITHOUT TIME ZONE
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE upload.incomebook(
    id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
    date TIMESTAMP WITHOUT TIME ZONE,
    incomeusd NUMERIC(19,4),
    exchangedate TIMESTAMP WITHOUT TIME ZONE,
    exchangevalue NUMERIC(19,4),
    exchangerate NUMERIC(19,4)
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE uts.resultunittest(
    testname VARCHAR(200),
    stepid INTEGER,
    error TEXT,
    datestamp TIMESTAMP WITHOUT TIME ZONE DEFAULT clock_timestamp()
)
        WITH (
        OIDS=FALSE
        );

-- ------------ Write CREATE-VIEW-stage scripts -----------

CREATE OR REPLACE  VIEW dbo.vw_quarterincome (calendaryear, calendarquarter, incomevalue) AS
SELECT
    calendaryear, calendarquarter, SUM(incomevalue) AS incomevalue
    FROM dbo.factincome AS f
    INNER JOIN dbo.dimdate AS d
        ON f.dateid = d.dateid
    GROUP BY calendaryear, calendarquarter;

-- ------------ Write CREATE-CONSTRAINT-stage scripts -----------

ALTER TABLE audit.logprocedures
ADD CONSTRAINT pk_audit_logprocedures_677577452 PRIMARY KEY (logid);

ALTER TABLE dbo.dimbatch
ADD CONSTRAINT pk_dimbatch_789577851 PRIMARY KEY (batchid);

ALTER TABLE dbo.dimdate
ADD CONSTRAINT pk_dimdate_613577224 PRIMARY KEY (dateid);

ALTER TABLE dbo.dimexchrateusd
ADD CONSTRAINT pk_dimexchrateusd_821577965 PRIMARY KEY (dateid);

ALTER TABLE dbo.factincome
ADD CONSTRAINT pk_factincome_885578193 PRIMARY KEY (id);

ALTER TABLE dbo.factincomehistory
ADD CONSTRAINT pk_factincomehistory_853578079 PRIMARY KEY (id);

ALTER TABLE meta.configapp
ADD CONSTRAINT pk_audit_logprocedures_917578307 PRIMARY KEY (parameter);

ALTER TABLE upload.currencyperiod
ADD CONSTRAINT pk_currencyperiod_645577338 PRIMARY KEY (id);

-- ------------ Write CREATE-FUNCTION-stage scripts -----------

CREATE OR REPLACE FUNCTION dbo.fn_tr_dimdate_biu()
RETURNS trigger
AS
$BODY$
BEGIN
IF ((TG_OP = 'INSERT' AND NEW.englishdayname IS NOT NULL) OR (TG_OP = 'UPDATE' AND NEW.englishdayname <> OLD.englishdayname)) THEN
    RAISE EXCEPTION ' The column "englishdayname" cannot be modified because it is a computed column ';
END IF;
IF ((TG_OP = 'INSERT' AND NEW.englishmonthname IS NOT NULL) OR (TG_OP = 'UPDATE' AND NEW.englishmonthname <> OLD.englishmonthname)) THEN
    RAISE EXCEPTION ' The column "englishmonthname" cannot be modified because it is a computed column ';
END IF;
IF ((TG_OP = 'INSERT' AND NEW.simplerussiandate IS NOT NULL) OR (TG_OP = 'UPDATE' AND NEW.simplerussiandate <> OLD.simplerussiandate)) THEN
    RAISE EXCEPTION ' The column "simplerussiandate" cannot be modified because it is a computed column ';
END IF;

/*
[7811 - Severity CRITICAL - PostgreSQL doesn't support the FORMAT(VARCHAR,VARCHAR) function. Review the converted code to make sure that the user-defined function produces the same results as the source code.]
(format([FullDateAlternateKey],'d','ru-ru'))
*/
NEW.englishmonthname := (to_char(NEW.fulldatealternatekey::DATE, 'Month'));
NEW.englishdayname := (CAST (date_part('week', NEW.fulldatealternatekey::DATE) AS VARCHAR(2)));
RETURN NEW;
END;
$BODY$
LANGUAGE  plpgsql;

CREATE OR REPLACE FUNCTION meta.ufn_convertdectostr(IN par_val NUMERIC)
RETURNS VARCHAR
AS
$BODY$
/* SELECT meta.ufn_ConvertDecToStr(0.00000010000), '0.0000001' */
BEGIN
    RETURN
    CASE
        WHEN aws_sqlserver_ext.ROUND3(par_val, 0, 1) = par_val THEN LTRIM(to_char(par_val::DOUBLE PRECISION, '99999999999999999999'))
        ELSE LEFT(par_val, LENGTH(par_val) - aws_sqlserver_ext.patindex('%[^0]%', REVERSE(par_val)) + 1)
    END;
END;
$BODY$
LANGUAGE  plpgsql;

CREATE OR REPLACE FUNCTION meta.ufn_getconfigvalue(IN par_parameter VARCHAR)
RETURNS VARCHAR
AS
$BODY$
/*
SELECT * FROM sys.sql_modules WHERE object_id  in (
SELECT object_id  FROM sys.objects WHERE name= 'ufn_GetConfigValue'
)
*/
DECLARE
    var_Value VARCHAR(256);
BEGIN
    var_Value := (SELECT
        strvalue
        FROM meta.configapp
        WHERE LOWER(parameter) = LOWER(par_Parameter));
    RETURN var_Value;
END;
$BODY$
LANGUAGE  plpgsql;

CREATE OR REPLACE FUNCTION meta.ufn_getlastdate()
RETURNS TIMESTAMP WITHOUT TIME ZONE
AS
$BODY$
/* SELECT [meta].[ufn_GetLastDate]() */
BEGIN
    RETURN make_date(2100, 12, 31);
END;
$BODY$
LANGUAGE  plpgsql;

-- ------------ Write CREATE-PROCEDURE-stage scripts -----------
DROP ROUTINE IF EXISTS audit.sp_auditerror(IN INTEGER, IN VARCHAR, IN NUMERIC);

DROP ROUTINE IF EXISTS audit.sp_auditfinish(IN INTEGER, IN INTEGER, IN TEXT, INOUT int);

DROP ROUTINE IF EXISTS audit.sp_auditstart(IN VARCHAR, IN TEXT, IN VARCHAR, INOUT INTEGER, INOUT int);

DROP ROUTINE IF EXISTS audit.sp_print(IN TEXT, IN NUMERIC, INOUT int);

insert into meta.configapp(parameter,strvalue) VALUES('AuditPrintAll',1);

CREATE PROCEDURE audit.sp_auditerror(IN par_logid INTEGER DEFAULT NULL, IN par_errormessage VARCHAR DEFAULT NULL, IN par_isfinish NUMERIC DEFAULT 0)
AS 
$BODY$
DECLARE
    sp_auditfinish$ReturnCode INTEGER;
BEGIN
    UPDATE audit.logprocedures
    SET errormessage = LEFT(COALESCE(errormessage, '') || COALESCE(par_ErrorMessage, 'Error') || '; ', 2048)
        WHERE logid = par_LogID;

    IF par_isFinish = 1 THEN
        CALL audit.sp_auditfinish(par_LogID := par_LogID, return_code => sp_auditfinish$ReturnCode);
    END IF;
END;
$BODY$
LANGUAGE plpgsql;

CREATE PROCEDURE audit.sp_auditfinish(IN par_logid INTEGER DEFAULT NULL, IN par_recordcount INTEGER DEFAULT NULL, IN par_spinfo TEXT DEFAULT NULL, INOUT return_code int DEFAULT 0)
AS 
$BODY$
DECLARE
    var_AuditProcEnable VARCHAR(128);
    var_TranCount INTEGER;
BEGIN
    SELECT
        meta.ufn_getconfigvalue('AuditProcAll')
        INTO var_AuditProcEnable;

    IF var_AuditProcEnable IS NULL THEN
        return_code := 0;
        RETURN;
    END IF;

    IF NOT EXISTS (SELECT
        *
        FROM tempdb_dbo.sysobjects
        WHERE id = aws_sqlserver_ext.object_id('tempdb.dbo.#AuditProc')) THEN
        CREATE TEMPORARY TABLE t$auditproc
        (logid INTEGER PRIMARY KEY NOT NULL);
    END IF;
    /*
    [7811 - Severity CRITICAL - PostgreSQL doesn't support the @@TRANCOUNT function. Review the converted code to make sure that the user-defined function produces the same results as the source code.]
    SET @TranCount = @@TRANCOUNT
    */
    UPDATE audit.logprocedures
    SET endtime = clock_timestamp(), duration = aws_sqlserver_ext.datediff('millisecond', starttime::TIMESTAMP, clock_timestamp()::TIMESTAMP), rowcount = par_RecordCount, spinfo = COALESCE(spinfo, '') ||
    CASE
        WHEN transactioncount = var_TranCount THEN ''
        ELSE 'Tran count changed to ' || COALESCE(LTRIM(to_char(var_TranCount::DOUBLE PRECISION, '9999999999')), 'NULL') || ';'
    END ||
    CASE
        WHEN par_SPInfo IS NULL THEN ''
        ELSE 'Finish:' || aws_sqlserver_ext.conv_datetime_to_string('VARCHAR(19)', 'DATETIME', clock_timestamp(), 120) || ':' || par_SPInfo || ';'
    END
        WHERE logid = par_LogID;
    DELETE FROM t$auditproc
        WHERE logid >= par_LogID;
    /*
    
    DROP TABLE IF EXISTS t$auditproc;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
END;
$BODY$
LANGUAGE plpgsql;

CREATE PROCEDURE audit.sp_auditstart(IN par_spname VARCHAR DEFAULT NULL, IN par_spparams TEXT DEFAULT NULL, IN par_spsub VARCHAR DEFAULT NULL, INOUT par_logid INTEGER DEFAULT NULL, INOUT return_code int DEFAULT 0)
AS 
$BODY$
/*
DECLARE @ID int
EXEC audit.sp_AuditStart @ID = @ID output
SELECT @ID
SELECT [meta].[ufn_GetConfigValue]('AuditProcAll')
*/
DECLARE
    var_AuditProcEnable VARCHAR(128);
    var_ParentID INTEGER;
    var_MainID INTEGER;
    var_CountIds INTEGER;
    var_TranCount INTEGER;
    SCOPE_IDENTITY BIGINT;
BEGIN
    SELECT
        meta.ufn_getconfigvalue('AuditProcAll')
        INTO var_AuditProcEnable;

    IF var_AuditProcEnable IS NULL THEN
        return_code := 0;
        RETURN;
    END IF;

    IF NOT EXISTS (SELECT
        *
        FROM tempdb_dbo.sysobjects
        WHERE id = aws_sqlserver_ext.object_id('tempdb.dbo.#AuditProc')) THEN
        CREATE TEMPORARY TABLE t$auditproc
        (logid INTEGER PRIMARY KEY NOT NULL);
    END IF;
    /*
    [7811 - Severity CRITICAL - PostgreSQL doesn't support the @@TRANCOUNT function. Review the converted code to make sure that the user-defined function produces the same results as the source code.]
    SET @TranCount = @@TRANCOUNT
    */
    SELECT
        MIN(logid), MAX(logid), COUNT(logid)
        INTO var_MainID, var_ParentID, var_CountIds
        FROM t$auditproc;
    par_SPName := LEFT(REPEAT('    ',
    CASE
        WHEN var_CountIds < 0 THEN NULL::INT
        ELSE var_CountIds
    END) || LTRIM(RTRIM(par_SPName)), 512) || COALESCE(': ' || par_SPSub, '');
    INSERT INTO audit.logprocedures (mainid, parentid, spname, spparams, transactioncount)
    VALUES (var_MainID, var_ParentID, par_SPName, par_SPParams, var_TranCount);
    par_LogID := SCOPE_IDENTITY;

    IF var_MainID IS NULL THEN
        UPDATE audit.logprocedures
        SET mainid = par_LogID
            WHERE logid = par_LogID;
    END IF;

    IF var_ParentID IS NULL OR var_ParentID < par_LogID THEN
        INSERT INTO t$auditproc (logid)
        VALUES (par_LogID);
    END IF;
    /*
    
    DROP TABLE IF EXISTS t$auditproc;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
END;
$BODY$
LANGUAGE plpgsql;

CREATE PROCEDURE audit.sp_print(IN par_string TEXT, IN par_overrideconfig NUMERIC DEFAULT 0, INOUT return_code int DEFAULT 0)
AS 
$BODY$
/* [audit].[sp_Print] @string = ' SELECT * FROM Security ' */
DECLARE
    var_str VARCHAR(4000);
    var_part INTEGER;
    var_len INTEGER;
    var_AuditPrintEnable INTEGER;
BEGIN
    var_part := 4000;
    var_len := LENGTH(par_string);
    SELECT
        meta.ufn_getconfigvalue('AuditPrintAll')::INTEGER
        INTO var_AuditPrintEnable;

    IF COALESCE(var_AuditPrintEnable, 0) = 2 OR (par_OverrideConfig = 0 AND COALESCE(var_AuditPrintEnable, 0) = 0) THEN
        return_code := 0;
        RETURN;
    END IF;
 
    WHILE var_len > 0 LOOP
        IF var_len <= var_part THEN
            RAISE NOTICE '%', par_string;
            EXIT;
        END IF;
        var_str := LEFT(par_string, var_part);
        /* SET @str = LEFT(@str, LEN(@str ) - CHARINDEX(CHAR(13), REVERSE(@str)) + 1) */
        RAISE NOTICE '%', var_str;
        par_string := RIGHT(par_string, var_len - LENGTH(var_str));
        var_len := LENGTH(par_string);
    END LOOP;
END;
$BODY$
LANGUAGE plpgsql;
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
