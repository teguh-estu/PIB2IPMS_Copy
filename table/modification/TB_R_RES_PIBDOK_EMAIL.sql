-- Create table
create table TB_R_RES_PIBDOK_EMAIL
(
  PROCESS_ID varchar2(20),
  PIB_NO     varchar2(6),
  PIB_DT     date,
  PI_NO      varchar2(255),
  created_by varchar2(20),
  created_dt date,
  send_date  date
)
;
-- Create/Recreate primary, unique and foreign key constraints 
alter table TB_R_RES_PIBDOK_EMAIL
  add constraint PK_TB_R_RES_PIBDOK_EMAIL primary key (PROCESS_ID, PIB_NO, PIB_DT, PI_NO);