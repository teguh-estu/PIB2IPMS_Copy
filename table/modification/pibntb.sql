create table TB_T_RES_PIBNTB
(
  PROCESS_ID VARCHAR2(20),
  CAR          VARCHAR2(26),
  NTB       VARCHAR2(30),
  NTPN        VARCHAR2(20),
  
  CREATED_BY VARCHAR2(20),
  CREATED_DT DATE,
  CHANGED_BY VARCHAR2(20),
  CHANGED_DT DATE
);

alter table TB_T_RES_PIBNTB
  add constraint PK_TB_T_RES_PIBNTB primary key (CAR);

create table TB_R_RES_PIBNTB
(
  CAR          VARCHAR2(26),
  NTB       VARCHAR2(30),
  NTPN        VARCHAR2(20),
  
  CREATED_BY VARCHAR2(20),
  CREATED_DT DATE,
  CHANGED_BY VARCHAR2(20),
  CHANGED_DT DATE
);

alter table TB_R_RES_PIBNTB
  add constraint PK_TB_R_RES_PIBNTB primary key (CAR);
