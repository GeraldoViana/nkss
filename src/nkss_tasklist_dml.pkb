create or replace package body nkss_tasklist_dml
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
  -- NKSS_TASKLIST_DML: NKSS_TASKLIST Simple CRUD API
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  ------------------------ Declare Session -------------------------
  ------------------------------------------------------------------
  -- Local constants
  gc_all_status   constant pls_integer := nkss_manager.all_tasks;
  gc_failure      constant pls_integer := nkss_manager.failed_tasks;
  gc_success      constant pls_integer := nkss_manager.succeeded_tasks;
  gc_scheduled    constant pls_integer := -1;
  nl              constant varchar2(1) := '
';

  -- API implementation subtypes
  subtype plstring    is varchar2(32767);
  subtype plraw       is raw(32767);

  -- API implementation types
  type weak_refcursor is ref cursor;
  type plstring_list  is table of plstring index by pls_integer;
  type urowid_list    is table of urowid   index by pls_integer;

  -- Arrays used in FORALL returning statements
  type pk001_list is table of number(16)   index by pls_integer;  --001 id

  -- Exceptions
  lock_timeout     exception;
  pragma exception_init(lock_timeout, -30006);    -- ORA-30006: resource busy; acquire with WAIT timeout expired
  lock_nowait      exception;
  pragma exception_init(lock_nowait, -54);        -- ORA-00054: resource busy and acquire with NOWAIT specified
  dml_error        exception;
  pragma exception_init(dml_error, -24381);       -- ORA-24381: error(s) in array DML

  -- Stateful Scalars/Containers
  --gt_rowid    plstring_map;

  ------------------------------------------------------------------
  ------------------------ Private Session -------------------------
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  -- INSPECT_DATA_PVT
  ------------------------------------------------------------------
  procedure inspect_data_pvt(fr_data  in out nocopy RecData)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.INSPECT_DATA_PVT:';
  begin
    if (fr_data.pid is null) then
      raise_application_error(-20888, 'fr_data.pid argument cannot be null:' || $$plsql_line);
    elsif (fr_data.payload is null) then
      raise_application_error(-20888, 'fr_data.payload argument cannot be null:' || $$plsql_line);
    end if;
    -- include defaults and sanities below this line...
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end inspect_data_pvt;

  ------------------------------------------------------------------
  -- INSPECT_ID_PVT
  ------------------------------------------------------------------
  procedure inspect_id_pvt(fr_id  in RecID)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.INSPECT_ID_PVT:';
  begin
    if (fr_id.r#wid is null) then
      raise_application_error(-20888, 'fr_id.r#wid argument cannot be null:' || $$plsql_line);
    elsif (fr_id.id is null) then
      raise_application_error(-20888, 'fr_id.id argument cannot be null:' || $$plsql_line);
    end if;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end inspect_id_pvt;

  ------------------------------------------------------------------
  -- SELECT_ROW_PVT
  ------------------------------------------------------------------
  procedure select_row_pvt(fr_data  in out nocopy RecData)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.SELECT_INSTANCE_PVT:';
    lv_refcur        weak_refcursor;
  begin
    open lv_refcur for
    select --+ choose
           a.rowid,                                                                             --000 urowid
           a.id,                                                                                --001 number(16)
           a.pid,                                                                               --002 number(16)
           a.status,                                                                            --003 number(1)
           a.payload,                                                                           --004 clob
           a.started,                                                                           --005 timestamp
           a.finished,                                                                          --006 timestamp
           a.cputime,                                                                           --007 number(16)
           a.errorstack                                                                         --008 varchar2(4000 byte)
      from nkss_tasklist    a
     where 1e1 = 1e1
       and (fr_data.r#wid is null or a.rowid = fr_data.r#wid)                                   --000 urowid
       and a.id = fr_data.id;                                                                   --001 number(16)
    fetch lv_refcur into fr_data;
    close lv_refcur;
  exception when others then
    if (lv_refcur%isopen) then
      close lv_refcur;
    end if;
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end select_row_pvt;

  ------------------------------------------------------------------
  -- SELECT_LOCKING_PVT
  ------------------------------------------------------------------
  procedure select_locking_pvt(fr_data  in out nocopy RecData)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.SELECT_LOCKING_PVT:';
    lv_refcur        weak_refcursor;
  begin
    open lv_refcur for
    select --+ choose
           a.rowid,                                                                             --000 urowid
           a.id,                                                                                --001 number(16)
           a.pid,                                                                               --002 number(16)
           a.status,                                                                            --003 number(1)
           a.payload,                                                                           --004 clob
           a.started,                                                                           --005 timestamp
           a.finished,                                                                          --006 timestamp
           a.cputime,                                                                           --007 number(16)
           a.errorstack                                                                         --008 varchar2(4000 byte)
      from nkss_tasklist    a
     where 1e1 = 1e1
       and (fr_data.r#wid is null or a.rowid = fr_data.r#wid)                                   --000 urowid
       and a.id = fr_data.id                                                                    --001 number(16)
       for update wait 4;
    fetch lv_refcur into fr_data;
    close lv_refcur;
  exception when others then
    if (lv_refcur%isopen) then
      close lv_refcur;
    end if;
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end select_locking_pvt;

  ------------------------------------------------------------------
  -- EXISTS_ROW_PVT
  ------------------------------------------------------------------
  function exists_row_pvt(fr_id  in RecID)
    return boolean
  is
    lc__   constant varchar2(100) := $$plsql_unit || '.EXISTS_ROW_PVT:';
    lv_refcur       weak_refcursor;
    lv_null         varchar2(1);
    lv_found        boolean := false;
  begin
    open lv_refcur for
    select --+ choose
           null
      from nkss_tasklist    a
     where 1e1 = 1e1
       and (fr_id.r#wid is null or a.rowid = fr_id.r#wid)                                       --000 urowid
       and a.id = fr_id.id;                                                                     --001 number(16)
    fetch lv_refcur into lv_null;
    lv_found := lv_refcur%found;
    close lv_refcur;
    return lv_found;
  exception when others then
    if (lv_refcur%isopen) then
      close lv_refcur;
    end if;
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end exists_row_pvt;

  ------------------------------------------------------------------
  -- DELETE_ROW_PVT
  ------------------------------------------------------------------
  procedure delete_row_pvt(fr_id  in RecID)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.DELETE_ROW_PVT:';
  begin
    delete --+ rowid(a)
      from nkss_tasklist    a
     where 1e1 = 1e1
       and a.rowid = fr_id.r#wid                                                                --000 urowid
       and a.id = fr_id.id;                                                                     --001 number(16)
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end delete_row_pvt;

  ------------------------------------------------------------------
  -- UPDATE_ROW_PVT
  ------------------------------------------------------------------
  procedure update_row_pvt(fr_data  in out nocopy RecData)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.UPDATE_ROW_PVT:';
  begin
    update --+ rowid(a)
           nkss_tasklist    a
       set -- set-list
           a.pid = fr_data.pid,                                                                 --002 number(16)
           a.status = fr_data.status,                                                           --003 number(1)
           a.payload = fr_data.payload,                                                         --004 clob
           a.started = fr_data.started,                                                         --005 timestamp
           a.finished = fr_data.finished,                                                       --006 timestamp
           a.cputime = fr_data.cputime,                                                         --007 number(16)
           a.errorstack = fr_data.errorstack                                                    --008 varchar2(4000 byte)
     where 1e1 = 1e1
       and a.rowid = fr_data.r#wid                                                              --000 urowid
       and a.id = fr_data.id                                                                    --001 number(16)
    returning
           rowid,                                                                               --000 urowid
           id,                                                                                  --001 number(16)
           pid,                                                                                 --002 number(16)
           status,                                                                              --003 number(1)
           payload,                                                                             --004 clob
           started,                                                                             --005 timestamp
           finished,                                                                            --006 timestamp
           cputime,                                                                             --007 number(16)
           errorstack                                                                           --008 varchar2(4000 byte)
      into
           fr_data.r#wid,                                                                       --000 urowid
           fr_data.id,                                                                          --001 number(16)
           fr_data.pid,                                                                         --002 number(16)
           fr_data.status,                                                                      --003 number(1)
           fr_data.payload,                                                                     --004 clob
           fr_data.started,                                                                     --005 timestamp
           fr_data.finished,                                                                    --006 timestamp
           fr_data.cputime,                                                                     --007 number(16)
           fr_data.errorstack;                                                                  --008 varchar2(4000 byte)
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end update_row_pvt;

  ------------------------------------------------------------------
  -- LOCK_ROW_PVT
  ------------------------------------------------------------------
  procedure lock_row_pvt(fr_id  in RecID)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.LOCK_ROW_PVT:';
    lv_refcur        weak_refcursor;
  begin
    begin
      open lv_refcur for
      select --+ rowid(a)
             null
        from nkss_tasklist    a
       where 1e1 = 1e1
         and a.rowid = fr_id.r#wid                                                              --000 urowid
         and a.id = fr_id.id                                                                    --001 number(16)
      for update wait 4;
      close lv_refcur;
    exception
      when lock_nowait or lock_timeout then
        raise_application_error(-20888, 'rowid[' || fr_id.r#wid
                                || '] locked by another session:' || $$plsql_line);
      when others then
        raise;
    end;
  exception when others then
    if (lv_refcur%isopen) then
      close lv_refcur;
    end if;
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end lock_row_pvt;

  ------------------------------------------------------------------
  ------------------------ Public Session --------------------------
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  -- EXISTS_ROW
  ------------------------------------------------------------------
  function exists_row(fr_id  in RecID)
    return boolean
  is
    lc__   constant varchar2(100) := $$plsql_unit || '.EXISTS_ROW:';
  begin
    return exists_row_pvt(fr_id => fr_id);
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end exists_row;
  ------------------------------------------------------------------
  function exists_row(fr_data  in RecData)
    return boolean
  is
    lc__   constant varchar2(100) := $$plsql_unit || '.EXISTS_ROW:';
    lr_id           RecID;
  begin
    lr_id.r#wid := fr_data.r#wid;
    lr_id.id := fr_data.id;
    return exists_row_pvt(fr_id => lr_id);
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end exists_row;

  ------------------------------------------------------------------
  -- SELECT_ROW
  ------------------------------------------------------------------
  procedure select_row(fr_data  in out nocopy RecData,
                       fv_lock  in boolean default false)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.SELECT_ROW:';
    lr_id            RecID;
  begin
    lr_id.r#wid := fr_data.r#wid;
    lr_id.id := fr_data.id;
    if (fv_lock) then
      select_locking_pvt(fr_data => fr_data);
    else
      select_row_pvt(fr_data => fr_data);
    end if;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end select_row;

  ------------------------------------------------------------------
  -- INSERT_ROW
  ------------------------------------------------------------------
  procedure insert_row(fr_data  in out nocopy RecData)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.INSERT_ROW:';
  begin
    inspect_data_pvt(fr_data => fr_data);
    insert into nkss_tasklist
      ( -- column-list
        id,                                                                                     --001 number(16)
        pid,                                                                                    --002 number(16)
        status,                                                                                 --003 number(1)
        payload,                                                                                --004 clob
        started,                                                                                --005 timestamp
        finished,                                                                               --006 timestamp
        cputime,                                                                                --007 number(16)
        errorstack)                                                                             --009 varchar2(4000 byte)
    values
      ( -- value-list
        nkss_tasklist_s.nextval,                                                                --001 number(16)
        fr_data.pid,                                                                            --002 number(16)
        gc_scheduled,                                                                           --003 number(1)
        fr_data.payload,                                                                        --004 clob
        null,                                                                                   --005 timestamp
        null,                                                                                   --006 timestamp
        null,                                                                                   --007 number(16)
        null)                                                                                   --009 varchar2(4000 byte)
    returning
        rowid,                                                                                  --000 urowid
        id,                                                                                     --001 number(16)
        pid,                                                                                    --002 number(16)
        status,                                                                                 --003 number(1)
        payload,                                                                                --004 clob
        started,                                                                                --005 timestamp
        finished,                                                                               --006 timestamp
        cputime,                                                                                --007 number(16)
        errorstack                                                                              --008 varchar2(4000 byte)
    into
        fr_data.r#wid,                                                                          --000 urowid
        fr_data.id,                                                                             --001 number(16)
        fr_data.pid,                                                                            --002 number(16)
        fr_data.status,                                                                         --003 number(1)
        fr_data.payload,                                                                        --004 clob
        fr_data.started,                                                                        --005 timestamp
        fr_data.finished,                                                                       --006 timestamp
        fr_data.cputime,                                                                        --007 number(16)
        fr_data.errorstack;                                                                     --008 varchar2(4000 byte)
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end insert_row;

  ------------------------------------------------------------------
  -- INSERT_ALL
  ------------------------------------------------------------------
  procedure insert_all(ft_data    in out nocopy ArrData,
                       fv_rebind  in boolean default false)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.INSERT_ALL:';
    lt_urowid        urowid_list;
    lt_pk001         pk001_list;   --001 id
    i                pls_integer;
  begin
    ------------
    << sanity >>
    ------------
    begin
      if (ft_data.count > gc_limit) then
        raise_application_error(-20888, 'ft_data.count() is limited to '
                                        || to_char(gc_limit) || ' elements:' || $$plsql_line);
      end if;
      i := ft_data.first;
      while (i is not null) loop
        pragma inline (inspect_data_pvt, 'YES');
        inspect_data_pvt(fr_data => ft_data(i));
        i := ft_data.next(i);
      end loop;
    exception when others then
      raise_application_error(-20777, '<< sanity >>:' || $$plsql_line || nl || dbms_utility.format_error_stack);
    end sanity;
    -----------------
    << forall_call >>
    -----------------
    begin
      forall i in indices of ft_data
      insert into nkss_tasklist
      ( -- column-list
        id,                                                                                     --001 number(16)
        pid,                                                                                    --002 number(16)
        status,                                                                                 --003 number(1)
        payload,                                                                                --004 clob
        started,                                                                                --005 timestamp
        finished,                                                                               --006 timestamp
        cputime,                                                                                --007 number(16)
        errorstack)                                                                             --009 varchar2(4000 byte)
      values
      ( -- value-list
        nkss_tasklist_s.nextval,                                                                --001 number(16)
        ft_data(i).pid,                                                                         --002 number(16)
        gc_scheduled,                                                                           --003 number(1)
        ft_data(i).payload,                                                                     --004 clob
        null,                                                                                   --005 timestamp
        null,                                                                                   --006 timestamp
        null,                                                                                   --007 number(16)
        null)                                                                                   --009 varchar2(4000 byte)
      returning
        rowid,                                                                                  --000 urowid
        id                                                                                      --001 number(16)
      bulk collect into
        lt_urowid,                                                                              --000 urowid
        lt_pk001;                                                                               --001 number(16)
    exception when others then
      raise_application_error(-20777, '<< forall_call >>:' || $$plsql_line || nl || dbms_utility.format_error_stack);
    end forall_call;
    ------------
    << rebind >>
    ------------
    begin
      i := lt_urowid.first;
      while (i is not null) loop
        ft_data(i).r#wid := lt_urowid(i);                                                       --000 urowid
        ft_data(i).id := lt_pk001(i);                                                           --001 number(16)
        if (fv_rebind) then
          pragma inline (select_row_pvt, 'YES');
          select_row_pvt(fr_data => ft_data(i));
        end if;
        i := lt_urowid.next(i);
      end loop;
    exception when others then
      raise_application_error(-20777, '<< rebind >>:'  || $$plsql_line || nl || dbms_utility.format_error_stack);
    end rowid_bind;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end insert_all;

  ------------------------------------------------------------------
  -- LOCK_ROW
  ------------------------------------------------------------------
  procedure lock_row(fr_id  in RecID)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.LOCK_ROW:';
  begin
    inspect_id_pvt(fr_id  => fr_id);
    lock_row_pvt(fr_id => fr_id);
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end lock_row;
  ------------------------------------------------------------------
  procedure lock_row(fr_data  in RecData)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.LOCK_ROW:';
    lr_id            RecID;
  begin
    lr_id.r#wid := fr_data.r#wid;
    lr_id.id := fr_data.id;
    inspect_id_pvt(fr_id  => lr_id);
    lock_row_pvt(fr_id => lr_id);
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end lock_row;

  ------------------------------------------------------------------
  -- LOCK_ALL
  ------------------------------------------------------------------
  procedure lock_all(ft_id  in ArrID)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.LOCK_ALL:';
    i       pls_integer;
  begin
    i := ft_id.first;
    while (i is not null) loop
      pragma inline (lock_row, 'YES');
      lock_row(fr_id => ft_id(i));
      i := ft_id.next(i);
    end loop;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end lock_all;
  ------------------------------------------------------------------
  procedure lock_all(ft_data  in ArrData)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.LOCK_ALL:';
    i       pls_integer;
  begin
    i := ft_data.first;
    while (i is not null) loop
      pragma inline (lock_row, 'YES');
      lock_row(fr_data => ft_data(i));
      i := ft_data.next(i);
    end loop;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end lock_all;

  ------------------------------------------------------------------
  -- UPDATE_ROW
  ------------------------------------------------------------------
  procedure update_row(fr_data  in out nocopy RecData)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.UPDATE_ROW:';
  begin
    inspect_data_pvt(fr_data => fr_data);
    lock_row(fr_data => fr_data);
    update_row_pvt(fr_data => fr_data);
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end update_row;

  ------------------------------------------------------------------
  -- UPDATE_ALL
  ------------------------------------------------------------------
  procedure update_all(ft_data    in out nocopy ArrData,
                       fv_rebind  in boolean default false)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.UPDATE_ALL:';
    lt_urowid        urowid_list;
    i                pls_integer;
  begin
    ------------
    << sanity >>
    ------------
    begin
      if (ft_data.count > gc_limit) then
        raise_application_error(-20888, 'ft_data.count() is limited to '
                                        || to_char(gc_limit) || ' elements:' || $$plsql_line);
      end if;
      i := ft_data.first;
      while (i is not null) loop
        pragma inline (inspect_data_pvt, 'YES');
        inspect_data_pvt(fr_data => ft_data(i));
        pragma inline (lock_row, 'YES');
        lock_row(fr_data => ft_data(i));
        i := ft_data.next(i);
      end loop;
    exception when others then
      raise_application_error(-20777, '<< sanity >>:' || $$plsql_line || nl || dbms_utility.format_error_stack);
    end sanity;
    -----------------
    << forall_call >>
    -----------------
    begin
      forall i in indices of ft_data
      update --+ rowid(a)
             nkss_tasklist    a
         set -- set-list
             a.pid = ft_data(i).pid,                                                            --002 number(16)
             a.status = ft_data(i).status,                                                      --003 number(1)
             a.payload = ft_data(i).payload,                                                    --004 clob
             a.started = ft_data(i).started,                                                    --005 timestamp
             a.finished = ft_data(i).finished,                                                  --006 timestamp
             a.cputime = ft_data(i).cputime,                                                    --007 number(16)
             a.errorstack = ft_data(i).errorstack                                               --008 varchar2(4000 byte)
       where 1e1 = 1e1
         and a.rowid = ft_data(i).r#wid                                                         --000 urowid
         and a.id = ft_data(i).id                                                               --001 number(16)
      returning rowid bulk collect into lt_urowid;
    exception when others then
      raise_application_error(-20777, '<< forall_call >>:' || $$plsql_line || nl || dbms_utility.format_error_stack);
    end forall_call;
    ------------
    << rebind >>
    ------------
    begin
      if (fv_rebind) then
        i := ft_data.first;
        while (i is not null) loop
          pragma inline (select_row_pvt, 'YES');
          select_row_pvt(fr_data => ft_data(i));
          i := ft_data.next(i);
        end loop;
      end if;
    exception when others then
      raise_application_error(-20777, '<< rebind >>:'  || $$plsql_line || nl || dbms_utility.format_error_stack);
    end rebind;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end update_all;

  ------------------------------------------------------------------
  -- DELETE_ROW
  ------------------------------------------------------------------
  procedure delete_row(fr_id  in RecID)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.DELETE_ROW:';
  begin
    lock_row(fr_id => fr_id);
    delete_row_pvt(fr_id => fr_id);
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end delete_row;
  ------------------------------------------------------------------
  procedure delete_row(fr_data  in RecData)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.DELETE_ROW:';
    lr_id            RecID;
  begin
    lr_id.r#wid := fr_data.r#wid;
    lr_id.id := fr_data.id;
    lock_row(fr_id => lr_id);
    delete_row_pvt(fr_id => lr_id);
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end delete_row;

  ------------------------------------------------------------------
  -- DELETE_ALL
  ------------------------------------------------------------------
  procedure delete_all(ft_id  in ArrID)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.DELETE_ALL:';
    lt_urowid        urowid_list;
    i                pls_integer;
  begin
    ------------
    << sanity >>
    ------------
    begin
      if (ft_id.count > gc_limit) then
        raise_application_error(-20888, 'ft_id.count() is limited to '
                                        || to_char(gc_limit) || ' elements:' || $$plsql_line);
      end if;
      i := ft_id.first;
      while (i is not null) loop
        pragma inline (lock_row, 'YES');
        lock_row(fr_id => ft_id(i));
        i := ft_id.next(i);
      end loop;
    exception when others then
      raise_application_error(-20777, '<< sanity >>:' || $$plsql_line || nl || dbms_utility.format_error_stack);
    end sanity;
    -----------------
    << forall_call >>
    -----------------
    begin
      forall i in indices of ft_id
      delete --+ rowid(a)
        from nkss_tasklist    a
       where 1e1 = 1e1
         and a.rowid = ft_id(i).r#wid                                                          --000 urowid
         and a.id = ft_id(i).id                                                                --001 number(16)
      returning rowid bulk collect into lt_urowid;
    exception when others then
      raise_application_error(-20777, '<< forall_call >>:' || $$plsql_line || nl || dbms_utility.format_error_stack);
    end forall_call;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end delete_all;
  ------------------------------------------------------------------
  procedure delete_all(ft_data  in ArrData)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.DELETE_ALL:';
    lt_urowid        urowid_list;
    i                pls_integer;
  begin
    ------------
    << sanity >>
    ------------
    begin
      if (ft_data.count > gc_limit) then
        raise_application_error(-20888, 'ft_data.count() is limited to '
                                        || to_char(gc_limit) || ' elements:' || $$plsql_line);
      end if;
      i := ft_data.first;
      while (i is not null) loop
        pragma inline (lock_row, 'YES');
        lock_row(fr_data => ft_data(i));
        i := ft_data.next(i);
      end loop;
    exception when others then
      raise_application_error(-20777, '<< sanity >>:' || $$plsql_line || nl || dbms_utility.format_error_stack);
    end sanity;
    -----------------
    << forall_call >>
    -----------------
    begin
      forall i in indices of ft_data
      delete --+ rowid(a)
        from nkss_tasklist    a
       where 1e1 = 1e1
         and a.rowid = ft_data(i).r#wid                                                        --000 urowid
         and a.id = ft_data(i).id                                                              --001 number(16)
      returning rowid bulk collect into lt_urowid;
    exception when others then
      raise_application_error(-20777, '<< forall_call >>:' || $$plsql_line || nl || dbms_utility.format_error_stack);
    end forall_call;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end delete_all;

  ------------------------------------------------------------------
  -- IS_NULL
  ------------------------------------------------------------------
  function is_null(fr_id  in RecID)
    return boolean
  is
    lc__   constant varchar2(100) := $$plsql_unit || '.IS_NULL:';
  begin
    return true
           and fr_id.id    is null;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end is_null;
  ------------------------------------------------------------------
  function is_null(fr_data  in RecData)
    return boolean
  is
    lc__   constant varchar2(100) := $$plsql_unit || '.IS_NULL:';
  begin
    return true
           and fr_data.id         is null
           and fr_data.pid        is null
           and fr_data.status     is null
           and fr_data.payload    is null
           and fr_data.started    is null
           and fr_data.finished   is null
           and fr_data.cputime    is null
           and fr_data.errorstack is null;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end is_null;

  ------------------------------------------------------------------
  -- IS_EQUAL
  ------------------------------------------------------------------
  function is_equal(fr_old  in RecID,
                    fr_new  in RecID)
    return boolean
  is
    lc__   constant varchar2(100) := $$plsql_unit || '.IS_EQUAL:';
  begin
    return true
           -- id: integer
           and ((    fr_old.id    is null and     fr_new.id    is null) or
                (not fr_old.id    is null and not fr_new.id    is null
                 and fr_old.id             =      fr_new.id   ));
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end is_equal;
  ------------------------------------------------------------------
  function is_equal(fr_old  in RecData,
                    fr_new  in RecData)
    return boolean
  is
    lc__   constant varchar2(100) := $$plsql_unit || '.IS_EQUAL:';
  begin
    return true
           --001 id: integer
           and ((    fr_old.id         is null and     fr_new.id         is null) or
                (not fr_old.id         is null and not fr_new.id         is null
                 and fr_old.id                  =      fr_new.id        ))
           --002 pid: integer
           and ((    fr_old.pid        is null and     fr_new.pid        is null) or
                (not fr_old.pid        is null and not fr_new.pid        is null
                 and fr_old.pid                 =      fr_new.pid       ))
           --003 status: integer
           and ((    fr_old.status     is null and     fr_new.status     is null) or
                (not fr_old.status     is null and not fr_new.status     is null
                 and fr_old.status              =      fr_new.status    ))
           --004 payload: clob
           and ((    fr_old.payload    is null and     fr_new.payload    is null) or
                (not fr_old.payload    is null and not fr_new.payload    is null
                 and dbms_lob.compare(lob_1  => fr_old.payload,
                                      lob_2  => fr_new.payload,
                                      amount => dbms_lob.lobmaxsize) = 0))
           --005 started: timestamp
           and ((    fr_old.started    is null and     fr_new.started    is null) or
                (not fr_old.started    is null and not fr_new.started    is null
                 and fr_old.started             =      fr_new.started   ))
           --006 finished: timestamp
           and ((    fr_old.finished   is null and     fr_new.finished   is null) or
                (not fr_old.finished   is null and not fr_new.finished   is null
                 and fr_old.finished            =      fr_new.finished  ))
           --007 cputime: integer
           and ((    fr_old.cputime    is null and     fr_new.cputime    is null) or
                (not fr_old.cputime    is null and not fr_new.cputime    is null
                 and fr_old.cputime             =      fr_new.cputime   ))
           --008 errorstack: varchar2
           and ((    fr_old.errorstack is null and     fr_new.errorstack is null) or
                (not fr_old.errorstack is null and not fr_new.errorstack is null
                 and fr_old.errorstack          =      fr_new.errorstack))
           and true;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end is_equal;

  ------------------------------------------------------------------
  -- IS_SAME
  ------------------------------------------------------------------
  function is_same(fr_old  in RecID,
                   fr_new  in RecID)
    return boolean
  is
    lc__   constant varchar2(100) := $$plsql_unit || '.IS_SAME:';
  begin
    pragma inline (is_equal, 'YES');
    return (     fr_old.r#wid is not null
             and fr_new.r#wid is not null
             and fr_old.r#wid = fr_new.r#wid
           ) and is_equal(fr_old => fr_old,
                          fr_new => fr_new);
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end is_same;
  ------------------------------------------------------------------
  function is_same(fr_old  in RecData,
                   fr_new  in RecData)
    return boolean
  is
    lc__   constant varchar2(100) := $$plsql_unit || '.IS_SAME:';
  begin
    pragma inline (is_equal, 'YES');
    return (     fr_old.r#wid is not null
             and fr_new.r#wid is not null
             and fr_old.r#wid = fr_new.r#wid
           ) and is_equal(fr_old => fr_old,
                          fr_new => fr_new);
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end is_same;

  ------------------------------------------------------------------
  -- COUNT_SCHEDULED_TASKS
  ------------------------------------------------------------------
  function count_scheduled_tasks(fv_setid  in integer)
    return integer
  is
    lc__   constant varchar2(100) := $$plsql_unit || '.COUNT_SCHEDULED_TASKS:';
    lv_refcur       weak_refcursor;
    lv_rowcount     integer;
  begin
    if (fv_setid is null) then
      raise_application_error(-20888, 'fv_setid argument cannot be null:' || $$plsql_line);
    end if;
    open lv_refcur for
    select --+ choose
           count(*)
      from nkss_tasklist    a
     where 1e1 = 1e1
       and a.pid = fv_setid
       and a.status = gc_scheduled;
    fetch lv_refcur into lv_rowcount;
    close lv_refcur;
    return lv_rowcount;
  exception when others then
    if (lv_refcur%isopen) then
      close lv_refcur;
    end if;
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end count_scheduled_tasks;

  ------------------------------------------------------------------
  -- TAKE_QUEUED_TASK
  ------------------------------------------------------------------
  procedure take_queued_task(fv_setid  in integer,
                             fr_data   in out nocopy RecData)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.TAKE_QUEUED_TASK:';
    lv_refcur        weak_refcursor;
  begin
    if (fv_setid is null) then
      raise_application_error(-20888, 'fv_setid argument cannot be null:' || $$plsql_line);
    end if;
    open lv_refcur for
    select --+ choose
           a.rowid,                                                                             --000 urowid
           a.id,                                                                                --001 number(16)
           a.pid,                                                                               --002 number(16)
           a.status,                                                                            --003 number(1)
           a.payload,                                                                           --004 clob
           a.started,                                                                           --005 timestamp
           a.finished,                                                                          --006 timestamp
           a.cputime,                                                                           --007 number(16)
           a.errorstack                                                                         --008 varchar2(4000 byte)
      from nkss_tasklist    a
     where 1e1 = 1e1
       and a.pid = fv_setid
       and a.started is null
       and a.status = gc_scheduled
     order by a.id
       for update skip locked;
    fetch lv_refcur into fr_data;
    close lv_refcur;
  exception when others then
    if (lv_refcur%isopen) then
      close lv_refcur;
    end if;
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end take_queued_task;

  ------------------------------------------------------------------
  -- RESCHEDULE
  ------------------------------------------------------------------
  procedure reschedule(fv_oldsetid  in  integer,
                       fv_newsetid  in  integer,
                       fv_status    in  integer,
                       fv_rowcount  out integer)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.RESCHEDULE:';
    lv_status#1      integer;
    lv_status#2      integer;
  begin
    if (fv_oldsetid is null) then
      raise_application_error(-20888, 'fv_oldsetid argument cannot be null:' || $$plsql_line);
    elsif (fv_newsetid is null) then
      raise_application_error(-20888, 'fv_newsetid argument cannot be null:' || $$plsql_line);
    elsif (fv_status not in (nkss_manager.all_tasks, nkss_manager.failed_tasks, nkss_manager.succeeded_tasks)) then
        raise_application_error(-20888, 'fv_status argument is not valid:' || $$plsql_line);
    end if;
    if (fv_status = nkss_manager.all_tasks) then
      lv_status#1 := 0;
      lv_status#2 := 1;
    elsif (fv_status = nkss_manager.failed_tasks) then
      lv_status#1 := 1;
      lv_status#2 := 1;
    elsif (fv_status = nkss_manager.succeeded_tasks) then
      lv_status#1 := 0;
      lv_status#2 := 0;
    end if;
    insert into nkss_tasklist (
           id,                                                                                  --001 number(16)
           pid,                                                                                 --002 number(16)
           status,                                                                              --003 number(1)
           payload,                                                                             --004 clob
           started,                                                                             --005 timestamp
           finished,                                                                            --006 timestamp
           cputime,                                                                             --007 number(16)
           errorstack)                                                                          --009 varchar2(4000 byte)
    select --+ choose
           nkss_tasklist_s.nextval,                                                             --001 number(16)
           fv_newsetid,                                                                         --002 number(16)
           gc_scheduled,                                                                        --003 number(1)
           payload,                                                                             --004 clob
           null,                                                                                --005 timestamp
           null,                                                                                --006 timestamp
           null,                                                                                --007 number(16)
           null                                                                                 --008 varchar2(4000 byte)
      from (--in-line-view
            select --+ choose
                   payload
              from nkss_tasklist
             where 1e1 = 1e1
               and pid = fv_oldsetid
               and status in (lv_status#1, lv_status#2)
             order by id
           )
     where 1e1 = 1e1;
    fv_rowcount := sql%rowcount;
  exception when others then
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end reschedule;

  ------------------------------------------------------------------
  -- PURGE_TASKLIST
  ------------------------------------------------------------------
  procedure purge_tasklist(fv_setid  in integer)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.PURGE_TASKLIST:';
    lv_refcur        weak_refcursor;
  begin
    if (fv_setid is null) then
      raise_application_error(-20888, 'fv_setid argument cannot be null:' || $$plsql_line);
    end if;
    ----------------
    << purge_lock >>
    ----------------
    begin
      open lv_refcur for
      select --+ choose
             null
        from nkss_tasklist    a
       where 1e1 = 1e1
         and a.pid = fv_setid
         for update wait 4;
      close lv_refcur;
    exception
      when lock_nowait or lock_timeout then
        raise_application_error(-20888, 'Task list[' || to_char(fv_setid)
                                || '] locked by another session:' || $$plsql_line);
      when others then
        raise;
    end purge_lock;
    ----------------
    << purge_stmt >>
    ----------------
    begin
      delete --+ choose
        from nkss_tasklist    a
       where 1e1 = 1e1
         and a.pid = fv_setid;
    exception when others then
      raise_application_error(-20777, '<< purge_stmt >>:' || $$plsql_line || nl || dbms_utility.format_error_stack);
    end purge_stmt;
  exception when others then
    if (lv_refcur%isopen) then
      close lv_refcur;
    end if;
    raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  end purge_tasklist;

  ------------------------------------------------------------------
  --------------------- Initialization Session ---------------------
  ------------------------------------------------------------------
begin
  $if $$plsql_optimize_level < 3 $then
    $error $$plsql_unit || ' must be compiled with PLSQL_OPTIMIZE_LEVEL=3' $end
  $end
  null;
exception when others then
  raise_application_error(-20777, $$plsql_unit || '<init>:'|| $$plsql_line || nl || dbms_utility.format_error_stack);
end nkss_tasklist_dml;
