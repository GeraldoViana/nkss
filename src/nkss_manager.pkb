create or replace package body nkss_manager
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
  -- NKSS_TASKMANAGER: Overall Task Management
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  ------------------------ Declare Session -------------------------
  ------------------------------------------------------------------
  gc_program    constant varchar2(30) := 'NKSS#WORKER';
  nl            constant varchar2(3) := '
';
  -- DMLAPI Subtypes
  subtype RecSetID    is nkss_taskset_dml.RecID;
  subtype RecSetData  is nkss_taskset_dml.RecData;
  subtype RecListID   is nkss_tasklist_dml.RecID;
  subtype RecListData is nkss_tasklist_dml.RecData;
  subtype ArrSetID    is nkss_taskset_dml.ArrID;
  subtype ArrSetData  is nkss_taskset_dml.ArrData;
  subtype ArrListID   is nkss_tasklist_dml.ArrID;
  subtype ArrListData is nkss_tasklist_dml.ArrData;

  ------------------------------------------------------------------
  ------------------------ Private Session -------------------------
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  -- CREATE_JOB_PVT
  ------------------------------------------------------------------
  procedure create_job_pvt(fv_job    in varchar2,
                           fv_setid  in integer)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.CREATE_JOB_PVT:';
  begin
    dbms_scheduler.create_job(job_name        => fv_job,
                              program_name    => gc_program,
                              start_date      => systimestamp,
                              repeat_interval => null,
                              end_date        => null,
                              job_class       => 'DEFAULT_JOB_CLASS',
                              enabled         => false,
                              auto_drop       => true,
                              comments        => 'TaskSetID=' || to_char(fv_setid));
    dbms_scheduler.set_job_argument_value(job_name       => fv_job,
                                          argument_name  => 'fv_setid',
                                          argument_value => to_char(fv_setid));
    dbms_scheduler.enable(name => fv_job);
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end create_job_pvt;

  ------------------------------------------------------------------
  -- ADD_TASK_PVT
  ------------------------------------------------------------------
  procedure add_task_pvt(fv_setid    in integer,
                         ft_payload  in ArrPayload)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.ADD_TASK_PVT:';
    lr_setid         RecSetID;
    lr_list          RecListData;
    i                pls_integer := ft_payload.first;
  begin
    if (ft_payload.count > gc_limit) then
      raise_application_error(-20888, 'ft_payload.count() is limited to '
                                      || to_char(gc_limit) || ' elements:' || $$plsql_line);
    elsif (fv_setid is null) then
      raise_application_error(-20888, 'fv_setid argument cannot be null:' || $$plsql_line);
    else
      lr_setid.id := fv_setid;
      if (not nkss_taskset_dml.exists_row(fr_id  => lr_setid)) then
        raise_application_error(-20888, 'Task set [' || to_char(fv_setid) || '] does not exists:' || $$plsql_line);
      end if;
    end if;
    if (i is null) then
      raise_application_error(-20888, 'ft_payload array has no elements:' || $$plsql_line);
    else
      while (i is not null) loop
        if (ft_payload(i) is null or dbms_lob.getlength(ft_payload(i)) = 0) then
          raise_application_error(-20888, 'ft_payload(i) argument cannot be null:' || $$plsql_line);
        end if;
        lr_list := null;
        lr_list.pid := fv_setid;
        lr_list.status := -1;
        lr_list.payload := ft_payload(i);
        nkss_tasklist_dml.insert_row(fr_data => lr_list);
        i := ft_payload.next(i);
      end loop;
    end if;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end add_task_pvt;

  ------------------------------------------------------------------
  ------------------------ Public Session --------------------------
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  -- NEW_TASKSET
  ------------------------------------------------------------------
  function new_taskset(fv_label    in varchar2,
                       fv_payload  in clob default null)
    return integer
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.NEW_TASKSET:';
    lr_setdata       RecSetData;
  begin
    if (trim(fv_label) is null) then
      raise_application_error(-20888, 'fv_label argument cannot be null:' || $$plsql_line);
    elsif (lengthb(fv_label) > 150) then
      raise_application_error(-20888, 'fv_label length is restricted to 150 bytes:' || $$plsql_line);
    end if;
    lr_setdata.label := fv_label;
    lr_setdata.payload := fv_payload;
    nkss_taskset_dml.insert_row(fr_data => lr_setdata);
    return lr_setdata.id;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end new_taskset;

  ------------------------------------------------------------------
  -- ADD_TASK
  ------------------------------------------------------------------
  procedure add_task(fv_setid    in integer,
                     fv_payload  in varchar2)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.ADD_TASK:';
    lt_payload       ArrPayload;
  begin
    lt_payload(1) := fv_payload;
    add_task_pvt(fv_setid   => fv_setid,
                 ft_payload => lt_payload);
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end add_task;
  ------------------------------------------------------------------
  procedure add_task(fv_setid    in integer,
                     fv_payload  in clob)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.ADD_TASK:';
    lt_payload       ArrPayload;
  begin
    lt_payload(1) := fv_payload;
    add_task_pvt(fv_setid   => fv_setid,
                 ft_payload => lt_payload);
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end add_task;
  ------------------------------------------------------------------
  procedure add_task(fv_setid    in integer,
                     ft_payload  in ArrPayload)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.ADD_TASK:';
  begin
    add_task_pvt(fv_setid   => fv_setid,
                 ft_payload => ft_payload);
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end add_task;

  ------------------------------------------------------------------
  -- RESCHEDULE
  ------------------------------------------------------------------
  function reschedule(fv_setid    in integer,
                      fv_label    in varchar2 default null,
                      fv_payload  in clob     default null,
                      fv_status   in integer  default failed_tasks)
    return integer
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.RESCHEDULE:';
    lv_newsetid      integer;
    lv_rowcount      integer;
    lr_oldset        RecSetData;
    lr_newset        RecSetData;
  begin
    if (fv_setid is null) then
      raise_application_error(-20888, 'fv_setid argument cannot be null:' || $$plsql_line);
    end if;
    lr_oldset.id := fv_setid;
    nkss_taskset_dml.select_row(fr_data => lr_oldset,
                                fv_lock => true);
    if (lr_oldset.r#wid is null) then
      raise_application_error(-20888, 'Task set [' || to_char(fv_setid) || '] does not exists:' || $$plsql_line);
    elsif (fv_status not in (all_tasks, failed_tasks, succeeded_tasks)) then
      raise_application_error(-20888, 'fv_status argument is not valid:' || $$plsql_line);
    end if;
    lr_oldset.label := nvl(fv_label, lr_oldset.label);
    lr_oldset.payload := nvl(fv_label, lr_oldset.payload);
    lv_newsetid := new_taskset(fv_label   => lr_oldset.label,
                               fv_payload => lr_oldset.payload);
    nkss_tasklist_dml.reschedule(fv_oldsetid  => fv_setid,
                                 fv_newsetid  => lv_newsetid,
                                 fv_status    => fv_status,
                                 fv_rowcount  => lv_rowcount);
    if (nvl(lv_rowcount,0) = 0) then
      raise_application_error(-20888, 'Task set [' || to_char(fv_setid) || '] has no schedulable tasks:' || $$plsql_line);
    end if;
    return lv_newsetid;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end reschedule;

  ------------------------------------------------------------------
  -- DAEMONIZE
  ------------------------------------------------------------------
  procedure daemonize(fv_setid    in integer,
                      fv_workers  in integer)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.DAEMONIZE:';
    lv_job           varchar2(30);
    lv_tasks         integer := 0;
  begin
    if (fv_setid is null) then
      raise_application_error(-20888, 'fv_setid argument cannot be null:' || $$plsql_line);
    elsif (nvl(fv_workers,0) <= 0) then
      raise_application_error(-20888, 'fv_workers argument must be greater than 0:' || $$plsql_line);
    end if;
    lv_tasks := nkss_tasklist_dml.count_scheduled_tasks(fv_setid => fv_setid);
    if (nvl(lv_tasks,0) = 0) then
      raise_application_error(-20888, 'Task set [' || to_char(fv_setid) || '] has no schedulable tasks:' || $$plsql_line);
    end if;
    for i in 1 .. fv_workers loop
      lv_job := 'NKSS' || trim(to_char(fv_setid)) || dbms_scheduler.generate_job_name(prefix => 'J');
      pragma inline (create_job_pvt, 'YES');
      create_job_pvt(fv_job   => lv_job,
                     fv_setid => fv_setid);
    end loop;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end daemonize;

  ------------------------------------------------------------------
  -- PURGE_TASKSET
  ------------------------------------------------------------------
  procedure purge_taskset(fv_setid  in integer)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.PURGE_TASKSET:';
    lr_taskset       RecSetData;
  begin
    if (fv_setid is null) then
      raise_application_error(-20888, 'fv_setid argument cannot be null:' || $$plsql_line);
    else
      lr_taskset.id := fv_setid;
      if (not nkss_taskset_dml.exists_row(fr_data  => lr_taskset)) then
        raise_application_error(-20888, 'Task set [' || to_char(fv_setid) || '] does not exists:' || $$plsql_line);
      end if;
      nkss_taskset_dml.select_row(fr_data => lr_taskset,
                                  fv_lock => true);
      nkss_tasklist_dml.purge_tasklist(fv_setid => fv_setid);
      nkss_taskset_dml.delete_row(fr_data => lr_taskset);
    end if;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end purge_taskset;

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
end nkss_manager;
