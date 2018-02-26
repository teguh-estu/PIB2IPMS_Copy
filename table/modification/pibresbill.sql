create table TB_T_RES_PIBRESBILL
(
  PROCESS_ID varchar2(20),
  CAR        varchar2(45),
  RESTG      date,
  RESWK      varchar2(6),
  AKUN       varchar2(100),
  NPWP       varchar2(15),
  NILAI      varchar2(18),
  CREATED_BY varchar2(20),
  CREATED_DT date,
  CHANGED_BY varchar2(20),
  CHANGED_DT date
)
;

alter table TB_T_RES_PIBRESBILL
  add constraint PK_TB_T_RES_PIBRESBILL primary key (CAR, RESTG, RESWK, AKUN);

create table TB_R_RES_PIBRESBILL
(
  CAR        varchar2(45),
  RESTG      date,
  RESWK      varchar2(6),
  AKUN       varchar2(100),
  NPWP       varchar2(15),
  NILAI      varchar2(18),
  CREATED_BY varchar2(20),
  CREATED_DT date,
  CHANGED_BY varchar2(20),
  CHANGED_DT date
)
;

alter table TB_R_RES_PIBRESBILL
  add constraint PK_TB_R_RES_PIBRESBILL primary key (CAR, RESTG, RESWK, AKUN);
