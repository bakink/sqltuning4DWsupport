
-----------------------------------------------------------------------------------------------------------
--	rollback_t.sql
--
--	Estimate how much time is remaining for all sessions of a sql_id to rollback (You can use it for a specific session too)
--
--	Note:
--		By default the script sleepd for 60 secs in order to calculate the rate of UNDO blocks used decrease. This should be
--		sufficient for large rollbacks. This can change by setting the l_sleep_time_secs variable below.
--
--
--  author: (C) Nikos Karagiannidis - http://oradwstories.blogspot.com
-----------------------------------------------------------------------------------------------------------


--col used_undo_blks_now new_value undo_blks_now

SELECT username,
       sid,
       SERIAL#,
       a.inst_id,
       xid,
       START_TIME,
       START_SCN,
       NAME xname,
       b.STATUS xstatus,
       c.tablespace_name undotbspace,
       c.segment_id undo_sgid,
       c.segment_name undo_sgname,
       USED_UBLK used_undo_blks_now,
       LOG_IO,
       PHY_IO,
       CR_GET,
       CR_CHANGE
  FROM gv$session a
       JOIN
       gv$transaction b
          ON (    a.taddr = b.addr
              AND a.saddr = b.ses_addr
              AND a.inst_id = b.inst_id)
       JOIN DBA_ROLLBACK_SEGS c ON (b.xidusn = c.segment_id)
 WHERE     username = NVL (UPPER ('&&username'), username)
       AND a.sql_id = NVL ('&&sql_id', sql_id)
	   AND sid = NVL ('&&sid', sid);
/

prompt Please wait while rollback time is calculated ...

----------------------------------------------
-- main
----------------------------------------------
set serveroutput on
set verify off

declare
	l_undo_blks_now		number;
	l_undo_blks_later	number;
	l_sleep_time_secs	number	:=	60;
	l_est_time			number;
begin
	-- get undo blocks used now (do a sum in the case of a parallel DML)
	SELECT sum(USED_UBLK)  into  l_undo_blks_now
	FROM gv$session a
		   JOIN
		   gv$transaction b
			  ON (    a.taddr = b.addr
				  AND a.saddr = b.ses_addr
				  AND a.inst_id = b.inst_id)
		   JOIN DBA_ROLLBACK_SEGS c ON (b.xidusn = c.segment_id)
	 WHERE     username = NVL (UPPER ('&&username'), username)
		   AND a.sql_id = NVL ('&&sql_id', sql_id)
		   AND sid = NVL ('&&sid', sid);
		   
	if (l_undo_blks_now is null) then
		dbms_output.put_line(chr(10)||chr(10)||'Sorry, the corresponding transaction could not be found!');
		return;
	end if;
		
	-- sleep for some time
	dbms_lock.sleep(l_sleep_time_secs);	
	
	-- get undo blocks used, again ...
	SELECT sum(USED_UBLK)  into  l_undo_blks_later
	FROM gv$session a
		   JOIN
		   gv$transaction b
			  ON (    a.taddr = b.addr
				  AND a.saddr = b.ses_addr
				  AND a.inst_id = b.inst_id)
		   JOIN DBA_ROLLBACK_SEGS c ON (b.xidusn = c.segment_id)
	 WHERE     username = NVL (UPPER ('&&username'), username)
		   AND a.sql_id = NVL ('&&sql_id', sql_id)
		   AND sid = NVL ('&&sid', sid);

	if (l_undo_blks_later < l_undo_blks_now) then
		l_est_time :=	round(	(l_undo_blks_later * l_sleep_time_secs/60) / (l_undo_blks_now - l_undo_blks_later), 2); 
		dbms_output.put_line(chr(10)||chr(10)||chr(10)||'Estimated Minutes for Rollback is: '||l_est_time||' (mins)');
	else
		dbms_output.put_line(chr(10)||chr(10)||chr(10)||'No rollback takes place!');
	end if;
end;
/

undef username
undef sql_id
undef sid
--undef undo_blks_now

set serveroutput off
set verify on
