------------------------------------------------------------------------------------------------------------------------
-- @nkss-uninstall.sql: uninstall "NKSS: PL/SQL Simple Scheduler" in the schema running this script
------------------------------------------------------------------------------------------------------------------------
-- FYI: To prevent accidental running this script, comment out or remove the two lines below...
--prompt aborting nkss-uninstall.sql execution ...
--quit failure;
------------------------------------------------------------------------------------------------------------------------
set echo off
spool nkss-uninstall.log
prompt +-------------------------------------------------------------------------+
prompt | NKSS: PL/SQL Simple Scheduler                                           |
prompt +-------------------------------------------------------------------------+
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
prompt +-------------------------------------------------------------------------+
prompt | SQL> @nkss-uninstall.sql                                                |
prompt +-------------------------------------------------------------------------+
whenever sqlerror continue
whenever oserror  continue
set arraysize 200
set echo off
set define off
set feedback off
set heading off
set linesize 120
set loboffset 1
set long 16777216
set longchunksize 8192
set pagesize 50000
set pause off
set scan on
set serveroutput on size 1000000
set sqlblanklines on
set tab off
set termout on
set timing off
set trimspool off
set verify off
set wrap on

prompt +-------------------------------------------------------------------------+
prompt | NKSS: Start of script                                                   |
prompt +-------------------------------------------------------------------------+

prompt +-------------------------------------------------------------------------+
prompt | NKSS: DROP DBMS_SCHEDULER Program                                       |
prompt +-------------------------------------------------------------------------+
declare
  lc__         constant varchar2(100) := 'Anonymous PL/SQL Block:';
  lc_program   constant varchar2(30) := 'NKSS#WORKER';
  nl           constant varchar2(3) := '
';
  does_not_exists       exception;
  pragma exception_init(does_not_exists, -27476);    -- ORA-27477: "string.string" does not exists
begin
  dbms_output.enable(buffer_size => 1e6);
  ------------------
  << drop_program >>
  ------------------
  begin
    dbms_scheduler.drop_program(program_name => lc_program,
                                force        => true);
  exception
    when does_not_exists then
      dbms_output.put_line('Program: ' || lc_program || ' does not exists. Exiting now...');
      return;
    when others then
      raise_application_error(-20888, '<< drop_program >>:' || $$plsql_line || nl || dbms_utility.format_error_stack);
  end;
exception when others then
  raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
end main;
/

prompt +-------------------------------------------------------------------------+
prompt | NKSS: Dropping tables ...                                               |
prompt +-------------------------------------------------------------------------+

prompt Dropping table: NKSS_TASKLIST ...
drop table nkss_tasklist cascade constraints purge;

prompt Dropping table: NKSS_TASKSET ...
drop table nkss_taskset cascade constraints purge;

prompt +-------------------------------------------------------------------------+
prompt | NKSS: Dropping sequences ...                                            |
prompt +-------------------------------------------------------------------------+

prompt Dropping sequence: NKSS_TASKSET_S ...
drop sequence nkss_taskset_s;

prompt Dropping sequence: NKSS_TASKLIST_S ...
drop sequence nkss_tasklist_s;

prompt +-------------------------------------------------------------------------+
prompt | NKSS: Dropping packages ...                                             |
prompt +-------------------------------------------------------------------------+

prompt Dropping Package: NKSS_MANAGER ...
drop package nkss_manager;

prompt Dropping Package: NKSS_TASKLIST_DML ...
drop package nkss_tasklist_dml;

prompt Dropping Package: NKSS_TASKSET_DML ...
drop package nkss_taskset_dml;

prompt Dropping Package: NKSS_WORKER ...
drop package nkss_worker;

prompt +-------------------------------------------------------------------------+
prompt | NKSS: End of Script                                                     |
prompt +-------------------------------------------------------------------------+
spool off
set feedback on
set heading on
set echo off
