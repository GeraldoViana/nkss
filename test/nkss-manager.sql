------------------------------------------------------------------------------------------------------------------------
-- NKSS: PL/SQL Simple Scheduler
------------------------------------------------------------------------------------------------------------------------
-- * This script tests NKSS_MANAGER which is the only API you need to use NKSS: PL/SQL Simple Scheduler
--   I did not enforced "ACCESSIBLE BY" 'cause it's only available from 12c onwards, but you should use
--   only NKSS_MANAGER.
------------------------------------------------------------------------------------------------------------------------
-- Check if you have at least 25 job queue processes, as DBA run:
--
-- SQL> alter system set job_queue_processes=25;
--
------------------------------------------------------------------------------------------------------------------------
-- @nkss-manager.sql
------------------------------------------------------------------------------------------------------------------------
set echo off
spool nkss-manager.log
prompt +-------------------------------------------------------------------------+
prompt | NKSS: PL/SQL Simple Scheduler                                           |
prompt |-------------------------------------------------------------------------|
prompt | (c) Copyright 2017 Geraldo Viana (r4vrya@gmail.com)                     |
prompt |                                                                         |
prompt | Licensed under the Apache License, Version 2.0 (the "License"):         |
prompt | you may not use this file except in compliance with the License.        |
prompt | You may obtain a copy of the License at                                 |
prompt |                                                                         |
prompt |     http://www.apache.org/licenses/LICENSE-2.0                          |
prompt |                                                                         |
prompt | Unless required by applicable law or agreed to in writing, software     |
prompt | distributed under the License is distributed on an "AS IS" BASIS,       |
prompt | WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.|
prompt | See the License for the specific language governing permissions and     |
prompt | limitations under the License.                                          |
prompt |-------------------------------------------------------------------------|
prompt | SQL> @nkss-manager.sql                                                  |
prompt +-------------------------------------------------------------------------+
whenever sqlerror continue
whenever oserror  continue
set define off
set feedback on
set heading on
set linesize 120
set loboffset 1
set long 16777216
set longchunksize 8192
set pause off
set scan on
set serveroutput on size 1000000
set sqlblanklines on
set tab off
set termout on
set timing on
set trimspool on
set verify off
set wrap on

prompt +--------------------------------------------------------------------------------------------------+
prompt | setting host variables to hold data between statements                                           |
prompt +--------------------------------------------------------------------------------------------------+
variable hv_setid number;

prompt +--------------------------------------------------------------------------------------------------+
prompt | Create new set of tasks and schedule them to run                                                 |
prompt +--------------------------------------------------------------------------------------------------+
declare
  lc__       constant varchar2(100) := 'Anonymous PL/SQL Block:';
  nl         constant varchar2(3) := '
';
  ---------------------------------------------------------------------------------------------------------
  -- Set payload(run once by each worker at the background session start)
  ---------------------------------------------------------------------------------------------------------
  lc_set_payload  constant clob :=
q'[-- NKSS: PL/SQL Simple Scheduler - Set payload
declare
  lc__   constant varchar2(100) := 'Task Set Anonymous PL/SQL Block:';
  nl     constant varchar2(3) := '
';
begin
  execute immediate q'{alter session set nls_date_format='yyyy-mm-dd hh24:mi:ss'}';
  execute immediate q'{alter session set nls_numeric_characters=',.'}';
exception when others then
  raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
end main;
]';
  ---------------------------------------------------------------------------------------------------------
  -- Task payload(run once and exclusivelly by worker awarded with this task after take_queued_task() call)
  ---------------------------------------------------------------------------------------------------------
  lc_task_payload constant clob :=
q'[-- NKSS: PL/SQL Simple Scheduler - Task payload
declare
  lc__     constant varchar2(100) := 'Task List Anonymous PL/SQL Block:';
  lv_max   constant pls_integer := 8;
  nl       constant varchar2(3) := '
';
  lv_count pls_integer := 1;
begin
  -- run about 8 seconds or hit by a random number multiple of 30
  loop
    if (mod(ceil(dbms_random.value(0, 100)), 30) = 0) then
      raise_application_error(-20888, 'aowh! I was hit:' || $$plsql_line);
    elsif (lv_count >= lv_max) then
      exit;
    else
      lv_count := lv_count + 1;
      dbms_lock.sleep(1);
    end if;
  end loop;
exception when others then
  raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
end main;
]';
  ---------------------------------------------------------------------------------------------------------
  lc_limit      constant integer := nkss_manager.gc_limit;
  lt_payload    nkss_manager.ArrPayload;
begin
  dbms_output.enable(buffer_size => 1e6);
  -- new set of tasks
  :hv_setid := nkss_manager.new_taskset(fv_label   => 'Randomize between 0 and 100 until hit a multiple of 30',
                                        fv_payload => lc_set_payload);
  -- bulk 2 chunks of payloads
  for x in 1 .. 2 loop
    lt_payload.delete;
    for y in 1 .. lc_limit loop
      lt_payload(y) := lc_task_payload;
    end loop;
    nkss_manager.add_task(fv_setid   => :hv_setid,
                          ft_payload => lt_payload);
  end loop;
  lt_payload.delete;
  -- register workers
  nkss_manager.daemonize(fv_setid   => :hv_setid,
                         fv_workers => 25);       -- alter system set job_queue_processes=25;
  -- start workers in background
  commit;
exception when others then
  raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
end main;
/

prompt +--------------------------------------------------------------------------------------------------+
prompt | Wait 8 seconds to start monitoring tasks                                                         |
prompt +--------------------------------------------------------------------------------------------------+
column status  format a10
column min_run format a26
column max_run format a26

begin dbms_lock.sleep(8); end main;
/
select --+ choose
       case a.status
         when -1 then 'scheduled'
         when  0 then 'success'
         when  1 then 'failure'
       end                            "STATUS",
       count(*)                       "COUNT(*)",
       min(finished - started)        "MIN_RUN",
       max(finished - started)        "MAX_RUN"
  from nkss_tasklist    a
 where 1e1 = 1e1
   and a.pid = :hv_setid
 group by a.status
 order by 2 desc
/

begin dbms_lock.sleep(8); end main;
/
select --+ choose
       case a.status
         when -1 then 'scheduled'
         when  0 then 'success'
         when  1 then 'failure'
       end                            "STATUS",
       count(*)                       "COUNT(*)",
       min(finished - started)        "MIN_RUN",
       max(finished - started)        "MAX_RUN"
  from nkss_tasklist    a
 where 1e1 = 1e1
   and a.pid = :hv_setid
 group by a.status
 order by 2 desc
/

begin dbms_lock.sleep(8); end main;
/
select --+ choose
       case a.status
         when -1 then 'scheduled'
         when  0 then 'success'
         when  1 then 'failure'
       end                            "STATUS",
       count(*)                       "COUNT(*)",
       min(finished - started)        "MIN_RUN",
       max(finished - started)        "MAX_RUN"
  from nkss_tasklist    a
 where 1e1 = 1e1
   and a.pid = :hv_setid
 group by a.status
 order by 2 desc
/

begin dbms_lock.sleep(8); end main;
/
select --+ choose
       case a.status
         when -1 then 'scheduled'
         when  0 then 'success'
         when  1 then 'failure'
       end                            "STATUS",
       count(*)                       "COUNT(*)",
       min(finished - started)        "MIN_RUN",
       max(finished - started)        "MAX_RUN"
  from nkss_tasklist    a
 where 1e1 = 1e1
   and a.pid = :hv_setid
 group by a.status
 order by 2 desc
/

begin dbms_lock.sleep(8); end main;
/
select --+ choose
       case a.status
         when -1 then 'scheduled'
         when  0 then 'success'
         when  1 then 'failure'
       end                            "STATUS",
       count(*)                       "COUNT(*)",
       min(finished - started)        "MIN_RUN",
       max(finished - started)        "MAX_RUN"
  from nkss_tasklist    a
 where 1e1 = 1e1
   and a.pid = :hv_setid
 group by a.status
 order by 2 desc
/

prompt +--------------------------------------------------------------------------------------------------+
prompt | EOS: End of script                                                                               |
prompt +--------------------------------------------------------------------------------------------------+
spool off
set feedback on
set heading on
set echo off
