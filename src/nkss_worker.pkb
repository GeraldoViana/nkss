create or replace package body nkss_worker
is
  ------------------------------------------------------------------
  -- NKSS: PL/SQL Simple Scheduler
  ------------------------------------------------------------------
  --  (c) Copyright 2017 Geraldo Viana (r4vrya@gmail.com)
  --
  --  Licensed under the Apache License, Version 2.0 (the "License"):
  --  you may not use this file except in compliance with the License.
  --  You may obtain a copy of the License at
  --
  --      http://www.apache.org/licenses/LICENSE-2.0
  --
  --  Unless required by applicable law or agreed to in writing, software
  --  distributed under the License is distributed on an "AS IS" BASIS,
  --  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  --  See the License for the specific language governing permissions and
  --  limitations under the License.
  ------------------------------------------------------------------
  -- NKSS_WORKER: Scheduler job entry point
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  -- Collections, Records, Variables, Constants, Exceptions, Cursors
  ------------------------------------------------------------------
  nl   constant varchar2(3) := '
';

  -- Inherited types
  subtype RecSetData  is nkss_taskset_dml.RecData;
  subtype RecListData is nkss_tasklist_dml.RecData;
  subtype ArrString   is dbms_sql.varchar2a;

  -- Stateful scalars/containers
  gv_cputime    number default 0;  -- DBMS_UTILITY.GET_CPU_TIME slices

  ------------------------------------------------------------------
  ----------------------- Private Session --------------------------
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  -- DEQUEUE_TASK_PVT
  ------------------------------------------------------------------
  procedure dequeue_task_pvt(fr_task  in out nocopy RecListData)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.DEQUEUE_TASK_PVT:';
  begin
    nkss_tasklist_dml.update_row(fr_data => fr_task);
    commit;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end dequeue_task_pvt;

  ------------------------------------------------------------------
  -- STARTED_TASK_PVT
  ------------------------------------------------------------------
  procedure started_task_pvt(fr_task  in out nocopy RecListData)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.STARTED_TASK_PVT:';
  begin
    nkss_tasklist_dml.update_row(fr_data => fr_task);
    commit;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end started_task_pvt;

  ------------------------------------------------------------------
  -- STOP_CPUTIMER_PVT
  ------------------------------------------------------------------
  procedure stop_cputimer_pvt
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.STOP_CPUTIMER_PVT:';
  begin
    gv_cputime := dbms_utility.get_cpu_time - gv_cputime;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end stop_cputimer_pvt;

  ------------------------------------------------------------------
  -- START_CPUTIMER_PVT
  ------------------------------------------------------------------
  procedure start_cputimer_pvt
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.START_CPUTIMER_PVT:';
  begin
    gv_cputime := dbms_utility.get_cpu_time;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end start_cputimer_pvt;

  ------------------------------------------------------------------
  -- FAILED_TASK_PVT
  ------------------------------------------------------------------
  procedure failed_task_pvt(fr_task        in out nocopy RecListData,
                            fv_errorstack  in varchar2)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.FAILED_TASK_PVT:';
  begin
    stop_cputimer_pvt;
    fr_task.status := 1;
    fr_task.finished := systimestamp;
    fr_task.cputime := gv_cputime;
    fr_task.errorstack := substrb(fv_errorstack, 1, 4000);
    dequeue_task_pvt(fr_task => fr_task);
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end failed_task_pvt;

  ------------------------------------------------------------------
  -- SUCCEEDED_TASK_PVT
  ------------------------------------------------------------------
  procedure succeeded_task_pvt(fr_task  in out nocopy RecListData)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.SUCCEEDED_TASK_PVT:';
  begin
    stop_cputimer_pvt;
    fr_task.status := 0;
    fr_task.finished := systimestamp;
    fr_task.cputime := gv_cputime;
    dequeue_task_pvt(fr_task => fr_task);
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end succeeded_task_pvt;

  ------------------------------------------------------------------
  -- CAST_LOCATOR_PVT: Pre 11g
  ------------------------------------------------------------------
  procedure cast_locator_pvt(fv_locator  in  clob,
                             ft_string   out nocopy ArrString)
  is
    lc__       constant varchar2(100) := $$plsql_unit || '.CAST_LOCATOR_PVT:';
    lv_offset           integer := 1;
    lv_amount           integer := 32767;
  begin
    if (fv_locator is not null) then
      loop
        begin
          dbms_lob.read(lob_loc => fv_locator,
                        amount  => lv_amount,
                        offset  => lv_offset,
                        buffer  => ft_string(ft_string.count+1));
          lv_offset := nvl(lv_offset,0) + nvl(lv_amount,0);
        exception
          when no_data_found then
            exit;
          when others then
            raise;
        end;
      end loop;
    end if;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end cast_locator_pvt;

  ------------------------------------------------------------------
  -- EXECUTE_LATER_PVT: Pre 11g
  ------------------------------------------------------------------
  procedure execute_later_pvt(fv_locator  in clob)
  is
    lc__       constant varchar2(100) := $$plsql_unit || '.EXECUTE_LATER_PVT:';
    lv_cursor           integer := 1;
    lt_string           ArrString;
  begin
    if (fv_locator is not null) then
      cast_locator_pvt(fv_locator => fv_locator,
                       ft_string  => lt_string);
      if (lt_string.count > 0) then
        lv_cursor := dbms_sql.open_cursor;
        dbms_sql.parse(c             => lv_cursor,
                       statement     => lt_string,
                       lb            => lt_string.first,
                       ub            => lt_string.last,
                       lfflg         => false,
                       language_flag => dbms_sql.native);
        dbms_sql.close_cursor(lv_cursor);
      end if;
    end if;
  exception when others then
    if (dbms_sql.is_open(lv_cursor)) then
      dbms_sql.close_cursor(lv_cursor);
    end if;
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end execute_later_pvt;

  ------------------------------------------------------------------
  -- EXECUTE_PVT
  ------------------------------------------------------------------
  procedure execute_pvt(fv_payload  in clob)
  is
    lc__       constant varchar2(100) := $$plsql_unit || '.EXECUTE_PVT:';
    lv_offset           integer := 1;
    lv_amount           integer := 32767;
    lv_stmt             varchar2(32767);
  begin
    if (fv_payload is not null) then
      execute immediate fv_payload;
      --------------------------------------------------------------
      -- Pre 11g
      --------------------------------------------------------------
      -- if (dbms_lob.getlength(fv_payload) <= lv_amount) then
      --   dbms_lob.read(lob_loc => fv_payload,
      --                 amount  => lv_amount,
      --                 offset  => lv_offset,
      --                 buffer  => lv_stmt);
      --   execute immediate lv_stmt;
      -- else
      --   execute_later_pvt(fv_locator => fv_payload);
      -- end if;
      --------------------------------------------------------------
    end if;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end execute_pvt;

  ------------------------------------------------------------------
  -- TASKSET_PAYLOAD_PVT: Run Task set Payload once
  ------------------------------------------------------------------
  -- Used to optionally set session parameters/contexts
  ------------------------------------------------------------------
  procedure taskset_payload_pvt(fv_setid  in integer)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.TASKSET_PAYLOAD_PVT:';
    lr_setdata       RecSetData;
  begin
    if (fv_setid is not null) then
      lr_setdata.id := fv_setid;
      nkss_taskset_dml.select_row(fr_data => lr_setdata);
      begin
        execute_pvt(fv_payload => lr_setdata.payload);
      exception when others then
        lr_setdata.errorstack := dbms_utility.format_error_stack;
        nkss_taskset_dml.update_row(fr_data => lr_setdata);
        commit;
        raise;
      end;
    end if;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end taskset_payload_pvt;

  ------------------------------------------------------------------
  ------------------------ Public Session --------------------------
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  -- MAIN
  ------------------------------------------------------------------
  procedure main(fv_setid  in integer)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.MAIN:';
    lr_task          RecListData;
  begin
    if (fv_setid is not null) then
      taskset_payload_pvt(fv_setid => fv_setid);
      loop
        lr_task := null;
        nkss_tasklist_dml.take_queued_task(fv_setid => fv_setid,
                                           fr_data  => lr_task);
        exit when (lr_task.r#wid is null);
        begin
          lr_task.started := systimestamp;
          started_task_pvt(fr_task => lr_task);
          start_cputimer_pvt;
          execute_pvt(fv_payload => lr_task.payload);
          succeeded_task_pvt(fr_task => lr_task);
        exception when others then
          failed_task_pvt(fr_task       => lr_task,
                          fv_errorstack => dbms_utility.format_error_stack);
        end;
      end loop;
    end if;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end main;

  ------------------------------------------------------------------
  --------------------- Initialization Session ---------------------
  ------------------------------------------------------------------
begin
  $if $$plsql_optimize_level < 3 $then
    $error $$plsql_unit || ' must be compiled with PLSQL_OPTIMIZE_LEVEL=3' $end
  $end
  null;
exception when others then
  raise_application_error(-20904, $$plsql_unit || '<init>:' || $$plsql_line || nl || dbms_utility.format_error_stack);
end nkss_worker;
