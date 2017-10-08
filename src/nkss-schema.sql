------------------------------------------------------------------------------------------------------------------------
-- @nkss-schema.sql: Optional "NKSS: PL/SQL Simple Scheduler" user/owner/schema creation
------------------------------------------------------------------------------------------------------------------------
-- The roles required are: 'connect', 'resource';
-- The system privileges are: 'create job';
------------------------------------------------------------------------------------------------------------------------
-- Optionally grant execute on DBMS_LOCK to simulate delay in task execution as this test is mainly done in Oracle XE
-- (Express Edition) wich does not have java enabled: http://docs.oracle.com/cd/E17781_01/license.112/e18068/toc.htm#XELIC117
------------------------------------------------------------------------------------------------------------------------
-- create or replace procedure sleep (millisecs in number)
-- as language java name 'java.lang.Thread.sleep(long)';
------------------------------------------------------------------------------------------------------------------------
declare
  lv__          constant varchar2(100) := 'Anonymous PL/SQL Block';
  lv_username   constant varchar2(30)  := 'nkss';
  lv_password   constant varchar2(30)  := 'nkss';
  lv_tablespace constant varchar2(30)  := 'users';
  lv_temp       constant varchar2(30)  := 'temp';
  nl            constant varchar2(3)   := '
';
  lv_stmt       varchar2(2048);
begin
  dbms_output.enable(buffer_size => 1e6);
  -- create user
  lv_stmt := ' create user '          || lv_username
          || ' identified by '        || lv_password
          || ' default tablespace '   || lv_tablespace
          || ' temporary tablespace ' || lv_temp
          || ' account unlock';
  dbms_output.put_line(lv_stmt);
  execute immediate lv_stmt;
  -- tablespace quota
  lv_stmt := ' alter user '          || lv_username
          || ' quota unlimited on '  || lv_tablespace;
  dbms_output.put_line(lv_stmt);
  execute immediate lv_stmt;
  -- grants
  lv_stmt := 'grant connect to '    || lv_username;
  dbms_output.put_line(lv_stmt);
  execute immediate lv_stmt;
  lv_stmt := 'grant resource to '   || lv_username;
  dbms_output.put_line(lv_stmt);
  execute immediate lv_stmt;
  lv_stmt := 'grant create job to ' || lv_username;
  dbms_output.put_line(lv_stmt);
  execute immediate lv_stmt;
  lv_stmt := 'grant execute on dbms_lock to ' || lv_username;
  dbms_output.put_line(lv_stmt);
  execute immediate lv_stmt;
exception when others then
  raise_application_error(-20777, lv__ || $$plsql_line || nl || dbms_utility.format_error_stack);
end;
/
