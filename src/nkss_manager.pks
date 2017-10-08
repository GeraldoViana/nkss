create or replace package nkss_manager
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
  -- NKSS_TASKMANAGER: Overall Task Management
  ------------------------------------------------------------------
  -- This is the only interface you need to manage your sets
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  ------------------------ Declare Session -------------------------
  ------------------------------------------------------------------
  -- Constants
  gc_limit           constant integer default 1e2; -- max elements on ArrPayload
  all_tasks          constant integer default 2;   -- excluding scheduled tasks(-1)
  failed_tasks       constant integer default 1;
  succeeded_tasks    constant integer default 0;
  scheduled_tasks    constant integer default -1;

  -- Types
  type ArrPayload is table of clob index by pls_integer;

  ------------------------------------------------------------------
  ----------------------- Subprogram Session -----------------------
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  -- NEW_TASKSET: Create a new task set
  ------------------------------------------------------------------
  -- Arguments:
  --   fv_label   => Task Set tag/description
  --   fv_payload => Optionall executable SQL, PL/SQL block;
  -- Return:
  --   New task set ID
  ------------------------------------------------------------------
  function new_taskset(fv_label    in varchar2,
                       fv_payload  in clob default null)
    return integer;

  ------------------------------------------------------------------
  -- ADD_TASK: Adds tasks to the set
  ------------------------------------------------------------------
  -- Arguments:
  --   fv_setid   => Task set ID
  --   fv_payload => Single executable SQL, PL/SQL statement;
  ------------------------------------------------------------------
  procedure add_task(fv_setid    in integer,
                     fv_payload  in varchar2);
  ------------------------------------------------------------------
  procedure add_task(fv_setid    in integer,
                     fv_payload  in clob);
  ------------------------------------------------------------------
  procedure add_task(fv_setid    in integer,
                     ft_payload  in ArrPayload);

  ------------------------------------------------------------------
  -- RESCHEDULE: Creates a new task set from a previous one
  ------------------------------------------------------------------
  -- Arguments:
  --   fv_setid   => Task set ID to reschedule
  --   fv_label   => Task set tag/description
  --   fv_payload => Optional single executable SQL, PL/SQL statement;
  --   fv_status  => Status of tasks to reschedule:
  --                 valid values are: - nkss_manager.all_tasks (excluding scheduled tasks);
  --                                   - nkss_manager.failed_tasks;
  --                                   - nkss_manager.succeeded_tasks;
  -- Return:
  --   New task set ID
  ------------------------------------------------------------------
  function reschedule(fv_setid    in integer,
                      fv_label    in varchar2 default null,
                      fv_payload  in clob     default null,
                      fv_status   in integer  default failed_tasks)
    return integer;

  ------------------------------------------------------------------
  -- DAEMONIZE
  ------------------------------------------------------------------
  -- Once committed, starts the background workers
  ------------------------------------------------------------------
  -- Arguments:
  --   fv_setid   => Task set ID
  --   fv_workers => Number of concurrent background jobs to dispatch
  ------------------------------------------------------------------
  procedure daemonize(fv_setid    in integer,
                      fv_workers  in integer);

  ------------------------------------------------------------------
  -- PURGE_TASKSET
  ------------------------------------------------------------------
  -- Purge all tasks and the set, regardless any status
  ------------------------------------------------------------------
  -- Arguments:
  --   fv_setid => Task set ID to purge definitely
  ------------------------------------------------------------------
  procedure purge_taskset(fv_setid  in integer);

end nkss_manager;
