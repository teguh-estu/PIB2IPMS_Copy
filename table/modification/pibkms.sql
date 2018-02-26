create table TB_T_RES_PIBKMS
(
  PROCESS_ID VARCHAR2(20),
  CAR       VARCHAR2(26),
  JNKEMAS   VARCHAR2(2),
  JMKEMAS   NUMBER(4),
  MERKKEMAS VARCHAR2(30),
  CREATED_BY VARCHAR2(20),
  CREATED_DT DATE,
  CHANGED_BY VARCHAR2(20),
  CHANGED_DT DATE
);

alter table TB_T_RES_PIBKMS
  add constraint PK_TB_T_RES_PIBKMS primary key (CAR, JNKEMAS, MERKKEMAS);

create table TB_R_RES_PIBKMS
(
  CAR       VARCHAR2(26),
  JNKEMAS   VARCHAR2(2),
  JMKEMAS   NUMBER(4),
  MERKKEMAS VARCHAR2(30),
  CREATED_BY VARCHAR2(20),
  CREATED_DT DATE,
  CHANGED_BY VARCHAR2(20),
  CHANGED_DT DATE
);

alter table TB_R_RES_PIBKMS
  add constraint PK_TB_R_RES_PIBKMS primary key (CAR, JNKEMAS, MERKKEMAS);
