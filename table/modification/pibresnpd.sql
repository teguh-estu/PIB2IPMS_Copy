(
  CAR        varchar2(26),
  RESTG      date,
  RESWK      varchar2(6),
  SERI     varchar2(22),
  URDOK    varchar2(100),
  NILAI  varchar2(3),

  CREATED_BY varchar2(20),
  CREATED_DT date,
  CHANGED_BY varchar2(20),
  CHANGED_DT date
)
;

alter table TB_R_RES_PIBRESNPD
  add constraint PK_TB_R_RES_PIBRESNPD primary key (CAR,RESTG, RESWK, SERI);

create table TB_T_RES_PIBRESNPD
(
  PROCESS_ID varchar2(20),
  CAR        varchar2(26),
  RESTG      date,
  RESWK      varchar2(6),
  SERI     varchar2(22),
  URDOK    varchar2(100),
  NILAI  varchar2(3),

  CREATED_BY varchar2(20),
  CREATED_DT date,
  CHANGED_BY varchar2(20),
  CHANGED_DT date
)
;

alter table TB_T_RES_PIBRESNPD
  add constraint PK_TB_T_RES_PIBRESNPD primary key (CAR,RESTG, RESWK, SERI);
