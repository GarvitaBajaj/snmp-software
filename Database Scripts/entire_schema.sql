--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: all_attendance(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION all_attendance(character varying, character varying, character varying) RETURNS TABLE(emails character varying, dates date)
    LANGUAGE plpgsql
    AS $_$
  DECLARE
  from_time timestamp;
  to_time timestamp;

  BEGIN
  from_time := to_timestamp($1,$3);
  to_time := to_timestamp($2,$3);

  RETURN QUERY SELECT rollno,ts::date FROM logs JOIN uid on client_id = uid WHERE ts::date >= from_time::date AND ts::date <= to_time::date
  AND ( (batch != 'phd' AND ts::time >= time '08:00:00' AND ts::time <= time '17:00:00') OR (batch = 'phd' AND ts::time >= time '09:00:00' AND ts::time <= time '18:00:00'))
  AND device_id IN (SELECT uid FROM label WHERE building = 'Academic')
  AND client_id IN ( SELECT uid FROM uid WHERE ta = 1)
  GROUP BY rollno,ts::date ORDER BY ts::date;
  END
  $_$;


ALTER FUNCTION public.all_attendance(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: all_client_std(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION all_client_std(character varying, character varying, character varying) RETURNS TABLE(device_id integer, client_id integer, fro timestamp without time zone, tro timestamp without time zone)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  from_time timestamp;
  to_time timestamp;
  id logs.client_id%TYPE;
  access uid.access%TYPE;
BEGIN
  from_time := to_timestamp($1,$3);
  to_time := to_timestamp($2,$3);
  CREATE TEMP TABLE tmptable (device_id int, client_id int, fro timestamp, tro timestamp) ON COMMIT DROP;
  
  FOR id IN SELECT DISTINCT l.client_id from logs l
  WHERE l.ts >= from_time and l.ts <= to_time
  ORDER BY l.client_id
  LOOP
    -- Check if access greater than 0
    SELECT u.access into access from uid u where u.uid = id;
    IF access IS NOT NULL and access >= 1 THEN
      PERFORM  * FROM client_std($1,$2,$3,id);
    END IF;
  END LOOP;
  RETURN QUERY SELECT t.device_id as device_id,t.client_id as client_id, t.fro as from, t.tro as to FROM tmptable t;
END
$_$;


ALTER FUNCTION public.all_client_std(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: all_count(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION all_count(in_from character varying, in_to character varying, in_format character varying) RETURNS TABLE(device_id integer, batch character varying, count integer)
    LANGUAGE plpgsql
    AS $_$
DECLARE
from_time timestamp;
to_time timestamp;
d_id logs.device_id%TYPE;
BEGIN
from_time := to_timestamp($1,$3);
to_time := to_timestamp($2,$3);

IF (EXTRACT( EPOCH FROM to_time - from_time)/60) > 30  THEN
to_time := from_time + interval '30 minutes';
in_to := to_char(to_time,in_format);
END IF;
RETURN QUERY SELECT A.device_id,B.batch,CAST (count(distinct A.client_id) as INT) FROM logs A inner join uid B on A.client_id = B.uid and A.ts>= from_time and ts< to_time and A.type = 1 GROUP BY A.device_id,B.Batch;
END
$_$;


ALTER FUNCTION public.all_count(in_from character varying, in_to character varying, in_format character varying) OWNER TO postgres;

--
-- Name: at_all_count(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION at_all_count(in_from character varying, in_format character varying) RETURNS TABLE(device_id integer, batch character varying, count integer)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  from_time timestamp;
  to_time timestamp;
  d_id logs.device_id%TYPE;
BEGIN
  from_time := to_timestamp($1,$2) - interval '2 hours';
  to_time := to_timestamp($1,$2);
  RETURN QUERY SELECT L.device_id,U.batch,CAST(count(*) AS INT) from logs L join uid U on L.client_id = U.uid where (client_id,ts) in (select client_id,max(ts) from logs where ts >= from_time AND ts <= to_time group by client_id) and L.type = 1 group by L.device_id,U.batch;
END
$_$;


ALTER FUNCTION public.at_all_count(in_from character varying, in_format character varying) OWNER TO postgres;

--
-- Name: at_all_uids(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION at_all_uids(in_from character varying, in_format character varying) RETURNS TABLE(device_id integer, client_id integer)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  from_time timestamp;
  to_time timestamp;
  d_id logs.device_id%TYPE;
BEGIN
  from_time := to_timestamp($1,$2) - interval '2 hours';
  to_time := to_timestamp($1,$2);
  RETURN QUERY SELECT L.device_id,L.client_id from logs L where (L.client_id,L.ts) in (select U.client_id,max(ts) from logs U where ts >= from_time AND ts <= to_time group by U.client_id) and L.type = 1 order by L.device_id,L.client_id;
END
$_$;


ALTER FUNCTION public.at_all_uids(in_from character varying, in_format character varying) OWNER TO postgres;

--
-- Name: attendance(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION attendance(character varying, character varying, character varying, character varying) RETURNS TABLE(dates date)
    LANGUAGE plpgsql
    AS $_$
  DECLARE
  from_time timestamp;
  to_time timestamp;

  BEGIN
  from_time := to_timestamp($2,$4);
  to_time := to_timestamp($3,$4);

  RETURN QUERY SELECT ts::date FROM logs JOIN uid ON uid = client_id 
  WHERE ts>= from_time AND ts <= to_time
  AND ( (batch != 'phd' AND ts::time >= time '08:00:00' AND ts::time <= time '17:00:00') OR (batch = 'phd' AND ts::time >= time '07:00:00' AND ts::time <= time '21:00:00'))
  AND device_id IN (SELECT uid FROM label WHERE building = 'Academic')
  AND client_id IN ( SELECT uid FROM uid WHERE lower(email) = lower($1) AND ta = 1)
  GROUP BY ts::date ORDER BY ts::date;
  END
  $_$;


ALTER FUNCTION public.attendance(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: attendance_at(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION attendance_at(in_from character varying, in_format character varying, in_batch character varying, in_room character varying) RETURNS TABLE(rollno character varying)
    LANGUAGE plpgsql
    AS $_$
DECLARE
from_time timestamp;
to_time timestamp;

BEGIN
from_time := to_timestamp($1,$2) - interval '2 hours';
to_time := to_timestamp($1,$2);
RETURN QUERY SELECT U.rollno from uid U join logs L on U.uid = L.client_id JOIN label R on L.device_id = R.uid WHERE (L.client_id,L.ts) in (SELECT client_id,max(ts) from logs where ts >= from_time and ts <= to_time GROUP BY client_id) and L.type = 1 and R.room = in_room and U.rollno IS NOT NULL ORDER BY U.rollno;
END
$_$;


ALTER FUNCTION public.attendance_at(in_from character varying, in_format character varying, in_batch character varying, in_room character varying) OWNER TO postgres;

--
-- Name: client_last(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION client_last(c_id integer) RETURNS TABLE(device_id integer, client_id integer, fro timestamp without time zone, tro timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
DECLARE
  from_time varchar;
  to_time varchar;
  format varchar;
  access int;
BEGIN
  format := 'YYYY-MM-DD HH24:MI:SS';
  from_time := to_char(now() - interval '1 month',format);
  to_time := to_char(now(),format);
  SELECT u.access INTO access FROM uid u
  WHERE u.uid = c_id;
  IF access >= 1 THEN
    RETURN QUERY SELECT * from client_std(from_time,to_time,format,c_id) ORDER BY tro DESC;
  END IF;
END
$$;


ALTER FUNCTION public.client_last(c_id integer) OWNER TO postgres;

--
-- Name: client_last_building(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION client_last_building(c_id integer) RETURNS TABLE(device_id integer, client_id integer, fro timestamp without time zone, tro timestamp without time zone, building text, floor text, wing text, room text)
    LANGUAGE plpgsql
    AS $$
DECLARE
  from_time varchar;
  to_time varchar;
  format varchar;
  access int;
BEGIN
  format := 'YYYY-MM-DD HH24:MI:SS';
  from_time := to_char(now() - interval '2 hour',format);
  to_time := to_char(now(),format);
  SELECT u.access INTO access FROM uid u
  WHERE u.uid = c_id;
  IF access = 1 THEN
    RETURN QUERY WITH s(s) AS(
      values ('')
    )
    SELECT cstd.device_id,cstd.client_id,cstd.fro,cstd.tro,s,s,s,s from client_std(from_time,to_time,format,c_id) cstd join label l on (cstd.device_id = l.uid) join s on (1=1);
  ELSIF access = 2 THEN
    RETURN QUERY WITH s(s) AS(
      values ('')
    )
    SELECT cstd.device_id,cstd.client_id,cstd.fro,cstd.tro,cast(l.building as text),s,s,s from client_std(from_time,to_time,format,c_id) cstd join label l on (cstd.device_id = l.uid) join s on (1=1);
  ELSIF access = 3 THEN
    RETURN QUERY WITH s(s) AS(
      values ('')
    )
    SELECT cstd.device_id,cstd.client_id,cstd.fro,cstd.tro,cast(l.building as text),cast(l.floor as text),s,s from client_std(from_time,to_time,format,c_id) cstd join label l on (cstd.device_id = l.uid) join s on (1=1);
  ELSIF access = 4 THEN
    RETURN QUERY WITH s(s) AS(
      values ('')
    )
    SELECT cstd.device_id,cstd.client_id,cstd.fro,cstd.tro,cast(l.building as text),cast(l.floor as text),cast(l.wing as text),s from client_std(from_time,to_time,format,c_id) cstd join label l on (cstd.device_id = l.uid) join s on (1=1);
  ELSIF access = 5 THEN
    RETURN QUERY SELECT cstd.device_id,cstd.client_id,cstd.fro,cstd.tro,cast(l.building as text),cast(l.floor as text),cast(l.wing as text),cast(l.room as text) from client_std(from_time,to_time,format,c_id) cstd join label l on (cstd.device_id = l.uid);
  END IF;
END
$$;


ALTER FUNCTION public.client_last_building(c_id integer) OWNER TO postgres;

--
-- Name: client_std(character varying, character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION client_std(character varying, character varying, character varying, integer) RETURNS TABLE(device_id integer, client_id integer, fro timestamp without time zone, tro timestamp without time zone)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  from_time timestamp;
  to_time timestamp;
  row2 logs%rowtype;
  prev_row logs%rowtype;
  id logs.client_id%TYPE;
  flag int;
  access uid.access%TYPE;
BEGIN
  from_time := to_timestamp($1,$3);
  to_time := to_timestamp($2,$3);
  id := $4;
  flag := 0;
  
  SELECT u.access INTO access FROM uid u
  WHERE u.uid = id;

  IF access = 0 THEN
    RETURN;
  END IF;

  CREATE TEMP TABLE IF NOT EXISTS tmptable ( device_id int, client_id int, fro timestamp, tro timestamp ) ON COMMIT DROP;
  
  FOR row2.device_id,row2.client_id,row2.ts,row2.label,row2.type IN SELECT l.device_id,l.client_id,l.ts,l.label,l.type from logs l
  WHERE id = l.client_id and l.ts >= from_time and l.ts <= to_time
  ORDER BY l.ts 
  LOOP
    IF flag = 0 THEN
      flag := 1;
      prev_row := row2;
    END IF;
    
    IF row2.type = 1 THEN
      IF row2.device_id = prev_row.device_id THEN
        NULL;
      ELSE
        INSERT INTO tmptable(device_id,client_id,fro,tro) VALUES
        (prev_row.device_id,id,prev_row.ts,row2.ts);
        prev_row := row2;
      END IF;
    ELSIF row2.type % 2= 0 THEN
      IF (row2.device_id = prev_row.device_id and prev_row.type = 1 )THEN
        INSERT INTO tmptable(device_id,client_id,fro,tro) VALUES
        (prev_row.device_id,id,prev_row.ts,row2.ts);
        flag := 0;
      END IF;
    END IF;
  END LOOP;
  IF prev_row.type = 1 AND flag = 1 THEN
    INSERT INTO tmptable(device_id,client_id,fro) VALUES
    (prev_row.device_id,id,prev_row.ts);
  END IF;
  RETURN QUERY SELECT t.device_id,t.client_id,t.fro,t.tro from tmptable t;
END
$_$;


ALTER FUNCTION public.client_std(character varying, character varying, character varying, integer) OWNER TO postgres;

--
-- Name: del_dead_conn(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION del_dead_conn() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
IF (NEW.type =4) THEN
DELETE FROM live_table WHERE client_id = 1;
END IF;
RETURN NULL;
END;
$$;


ALTER FUNCTION public.del_dead_conn() OWNER TO postgres;

--
-- Name: device_last(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION device_last(d_id integer) RETURNS TABLE(device_id integer, client_id integer, fro timestamp without time zone, tro timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
DECLARE
  from_time varchar;
  to_time varchar;
  format varchar;
BEGIN
  format := 'YYYY-MM-DD HH24:MI:SS';
  from_time := to_char(now() - interval '1 hour',format);
  to_time := to_char(now(),format);
  RETURN QUERY SELECT * from device_std(from_time,to_time,format,d_id);
END
$$;


ALTER FUNCTION public.device_last(d_id integer) OWNER TO postgres;

--
-- Name: device_std(character varying, character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION device_std(character varying, character varying, character varying, integer) RETURNS TABLE(device_id integer, client_id integer, fro timestamp without time zone, tro timestamp without time zone)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  row1 logs.client_id%TYPE;
  from_time timestamp;
  to_time timestamp;
  row2 logs%rowtype;
  prev_row logs%rowtype;
  id logs.device_id%TYPE;
  flag int;
BEGIN
  from_time := to_timestamp($1,$3);
  to_time := to_timestamp($2,$3);
  id := $4;
  flag := 0;

  CREATE TEMP TABLE IF NOT EXISTS tmptable ( device_id int, client_id int, fro timestamp, tro timestamp ) ON COMMIT DROP;

  FOR row2.device_id,row2.client_id,row2.ts,row2.label,row2.type IN SELECT l.device_id,l.client_id,l.ts,l.label,l.type
  FROM logs l LEFT JOIN uid u ON (l.client_id = u.uid)
  WHERE id = l.device_id and l.ts >= from_time and l.ts <= to_time and u.access >= 0
  ORDER BY l.client_id,l.ts 
  LOOP
    IF flag = 0 THEN
      flag := 1;
      prev_row := row2;
    END IF;
    IF prev_row.client_id != row2.client_id THEN
      INSERT INTO tmptable(device_id,client_id,fro) VALUES
      (id,prev_row.client_id,prev_row.ts);
      prev_row := row2;
    END IF;

    IF row2.type = 1 and prev_row.type %2 = 0 THEN
      prev_row := row2;
    ELSIF row2.type % 2 = 0 and prev_row.type = 1 THEN
      INSERT INTO tmptable(device_id,client_id,fro,tro)
      VALUES (id,prev_row.client_id,prev_row.ts,row2.ts);
      flag := 0;
    ELSE
      -- Do nothing
      NULL;
    END IF;
  END LOOP;
  IF prev_row.type = 1 and flag = 1 THEN
    INSERT INTO tmptable(device_id,client_id,fro) VALUES
    (id,prev_row.client_id,prev_row.ts);
  END IF;
  RETURN QUERY SELECT t.device_id,t.client_id,t.fro,t.tro from tmptable t;
END
$_$;


ALTER FUNCTION public.device_std(character varying, character varying, character varying, integer) OWNER TO postgres;

--
-- Name: function_live_logs(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION function_live_logs() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  res RECORD;
  foundFlag INTEGER :=0;
BEGIN
  IF (NEW.type =1) THEN
    FOR res IN SELECT * FROM live_table where live_table.client_id = NEW.client_id LOOP
    foundFlag :=1;
      IF (NEW.device_id != res.device_id and NEW.ts >= res.ts) THEN
        UPDATE live_table SET device_id = NEW.device_id,ts = NEW.ts where client_id = NEW.client_id;
      END IF;
    END LOOP;
    IF (foundFlag =0) THEN
      INSERT INTO live_table VALUES(NEW.client_id, NEW.device_id, NEW.ts);
    END IF;
  END IF;
  IF (NEW.type %2 = 0) THEN
    FOR res IN SELECT * FROM live_table where live_table.client_id = NEW.client_id LOOP
      IF(NEW.device_id = res.device_id and NEW.ts >= res.ts) THEN
        DELETE FROM live_table where client_id = NEW.client_id;
      END IF;
    END LOOP;
  END IF;
  RETURN NULL;
END;
$$;


ALTER FUNCTION public.function_live_logs() OWNER TO postgres;

--
-- Name: get_entries(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_entries(character varying, character varying, character varying) RETURNS TABLE(device_id integer, client_id integer, ts timestamp without time zone, label character varying, type integer)
    LANGUAGE plpgsql
    AS $_$
begin
create temp table if not exists real_from (id int, ts timestamp);
delete from real_from;
insert into real_from (select logs.client_id,max(logs.ts) from logs where logs.ts < to_timestamp($1,$3) and logs.type = 1 group by logs.client_id);
return query select logs.device_id,logs.client_id,logs.ts,logs.label,logs.type from logs left join real_from on logs.client_id = real_from.id and logs.ts >= real_from.ts and logs.ts <= to_timestamp($2,$3);
end
$_$;


ALTER FUNCTION public.get_entries(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: get_live_ip(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_live_ip() RETURNS TABLE(c_id integer, d_id integer, tstamp timestamp without time zone, ip character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
RETURN QUERY SELECT client_id, device_id, ts, uid.ip
FROM live_table INNER JOIN uid 
ON (live_table.client_id=uid.uid)
where uid.ip IS NOT NULL;
END
$$;


ALTER FUNCTION public.get_live_ip() OWNER TO postgres;

--
-- Name: get_live_table(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_live_table() RETURNS TABLE(c_id integer, d_id integer, tstamp timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY SELECT client_id, device_id, ts
  FROM live_table LEFT OUTER JOIN uid
  ON (live_table.client_id=uid.uid)
  where uid.access >=1;
END
$$;


ALTER FUNCTION public.get_live_table() OWNER TO postgres;

--
-- Name: get_uid(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_uid(thash character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
res integer;
begin
select uid into res from uid where hash = decode(thash,'hex');
if not found then
select insert_uid(thash) into res;
end if;
return res;
end
;$$;


ALTER FUNCTION public.get_uid(thash character varying) OWNER TO postgres;

--
-- Name: FUNCTION get_uid(thash character varying); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION get_uid(thash character varying) IS 'Return uid for a given MAC address.
If MAC not present, then call insert_uid and return the uid assigned.';


--
-- Name: heavy(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION heavy() RETURNS TABLE(a integer, b integer, c timestamp without time zone, d timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
declare
v int;
begin
for v in select distinct uid from label limit 10 loop 
return query select * from no_access_device_std('2014-09-05 00:00:00','2014-09-06 00:00:00','yyyy-mm-dd hh24:mi:ss',v);
end loop;
end
$$;


ALTER FUNCTION public.heavy() OWNER TO postgres;

--
-- Name: insert_uid(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_uid(thash character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$declare
id integer;
begin
insert into uid(hash) values (decode(thash,'hex'));
select uid into id from uid where hash = decode(thash,'hex');
return id;
end;$$;


ALTER FUNCTION public.insert_uid(thash character varying) OWNER TO postgres;

--
-- Name: FUNCTION insert_uid(thash character varying); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION insert_uid(thash character varying) IS 'Insert a new record for a given mac hash.
Returns new uid.
To be called only when the hash is not already present.';


--
-- Name: log_insert(character varying, character varying, timestamp without time zone, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION log_insert(tdevice character varying, tclient character varying, tts timestamp without time zone, tlabel character varying, ttype integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
id1 integer;
id2 integer;
begin
select get_uid(tdevice) into id1;
select get_uid(tclient) into id2;
insert into logs(device_id,client_id,ts,label,type)
values (id1,id2,tts,tlabel,ttype);
return 1;
end
;
$$;


ALTER FUNCTION public.log_insert(tdevice character varying, tclient character varying, tts timestamp without time zone, tlabel character varying, ttype integer) OWNER TO postgres;

--
-- Name: logs_std(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION logs_std(character varying, character varying, character varying) RETURNS TABLE(device_id integer, client_id integer, ts timestamp without time zone, type integer)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  from_time timestamp;
  to_time timestamp;
BEGIN
  from_time := to_timestamp($1,$3);
  to_time := to_timestamp($2,$3);
  RETURN QUERY SELECT l.device_id,l.client_id,l.ts,l.type FROM logs l WHERE l.ts >= from_time and l.ts <= to_time ORDER BY l.ts,l.device_id,l.client_id;
END
$_$;


ALTER FUNCTION public.logs_std(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: no_access_device_std(character varying, character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION no_access_device_std(character varying, character varying, character varying, integer) RETURNS TABLE(device_id integer, client_id integer, fro timestamp without time zone, tro timestamp without time zone)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  from_time timestamp;
  to_time timestamp;
  row2 logs%rowtype;
  prev_row logs%rowtype;
  id logs.device_id%TYPE;
  flag int;
BEGIN
  from_time := to_timestamp($1,$3);
  to_time := to_timestamp($2,$3);
  id := $4;
  flag := 0;

  CREATE TEMP TABLE IF NOT EXISTS tmptable ( device_id int, client_id int, fro timestamp, tro timestamp ) ON COMMIT DROP;

  FOR row2.device_id,row2.client_id,row2.ts,row2.label,row2.type IN SELECT l.device_id,l.client_id,l.ts,l.label,l.type
  FROM logs l LEFT JOIN uid u ON (l.client_id = u.uid)
  WHERE id = l.device_id and l.ts >= from_time and l.ts <= to_time
  ORDER BY l.client_id,l.ts 
  LOOP
    IF flag = 0 THEN
      flag := 1;
      prev_row := row2;
    END IF;
    IF prev_row.client_id != row2.client_id THEN
      INSERT INTO tmptable(device_id,client_id,fro) VALUES
      (id,prev_row.client_id,prev_row.ts);
      prev_row := row2;
    END IF;

    IF row2.type = 1 and prev_row.type % 2 = 0 THEN
      prev_row := row2;
    ELSIF row2.type % 2 = 0 and prev_row.type = 1 THEN
      INSERT INTO tmptable(device_id,client_id,fro,tro)
      VALUES (id,prev_row.client_id,prev_row.ts,row2.ts);
      flag := 0;
    ELSE
      -- Do nothing
      NULL;
    END IF;
  END LOOP;
  IF prev_row.type = 1 and flag = 1 THEN
    INSERT INTO tmptable(device_id,client_id,fro) VALUES
    (id,prev_row.client_id,prev_row.ts);
  END IF;
  RETURN QUERY SELECT t.device_id,t.client_id,t.fro,t.tro from tmptable t;
END
$_$;


ALTER FUNCTION public.no_access_device_std(character varying, character varying, character varying, integer) OWNER TO postgres;

--
-- Name: presence(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION presence(character varying, character varying, character varying, character varying) RETURNS TABLE(dates date)
    LANGUAGE plpgsql
    AS $_$
  DECLARE
  from_date date;
  to_date date;
  from_time timestamp;
  to_time timestamp;
  id int;
  BEGIN
  from_time := to_timestamp($2,$4);
  to_time := to_timestamp($3,$4);
  from_date := from_time::date;
  to_date := to_time::date;
  SELECT uid INTO id FROM uid WHERE hash = decode($1,'hex');
  RETURN QUERY WITH academic_ids as(
  SELECT uid  from label where building ='Academic'
  )
  SELECT ts::date FROM logs JOIN uid ON uid = client_id
  WHERE ts::date >= from_date AND ts::date <= to_date
  AND client_id = id
  AND ts::time >= from_time::time  AND ts::time <= to_time::time
  AND device_id IN (select * from academic_ids)
  GROUP BY ts::date ORDER BY ts::date;
  END
  $_$;


ALTER FUNCTION public.presence(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: presence_location(character varying, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION presence_location(character varying, character varying, character varying, character varying, character varying, character varying) RETURNS TABLE(dates date)
    LANGUAGE plpgsql
    AS $_$
  DECLARE
  from_date date;
  to_date date;
  from_time timestamp;
  to_time timestamp;
  id int;
  BEGIN
  from_time := to_timestamp($2,$4);
  to_time := to_timestamp($3,$4);
  from_date := from_time::date;
  to_date := to_time::date;
  SELECT uid INTO id FROM uid WHERE hash = decode($1,'hex');
  IF lower($6) = 'any' THEN
    RETURN QUERY WITH academic_ids as(
    SELECT uid  from label where lower(building) =lower($5)
    )
    SELECT ts::date FROM logs JOIN uid ON uid = client_id
    WHERE ts::date >= from_date AND ts::date <= to_date
    AND client_id = id
    AND ts::time >= from_time::time  AND ts::time <= to_time::time
    AND device_id IN (select * from academic_ids)
    GROUP BY ts::date ORDER BY ts::date;
  ELSE
    RETURN QUERY WITH academic_ids as(
    SELECT uid  from label where lower(building) =lower($5) and lower(floor) = lower($6)
    )
    SELECT ts::date FROM logs JOIN uid ON uid = client_id
    WHERE ts::date >= from_date AND ts::date <= to_date
    AND client_id = id
    AND ts::time >= from_time::time  AND ts::time <= to_time::time
    AND device_id IN (select * from academic_ids)
    GROUP BY ts::date ORDER BY ts::date;
  END IF;
  END
  $_$;


ALTER FUNCTION public.presence_location(character varying, character varying, character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: service_insert(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION service_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  found_uid integer;
   label_row label%rowtype;
  _building varchar := '';
  _floor varchar := '';
  _room varchar := '';
  _wing varchar := '';
  _regId location_service%rowtype;
BEGIN
  SELECT count(*) INTO found_uid FROM location_service WHERE (NEW.client_id = location_service.uid) AND NEW.type=1;
  IF (found_uid = 1) THEN
  SELECT * INTO _regId FROM location_service WHERE NEW.client_id = location_service.uid;
  FOR label_row.building, label_row.floor, label_row.wing, label_row.room IN SELECT building, floor, wing, room FROM label where
  NEW.device_id = label.uid LOOP
    IF (label_row.building IS NOT NULL) THEN
      _building = label_row.building;
          END IF;
    IF (label_row.floor IS NOT NULL) THEN
      _floor = label_row.floor;
          END IF;
    IF (label_row.wing IS NOT NULL) THEN
      _wing = label_row.wing;
          END IF;
    IF (label_row.room IS NOT NULL) THEN
      _room = label_row.room;
          END IF;
  END LOOP;
  PERFORM pg_notify('channel_service_insert', '{"data":' || '{"uid":' || NEW.client_id || ',"time":"' || NEW.ts || '","ap_id":'|| NEW.device_id || ',"label":"'|| NEW.label || '","building":"'|| _building || '","floor":"' || _floor || '","wing":"' || _wing || '","room":"' || _room || '"},"registration_ids":["' || _regId.gcm_appid || '"]}');
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.service_insert() OWNER TO postgres;

--
-- Name: tmp_all_count(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION tmp_all_count(in_from character varying, in_to character varying, in_format character varying) RETURNS TABLE(device_id integer, batch character varying, count integer)
    LANGUAGE plpgsql
    AS $_$
DECLARE
from_time timestamp;
to_time timestamp;
d_id logs.device_id%TYPE;
BEGIN
from_time := to_timestamp($1,$3);
to_time := to_timestamp($2,$3);

IF (EXTRACT( EPOCH FROM to_time - from_time)/60) > 30  THEN
to_time := from_time + interval '30 minutes';
in_to := to_char(to_time,in_format);
END IF;
RETURN QUERY SELECT A.device_id,B.batch,CAST (count(distinct A.client_id) as INT) FROM logs A inner join uid B on A.client_id = B.uid and A.ts>= from_time and ts< to_time and A.type = 1 GROUP BY A.device_id,B.Batch;
END
$_$;


ALTER FUNCTION public.tmp_all_count(in_from character varying, in_to character varying, in_format character varying) OWNER TO postgres;

--
-- Name: try(character varying, character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION try(character varying, character varying, character varying, integer) RETURNS TABLE(device_id integer, client_id integer, fro timestamp without time zone, tro timestamp without time zone)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  from_time timestamp;
  to_time timestamp;
  row2 logs%rowtype;
  prev_row logs%rowtype;
  id logs.device_id%TYPE;
  flag int;
BEGIN
  from_time := to_timestamp($1,$3);
  to_time := to_timestamp($2,$3);
  id := $4;
  flag := 0;

  CREATE TEMP TABLE IF NOT EXISTS tmptable ( device_id int, client_id int, fro timestamp, tro timestamp ) ON COMMIT DROP;

  FOR row2.device_id,row2.client_id,row2.ts,row2.label,row2.type IN SELECT l.device_id,l.client_id,l.ts,l.label,l.type
  FROM logs l LEFT JOIN uid u ON (l.client_id = u.uid)
  WHERE id = l.device_id and l.ts >= from_time and l.ts <= to_time
  ORDER BY l.client_id,l.ts 
  LOOP
    IF flag = 0 THEN
      flag := 1;
      prev_row := row2;
    END IF;
    IF prev_row.client_id != row2.client_id THEN
      INSERT INTO tmptable(device_id,client_id,fro) VALUES
      (id,prev_row.client_id,prev_row.ts);
      prev_row := row2;
    END IF;

    IF row2.type = 1 and prev_row.type % 2 = 0 THEN
      prev_row := row2;
    ELSIF row2.type % 2 = 0 and prev_row.type = 1 THEN
      INSERT INTO tmptable(device_id,client_id,fro,tro)
      VALUES (id,prev_row.client_id,prev_row.ts,row2.ts);
      flag := 0;
    ELSE
      -- Do nothing
      NULL;
    END IF;
  END LOOP;
  IF prev_row.type = 1 and flag = 1 THEN
    INSERT INTO tmptable(device_id,client_id,fro) VALUES
    (id,prev_row.client_id,prev_row.ts);
  END IF;
  RETURN QUERY SELECT t.device_id,t.client_id,t.fro,t.tro from tmptable t;
END
$_$;


ALTER FUNCTION public.try(character varying, character varying, character varying, integer) OWNER TO postgres;

--
-- Name: update_access(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION update_access(integer, integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
rcount int;
BEGIN
IF $2 <= 5 and $2 >=0 THEN
UPDATE uid SET access = $2 where uid = $1;
END IF;
GET DIAGNOSTICS rcount := ROW_COUNT;
RETURN rcount;
END;
$_$;


ALTER FUNCTION public.update_access(integer, integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: label; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE label (
    uid integer NOT NULL,
    building character varying DEFAULT ''::character varying,
    floor character varying DEFAULT ''::character varying,
    wing character varying DEFAULT ''::character varying,
    room character varying DEFAULT ''::character varying
);


ALTER TABLE public.label OWNER TO postgres;

--
-- Name: live_table; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE live_table (
    client_id integer NOT NULL,
    device_id integer NOT NULL,
    ts timestamp without time zone NOT NULL
);


ALTER TABLE public.live_table OWNER TO postgres;

--
-- Name: location_service; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE location_service (
    uid integer NOT NULL,
    ts timestamp without time zone NOT NULL,
    gcm_appid text NOT NULL
);


ALTER TABLE public.location_service OWNER TO postgres;

--
-- Name: logs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE logs (
    device_id integer NOT NULL,
    client_id integer NOT NULL,
    ts timestamp without time zone NOT NULL,
    label character varying(30),
    type integer NOT NULL
);


ALTER TABLE public.logs OWNER TO postgres;

--
-- Name: tokentable; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tokentable (
    username text NOT NULL,
    expiration integer NOT NULL,
    token bytea NOT NULL
);


ALTER TABLE public.tokentable OWNER TO postgres;

--
-- Name: uid; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE uid (
    uid integer NOT NULL,
    mac character varying(17),
    hash bytea,
    batch character varying DEFAULT 'others'::character varying,
    access integer DEFAULT 0 NOT NULL,
    ip character varying(15),
    rollno character varying,
    email character varying,
    type character varying,
    ta integer DEFAULT 0
);


ALTER TABLE public.uid OWNER TO postgres;

--
-- Name: uid_uid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE uid_uid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.uid_uid_seq OWNER TO postgres;

--
-- Name: uid_uid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE uid_uid_seq OWNED BY uid.uid;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE users (
    username text NOT NULL,
    password bytea NOT NULL,
    su integer DEFAULT 0
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: uid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY uid ALTER COLUMN uid SET DEFAULT nextval('uid_uid_seq'::regclass);


--
-- Name: label_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY label
    ADD CONSTRAINT label_pkey PRIMARY KEY (uid);


--
-- Name: location_service_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY location_service
    ADD CONSTRAINT location_service_pkey PRIMARY KEY (uid);


--
-- Name: logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY logs
    ADD CONSTRAINT logs_pkey PRIMARY KEY (device_id, client_id, ts, type);


--
-- Name: tokentable_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tokentable
    ADD CONSTRAINT tokentable_pkey PRIMARY KEY (username);


--
-- Name: uid_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY uid
    ADD CONSTRAINT uid_pkey PRIMARY KEY (uid);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (username);


--
-- Name: logs_client_id_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX logs_client_id_idx ON logs USING btree (client_id);


--
-- Name: logs_device_id_client_id_ts_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX logs_device_id_client_id_ts_idx ON logs USING btree (device_id, client_id, ts);


--
-- Name: timestamp_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX timestamp_index ON logs USING btree (ts);


--
-- Name: notify_service_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER notify_service_insert AFTER INSERT ON logs FOR EACH ROW EXECUTE PROCEDURE service_insert();


--
-- Name: trigger_live_logs; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_live_logs AFTER INSERT ON logs FOR EACH ROW EXECUTE PROCEDURE function_live_logs();


--
-- Name: trigger_type_4; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_type_4 AFTER INSERT ON logs FOR EACH ROW EXECUTE PROCEDURE del_dead_conn();


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

