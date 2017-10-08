create or replace package nkss_taskset_dml
authid current_user
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
  gc_limit   constant pls_integer := 1e2; --FORALL collection limit: 100

  -- API types
  type RecID is record(r#wid    urowid,
                       id       number(16));
  type ArrID is table of RecID index by pls_integer;

  type RecData is record(r#wid         urowid,
                         id            number(16),             -- PK 1/1
                         created       timestamp,
                         label         varchar2(150 byte),
                         payload       clob,
                         errorstack    varchar2(4000 byte));
  type ArrData is table of RecData index by pls_integer;

  ------------------------------------------------------------------
  ----------------------- Subprogram Session -----------------------
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  -- EXISTS_ROW
  ------------------------------------------------------------------
  function exists_row(fr_id  in RecID)
    return boolean;
  ------------------------------------------------------------------
  function exists_row(fr_data  in RecData)
    return boolean;

  ------------------------------------------------------------------
  -- SELECT_ROW
  ------------------------------------------------------------------
  procedure select_row(fr_data  in out nocopy RecData,
                       fv_lock  in boolean default false);

  ------------------------------------------------------------------
  -- INSERT_ROW
  ------------------------------------------------------------------
  procedure insert_row(fr_data  in out nocopy RecData);

  ------------------------------------------------------------------
  -- INSERT_ALL
  ------------------------------------------------------------------
  procedure insert_all(ft_data    in out nocopy ArrData,
                       fv_rebind  in boolean default false);

  ------------------------------------------------------------------
  -- LOCK_ROW
  ------------------------------------------------------------------
  procedure lock_row(fr_id  in RecID);
  ------------------------------------------------------------------
  procedure lock_row(fr_data  in RecData);

  ------------------------------------------------------------------
  -- LOCK_ALL
  ------------------------------------------------------------------
  procedure lock_all(ft_id  in ArrID);
  ------------------------------------------------------------------
  procedure lock_all(ft_data  in ArrData);

  ------------------------------------------------------------------
  -- UPDATE_ROW
  ------------------------------------------------------------------
  procedure update_row(fr_data  in out nocopy RecData);

  ------------------------------------------------------------------
  -- UPDATE_ALL
  ------------------------------------------------------------------
  procedure update_all(ft_data    in out nocopy ArrData,
                       fv_rebind  in boolean default false);

  ------------------------------------------------------------------
  -- DELETE_ROW
  ------------------------------------------------------------------
  procedure delete_row(fr_id  in RecID);
  ------------------------------------------------------------------
  procedure delete_row(fr_data  in RecData);

  ------------------------------------------------------------------
  -- DELETE_ALL
  ------------------------------------------------------------------
  procedure delete_all(ft_id  in ArrID);
  ------------------------------------------------------------------
  procedure delete_all(ft_data  in ArrData);

  ------------------------------------------------------------------
  -- IS_NULL
  ------------------------------------------------------------------
  function is_null(fr_id  in RecID)
    return boolean;
  ------------------------------------------------------------------
  function is_null(fr_data  in RecData)
    return boolean;

  ------------------------------------------------------------------
  -- IS_EQUAL
  ------------------------------------------------------------------
  function is_equal(fr_old  in RecID,
                    fr_new  in RecID)
    return boolean;
  ------------------------------------------------------------------
  function is_equal(fr_old  in RecData,
                    fr_new  in RecData)
    return boolean;

  ------------------------------------------------------------------
  -- IS_SAME
  ------------------------------------------------------------------
  function is_same(fr_old  in RecID,
                   fr_new  in RecID)
    return boolean;
  ------------------------------------------------------------------
  function is_same(fr_old  in RecData,
                   fr_new  in RecData)
    return boolean;

end nkss_taskset_dml;
