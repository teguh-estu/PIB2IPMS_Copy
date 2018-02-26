alter table TB_T_RES_PIBDOK add NOURUT number(5);
alter table TB_T_RES_PIBDOK add KDGROUPDOK varchar2(3);

create table TB_R_RES_PIBDOK
(
  CAR           VARCHAR2(26),
  DOKKD         VARCHAR2(3),
  DOKDESC       VARCHAR2(70),
  DOKNO         VARCHAR2(30),
  DOKTG         DATE,
  DOKINST       VARCHAR2(3),
   NOURUT        NUMBER(5),
  KDGROUPDOK    VARCHAR2(3),
  CREATED_BY    VARCHAR2(20),
  CREATED_DT    DATE,
  CHANGED_BY    VARCHAR2(20),
  CHANGED_DT    DATE
 
)
;

alter table TB_R_RES_PIBDOK
  add constraint PK_TB_R_RES_PIBDOK primary key (CAR, DOKKD, DOKNO);
