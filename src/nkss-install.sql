------------------------------------------------------------------------------------------------------------------------
-- @nkss-install.sql: Install "NKSS: PL/SQL Simple Scheduler" in the schema running this script
------------------------------------------------------------------------------------------------------------------------
-- You can create an specific user/owner/schema with the script: nkss-schema.sql
------------------------------------------------------------------------------------------------------------------------
set echo off
spool nkss-install.log
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
prompt | SQL> @nkss-install.sql                                                  |
prompt +-------------------------------------------------------------------------+
whenever sqlerror continue
whenever oserror  continue
set define off
set feedback off
set heading off
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
set timing off
set trimspool off
set verify off
set wrap on

prompt +-------------------------------------------------------------------------+
prompt | NKSS: Start of script                                                   |
prompt +-------------------------------------------------------------------------+

alter session set plsql_warnings='enable:all,disable:05005,disable:06002,disable:06004,disable:06005,disable:06006,disable:06009,disable:06010,disable:07202,disable:07204,disable:07206';
alter session set plsql_optimize_level=3;
alter session set plsql_code_type=native;
alter session set plscope_settings='identifiers:none';

prompt +-------------------------------------------------------------------------+
prompt | NKSS: CREATE TABLES                                                     |
prompt +-------------------------------------------------------------------------+

prompt Creating table: NKSS_TASKSET ...
create table nkss_taskset (
  id                         number(16)           not null enable,
  created                    timestamp(6)         not null enable,
  label                      varchar2(150 byte)   not null enable,
  payload                    clob,
  errorstack                 varchar2(4000 byte))
  -- Usually this should be a small anonymous pl/sql block with calls to stored procedures.
  lob (payload) store as securefile nkss_taskset_payload(enable storage in row);

create unique index nkss_taskset_pk on nkss_taskset (id);
create index nkss_taskset_n1 on nkss_taskset (created);

alter table nkss_taskset add constraint nkss_taskset_pk  primary key (id) using index enable;

comment on table  nkss_taskset            is 'Define a set of tasks to run concurrently.';
comment on column nkss_taskset.id         is 'Primary key from sequence: nkss_taskset_s';
comment on column nkss_taskset.created    is 'systimestamp when the set was created.';
comment on column nkss_taskset.label      is 'Description of this Set';
comment on column nkss_taskset.payload    is 'Optional execute immediate statement. Run once in the start of each worker session. Use to initialize common session variables/contexts/etc. If any exception occurs the worker logs the exception and terminates.';
comment on column nkss_taskset.errorstack is 'Eventually holds the payload execution exception stack.';

prompt Creating table: NKSS_TASKLIST ...
create table nkss_tasklist (
  id                         number(16)           not null enable,
  pid                        number(16)           not null enable,
  status                     number(1)            not null enable,  -- -1=scheduled 0=success 1=failure
  payload                    clob                 not null enable,
  started                    timestamp(6),
  finished                   timestamp(6),
  cputime                    number(16),
  errorstack                 varchar2(4000 byte))
  -- Usually this should be a small anonymous pl/sql block with calls to stored procedures.
  lob (payload) store as securefile nkss_tasklist_payload(enable storage in row);

create unique index nkss_tasklist_pk on nkss_tasklist (id);
create index nkss_tasklist_fk1 on nkss_tasklist (pid);

alter table nkss_tasklist add constraint nkss_tasklist_pk primary key (id) using index enable;
alter table nkss_tasklist add constraint nkss_tasklist_fk1 foreign key (pid) references nkss_taskset (id) enable;
alter table nkss_tasklist add constraint nkss_tasklist_ck1 check (status in (-1, 0, 1));

comment on table  nkss_tasklist            is 'Each task for a defined set. The run will be scheduled by insertion order. Natural load balance, every concurrent worker only terminates when there is no more scheduled tasks.';
comment on column nkss_tasklist.id         is 'Primary key from sequence: nkss_tasklist_s';
comment on column nkss_tasklist.pid        is 'Foreign key from nkss_taskset.id';
comment on column nkss_tasklist.status     is '[ -1 = scheduled | 0 = success | 1 = failure ]';
comment on column nkss_tasklist.payload    is 'Execute immediate statement. Run once and exclusively by the worker awarded with this task. If any exception occurs the worker logs the exception and continues.';
comment on column nkss_tasklist.started    is 'systimestamp when the worker started executing this task.';
comment on column nkss_tasklist.finished   is 'systimestamp when the worker finished executing this task.';
comment on column nkss_tasklist.cputime    is 'dbms_utility.get_cpu_time execution from start to finish in 100th''s of a second.';
comment on column nkss_tasklist.errorstack is 'Eventually holds the payload execution exception stack.';

prompt +-------------------------------------------------------------------------+
prompt | NKSS: CREATE SEQUENCES                                                  |
prompt +-------------------------------------------------------------------------+

prompt Creating sequence: NKSS_TASKSET_S ...
create sequence nkss_taskset_s  start with 1 increment by 1 cache 20 nocycle order;

prompt Creating sequence: NKSS_TASKLIST_S ...
create sequence nkss_tasklist_s start with 1 increment by 1 cache 20 nocycle order;

prompt +-------------------------------------------------------------------------+
prompt | NKSS: Creating Package Specification                                    |
prompt +-------------------------------------------------------------------------+

prompt Creating Package: NKSS_MANAGER ...
@@nkss_manager.pks
/
show errors

prompt Creating Package: NKSS_TASKLIST_DML ...
@@nkss_tasklist_dml.pks
/
show errors

prompt Creating Package: NKSS_TASKSET_DML ...
@@nkss_taskset_dml.pks
/
show errors

prompt Creating Package: NKSS_WORKER ...
@@nkss_worker.pks
/
show errors

prompt +-------------------------------------------------------------------------+
prompt | NKSS: Creating Package Implementation                                   |
prompt +-------------------------------------------------------------------------+

prompt Creating Package Body: NKSS_MANAGER ...
@@nkss_manager.pkb
/
show errors

prompt Creating Package Body: NKSS_TASKLIST_DML ...
@@nkss_tasklist_dml.pkb
/
show errors

prompt Creating Package Body: NKSS_TASKSET_DML ...
@@nkss_taskset_dml.pkb
/
show errors

prompt Creating Package Body: NKSS_WORKER ...
@@nkss_worker.pkb
/
show errors

prompt +-------------------------------------------------------------------------+
prompt | NKSS: CREATE DBMS_SCHEDULER Program                                     |
prompt +-------------------------------------------------------------------------+
declare
  lc__         constant varchar2(100) := 'Anonymous PL/SQL Block:';
  lc_program   constant varchar2(30) := 'NKSS#WORKER';
  nl           constant varchar2(3) := '
';
  already_exists        exception;
  pragma exception_init(already_exists, -27477);    -- ORA-27477: "string.string" already exists
begin
  dbms_output.enable(buffer_size => 1e6);
  --------------------
  << create_program >>
  --------------------
  begin
    dbms_scheduler.create_program(program_name        => lc_program,
                                  program_type        => 'STORED_PROCEDURE',
                                  program_action      => 'nkss_worker.main',
                                  number_of_arguments => 1,
                                  enabled             => false,
                                  comments            => 'NKSS Worker');
  exception
    when already_exists then
      dbms_output.put_line('Program: ' || lc_program || ' already exists. Exiting now...');
      return;
    when others then
      raise_application_error(-20888, '<< create_program >>:' || $$plsql_line || nl || dbms_utility.format_error_stack);
  end create_program;
  -----------------------------
  << define_program_argument >>
  -----------------------------
  begin
    dbms_scheduler.define_program_argument(program_name      => lc_program,
                                           argument_position => 1,
                                           argument_name     => 'fv_setid',
                                           argument_type     => 'integer',
                                           out_argument      => false);
  exception when others then
    raise_application_error(-20888, '<< define_program_argument >>:' || $$plsql_line || nl || dbms_utility.format_error_stack);
  end define_program_argument;
  --------------------
  << enable_program >>
  --------------------
  begin
    dbms_scheduler.enable(name => lc_program);
  exception when others then
    raise_application_error(-20888, '<< enable_program >>:' || $$plsql_line || nl || dbms_utility.format_error_stack);
  end enable_program;
exception when others then
  raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
end main;
/

prompt +-------------------------------------------------------------------------+
prompt | NKSS: End of Script                                                     |
prompt +-------------------------------------------------------------------------+
spool off
set feedback on
set heading on
set echo off
