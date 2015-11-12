-- ----------------------------------------------------------------------------------------------
--	xplan_rac_all.sql
--
--		Display the execution plan (display option ADVANCED) for a specific cursor (sql_id and child number) or the last statement for this session from library cache
--		You dont have to explicitly log in to a specific instance (in a RAC), to find the execution plan in the library cache of a node. It uses 
--		gv$sql_plan_statistics_all as a plan_table input to DBMS_XPLAN.DISPLAY in order to get the execution plan in loaded in the library cache of any RAC instance.									
--		(format parameter: 'ADVANCED ALLSTATS LAST')
--
-- (C) 2015 Nikos Karagiannidis - http://oradwstories.blogspot.com    
-- ----------------------------------------------------------------------------------------------

set linesize 9999
set pagesize 999

WITH v AS (
SELECT /*+ MATERIALIZE */
       DISTINCT sql_id, inst_id, child_number
  FROM gv$sql
 WHERE sql_id = '&sql_id' and child_number = '&child_number'
   AND loaded_versions > 0
 ORDER BY 1, 2, 3 )
,u 
as ( 
SELECT /*+ ORDERED USE_NL(t) */
       rank() over(order by v.inst_id) rn, 
       RPAD('Inst: '||v.inst_id, 9)||' '||RPAD('Child: '||v.child_number, 11) inst_child, 
       t.plan_table_output
  FROM v, TABLE(DBMS_XPLAN.DISPLAY('gv$sql_plan_statistics_all', NULL, 'ADVANCED ALLSTATS LAST', 
       'inst_id = '||v.inst_id||' AND sql_id = '''||v.sql_id||''' AND child_number = '||v.child_number)) t
)
select u.plan_table_output
from u
where
    rn = 1  -- to avoid multiple occurences per instance	   
/
