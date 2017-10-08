create or replace package body nkss_taskset_dml
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
  -- NKSS_TASKSET_DML: NKSS_TASKSET Simple CRUD API
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  ------------------------ Declare Session -------------------------
  ------------------------------------------------------------------
  -- Local constants
  nl       constant varchar2(1) := '
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

  ------------------------------------------------------------------
  ------------------------ Private Session -------------------------
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  -- BULK_EXCEPTION_PVT
  -- *** TODO ***
  ------------------------------------------------------------------
  --procedure bulk_exception_pvt(ft_error  in out nocopy plstring_list)
  --is
  --  lc__    constant varchar2(100) := $$plsql_unit || '.BULK_EXCEPTION_PVT:';
  --  j                pls_integer;
  --begin
  --  for i in 1 .. sql%bulk_exceptions.count loop
  --    j := sql%bulk_exceptions(i).error_index;
  --    ft_error(j) := sqlerrm(-sql%bulk_exceptions(i).error_code);
  --  end loop;
  --exception when others then
  --  raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  --end bulk_exception_pvt;

  ------------------------------------------------------------------
  -- INSPECT_DATA_PVT
  ------------------------------------------------------------------
  procedure inspect_data_pvt(fr_data  in out nocopy RecData)
  is
    lc__    constant varchar2(100) := $$plsql_unit || '.INSPECT_DATA_PVT:';
  begin
    if (fr_data.label is null) then
      raise_application_error(-20888, 'fr_data.label argument cannot be null:' || $$plsql_line);
    end if;
    -- include defaults and sanities below this line...
    fr_data.created := systimestamp;
    fr_data.errorstack := null;
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
    lc__    constant varchar2(100) := $$plsql_unit || '.SELECT_ROW_PVT:';
    lv_refcur        weak_refcursor;
  begin
    open lv_refcur for
    select --+ choose
           a.rowid,                                                                             --000 urowid
           a.id,                                                                                --001 number(16)
           a.created,                                                                           --002 timestamp
           a.label,                                                                             --003 varchar2(150 byte)
           a.payload,                                                                           --004 clob
           a.errorstack                                                                         --005 varchar2(4000 byte)
      from nkss_taskset    a
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
           a.created,                                                                           --002 timestamp
           a.label,                                                                             --003 varchar2(150 byte)
           a.payload,                                                                           --004 clob
           a.errorstack                                                                         --005 varchar2(4000 byte)
      from nkss_taskset    a
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
      from nkss_taskset    a
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
      from nkss_taskset    a
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
           nkss_taskset    a
       set -- set-list
           a.created = fr_data.created,                                                         --002 timestamp
           a.label = fr_data.label,                                                             --003 varchar2(150 byte)
           a.payload = fr_data.payload,                                                         --004 clob
           a.errorstack = fr_data.errorstack                                                    --005 varchar2(4000 byte)
     where 1e1 = 1e1
       and a.rowid = fr_data.r#wid                                                              --000 urowid
       and a.id = fr_data.id                                                                    --001 number(16)
    returning
           rowid,                                                                               --000 urowid
           id,                                                                                  --001 number(16)
           created,                                                                             --002 timestamp
           label,                                                                               --003 varchar2(150 byte)
           payload,                                                                             --004 clob
           errorstack                                                                           --005 varchar2(4000 byte)
      into
           fr_data.r#wid,                                                                       --000 urowid
           fr_data.id,                                                                          --001 number(16)
           fr_data.created,                                                                     --002 timestamp
           fr_data.label,                                                                       --003 varchar2(150 byte)
           fr_data.payload,                                                                     --004 clob
           fr_data.errorstack;                                                                  --005 varchar2(4000 byte)
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
        from nkss_taskset    a
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
  -- LOCK_ALL_PVT
  -- *** TODO ***
  ------------------------------------------------------------------
  --procedure lock_all_pvt
  --is
  --  lc__    constant varchar2(100) := $$plsql_unit || '.LOCK_ALL_PVT:';
  --  lv_refcur        weak_refcursor;
  --begin
  --  begin
  --    open lv_refcur for
  --    select --+ rowid(a)
  --           null
  --      from nkss_taskset    a
  --     where 1e1 = 1e1
  --       and (a.rowid, a.id) in (select --+ dynamic_sampling(p, 10)
  --                                      chartorowid(p.map_item),
  --                                      to_number(p.map_value)
  --                                 from table(nksg_dmlapi.pipe_rowid)    p
  --                                where 1e1 = 1e1)
  --       for update wait 4;
  --    close lv_refcur;
  --  exception
  --    when lock_nowait or lock_timeout then
  --      raise_application_error(-20888, 'Some element in collection has been locked by another session:' || $$plsql_line);
  --    when others then
  --      raise;
  --  end;
  --exception when others then
  --  if (lv_refcur%isopen) then
  --    close lv_refcur;
  --  end if;
  --  raise_application_error(-20777, lc__ || $$plsql_line || nl || dbms_utility.format_error_stack);
  --end lock_all_pvt;

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
    insert into nkss_taskset
      ( -- column-list
        id,                                                                                     --001 number(16)
        created,                                                                                --002 timestamp
        label,                                                                                  --003 varchar2(150 byte)
        payload,                                                                                --004 clob
        errorstack)                                                                             --005 varchar2(4000 byte)
    values
      ( -- value-list
        nkss_taskset_s.nextval,                                                                 --001 number(16)
        fr_data.created,                                                                        --002 timestamp
        fr_data.label,                                                                          --003 varchar2(150 byte)
        fr_data.payload,                                                                        --004 clob
        fr_data.errorstack)                                                                     --005 varchar2(4000 byte)
    returning
        rowid,                                                                                  --000 urowid
        id,                                                                                     --001 number(16)
        created,                                                                                --002 timestamp
        label,                                                                                  --003 varchar2(150 byte)
        payload,                                                                                --004 clob
        errorstack                                                                              --005 varchar2(4000 byte)
    into
        fr_data.r#wid,                                                                          --000 urowid
        fr_data.id,                                                                             --001 number(16)
        fr_data.created,                                                                        --002 timestamp
        fr_data.label,                                                                          --003 varchar2(150 byte)
        fr_data.payload,                                                                        --004 clob
        fr_data.errorstack;                                                                     --005 varchar2(4000 byte)
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
      insert into nkss_taskset
      ( -- column-list
        id,                                                                                     --001 number(16)
        created,                                                                                --002 timestamp
        label,                                                                                  --003 varchar2(150 byte)
        payload,                                                                                --004 clob
        errorstack)                                                                             --005 varchar2(4000 byte)
      values
      ( -- value-list
        nkss_taskset_s.nextval,                                                                 --001 number(16)
        ft_data(i).created,                                                                     --002 timestamp
        ft_data(i).label,                                                                       --003 varchar2(150 byte)
        ft_data(i).payload,                                                                     --004 clob
        ft_data(i).errorstack)                                                                  --005 varchar2(4000 byte)
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
    end rebind;
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
             nkss_taskset    a
         set -- set-list
             a.created = ft_data(i).created,                                                    --002 timestamp
             a.label = ft_data(i).label,                                                        --003 varchar2(150 byte)
             a.payload = ft_data(i).payload,                                                    --004 clob
             a.errorstack = ft_data(i).errorstack                                               --005 varchar2(4000 byte)
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
        from nkss_taskset    a
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
        from nkss_taskset    a
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
           and fr_data.created    is null
           and fr_data.label      is null
           and fr_data.payload    is null
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
           --002 created: timestamp
           and ((    fr_old.created    is null and     fr_new.created    is null) or
                (not fr_old.created    is null and not fr_new.created    is null
                 and fr_old.created             =      fr_new.created   ))
           --003 label: varchar2
           and ((    fr_old.label      is null and     fr_new.label      is null) or
                (not fr_old.label      is null and not fr_new.label      is null
                 and fr_old.label               =      fr_new.label     ))
           --004 payload: clob
           and ((    fr_old.payload    is null and     fr_new.payload    is null) or
                (not fr_old.payload    is null and not fr_new.payload    is null
                 and dbms_lob.compare(lob_1  => fr_old.payload,
                                      lob_2  => fr_new.payload,
                                      amount => dbms_lob.lobmaxsize) = 0))
           --005 errorstack: varchar2
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
  --------------------- Initialization Session ---------------------
  ------------------------------------------------------------------
begin
  $if $$plsql_optimize_level < 3 $then
    $error $$plsql_unit || ' must be compiled with PLSQL_OPTIMIZE_LEVEL=3' $end
  $end
  null;
exception when others then
  raise_application_error(-20777, $$plsql_unit || '<init>:'|| $$plsql_line || nl || dbms_utility.format_error_stack);
end nkss_taskset_dml;
