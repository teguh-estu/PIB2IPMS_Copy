create table TB_T_RES_PIBRESNPBL
(
  PROCESS_ID varchar2(20),
  CAR        varchar2(26),
  RESKD      varchar2(3),
  RESTG      date,
  RESWK      varchar2(6),
  SERIAL     varchar2(22),
  BRGURAI    varchar2(100),
  KETENTUAN  varchar2(50),
  PEMBERITAHUAN varchar2(50),
  PENETAPAN varchar2(50),

  CREATED_BY varchar2(20),
  CREATED_DT date,
  CHANGED_BY varchar2(20),
  CHANGED_DT date
)
;

alter table TB_T_RES_PIBRESNPBL
  add constraint PK_TB_T_RES_PIBRESNPBL primary key (CAR, RESKD, RESTG, RESWK, SERIAL);

create table TB_R_RES_PIBRESNPBL
(
  CAR        varchar2(26),
  RESKD      varchar2(3),
  RESTG      date,
  RESWK      varchar2(6),
  SERIAL     varchar2(22),
  BRGURAI    varchar2(100),
  KETENTUAN  varchar2(50),
  PEMBERITAHUAN varchar2(50),
  PENETAPAN varchar2(50),

  CREATED_BY varchar2(20),
  CREATED_DT date,
  CHANGED_BY varchar2(20),
  CHANGED_DT date
)
;

alter table TB_R_RES_PIBRESNPBL
  add constraint PK_TB_R_RES_PIBRESNPBL primary key (CAR, RESKD, RESTG, RESWK, SERIAL);
