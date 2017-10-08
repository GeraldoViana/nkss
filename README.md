# NKSS: PL/SQL Simple Scheduler
### Run concurrent programs with an arbitrary number of workers

Although tools like Apache JMeter is very good to simulate high concurrency,  
I always prefer run my tests and production batch parallel processing directly from the database.

This very simple API can be used for any type of processing and workloads within the database.

With more and more cores being added to processors nowadays, there's no excuse to write single  
core batch programs anymore.

The API consists in mere two database tables and one very generic DBMS_SCHEDULER program.

Tables:  
NKSS_TASKSET - Task definition  
NKSS_TASKLIST - All tasks that you want to run concurrently with a variable number of workers

```sql
╭─┤⛁ oracle@katana│⌚07:38:43│☂ 977│⚓/d01/github/nkss/src│
└──╼ sqlplus nkss/nkss

SQL*Plus: Release 11.2.0.2.0 Production on Sun Oct 8 07:38:50 2017
Copyright (c) 1982, 2011, Oracle.  All rights reserved.
Connected to:
Oracle Database 11g Express Edition Release 11.2.0.2.0 - 64bit Production

NKSS@XE:SQL> desc nkss_taskset
 Name                                      Null?    Type
 ----------------------------------------- -------- ----------------------------
 ID                                        NOT NULL NUMBER(16)
 CREATED                                   NOT NULL TIMESTAMP(6)
 LABEL                                     NOT NULL VARCHAR2(150)
 PAYLOAD                                            CLOB
 ERRORSTACK                                         VARCHAR2(4000)

NKSS@XE:SQL> desc nkss_tasklist
 Name                                      Null?    Type
 ----------------------------------------- -------- ----------------------------
 ID                                        NOT NULL NUMBER(16)
 PID                                       NOT NULL NUMBER(16)
 STATUS                                    NOT NULL NUMBER(1)
 PAYLOAD                                   NOT NULL CLOB
 STARTED                                            TIMESTAMP(6)
 FINISHED                                           TIMESTAMP(6)
 CPUTIME                                            NUMBER(16)
 ERRORSTACK                                         VARCHAR2(4000)

NKSS@XE:SQL>
Disconnected from Oracle Database 11g Express Edition Release 11.2.0.2.0 - 64bit Production
```
