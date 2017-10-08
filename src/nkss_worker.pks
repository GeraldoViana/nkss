create or replace package nkss_worker
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
  -- NKSS_WORKER: Scheduler job entry point
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  -- This is the only PL/SQL Package called from previous registered
  -- DBMS_SCHEDULER Program: 'NKSS#WORKER'.
  ------------------------------------------------------------------
  -- This background job session will deal gracefully with others
  -- siblings concurrently in the task set, and will terminate only
  -- when there is not a single task left unprocessed(status = -1),
  -- providing a natural load balancing amongst the list of tasks.
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  -- MAIN: Called from a NKSS scheduled job
  ------------------------------------------------------------------
  -- *** FYI ***
  -- You should not call this directly, although it will run
  -- concurrently with other workers scheduled in the background,
  -- it will not be detached from your current session.
  ------------------------------------------------------------------
  -- Arguments:
  --   fv_setid => Task set ID
  ------------------------------------------------------------------
  procedure main(fv_setid  in integer);

end nkss_worker;
