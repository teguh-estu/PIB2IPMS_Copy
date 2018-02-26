create table TB_T_RES_PIBDTLVD
(
  PROCESS_ID   VARCHAR2(20),
  CAR          VARCHAR2(26) not null,
  SERIAL       NUMBER(4) not null,
  JENIS        VARCHAR2(3) not null,
  NILAI        NUMBER(18,2),
  TGJATUHTEMPO VARCHAR2(8),
  CREATED_BY   VARCHAR2(20),
  CREATED_DT   DATE,
  CHANGED_BY   VARCHAR2(20),
  CHANGED_DT   DATE
)
;

alter table TB_T_RES_PIBDTLVD
  add constraint PK_TB_T_RES_PIBDTLVD primary key (CAR, SERIAL, JENIS)


create table TB_R_RES_PIBDTLVD
(
   CAR          VARCHAR2(26) not null,
  SERIAL       NUMBER(4) not null,
  JENIS        VARCHAR2(3) not null,
  NILAI        NUMBER(18,2),
  TGJATUHTEMPO VARCHAR2(8),
  CREATED_BY   VARCHAR2(20),
  CREATED_DT   DATE,
  CHANGED_BY   VARCHAR2(20),
  CHANGED_DT   DATE
)
;

alter table TB_R_RES_PIBDTLVD
  add constraint PK_TB_R_RES_PIBDTLVD primary key (CAR, SERIAL, JENIS)
