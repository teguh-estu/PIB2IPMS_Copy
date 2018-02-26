CREATE OR REPLACE PACKAGE pkg_bipmb471 IS

  /********************************************************************************
  **  PROJECT        : IPMS (Import Part Management System)                      **
  **  COPYRIGHT      : FUJITSU INDONESIA (FID)                                   **
  **  SCRIPT         : Package pkg_bipmb470                                      **
  **  AUTHOR         : Henry Kusuma, Wong                                        **
  **  CREATED        : 03/31/2010                                                **
  **  PURPOSE        : Interface Import Declaration Response                     **
  **  VERSION        : 1.0                                                       **
  **                                                                             **
  **  Ver        Date        Author              Description                     **
  **  1          03/31/2010  Henry Kusuma        Initial Creation                **
  ********************************************************************************/

  FUNCTION fn_interface_import_response (ri_v_process_id IN VARCHAR2
  ) RETURN NUMBER;

END;
/
CREATE OR REPLACE PACKAGE BODY pkg_bipmb471 IS



  FUNCTION fn_interface_import_response(ri_v_process_id IN VARCHAR2) RETURN NUMBER IS

    TYPE status_rec IS RECORD
    (
     v_process_id tb_t_sd_vessel.process_id%TYPE,
     v_user_id tb_t_sd_vessel.created_by%TYPE := 'IPMS_PIB_RES',
     n_seq_no NUMBER := 0,
     v_replace_flag tb_m_system.system_value_txt%TYPE,
     b_error BOOLEAN := FALSE,
     b_error_per_submission BOOLEAN := FALSE,
     b_warning BOOLEAN := FALSE,
     b_lock BOOLEAN := FALSE,
     b_debug_mode BOOLEAN := FALSE
    );

    g_rec_status status_rec;

    c_success CONSTANT NUMBER(1) := 0;
    c_failed1 CONSTANT NUMBER(1) := 1;
    c_failed2 CONSTANT NUMBER(1) := 2;
    c_warning CONSTANT NUMBER(1) := 3;
    c_on_progress CONSTANT NUMBER(1) := 4;
    c_function_id CONSTANT tb_r_log_h.function_id%TYPE := 'BIPMB471';
    c_function_name CONSTANT VARCHAR2(50) := 'Interface Import Declaration Response';
    c_lock_ref_key CONSTANT tb_r_lock.lock_ref_key%TYPE := 'FUNCTION_ID:BIPMB471';
    c_new_line CONSTANT VARCHAR2(2) :=  chr(13) || chr(10);

    l_v_error_message tb_r_log_d.err_message%TYPE;

    l_v_import_decl_no tb_r_res_import_decl_h.import_decl_no%TYPE;
    l_d_import_decl_dt tb_r_res_import_decl_h.import_decl_dt%TYPE;
    l_v_res_doc_no tb_r_res_import_decl_h.res_doc_no%TYPE;
    l_n_cur_amount tb_r_res_import_decl_h.cur_amount%TYPE;
    l_v_bl_no tb_r_res_import_decl_h.bl_no%TYPE;
    l_d_bl_dt tb_r_res_import_decl_h.bl_dt%TYPE;
    l_v_paid tb_m_system.system_value_txt%TYPE;
    l_v_non_paid tb_m_system.system_value_txt%TYPE;
    l_v_paid_sts tb_m_system.system_value_txt%TYPE;
    l_v_email_from tb_m_system.system_value_txt%TYPE;
    l_v_email_to tb_m_system.system_value_txt%TYPE;
    l_v_email_cc tb_m_system.system_value_txt%TYPE;
    l_v_email_subject tb_m_system.system_value_txt%TYPE;
    l_v_email_header tb_m_system.system_value_txt%TYPE;
    l_v_email_footer tb_m_system.system_value_txt%TYPE;
    l_v_email_body VARCHAR2(32767);

    l_v_inv_no_unpacked tb_r_sd_invoice.inv_no%TYPE;
    l_d_inv_dt_unpacked tb_r_sd_invoice.inv_dt%TYPE;
    l_v_container_no_unpacked tb_r_sd_module.container_no%TYPE;
    l_v_module_no_unpacked tb_r_sd_module.module_no%TYPE;
    l_v_case_no_unpacked tb_r_sd_module.case_no%TYPE;
    l_v_lot_no_unpacked tb_r_sd_module.lot_no%TYPE;
    l_d_warehouse_dt_unpacked tb_r_sd_module.warehouse_arrival_dt%TYPE;
    l_d_unpacking_dt_unpacked tb_r_sd_module.unpacking_dt%TYPE;
    l_v_inv_no_yard tb_r_sd_invoice.inv_no%TYPE;
    l_d_inv_dt_yard tb_r_sd_invoice.inv_dt%TYPE;
    l_v_container_no_yard tb_r_sd_container.container_no%TYPE;
    l_d_yard_arrival_dt_yard tb_r_sd_container.yard_arrival_dt%TYPE;
    l_d_warehouse_arrival_dt_yard tb_r_sd_container.warehouse_arrival_dt%TYPE;

    l_n_temp PLS_INTEGER;
    l_d_temp DATE;

    /*Start: Add fid.teguh 20170802*/
    l_v_pib_status VARCHAR2(10) := 'BC 2.0'; 
    /*End: Add fid.teguh 20170802*/
    
    FUNCTION f_upd_r_import_decl_d(l_v_submission_no IN VARCHAR2,
                                   l_d_submission_dt IN DATE,
                                   l_n_submission_item_no IN NUMBER,
                                   l_v_paid_sts IN VARCHAR2,
                                   l_v_import_decl_no IN VARCHAR2,
                                   l_d_import_decl_dt IN DATE,
                                   l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE tb_r_import_decl_d
         SET import_decl_no = l_v_import_decl_no,
             import_decl_dt = l_d_import_decl_dt,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE
       WHERE submission_no = l_v_submission_no
         AND submission_dt = l_d_submission_dt
         AND submission_item_no = l_n_submission_item_no
         AND paid_sts = l_v_paid_sts;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_import_decl_d: ' || SQLERRM);
                     RETURN FALSE;

    END;

    FUNCTION f_upd_m_exc_rate(l_v_curr_cd IN VARCHAR2,
                              l_d_valid_from IN DATE,
                              l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE (SELECT a.valid_to,
                     a.rate_value,
                     a.curr_remark,
                     a.changed_by,
                     a.changed_dt,
                     b.valid_to new_valid_to,
                     b.rate_value new_rate_value,
                     b.curr_remark new_curr_remark
                FROM tb_m_exchange_rate a,
                     tb_t_exchange_rate b
               WHERE a.curr_cd = l_v_curr_cd
                 AND a.valid_fr = l_d_valid_from
                 AND a.curr_cd = b.curr_cd
                 AND a.valid_fr = b.valid_fr)
         SET valid_to = new_valid_to,
             rate_value = new_rate_value,
             curr_remark = new_curr_remark,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_m_exc_rate: ' || SQLERRM || ' for [Currency Code] = [' || l_v_curr_cd || '] [Valid From] = [' || l_d_valid_from || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_upd_r_sd_import_decl_d(l_v_bl_no IN VARCHAR2,
                                      l_d_bl_dt IN DATE,
                                      l_v_import_decl_no IN VARCHAR2,
                                      l_d_import_decl_dt IN DATE,
                                      l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE tb_r_import_decl_d a
         SET import_decl_no = l_v_import_decl_no,
             import_decl_dt = l_d_import_decl_dt,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE
       WHERE EXISTS
             (SELECT 1
                FROM tb_r_import_decl_h b
               WHERE b.bl_no = l_v_bl_no
                 AND b.bl_dt = l_d_bl_dt
                 AND a.bl_no = b.bl_no
                 AND a.bl_dt = b.bl_dt);

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_sd_import_decl_d: ' || SQLERRM || ' for [BL No] = [' || l_v_bl_no ||  '] [BL Date] = [' || l_d_bl_dt || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_upd_r_sd_inv_pxp(l_v_bl_no IN VARCHAR2,
                                l_d_bl_dt IN DATE,
                                l_n_cur_amount IN NUMBER,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE tb_r_sd_inv_pxp a
         SET exch_rate = l_n_cur_amount,
             /*
             Remarks: 8UA-B4-0023
             Time: 20-Apr-2010 by Henry Kusuma
             Was:
             id_tax_amount = id_tax_amount * l_n_cur_amount,
             va_tax_amount = va_tax_amount * l_n_cur_amount,
             lux_tax_amount = lux_tax_amount * l_n_cur_amount,
             inc_tax_amount = inc_tax_amount * l_n_cur_amount,
             */
             id_tax_amount = part_cif * (id_tax_tariff / 100) * l_n_cur_amount,
             va_tax_amount = part_cif * (va_tax_tariff / 100) * l_n_cur_amount,
             lux_tax_amount = part_cif * (lux_tax_tariff / 100) * l_n_cur_amount,
             inc_tax_amount = part_cif * (inc_tax_tariff / 100) * l_n_cur_amount,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE
       WHERE EXISTS
             (SELECT 1
                FROM tb_r_sd_invoice b
               WHERE b.bl_no = l_v_bl_no
                 AND b.bl_dt = l_d_bl_dt
                 AND b.confirm_sts = 'Y'
                 AND a.inv_no = b.inv_no
                 AND a.inv_dt = b.inv_dt);

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_sd_inv_pxp: ' || SQLERRM || ' for [BL No] = [' || l_v_bl_no ||  '] [BL Date] = [' || l_d_bl_dt || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_upd_r_sd_module(l_v_bl_no IN VARCHAR2,
                               l_d_bl_dt IN DATE,
                               l_v_mvt_cd IN VARCHAR2,
                               l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE tb_r_sd_module a
         SET mvt_cd = l_v_mvt_cd,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE
       WHERE EXISTS
             (SELECT 1
                FROM tb_r_sd_invoice b
               WHERE b.bl_no = l_v_bl_no
                 AND b.bl_dt = l_d_bl_dt
                 AND b.confirm_sts = 'Y'
                 AND a.inv_no = b.inv_no
                 AND a.inv_dt = b.inv_dt);

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_sd_container: ' || SQLERRM || ' for [BL No] = [' || l_v_bl_no ||  '] [BL Date] = [' || l_d_bl_dt || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_upd_r_sd_container(l_v_bl_no IN VARCHAR2,
                                  l_d_bl_dt IN DATE,
                                  l_v_mvt_cd IN VARCHAR2,
                                  l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE tb_r_sd_container a
         SET mvt_cd = l_v_mvt_cd,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE
       WHERE EXISTS
             (SELECT 1
                FROM tb_r_sd_invoice b
               WHERE b.bl_no = l_v_bl_no
                 AND b.bl_dt = l_d_bl_dt
                 AND b.confirm_sts = 'Y'
                 AND a.inv_no = b.inv_no
                 AND a.inv_dt = b.inv_dt);

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_sd_container: ' || SQLERRM || ' for [BL No] = [' || l_v_bl_no ||  '] [BL Date] = [' || l_d_bl_dt || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_upd_r_sd_invoice(l_v_bl_no IN VARCHAR2,
                                l_d_bl_dt IN DATE,
                                l_v_mvt_cd IN VARCHAR2,
                                l_d_gr_dt IN DATE,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE tb_r_sd_invoice
         SET mvt_cd = l_v_mvt_cd,
             --gr_dt = l_d_gr_dt, --CR, 07-05-2010
             --gr_dt_input = SYSDATE, --CR, 07-05-2010
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE
       WHERE bl_no = l_v_bl_no
         AND bl_dt = l_d_bl_dt
         AND confirm_sts = 'Y';

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_sd_invoice: ' || SQLERRM || ' for [BL No] = [' || l_v_bl_no ||  '] [BL Date] = [' || l_d_bl_dt || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_check_not_arrived_unpacked RETURN BOOLEAN IS

      l_n_count_inv_no NUMBER(1);

    BEGIN

      SELECT COUNT(a.inv_no)
        INTO l_n_count_inv_no
        FROM tb_r_sd_invoice a,
             tb_r_sd_container b,
             tb_r_sd_module c
       WHERE a.bl_no = l_v_bl_no
         AND a.bl_dt = l_d_bl_dt
         AND a.inv_no = b.inv_no
         AND a.inv_dt = b.inv_dt
         AND b.inv_no = c.inv_no
         AND b.inv_dt = c.inv_dt
         AND b.container_no = c.container_no
         AND (b.yard_arrival_sts = 'Y'
          OR  b.warehouse_arrival_sts = 'Y'
          OR  c.warehouse_arrival_sts = 'Y'
          OR  c.unpacking_sts = 'Y')
         AND rownum = 1;

      IF l_n_count_inv_no = 0 THEN
        RETURN TRUE;
      ELSE
        RETURN FALSE;
      END IF;

    END;

    FUNCTION f_upd_r_import_decl_h(l_v_submission_no IN VARCHAR2,
                                   l_d_submission_dt IN DATE,
                                   l_v_import_decl_no IN VARCHAR2,
                                   l_d_import_decl_dt IN DATE,
                                   l_v_sppb_no IN VARCHAR2,
                                   l_v_pib_response_no IN VARCHAR2,
                                   l_v_cust_clearance_by IN VARCHAR2,
                                   l_d_cust_clearance_dt IN DATE,
                                   l_v_cust_clearance_input_by IN VARCHAR2,
                                   l_v_cust_clearance_sts IN VARCHAR2,
                                   l_v_int_import_decl_sts IN VARCHAR2, --CR, added, 17-05-2010
                                   l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE tb_r_import_decl_h
         SET import_decl_no = l_v_import_decl_no,
             import_decl_dt = l_d_import_decl_dt,
             sppb_no = l_v_sppb_no,
             pib_response_no = l_v_pib_response_no,
             cust_clearance_by = l_v_cust_clearance_by,
             /*
             Remarks: Change Request, confirmed by FID) Melissa
             Time: 26-May-2010 by Henry Kusuma
             Was:
             cust_clearance_dt = l_d_cust_clearance_dt,
             */
             cust_clearance_dt = l_d_import_decl_dt,
             cust_clearance_input_by = l_v_cust_clearance_input_by,
             cust_clearance_sts = l_v_cust_clearance_sts,
             changed_by = g_rec_status.v_user_id,
             /*Start: Add fid.teguh 20170802*/
             pib_status = l_v_pib_status,
             /*End: Add fid.teguh 20170802*/
             changed_dt = SYSDATE
       WHERE submission_no = l_v_submission_no
         AND submission_dt = l_d_submission_dt
         AND int_import_decl_sts = l_v_int_import_decl_sts; --CR, added, 17-05-2010

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_import_decl_h: ' || SQLERRM || ' for [Submission No] = [' || l_v_submission_no || '] [Submission Date] = [' || l_d_submission_dt || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_upd_r_res_import_decl_d(l_v_submission_no IN VARCHAR2,
                                       l_d_submission_dt IN DATE,
                                       l_n_serial IN NUMBER,
                                       l_v_hs_no IN VARCHAR2,
                                       l_n_tariff_serial IN NUMBER,
                                       l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE (SELECT a.submission_car,
                     a.desc_of_goods,
                     a.merk,
                     a.tipe,
                     a.country_cd,
                     a.country_name,
                     a.part_fob,
                     a.part_cif,
                     a.measurement_cd,
                     a.measurement_desc,
                     a.part_qty,
                     a.id_tax_non_exemp_tariff,
                     a.id_tax_suspended_tariff,
                     a.id_tax_released_tariff,
                     a.id_tax_periodical_tariff,
                     a.id_tax_gov_borned_tariff,
                     a.id_tax_amt,
                     a.id_tax_ad_valorem,
                     a.va_tax_non_exemp_tariff,
                     a.va_tax_suspended_tariff,
                     a.va_tax_released_tariff,
                     a.va_tax_periodical_tariff,
                     a.va_tax_gov_borned_tariff,
                     a.va_tax_amt,
                     a.va_tax_ad_valorem,
                     a.lux_tax_non_exemp_tariff,
                     a.lux_tax_suspended_tariff,
                     a.lux_tax_released_tariff,
                     a.lux_tax_periodical_tariff,
                     a.lux_tax_gov_borned_tariff,
                     a.lux_tax_amt,
                     a.lux_tax_ad_valorem,
                     a.inc_tax_non_exemp_tariff,
                     a.inc_tax_suspended_tariff,
                     a.inc_tax_released_tariff,
                     a.inc_tax_periodical_tariff,
                     a.inc_tax_gov_borned_tariff,
                     a.inc_tax_amt,
                     a.inc_tax_ad_valorem,
                     a.changed_by,
                     a.changed_dt,
                     b.submission_car new_submission_car,
                     b.desc_of_goods new_desc_of_goods,
                     b.merk new_merk,
                     b.tipe new_tipe,
                     b.country_cd new_country_cd,
                     b.country_name new_country_name,
                     b.part_fob new_part_fob,
                     b.part_cif new_part_cif,
                     b.measurement_cd new_measurement_cd,
                     b.measurement_desc new_measurement_desc,
                     b.part_qty new_part_qty,
                     b.id_tax_non_exemp_tariff new_id_tax_non_exemp_tariff,
                     b.id_tax_suspended_tariff new_id_tax_suspended_tariff,
                     b.id_tax_released_tariff new_id_tax_released_tariff,
                     b.id_tax_periodical_tariff new_id_tax_periodical_tariff,
                     b.id_tax_gov_borned_tariff new_id_tax_gov_borned_tariff,
                     b.id_tax_amt new_id_tax_amt,
                     b.id_tax_ad_valorem new_id_tax_ad_valorem,
                     b.va_tax_non_exemp_tariff new_va_tax_non_exemp_tariff,
                     b.va_tax_suspended_tariff new_va_tax_suspended_tariff,
                     b.va_tax_released_tariff new_va_tax_released_tariff,
                     b.va_tax_periodical_tariff new_va_tax_periodical_tariff,
                     b.va_tax_gov_borned_tariff new_va_tax_gov_borned_tariff,
                     b.va_tax_amt new_va_tax_amt,
                     b.va_tax_ad_valorem new_va_tax_ad_valorem,
                     b.lux_tax_non_exemp_tariff new_lux_tax_non_exemp_tariff,
                     b.lux_tax_suspended_tariff new_lux_tax_suspended_tariff,
                     b.lux_tax_released_tariff new_lux_tax_released_tariff,
                     b.lux_tax_periodical_tariff new_lux_tax_periodical_tariff,
                     b.lux_tax_gov_borned_tariff new_lux_tax_gov_borned_tariff,
                     b.lux_tax_amt new_lux_tax_amt,
                     b.lux_tax_ad_valorem new_lux_tax_ad_valorem,
                     b.inc_tax_non_exemp_tariff new_inc_tax_non_exemp_tariff,
                     b.inc_tax_suspended_tariff new_inc_tax_suspended_tariff,
                     b.inc_tax_released_tariff new_inc_tax_released_tariff,
                     b.inc_tax_periodical_tariff new_inc_tax_periodical_tariff,
                     b.inc_tax_gov_borned_tariff new_inc_tax_gov_borned_tariff,
                     b.inc_tax_amt new_inc_tax_amt,
                     b.inc_tax_ad_valorem new_inc_tax_ad_valorem
                FROM tb_r_res_import_decl_d a,
                     tb_t_res_import_decl_d b
               WHERE a.submission_no = b.submission_no
                 AND a.submission_dt = b.submission_dt
                 AND a.serial = b.serial
                 AND a.hs_no = b.hs_no
                 AND a.tariff_serial = b.tariff_serial)
         SET submission_car = new_submission_car,
             desc_of_goods = new_desc_of_goods,
             merk = new_merk,
             tipe = new_tipe,
             country_cd = new_country_cd,
             country_name = new_country_name,
             part_fob = new_part_fob,
             part_cif = new_part_cif,
             measurement_cd = new_measurement_cd,
             measurement_desc = new_measurement_desc,
             part_qty = new_part_qty,
             id_tax_non_exemp_tariff = new_id_tax_non_exemp_tariff,
             id_tax_suspended_tariff = new_id_tax_suspended_tariff,
             id_tax_released_tariff = new_id_tax_released_tariff,
             id_tax_periodical_tariff = new_id_tax_periodical_tariff,
             id_tax_gov_borned_tariff = new_id_tax_gov_borned_tariff,
             id_tax_amt = new_id_tax_amt,
             id_tax_ad_valorem = new_id_tax_ad_valorem,
             va_tax_non_exemp_tariff = new_va_tax_non_exemp_tariff,
             va_tax_suspended_tariff = new_va_tax_suspended_tariff,
             va_tax_released_tariff = new_va_tax_released_tariff,
             va_tax_periodical_tariff = new_va_tax_periodical_tariff,
             va_tax_gov_borned_tariff = new_va_tax_gov_borned_tariff,
             va_tax_amt = new_va_tax_amt,
             va_tax_ad_valorem = new_va_tax_ad_valorem,
             lux_tax_non_exemp_tariff = new_lux_tax_non_exemp_tariff,
             lux_tax_suspended_tariff = new_lux_tax_suspended_tariff,
             lux_tax_released_tariff = new_lux_tax_released_tariff,
             lux_tax_periodical_tariff = new_lux_tax_periodical_tariff,
             lux_tax_gov_borned_tariff = new_lux_tax_gov_borned_tariff,
             lux_tax_amt = new_lux_tax_amt,
             lux_tax_ad_valorem = new_lux_tax_ad_valorem,
             inc_tax_non_exemp_tariff = new_inc_tax_non_exemp_tariff,
             inc_tax_suspended_tariff = new_inc_tax_suspended_tariff,
             inc_tax_released_tariff = new_inc_tax_released_tariff,
             inc_tax_periodical_tariff = new_inc_tax_periodical_tariff,
             inc_tax_gov_borned_tariff = new_inc_tax_gov_borned_tariff,
             inc_tax_amt = new_inc_tax_amt,
             inc_tax_ad_valorem = new_inc_tax_ad_valorem,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_res_import_decl_d: ' || SQLERRM || ' for [Submission No] = [' || l_v_submission_no ||  '] [Submission Date] = [' || l_d_submission_dt || '] [Serial] = [' || l_n_serial || '] [HS No] = [' || l_v_hs_no || '] [Tariff Serial] = [' || l_n_tariff_serial || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_upd_r_res_import_decl_h(l_v_submission_no IN VARCHAR2,
                                       l_d_submission_dt IN DATE,
                                       l_v_import_decl_no IN VARCHAR2,
                                       l_d_import_decl_dt IN DATE,
                                       l_v_bl_no IN VARCHAR2,
                                       l_d_bl_dt IN DATE,
                                       l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      FOR cur_t_res_import_decl_h IN (SELECT submission_car,
                                             submission_no,
                                             submission_dt,
                                             customs_office_cd,
                                             import_decl_no,
                                             import_decl_dt,
                                             bl_no,
                                             bl_dt,
                                             bc_1_1_cd,
                                             bc_1_1_no,
                                             bc_1_1_dt,
                                             bc_1_1_pos,
                                             bc_1_1_possub,
                                             bc_1_1_possubsub,
                                             supplier_name,
                                             supplier_addr,
                                             supplier_country,
                                             port_unloading_cd,
                                             port_unloading_desc,
                                             port_loading_cd,
                                             port_loading_desc,
                                             vessel_name,
                                             voyage_no,
                                             voyage_flag,
                                             eta,
                                             cur_cd,
                                             cur_desc,
                                             cur_amount,
                                             ttl_amount,
                                             ttl_freight,
                                             ttl_insurance,
                                             ttl_cif,
                                             ttl_case,
                                             ttl_qty,
                                             duty_facility,
                                             res_cd,
                                             res_doc_no,
                                             res_doc_dt,
                                             id_tax_non_exemp_sum,
                                             id_tax_suspended_sum,
                                             id_tax_released_sum,
                                             id_tax_periodical_sum,
                                             id_tax_gov_borned_sum,
                                             va_tax_non_exemp_sum,
                                             va_tax_suspended_sum,
                                             va_tax_released_sum,
                                             va_tax_periodical_sum,
                                             va_tax_gov_borned_sum,
                                             lux_tax_non_exemp_sum,
                                             lux_tax_suspended_sum,
                                             lux_tax_released_sum,
                                             lux_tax_periodical_sum,
                                             lux_tax_gov_borned_sum,
                                             inc_tax_non_exemp_sum,
                                             inc_tax_suspended_sum,
                                             inc_tax_released_sum,
                                             inc_tax_periodical_sum,
                                             inc_tax_gov_borned_sum
                                        FROM tb_t_res_import_decl_h
                                       WHERE submission_no = l_v_submission_no
                                         AND submission_dt = l_d_submission_dt
                                         AND import_decl_no = l_v_import_decl_no
                                         AND import_decl_dt = l_d_import_decl_dt
                                         AND bl_no = l_v_bl_no
                                         AND bl_dt = l_d_bl_dt) LOOP

        UPDATE tb_r_res_import_decl_h
           SET submission_car = cur_t_res_import_decl_h.submission_car,
               customs_office_cd = cur_t_res_import_decl_h.customs_office_cd,
               bc_1_1_cd = cur_t_res_import_decl_h.bc_1_1_cd,
               bc_1_1_no = cur_t_res_import_decl_h.bc_1_1_no,
               bc_1_1_dt = cur_t_res_import_decl_h.bc_1_1_dt,
               bc_1_1_pos = cur_t_res_import_decl_h.bc_1_1_pos,
               bc_1_1_possub = cur_t_res_import_decl_h.bc_1_1_possub,
               bc_1_1_possubsub = cur_t_res_import_decl_h.bc_1_1_possubsub,
               supplier_name = cur_t_res_import_decl_h.supplier_name,
               supplier_addr = cur_t_res_import_decl_h.supplier_addr,
               supplier_country = cur_t_res_import_decl_h.supplier_country,
               port_unloading_cd = cur_t_res_import_decl_h.port_unloading_cd,
               port_unloading_desc = cur_t_res_import_decl_h.port_unloading_desc,
               port_loading = cur_t_res_import_decl_h.port_loading_cd,
               port_loading_desc = cur_t_res_import_decl_h.port_loading_desc,
               vessel_name = cur_t_res_import_decl_h.vessel_name,
               voyage_no = cur_t_res_import_decl_h.voyage_no,
               voyage_flag = cur_t_res_import_decl_h.voyage_flag,
               eta = cur_t_res_import_decl_h.eta,
               cur_cd = cur_t_res_import_decl_h.cur_cd,
               cur_desc = cur_t_res_import_decl_h.cur_desc,
               cur_amount = cur_t_res_import_decl_h.cur_amount,
               ttl_amount = cur_t_res_import_decl_h.ttl_amount,
               ttl_freight = cur_t_res_import_decl_h.ttl_freight,
               ttl_insurance = cur_t_res_import_decl_h.ttl_insurance,
               ttl_cif = cur_t_res_import_decl_h.ttl_cif,
               ttl_case = cur_t_res_import_decl_h.ttl_case,
               ttl_qty = cur_t_res_import_decl_h.ttl_qty,
               duty_facility = cur_t_res_import_decl_h.duty_facility,
               res_cd = cur_t_res_import_decl_h.res_cd,
               res_doc_no = cur_t_res_import_decl_h.res_doc_no,
               res_doc_dt = cur_t_res_import_decl_h.res_doc_dt,
               id_tax_non_exemp_sum = cur_t_res_import_decl_h.id_tax_non_exemp_sum,
               id_tax_suspended_sum = cur_t_res_import_decl_h.id_tax_suspended_sum,
               id_tax_released_sum = cur_t_res_import_decl_h.id_tax_released_sum,
               id_tax_periodical_sum = cur_t_res_import_decl_h.id_tax_periodical_sum,
               id_tax_gov_borned_sum = cur_t_res_import_decl_h.id_tax_gov_borned_sum,
               va_tax_non_exemp_sum = cur_t_res_import_decl_h.va_tax_non_exemp_sum,
               va_tax_suspended_sum = cur_t_res_import_decl_h.va_tax_suspended_sum,
               va_tax_released_sum = cur_t_res_import_decl_h.va_tax_released_sum,
               va_tax_periodical_sum = cur_t_res_import_decl_h.va_tax_periodical_sum,
               va_tax_gov_borned_sum = cur_t_res_import_decl_h.va_tax_gov_borned_sum,
               lux_tax_non_exemp_sum = cur_t_res_import_decl_h.lux_tax_non_exemp_sum,
               lux_tax_suspended_sum = cur_t_res_import_decl_h.lux_tax_suspended_sum,
               lux_tax_released_sum = cur_t_res_import_decl_h.lux_tax_released_sum,
               lux_tax_periodical_sum = cur_t_res_import_decl_h.lux_tax_periodical_sum,
               lux_tax_gov_borned_sum = cur_t_res_import_decl_h.lux_tax_gov_borned_sum,
               inc_tax_non_exemp_sum = cur_t_res_import_decl_h.inc_tax_non_exemp_sum,
               inc_tax_suspended_sum = cur_t_res_import_decl_h.inc_tax_suspended_sum,
               inc_tax_released_sum = cur_t_res_import_decl_h.inc_tax_released_sum,
               inc_tax_periodical_sum = cur_t_res_import_decl_h.inc_tax_periodical_sum,
               inc_tax_gov_borned_sum = cur_t_res_import_decl_h.inc_tax_gov_borned_sum,
               changed_by = g_rec_status.v_user_id,
               changed_dt = SYSDATE
         WHERE submission_no = cur_t_res_import_decl_h.submission_no
           AND submission_dt = cur_t_res_import_decl_h.submission_dt
           AND import_decl_no = cur_t_res_import_decl_h.import_decl_no
           AND import_decl_dt = cur_t_res_import_decl_h.import_decl_dt
           AND bl_no = cur_t_res_import_decl_h.bl_no
           AND bl_dt = cur_t_res_import_decl_h.bl_dt;

      END LOOP;

      /*
      Remarks: Need to change the update process due its possibly to have error
      Time: 3-Jun-2010 by Henry Kusuma
      Was;
      UPDATE (SELECT a.submission_car,
                     a.customs_office_cd,
                     a.bc_1_1_cd,
                     a.bc_1_1_no,
                     a.bc_1_1_dt,
                     a.bc_1_1_pos,
                     a.bc_1_1_possub,
                     a.bc_1_1_possubsub,
                     a.supplier_name,
                     a.supplier_addr,
                     a.supplier_country,
                     a.port_unloading_cd,
                     a.port_unloading_desc,
                     a.port_loading,
                     a.port_loading_desc,
                     a.vessel_name,
                     a.voyage_no,
                     a.voyage_flag,
                     a.eta,
                     a.cur_cd,
                     a.cur_desc,
                     a.cur_amount,
                     a.ttl_amount,
                     a.ttl_freight,
                     a.ttl_insurance,
                     a.ttl_cif,
                     a.ttl_case,
                     a.ttl_qty,
                     a.duty_facility,
                     a.res_cd,
                     a.res_doc_no,
                     a.res_doc_dt,
                     a.id_tax_non_exemp_sum,
                     a.id_tax_suspended_sum,
                     a.id_tax_released_sum,
                     a.id_tax_periodical_sum,
                     a.id_tax_gov_borned_sum,
                     a.va_tax_non_exemp_sum,
                     a.va_tax_suspended_sum,
                     a.va_tax_released_sum,
                     a.va_tax_periodical_sum,
                     a.va_tax_gov_borned_sum,
                     a.lux_tax_non_exemp_sum,
                     a.lux_tax_suspended_sum,
                     a.lux_tax_released_sum,
                     a.lux_tax_periodical_sum,
                     a.lux_tax_gov_borned_sum,
                     a.inc_tax_non_exemp_sum,
                     a.inc_tax_suspended_sum,
                     a.inc_tax_released_sum,
                     a.inc_tax_periodical_sum,
                     a.inc_tax_gov_borned_sum,
                     a.changed_by,
                     a.changed_dt,
                     b.submission_car new_submission_car,
                     b.customs_office_cd new_customs_office_cd,
                     b.bc_1_1_cd new_bc_1_1_cd,
                     b.bc_1_1_no new_bc_1_1_no,
                     b.bc_1_1_dt new_bc_1_1_dt,
                     b.bc_1_1_pos new_bc_1_1_pos,
                     b.bc_1_1_possub new_bc_1_1_possub,
                     b.bc_1_1_possubsub new_bc_1_1_possubsub,
                     b.supplier_name new_supplier_name,
                     b.supplier_addr new_supplier_addr,
                     b.supplier_country new_supplier_country,
                     b.port_unloading_cd new_port_unloading_cd,
                     b.port_unloading_desc new_port_unloading_desc,
                     --b.port_loading new_port_loading,
                     b.port_loading_desc new_port_loading_desc,
                     b.vessel_name new_vessel_name,
                     b.voyage_no new_voyage_no,
                     b.voyage_flag new_voyage_flag,
                     b.eta new_eta,
                     b.cur_cd new_cur_cd,
                     b.cur_desc new_cur_desc,
                     b.cur_amount new_cur_amount,
                     b.ttl_amount new_ttl_amount,
                     b.ttl_freight new_ttl_freight,
                     b.ttl_insurance new_ttl_insurance,
                     b.ttl_cif new_ttl_cif,
                     b.ttl_case new_ttl_case,
                     b.ttl_qty new_ttl_qty,
                     b.duty_facility new_duty_facility,
                     b.res_cd new_res_cd,
                     b.res_doc_no new_res_doc_no,
                     b.res_doc_dt new_res_doc_dt,
                     b.id_tax_non_exemp_sum new_id_tax_non_exemp_sum,
                     b.id_tax_suspended_sum new_id_tax_suspended_sum,
                     b.id_tax_released_sum new_id_tax_released_sum,
                     b.id_tax_periodical_sum new_id_tax_periodical_sum,
                     b.id_tax_gov_borned_sum new_id_tax_gov_borned_sum,
                     b.va_tax_non_exemp_sum new_va_tax_non_exemp_sum,
                     b.va_tax_suspended_sum new_va_tax_suspended_sum,
                     b.va_tax_released_sum new_va_tax_released_sum,
                     b.va_tax_periodical_sum new_va_tax_periodical_sum,
                     b.va_tax_gov_borned_sum new_va_tax_gov_borned_sum,
                     b.lux_tax_non_exemp_sum new_lux_tax_non_exemp_sum,
                     b.lux_tax_suspended_sum new_lux_tax_suspended_sum,
                     b.lux_tax_released_sum new_lux_tax_released_sum,
                     b.lux_tax_periodical_sum new_lux_tax_periodical_sum,
                     b.lux_tax_gov_borned_sum new_lux_tax_gov_borned_sum,
                     b.inc_tax_non_exemp_sum new_inc_tax_non_exemp_sum,
                     b.inc_tax_suspended_sum new_inc_tax_suspended_sum,
                     b.inc_tax_released_sum new_inc_tax_released_sum,
                     b.inc_tax_periodical_sum new_inc_tax_periodical_sum,
                     b.inc_tax_gov_borned_sum new_inc_tax_gov_borned_sum
                FROM tb_r_res_import_decl_h a,
                     tb_t_res_import_decl_h b
               WHERE a.submission_no = l_v_submission_no
                 AND a.submission_dt = l_d_submission_dt
                 AND a.import_decl_no = l_v_import_decl_no
                 AND a.import_decl_dt = l_d_import_decl_dt
                 AND a.bl_no = l_v_bl_no
                 AND a.bl_dt = l_d_bl_dt
                 AND a.submission_no = b.submission_no
                 AND a.submission_dt = b.submission_dt
                 \* remarked by iwang 8UA-B4-0040 #20100527
                 AND a.import_decl_no = b.import_decl_no
                 AND a.import_decl_dt = b.import_decl_dt*\
                 AND a.bl_no = b.bl_no
                 AND a.bl_dt = b.bl_dt)
         SET submission_car = new_submission_car,
             customs_office_cd = new_customs_office_cd,
             bc_1_1_cd = new_bc_1_1_cd,
             bc_1_1_no = new_bc_1_1_no,
             bc_1_1_dt = new_bc_1_1_dt,
             bc_1_1_pos = new_bc_1_1_pos,
             bc_1_1_possub = new_bc_1_1_possub,
             bc_1_1_possubsub = new_bc_1_1_possubsub,
             supplier_name = new_supplier_name,
             supplier_addr = new_supplier_addr,
             supplier_country = new_supplier_country,
             port_unloading_cd = new_port_unloading_cd,
             port_unloading_desc = new_port_unloading_desc,
             --port_loading = new_port_loading,
             port_loading_desc = new_port_loading_desc,
             vessel_name = new_vessel_name,
             voyage_no = new_voyage_no,
             voyage_flag = new_voyage_flag,
             eta = new_eta,
             cur_cd = new_cur_cd,
             cur_desc = new_cur_desc,
             cur_amount = new_cur_amount,
             ttl_amount = new_ttl_amount,
             ttl_freight = new_ttl_freight,
             ttl_insurance = new_ttl_insurance,
             ttl_cif = new_ttl_cif,
             ttl_case = new_ttl_case,
             ttl_qty = new_ttl_qty,
             duty_facility = new_duty_facility,
             res_cd = new_res_cd,
             res_doc_no = new_res_doc_no,
             res_doc_dt = new_res_doc_dt,
             id_tax_non_exemp_sum = new_id_tax_non_exemp_sum,
             id_tax_suspended_sum = new_id_tax_suspended_sum,
             id_tax_released_sum = new_id_tax_released_sum,
             id_tax_periodical_sum = new_id_tax_periodical_sum,
             id_tax_gov_borned_sum = new_id_tax_gov_borned_sum,
             va_tax_non_exemp_sum = new_va_tax_non_exemp_sum,
             va_tax_suspended_sum = new_va_tax_suspended_sum,
             va_tax_released_sum = new_va_tax_released_sum,
             va_tax_periodical_sum = new_va_tax_periodical_sum,
             va_tax_gov_borned_sum = new_va_tax_gov_borned_sum,
             lux_tax_non_exemp_sum = new_lux_tax_non_exemp_sum,
             lux_tax_suspended_sum = new_lux_tax_suspended_sum,
             lux_tax_released_sum = new_lux_tax_released_sum,
             lux_tax_periodical_sum = new_lux_tax_periodical_sum,
             lux_tax_gov_borned_sum = new_lux_tax_gov_borned_sum,
             inc_tax_non_exemp_sum = new_inc_tax_non_exemp_sum,
             inc_tax_suspended_sum = new_inc_tax_suspended_sum,
             inc_tax_released_sum = new_inc_tax_released_sum,
             inc_tax_periodical_sum = new_inc_tax_periodical_sum,
             inc_tax_gov_borned_sum = new_inc_tax_gov_borned_sum,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE;
      */

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_res_import_decl_h: ' || SQLERRM || ' for [Submission No] = [' || l_v_submission_no || '] [Submission Date] = [' || l_d_submission_dt || '] [Import Declaration No] = [' || l_v_import_decl_no || '] [Import Declaration Date] = [' || l_d_import_decl_dt || '] [BL No] = [' || l_v_bl_no || '] [BL Date] = [' || l_d_bl_dt || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_upd_r_res_pibfas(l_v_car IN VARCHAR2,
                                l_v_serial IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE (SELECT a.kdfasbm,
                     a.fasbm,
                     a.kdfascuk,
                     a.fascuk,
                     a.kdfasppn,
                     a.fasppn,
                     a.kdfaspph,
                     a.faspph,
                     a.kdfaspbm,
                     a.faspbm,
                     a.kdfasbmad,
                    a.fasbmad,
                    a.bmads,
                    a.kdfasbmtp,
                    a.fasbmtp,
                    a.bmtps,
                    a.kdfasbmim,
                    a.fasbmim,
                    a.bmims,
                    a.kdfasbmpb,
                    a.fasbmpb,
                    a.bmpbs,
                     a.changed_by,
                     a.changed_dt,
                     b.kdfasbm new_kdfasbm,
                     b.fasbm new_fasbm,
                     b.kdfascuk new_kdfascuk,
                     b.fascuk new_fascuk,
                     b.kdfasppn new_kdfasppn,
                     b.fasppn new_fasppn,
                     b.kdfaspph new_kdfaspph,
                     b.faspph new_faspph,
                     b.kdfaspbm new_kdfaspbm,
                     b.faspbm new_faspbm,
                     b.kdfasbmad new_kdfasbmad,
                    b.fasbmad new_fasbmad,
                    b.bmads new_bmads,
                    b.kdfasbmtp new_kdfasbmtp,
                    b.fasbmtp new_fasbmtp,
                    b.bmtps new_bmtps,
                    b.kdfasbmim new_kdfasbmim,
                    b.fasbmim new_fasbmim,
                    b.bmims new_bmims,
                    b.kdfasbmpb new_kdfasbmpb,
                    b.fasbmpb new_fasbmpb,
                    b.bmpbs new_bmpbs
                FROM tb_r_res_pibfas a,
                     tb_t_res_pibfas b
               WHERE a.car = l_v_car
                 AND a.serial = l_v_serial
                 AND a.car = b.car
                 AND a.serial = b.serial)
         SET kdfasbm = new_kdfasbm,
             fasbm = new_fasbm,
             kdfascuk = new_kdfascuk,
             fascuk = new_fascuk,
             kdfasppn = new_kdfasppn,
             fasppn = new_fasppn,
             kdfaspph = new_kdfaspph,
             faspph = new_faspph,
             kdfaspbm = new_kdfaspbm,
             faspbm = new_faspbm,
             kdfasbmad = new_kdfasbmad,
              fasbmad = new_fasbmad,
              bmads = new_bmads,
              kdfasbmtp = new_kdfasbmtp,
              fasbmtp = new_fasbmtp,
              bmtps = new_bmtps,
              kdfasbmim = new_kdfasbmim,
              fasbmim = new_fasbmim,
              bmims = new_bmims,
              kdfasbmpb = new_kdfasbmpb,
              fasbmpb = new_fasbmpb,
              bmpbs = new_bmpbs,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_res_pibfas: ' || SQLERRM || ' for [CAR] = [' || l_v_car || '] [SERIAL] = [' || l_v_serial || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_upd_r_res_pibpgt(l_v_car IN VARCHAR2,
                                l_v_kdbeban IN VARCHAR2,
                                l_v_kdfasil IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE (SELECT a.nilbeban,
                     a.changed_by,
                     a.changed_dt,
                     b.nilbeban new_nilbeban,
                     b.npwp new_npwp
                FROM tb_r_res_pibpgt a,
                     tb_t_res_pibpgt b
               WHERE a.car = l_v_car
                 AND a.kdbeban = l_v_kdbeban
                 AND a.kdfasil = l_v_kdfasil
                 AND a.car = b.car
                 AND a.kdbeban = b.kdbeban
                 AND a.kdfasil = b.kdfasil)
         SET nilbeban = new_nilbeban,
             npwp = new_npwp,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_res_pibpgt: ' || SQLERRM || ' for [CAR] = [' || l_v_car || '] [KDBEBAN] = [' || l_v_kdbeban || '] [KDFASIL] = [' || l_v_kdfasil || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_upd_r_res_pibres(l_v_car IN VARCHAR2,
                                l_v_reskd IN VARCHAR2,
                                l_d_restg IN DATE,
                                l_v_reswk IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE (SELECT a.dokresno,
                     a.dokrestg,
                     a.kpbc,
                     a.pibno,
                     a.pibtg,
                     a.kdgudang,
                     a.pejabat1,
                     a.nip1,
                     a.jabatan1,
                     a.pejabat2,
                     a.nip2,
                     a.jatuhtempo,
                     a.komtg,
                     a.komwk,
                     a.deskripsi,
                     a.dibaca,
                     a.jmkemas,
                      a.nokemas,
                      a.npwpimp,
                      a.namaimp,
                      a.alamatimp,
                      a.idppjk,
                      a.namappjk,
                      a.alamatppjk,
                      a.kodebill,
                      a.tanggalbill,
                      a.tanggaljttempo,
                      a.tanggalaju,
                      a.totalbayar,
                      a.terbilang,
                     a.changed_by,
                     a.changed_dt,
                     b.dokresno new_dokresno,
                     b.dokrestg new_dokrestg,
                     b.kpbc new_kpbc,
                     b.pibno new_pibno,
                     b.pibtg new_pibtg,
                     b.kdgudang new_kdgudang,
                     b.pejabat1 new_pejabat1,
                     b.nip1 new_nip1,
                     b.jabatan1 new_jabatan1,
                     b.pejabat2 new_pejabat2,
                     b.nip2 new_nip2,
                     b.jatuhtempo new_jatuhtempo,
                     b.komtg new_komtg,
                     b.komwk new_komwk,
                     b.deskripsi new_deskripsi,
                     b.dibaca new_dibaca,
                     b.jmkemas new_jmkemas,
                      b.nokemas new_nokemas,
                      b.npwpimp new_npwpimp,
                      b.namaimp new_namaimp,
                      b.alamatimp new_alamatimp,
                      b.idppjk new_idppjk,
                      b.namappjk new_namappjk,
                      b.alamatppjk new_alamatppjk,
                      b.kodebill new_kodebill,
                      b.tanggalbill new_tanggalbill,
                      b.tanggaljttempo new_tanggaljttempo,
                      b.tanggalaju new_tanggalaju,
                      b.totalbayar new_totalbayar,
                      b.terbilang new_terbilang
                FROM tb_r_res_pibres a,
                     tb_t_res_pibres b
               WHERE a.car = l_v_car
                 AND a.reskd = l_v_reskd
                 AND a.restg = l_d_restg
                 AND a.reswk = l_v_reswk
                 AND a.car = b.car
                 AND a.reskd = b.reskd
                 AND a.restg = b.restg
                 AND a.reswk = b.reswk)
         SET dokresno = new_dokresno,
             dokrestg = new_dokrestg,
             kpbc = new_kpbc,
             pibno = new_pibno,
             pibtg = new_pibtg,
             kdgudang = new_kdgudang,
             pejabat1 = new_pejabat1,
             nip1 = new_nip1,
             jabatan1 = new_jabatan1,
             pejabat2 = new_pejabat2,
             nip2 = new_nip2,
             jatuhtempo = new_jatuhtempo,
             komtg = new_komtg,
             komwk = new_komwk,
             deskripsi = new_deskripsi,
             dibaca = new_dibaca,
             jmkemas = new_jmkemas,
              nokemas = new_nokemas,
              npwpimp = new_npwpimp,
              namaimp = new_namaimp,
              alamatimp = new_alamatimp,
              idppjk = new_idppjk,
              namappjk = new_namappjk,
              alamatppjk = new_alamatppjk,
              kodebill = new_kodebill,
              tanggalbill = new_tanggalbill,
              tanggaljttempo = new_tanggaljttempo,
              tanggalaju = new_tanggalaju,
              totalbayar = new_totalbayar,
              terbilang = new_terbilang,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_res_pibres: ' || SQLERRM || ' for [CAR] = [' || l_v_car || '] [RESKD] = [' || l_v_reskd || '] [RESTG] = [' || l_d_restg || '] [RESWK] = [' || l_v_reswk || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_upd_r_res_pibcon(l_v_car IN VARCHAR2,
                                l_v_contno IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE (SELECT a.contukur,
                     a.contipe,
                     a.changed_by,
                     a.changed_dt,
                     b.contukur new_contukur,
                     b.contipe new_contipe
                FROM tb_r_res_pibcon a,
                     tb_t_res_pibcon b
               WHERE a.car = l_v_car
                 AND a.contno = l_v_contno
                 AND a.car = b.car
                 AND a.contno = b.contno)
         SET contukur = new_contukur,
             contipe = new_contipe,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_res_pibcon: ' || SQLERRM || ' for [CAR] = [' || l_v_car || '] [Container No] = [' || l_v_contno || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_upd_r_res_pibdok(l_v_car IN VARCHAR2,
                                l_v_dokkd IN VARCHAR2,
                                l_v_dokno IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE (SELECT a.doktg,
                    a.dokinst,
                    a.nourut,
                    a.kdgroupdok,
                    a.changed_by,
                    a.changed_dt,
                    b.doktg new_doktg,
                    b.dokinst new_dokinst,
                    b.nourut new_nourut,
                    b.kdgroupdok new_kdgroupdok

                FROM tb_r_res_pibdok a,
                     tb_t_res_pibdok b
               WHERE a.car = l_v_car
                 AND a.dokkd = l_v_dokkd
                 AND a.dokno = l_v_dokno
                 AND a.car = b.car
                 AND a.dokkd = b.dokkd
                 AND a.dokno = b.dokno)
         SET doktg = new_doktg,
              dokinst = new_dokinst,
              nourut = new_nourut,
              kdgroupdok = new_kdgroupdok,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_res_pibdok: ' || SQLERRM || ' for [CAR] = [' || l_v_car || '] [Doc Cd] = [' || l_v_dokkd || '] [Doc No] = [' || l_v_dokno || ']');
                     RETURN FALSE;

    END;
    
    FUNCTION f_upd_r_res_pibdtldok(l_v_car IN VARCHAR2,
                                l_v_dokkd IN VARCHAR2,
                                l_v_dokno IN VARCHAR2,
                                l_v_serial IN NUMBER,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE (SELECT a.kdfasdtl,
                    a.nourut,
                    a.doktg,
                    a.changed_by,
                    a.changed_dt,
                    b.kdfasdtl new_kdfasdtl,
                    b.nourut new_nourut,
                    b.doktg new_doktg
                FROM tb_r_res_pibdtldok a,
                     tb_t_res_pibdtldok b
               WHERE a.car = l_v_car
                 AND a.dokkd = l_v_dokkd
                 AND a.dokno = l_v_dokno
                 AND a.serial = l_v_serial
                 AND a.car = b.car
                 AND a.dokkd = b.dokkd
                 AND a.dokno = b.dokno
                 AND a.serial = b.serial)
         SET kdfasdtl = new_kdfasdtl,
              nourut = new_nourut,
              doktg = new_doktg,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_res_pibdtldok: ' || SQLERRM || ' for [CAR] = [' || l_v_car || '] [Doc Cd] = [' || l_v_dokkd || '] [Doc No] = [' || l_v_dokno || ']  [Serial] = [' || l_v_serial || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_upd_r_res_pibdtlvd(l_v_car IN VARCHAR2,
                                l_v_serial IN NUMBER,
                                l_v_jenis IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE (SELECT a.nilai,
                     a.tgjatuhtempo,
                    a.changed_by,
                    a.changed_dt,
                    b.nilai new_nilai,
                    b.tgjatuhtempo new_tgjatuhtempo
                FROM tb_r_res_pibdtlvd a,
                     tb_t_res_pibdtlvd b
               WHERE a.car = l_v_car
                 AND a.serial = l_v_serial
                 AND a.jenis = l_v_jenis
                 AND a.car = b.car
                 AND a.serial = b.serial
                 AND a.jenis = b.jenis)
         SET   nilai = new_nilai,
               tgjatuhtempo = new_tgjatuhtempo,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_res_pibdtlvd: ' || SQLERRM || ' for [CAR] = [' || l_v_car || '] [Serial] = [' || l_v_serial || '] [Jenis] = [' || l_v_jenis || ']');
                     RETURN FALSE;

    END;
    
    FUNCTION f_upd_r_res_pibkendaraan(l_v_car IN VARCHAR2,
                                l_v_serial IN NUMBER,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE (SELECT a.norangka,
                    a.nomesin,
                    a.silinder,
                    a.tahun,
                    a.changed_by,
                    a.changed_dt,
                    b.norangka new_norangka,
                    b.nomesin new_nomesin,
                    b.silinder new_silinder,
                    b.tahun new_tahun

                FROM tb_r_res_pibkendaraan a,
                     tb_t_res_pibkendaraan b
               WHERE a.car = l_v_car
                 AND a.serial = l_v_serial
                 AND a.car = b.car
                 AND a.serial = b.serial)
         SET  norangka = new_norangka,
              nomesin = new_nomesin,
              silinder = new_silinder,
              tahun = new_tahun,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_res_pibdtlkendaraan: ' || SQLERRM || ' for [CAR] = [' || l_v_car || '] [Serial] = [' || l_v_serial || ']');
                     RETURN FALSE;

    END;
    
    FUNCTION f_upd_r_res_pibconr(l_v_car IN VARCHAR2,
                                l_v_reskd IN VARCHAR2,
                                l_v_contno IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE (SELECT a.contukur,
                     a.conttipe,
                     a.changed_by,
                     a.changed_dt,
                     b.contukur new_contukur,
                     b.conttipe new_contipe
                FROM tb_r_res_pibconr a,
                     tb_t_res_pibconr b
               WHERE a.car = l_v_car
                 AND a.reskd = l_v_reskd
                 AND a.contno = l_v_contno
                 AND a.car = b.car
                 AND a.reskd = b.reskd
                 AND a.contno = b.contno)
         SET contukur = new_contukur,
             conttipe = new_conttipe,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_res_pibconr: ' || SQLERRM || ' for [CAR] = [' || l_v_car || '] [Response Code] = [' || l_v_reskd || '] [Container No] = [' || l_v_contno || ']');
                     RETURN FALSE;

    END;
    
    FUNCTION f_upd_r_res_pibkms(l_v_car IN VARCHAR2,
                                l_v_jnkemas IN VARCHAR2,
                                l_v_merkkemas IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE (SELECT a.jmkemas,
                     a.changed_by,
                     a.changed_dt,
                     b.jmkemas new_jmkemas
                FROM tb_r_res_pibkms a,
                     tb_t_res_pibkms b
               WHERE a.car = l_v_car
                 AND a.jnkemas = l_v_jnkemas
                 AND a.merkkemas = l_v_merkkemas
                 AND a.car = b.car
                 AND a.jnkemas = b.jnkemas
                 AND a.merkkemas = b.merkkemas)
         SET contukur = new_contukur,
             conttipe = new_conttipe,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_res_pibkms: ' || SQLERRM || ' for [CAR] = [' || l_v_car || '] [Jenis Kemasan] = [' || l_v_jnkemas || '] [Merk Kemasan] = [' || l_v_merkkemas || ']');
                     RETURN FALSE;

    END;
    
    FUNCTION f_upd_r_res_pibnpt(l_v_car IN VARCHAR2,
                                l_v_reskd IN VARCHAR2,
                                l_v_restg IN VARCHAR2,
                                l_v_reswk IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE (SELECT a.bm_asal,
                    a.cuk_asal,
                    a.ppn_asal,
                    a.ppnbm_asal,
                    a.pph_asal,
                    a.bmbyr,
                    a.cukbyr,
                    a.ppnbyr,
                    a.ppnbmbyr,
                    a.pphbyr,
                    a.denda,
                    a.bm_kurang,
                    a.cuk_kurang,
                    a.ppn_kurang,
                    a.ppnbm_kurang,
                    a.pph_kurang,
                    a.bm_lebih,
                    a.cuk_lebih,
                    a.ppn_lebih,
                    a.ppnbm_lebih,
                    a.pph_lebih,
                    a.total_kurang,
                    a.total_lebih,
                    a.s_jnsbrg,
                    a.s_jmlbrg,
                    a.s_tarif,
                    a.s_nilpab,
                    a.bmad_asal,
                    a.bmadbyr,
                    a.bmad_kurang,
                    a.bmad_lebih,
                    a.bmi_asal,
                    a.bmibyr,
                    a.bmi_kurang,
                    a.bmi_lebih,
                    a.bmtp_asal,
                    a.bmtpbyr,
                    a.bmtp_kurang,
                    a.bmtp_lebih,
                    a.bmads_asal,
                    a.bmadsbyr,
                    a.bmads_kurang,
                    a.bmads_lebih,
                    a.bmis_asal,
                    a.bmisbyr,
                    a.bmis_kurang,
                    a.bmis_lebih,
                    a.bmtps_asal,
                    a.bmtpsbyr,
                    a.bmtps_kurang,
                    a.bmtps_lebih,
                    a.bmkt_asal,
                    a.bmkt,
                    a.bmkt_kurang,
                    a.bmkt_lebih,
                    b.bm_asal new_bm_asal,
                    b.cuk_asal new_cuk_asal,
                    b.ppn_asal new_ppn_asal,
                    b.ppnbm_asal new_ppnbm_asal,
                    b.pph_asal new_pph_asal,
                    b.bmbyr new_bmbyr,
                    b.cukbyr new_cukbyr,
                    b.ppnbyr new_ppnbyr,
                    b.ppnbmbyr new_ppnbmbyr,
                    b.pphbyr new_pphbyr,
                    b.denda new_denda,
                    b.bm_kurang new_bm_kurang,
                    b.cuk_kurang new_cuk_kurang,
                    b.ppn_kurang new_ppn_kurang,
                    b.ppnbm_kurang new_ppnbm_kurang,
                    b.pph_kurang new_pph_kurang,
                    b.bm_lebih new_bm_lebih,
                    b.cuk_lebih new_cuk_lebih,
                    b.ppn_lebih new_ppn_lebih,
                    b.ppnbm_lebih new_ppnbm_lebih,
                    b.pph_lebih new_pph_lebih,
                    b.total_kurang new_total_kurang,
                    b.total_lebih new_total_lebih,
                    b.s_jnsbrg new_s_jnsbrg,
                    b.s_jmlbrg new_s_jmlbrg,
                    b.s_tarif new_s_tarif,
                    b.s_nilpab new_s_nilpab,
                    b.bmad_asal new_bmad_asal,
                    b.bmadbyr new_bmadbyr,
                    b.bmad_kurang new_bmad_kurang,
                    b.bmad_lebih new_bmad_lebih,
                    b.bmi_asal new_bmi_asal,
                    b.bmibyr new_bmibyr,
                    b.bmi_kurang new_bmi_kurang,
                    b.bmi_lebih new_bmi_lebih,
                    b.bmtp_asal new_bmtp_asal,
                    b.bmtpbyr new_bmtpbyr,
                    b.bmtp_kurang new_bmtp_kurang,
                    b.bmtp_lebih new_bmtp_lebih,
                    b.bmads_asal new_bmads_asal,
                    b.bmadsbyr new_bmadsbyr,
                    b.bmads_kurang new_bmads_kurang,
                    b.bmads_lebih new_bmads_lebih,
                    b.bmis_asal new_bmis_asal,
                    b.bmisbyr new_bmisbyr,
                    b.bmis_kurang new_bmis_kurang,
                    b.bmis_lebih new_bmis_lebih,
                    b.bmtps_asal new_bmtps_asal,
                    b.bmtpsbyr new_bmtpsbyr,
                    b.bmtps_kurang new_bmtps_kurang,
                    b.bmtps_lebih new_bmtps_lebih,
                    b.bmkt_asal new_bmkt_asal,
                    b.bmkt new_bmkt,
                    b.bmkt_kurang new_bmkt_kurang,
                    b.bmkt_lebih new_bmkt_lebih,

                     a.changed_by,
                     a.changed_dt
                FROM tb_r_res_pibnpt a,
                     tb_t_res_pibnpt b
               WHERE a.car = l_v_car
                 AND a.reskd = l_v_reskd
                 AND a.restg = l_v_restg
                 AND a.reswk = l_v_reswk
                 AND a.car = b.car
                 AND a.reskd = b.reskd
                 AND a.restg = b.restg
                 AND a.reswk = b.reswk)
         SET bm_asal = new_bm_asal,
                cuk_asal = new_cuk_asal,
                ppn_asal = new_ppn_asal,
                ppnbm_asal = new_ppnbm_asal,
                pph_asal = new_pph_asal,
                bmbyr = new_bmbyr,
                cukbyr = new_cukbyr,
                ppnbyr = new_ppnbyr,
                ppnbmbyr = new_ppnbmbyr,
                pphbyr = new_pphbyr,
                denda = new_denda,
                bm_kurang = new_bm_kurang,
                cuk_kurang = new_cuk_kurang,
                ppn_kurang = new_ppn_kurang,
                ppnbm_kurang = new_ppnbm_kurang,
                pph_kurang = new_pph_kurang,
                bm_lebih = new_bm_lebih,
                cuk_lebih = new_cuk_lebih,
                ppn_lebih = new_ppn_lebih,
                ppnbm_lebih = new_ppnbm_lebih,
                pph_lebih = new_pph_lebih,
                total_kurang = new_total_kurang,
                total_lebih = new_total_lebih,
                s_jnsbrg = new_s_jnsbrg,
                s_jmlbrg = new_s_jmlbrg,
                s_tarif = new_s_tarif,
                s_nilpab = new_s_nilpab,
                bmad_asal = new_bmad_asal,
                bmadbyr = new_bmadbyr,
                bmad_kurang = new_bmad_kurang,
                bmad_lebih = new_bmad_lebih,
                bmi_asal = new_bmi_asal,
                bmibyr = new_bmibyr,
                bmi_kurang = new_bmi_kurang,
                bmi_lebih = new_bmi_lebih,
                bmtp_asal = new_bmtp_asal,
                bmtpbyr = new_bmtpbyr,
                bmtp_kurang = new_bmtp_kurang,
                bmtp_lebih = new_bmtp_lebih,
                bmads_asal = new_bmads_asal,
                bmadsbyr = new_bmadsbyr,
                bmads_kurang = new_bmads_kurang,
                bmads_lebih = new_bmads_lebih,
                bmis_asal = new_bmis_asal,
                bmisbyr = new_bmisbyr,
                bmis_kurang = new_bmis_kurang,
                bmis_lebih = new_bmis_lebih,
                bmtps_asal = new_bmtps_asal,
                bmtpsbyr = new_bmtpsbyr,
                bmtps_kurang = new_bmtps_kurang,
                bmtps_lebih = new_bmtps_lebih,
                bmkt_asal = new_bmkt_asal,
                bmkt = new_bmkt,
                bmkt_kurang = new_bmkt_kurang,
                bmkt_lebih = new_bmkt_lebih,

             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_res_pibkms: ' || SQLERRM || ' for [CAR] = [' || l_v_car || '] [Jenis Kemasan] = [' || l_v_jnkemas || '] [Merk Kemasan] = [' || l_v_merkkemas || ']');
                     RETURN FALSE;

    END;
    
    FUNCTION f_upd_r_res_pibtrf(l_v_car IN VARCHAR2,
                                l_v_nohs IN VARCHAR2,
                                l_v_seritrp IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE (SELECT a.process_id,
                     a.kdtrpbm,
                     a.kdsatbm,
                     a.trpbm,
                     a.kdcuk,
                     a.kdtrpcuk,
                     a.kdsatcuk,
                     a.trpcuk,
                     a.trpppn,
                     a.trppbm,
                     a.trppph,
                    a.kdtrpbmad,
                    a.trpbmad,
                    a.kdtrpbmtp,
                    a.trpbmtp,
                    a.kdtrpbmim,
                    a.trpbmim,
                    a.kdtrpbmpb,
                    a.trpbmpb,
                    a.kdcuksub,
                    a.hjecuk,
                    a.kdkmscuk,
                    a.isiperkmscuk,
                     a.changed_by,
                     a.changed_dt,
                     b.car new_car,
                     b.nohs new_nohs,
                     b.seritrp new_seritrp,
                     b.kdtrpbm new_kdtrpbm,
                     b.kdsatbm new_kdsatbm,
                     b.trpbm new_trpbm,
                     b.kdcuk new_kdcuk,
                     b.kdtrpcuk new_kdtrpcuk,
                     b.kdsatcuk new_kdsatcuk,
                     b.trpcuk new_trpcuk,
                     b.trpppn new_trpppn,
                     b.trppbm new_trppbm,
                     b.trppph new_trppph,
                    b.kdtrpbmad new_kdtrpbmad,
                    b.trpbmad new_trpbmad,
                    b.kdtrpbmtp new_kdtrpbmtp,
                    b.trpbmtp new_trpbmtp,
                    b.kdtrpbmim new_kdtrpbmim,
                    b.trpbmim new_trpbmim,
                    b.kdtrpbmpb new_kdtrpbmpb,
                    b.trpbmpb new_trpbmpb,
                    b.kdcuksub new_kdcuksub,
                    b.hjecuk new_hjecuk,
                    b.kdkmscuk new_kdkmscuk,
                    b.isiperkmscuk new_isiperkmscuk
                FROM tb_r_res_pibtrf a,
                     tb_t_res_pibtrf b
               WHERE a.car = l_v_car
                 AND a.nohs = l_v_nohs
                 AND a.seritrp = l_v_seritrp
                 AND a.car = b.car
                 AND a.nohs = b.nohs
                 AND a.seritrp = b.seritrp)
         SET process_id = g_rec_status.v_process_id,
             kdtrpbm = new_kdtrpbm,
             kdsatbm = new_kdsatbm,
             trpbm = new_trpbm,
             kdcuk = new_kdcuk,
             kdtrpcuk = new_kdtrpcuk,
             kdsatcuk = new_kdsatcuk,
             trpcuk = new_trpcuk,
             trpppn = new_trpppn,
             trppbm = new_trppbm,
             trppph = new_trppph,
              kdtrpbmad = new_kdtrpbmad,
              trpbmad = new_trpbmad,
              kdtrpbmtp = new_kdtrpbmtp,
              trpbmtp = new_trpbmtp,
              kdtrpbmim = new_kdtrpbmim,
              trpbmim = new_trpbmim,
              kdtrpbmpb = new_kdtrpbmpb,
              trpbmpb = new_trpbmpb,
              kdcuksub = new_kdcuksub,
              hjecuk = new_hjecuk,
              kdkmscuk = new_kdkmscuk,
              isiperkmscuk = new_isiperkmscuk,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_res_pibtrf: ' || SQLERRM || ' for [CAR] = [' || l_v_car || '] [NOHS] = [' || l_v_nohs || '] [SeriTRP] = [' || l_v_seritrp || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_upd_r_res_pibdtl(l_v_car IN VARCHAR2,
                                l_v_serial IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE (SELECT a.process_id,
                     a.nohs,
                     a.seritrp,
                     a.brgurai,
                     a.merk,
                     a.tipe,
                     a.spflain,
                     a.brgasal,
                     a.dnilinv,
                     a.dcif,
                     a.kdsat,
                     a.jmlsat,
                     a.kemasjn,
                     a.kemasjm,
                     a.satbmjm,
                     a.satcukjm,
                     a.nettodtl,
                     a.kdfasdtl,
                     a.dtlok,
                     a.flbarangbaru,
                    a.fllartas,
                    a.katlartas,
                    a.spektarif,
                    a.dnilcuk,
                    a.jmpc,
                    a.saldoawalpc,
                    a.saldoakhirpc,
                     a.changed_by,
                     a.changed_dt,
                     b.nohs new_nohs,
                     b.seritrp new_seritrp,
                     b.brgurai new_brgurai,
                     b.merk new_merk,
                     b.tipe new_tipe,
                     b.spflain new_spflain,
                     b.brgasal new_brgasal,
                     b.dnilinv new_dnilinv,
                     b.dcif new_dcif,
                     b.kdsat new_kdsat,
                     b.jmlsat new_jmlsat,
                     b.kemasjn new_kemasjn,
                     b.kemasjm new_kemasjm,
                     b.satbmjm new_satbmjm,
                     b.satcukjm new_satcukjm,
                     b.nettodtl new_nettodtl,
                     b.kdfasdtl new_kdfasdtl,
                     b.dtlok new_dtlok,
                     b.flbarangbaru new_flbarangbaru,
                      b.fllartas new_fllartas,
                      b.katlartas new_katlartas,
                      b.spektarif new_spektarif,
                      b.dnilcuk new_dnilcuk,
                      b.jmpc new_jmpc,
                      b.saldoawalpc new_saldoawalpc,
                      b.saldoakhirpc new_saldoakhirpc
                FROM tb_r_res_pibdtl a,
                     tb_t_res_pibdtl b
               WHERE a.car = l_v_car
                 AND a.serial = l_v_serial
                 AND a.car = b.car
                 AND a.serial = b.serial)
         SET process_id = g_rec_status.v_process_id,
             nohs = new_nohs,
             seritrp = new_seritrp,
             brgurai = new_brgurai,
             merk = new_merk,
             tipe = new_tipe,
             spflain = new_spflain,
             brgasal = new_brgasal,
             dnilinv = new_dnilinv,
             dcif = new_dcif,
             kdsat = new_kdsat,
             jmlsat = new_jmlsat,
             kemasjn = new_kemasjn,
             kemasjm = new_kemasjm,
             satbmjm = new_satbmjm,
             satcukjm = new_satcukjm,
             nettodtl = new_nettodtl,
             kdfasdtl = new_kdfasdtl,
             dtlok = new_dtlok,
             flbarangbaru = new_flbarangbaru,
            fllartas = new_fllartas,
            katlartas = new_katlartas,
            spektarif = new_spektarif,
            dnilcuk = new_dnilcuk,
            jmpc = new_jmpc,
            saldoawalpc = new_saldoawalpc,
            saldoakhirpc = new_saldoakhirpc,

             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_res_pibdtl: ' || SQLERRM || ' for [CAR] = [' || l_v_car || '] [Serial] = [' || l_v_serial || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_upd_r_res_import_decl_doc(l_v_submission_car IN VARCHAR2,
                                         l_v_submission_no IN VARCHAR2,
                                         l_d_submission_dt IN DATE,
                                         l_v_doc_no IN VARCHAR2,
                                         l_v_doc_cd IN VARCHAR2,
                                         l_v_doc_desc IN VARCHAR2,
                                         l_d_doc_dt IN DATE,
                                         l_v_doc_inst IN VARCHAR2,
                                         l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE tb_r_res_import_decl_doc
         SET process_id = g_rec_status.v_process_id,
             doc_cd = l_v_doc_cd,
             doc_desc = l_v_doc_desc,
             doc_dt = l_d_doc_dt,
             doc_inst = l_v_doc_inst,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE
       WHERE submission_car = l_v_submission_car
         AND submission_no = l_v_submission_no
         AND submission_dt = l_d_submission_dt
         AND doc_no = l_v_doc_no;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_res_import_decl_doc: ' || SQLERRM || ' for [Submission No] = [' || l_v_submission_no || '] [Submission Date] = [' || l_d_submission_dt || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_upd_r_res_pibhdr(l_v_car IN VARCHAR2,
                                l_v_kdkpbc IN VARCHAR2,
                                l_v_pibno IN VARCHAR2,
                                l_d_pibtg IN DATE,
                                l_v_jnpib IN VARCHAR2,
                                l_v_jnimp IN VARCHAR2,
                                l_n_jkwaktu IN NUMBER,
                                l_v_crbyr IN VARCHAR2,
                                l_v_doktupkd IN VARCHAR2,
                                l_v_doktupno IN VARCHAR2,
                                l_d_doktuptg IN DATE,
                                l_v_posno IN VARCHAR2,
                                l_v_possub IN VARCHAR2,
                                l_v_possubsub IN VARCHAR2,
                                l_v_impid IN VARCHAR2,
                                l_v_impnpwp IN VARCHAR2,
                                l_v_impnama IN VARCHAR2,
                                l_v_impalmt IN VARCHAR2,
                                l_v_apikd IN VARCHAR2,
                                l_v_apino IN VARCHAR2,
                                l_v_ppjknpwp IN VARCHAR2,
                                l_v_ppjknama IN VARCHAR2,
                                l_v_ppjkalmt IN VARCHAR2,
                                l_v_ppjkno IN VARCHAR2,
                                l_d_ppjktg IN DATE,
                                l_v_indid IN VARCHAR2,
                                l_v_indnpwp IN VARCHAR2,
                                l_v_indnama IN VARCHAR2,
                                l_v_indalmt IN VARCHAR2,
                                l_v_pasoknama IN VARCHAR2,
                                l_v_pasokalmt IN VARCHAR2,
                                l_v_pasokneg IN VARCHAR2,
                                l_v_pelbkr IN VARCHAR2,
                                l_v_pelmuat IN VARCHAR2,
                                l_v_peltransit IN VARCHAR2,
                                l_v_tmptbn IN VARCHAR2,
                                l_v_moda IN VARCHAR2,
                                l_v_angkutnama IN VARCHAR2,
                                l_v_angkutno IN VARCHAR2,
                                l_v_angkutfl IN VARCHAR2,
                                l_d_tgtiba IN DATE,
                                l_v_kdval IN VARCHAR2,
                                l_n_ndpbm IN NUMBER,
                                l_n_nilinv IN NUMBER,
                                l_n_freight IN NUMBER,
                                l_n_btambahan IN NUMBER,
                                l_n_diskon IN NUMBER,
                                l_v_kdass IN VARCHAR2,
                                l_n_asuransi IN NUMBER,
                                l_v_kdhrg IN VARCHAR2,
                                l_n_fob IN NUMBER,
                                l_n_cif IN NUMBER,
                                l_n_bruto IN NUMBER,
                                l_n_netto IN NUMBER,
                                l_n_jmcont IN NUMBER,
                                l_n_jmbrg IN NUMBER,
                                l_v_status IN VARCHAR2,
                                l_v_snrf IN VARCHAR2,
                                l_v_kdfas IN VARCHAR2,
                                l_v_lengkap IN VARCHAR2,
                                l_v_billnpwp in VARCHAR2,
                                l_v_billnama in VARCHAR2,
                                l_v_billalmt in VARCHAR2,
                                l_v_penjualnama in VARCHAR2,
                                l_v_penjualalmt in VARCHAR2,
                                l_v_penjualneg in VARCHAR2,
                                l_v_pernyataan in VARCHAR2,
                                l_v_jnstrans in VARCHAR2,
                                l_v_vd in VARCHAR2,
                                l_n_versimodul in NUMBER,
                                l_n_nilvd in NUMBER,

                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      UPDATE tb_r_res_pibhdr
         SET process_id = g_rec_status.v_process_id,
             kdkpbc = l_v_kdkpbc,
             pibno = l_v_pibno,
             pibtg = l_d_pibtg,
             jnpib = l_v_jnpib,
             jnimp = l_v_jnimp,
             jkwaktu = l_n_jkwaktu,
             crbyr = l_v_crbyr,
             doktupkd = l_v_doktupkd,
             doktupno = l_v_doktupno,
             doktuptg = l_d_doktuptg,
             posno = l_v_posno,
             possub = l_v_possub,
             possubsub = l_v_possubsub,
             impid = l_v_impid,
             impnpwp = l_v_impnpwp,
             impnama = l_v_impnama,
             impalmt = l_v_impalmt,
             apikd = l_v_apikd,
             apino = l_v_apino,
             ppjknpwp = l_v_ppjknpwp,
             ppjknama = l_v_ppjknama,
             ppjkalmt = l_v_ppjkalmt,
             ppjkno = l_v_ppjkno,
             ppjktg = l_d_ppjktg,
             indid = l_v_indid,
             indnpwp = l_v_indnpwp,
             indnama = l_v_indnama,
             indalmt = l_v_indalmt,
             pasoknama = l_v_pasoknama,
             pasokalmt = l_v_pasokalmt,
             pasokneg = l_v_pasokneg,
             pelbkr = l_v_pelbkr,
             pelmuat = l_v_pelmuat,
             peltransit = l_v_peltransit,
             tmptbn = l_v_tmptbn,
             moda = l_v_moda,
             angkutnama = l_v_angkutnama,
             angkutno = l_v_angkutno,
             angkutfl = l_v_angkutfl,
             tgtiba = l_d_tgtiba,
             kdval = l_v_kdval,
             ndpbm = l_n_ndpbm,
             nilinv = l_n_nilinv,
             freight = l_n_freight,
             btambahan = l_n_btambahan,
             diskon = l_n_diskon,
             kdass = l_v_kdass,
             asuransi = l_n_asuransi,
             kdhrg = l_v_kdhrg,
             fob = l_n_fob,
             cif = l_n_cif,
             bruto = l_n_bruto,
             netto = l_n_netto,
             jmcont = l_n_jmcont,
             jmbrg = l_n_jmbrg,
             status = l_v_status,
             snrf = l_v_snrf,
             kdfas = l_v_kdfas,
             lengkap = l_v_lengkap,
             billnpwp = l_v_billnpwp,
              billnama = l_v_billnama,
              billalmt = l_v_billalmt,
              penjualnama = l_v_penjualnama,
              penjualalmt = l_v_penjualalmt,
              penjualneg = l_v_penjualneg,
              pernyataan = l_v_pernyataan,
              jnstrans = l_v_jnstrans,
              vd = l_v_vd,
              versimodul = l_n_versimodul,
              nilvd = l_n_nilvd,
             changed_by = g_rec_status.v_user_id,
             changed_dt = SYSDATE
       WHERE car = l_v_car;

      RETURN TRUE;

      EXCEPTION WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_upd_r_res_pibhdr: ' || SQLERRM || ' for [CAR] = [' || l_v_car || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_ins_m_exc_rate(l_v_curr_cd IN VARCHAR2,
                              l_d_valid_from IN DATE,
                              l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_m_exchange_rate
      (
       curr_cd, --1
       valid_fr, --2
       valid_to, --3
       rate_value, --4
       curr_remark, --5
       created_by, --6
       created_dt, --7
       changed_by, --9
       changed_dt --10
      )
      (
       SELECT curr_cd, --1
              valid_fr, --2
              valid_to, --3
              rate_value, --4
              curr_remark, --5
              g_rec_status.v_user_id, --created_by, --6
              SYSDATE, --created_dt, --7
              g_rec_status.v_user_id, --changed_by, --9
              SYSDATE --changed_dt --10
         FROM tb_t_exchange_rate
        WHERE curr_cd = l_v_curr_cd
          AND valid_fr = l_d_valid_from
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[Currency Code] = [' || l_v_curr_cd || '] [Valid From] = [' || l_d_valid_from || ']', 'Exchange Rate Master');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_m_exc_rate: ' || SQLERRM);
                     RETURN FALSE;
    END;

    FUNCTION f_ins_r_res_import_decl_d(l_v_submission_no IN VARCHAR2,
                                       l_d_submission_dt IN DATE,
                                       l_n_serial IN NUMBER,
                                       l_v_hs_no IN VARCHAR2,
                                       l_n_tariff_serial IN NUMBER,
                                       l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_r_res_import_decl_d
      (
       submission_car, --1
       submission_no, --2
       submission_dt, --3
       serial, --4
       hs_no, --5
       tariff_serial, --6
       desc_of_goods, --7
       merk, --8
       tipe, --9
       country_cd, --10
       country_name, --11
       part_fob, --12
       part_cif, --13
       measurement_cd, --14
       measurement_desc, --15
       part_qty, --16
       id_tax_non_exemp_tariff, --17
       id_tax_suspended_tariff, --18
       id_tax_released_tariff, --19
       id_tax_periodical_tariff, --20
       id_tax_gov_borned_tariff, --21
       id_tax_amt, --22
       id_tax_ad_valorem, --23
       va_tax_non_exemp_tariff, --24
       va_tax_suspended_tariff, --25
       va_tax_released_tariff, --26
       va_tax_periodical_tariff, --27
       va_tax_gov_borned_tariff, --28
       va_tax_amt, --29
       va_tax_ad_valorem, --30
       lux_tax_non_exemp_tariff, --31
       lux_tax_suspended_tariff, --32
       lux_tax_released_tariff, --33
       lux_tax_periodical_tariff, --34
       lux_tax_gov_borned_tariff, --35
       lux_tax_amt, --36
       lux_tax_ad_valorem, --37
       inc_tax_non_exemp_tariff, --38
       inc_tax_suspended_tariff, --39
       inc_tax_released_tariff, --40
       inc_tax_periodical_tariff, --41
       inc_tax_gov_borned_tariff, --42
       inc_tax_amt, --43
       inc_tax_ad_valorem, --44
       created_by, --45
       created_dt, --46
       changed_by, --47
       changed_dt --48
      )
      (
       SELECT submission_car, --1
              submission_no, --2
              submission_dt, --3
              serial, --4
              hs_no, --5
              tariff_serial, --6
              desc_of_goods, --7
              merk, --8
              tipe, --9
              country_cd, --10
              country_name, --11
              part_fob, --12
              part_cif, --13
              measurement_cd, --14
              measurement_desc, --15
              part_qty, --16
              id_tax_non_exemp_tariff, --17
              id_tax_suspended_tariff, --18
              id_tax_released_tariff, --19
              id_tax_periodical_tariff, --20
              id_tax_gov_borned_tariff, --21
              id_tax_amt, --22
              id_tax_ad_valorem, --23
              va_tax_non_exemp_tariff, --24
              va_tax_suspended_tariff, --25
              va_tax_released_tariff, --26
              va_tax_periodical_tariff, --27
              va_tax_gov_borned_tariff, --28
              va_tax_amt, --29
              va_tax_ad_valorem, --30
              lux_tax_non_exemp_tariff, --31
              lux_tax_suspended_tariff, --32
              lux_tax_released_tariff, --33
              lux_tax_periodical_tariff, --34
              lux_tax_gov_borned_tariff, --35
              lux_tax_amt, --36
              lux_tax_ad_valorem, --37
              inc_tax_non_exemp_tariff, --38
              inc_tax_suspended_tariff, --39
              inc_tax_released_tariff, --40
              inc_tax_periodical_tariff, --41
              inc_tax_gov_borned_tariff, --42
              inc_tax_amt, --43
              inc_tax_ad_valorem, --44
              g_rec_status.v_user_id, --created_by, --45
              SYSDATE, --created_dt, --46
              g_rec_status.v_user_id, --changed_by, --47
              SYSDATE --changed_dt --48
         FROM tb_t_res_import_decl_d
        WHERE submission_no = l_v_submission_no
          AND submission_dt = l_d_submission_dt
          AND serial = l_n_serial
          AND hs_no = l_v_hs_no
          AND tariff_serial = l_n_tariff_serial
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[Submission No] = [' || l_v_submission_no ||  '] [Submission Date] = [' || l_d_submission_dt || '] [Serial] = [' || l_n_serial || '] [HS No] = [' || l_v_hs_no || '] [Tariff Serial] = [' || l_n_tariff_serial || ']', 'RES Import Declaration Detail');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_import_decl_d: ' || SQLERRM);
                     RETURN FALSE;

    END;

    FUNCTION f_ins_r_res_import_decl_h(l_v_submission_no IN VARCHAR2,
                                       l_d_submission_dt IN DATE,
                                       l_v_import_decl_no IN VARCHAR2,
                                       l_d_import_decl_dt IN DATE,
                                       l_v_bl_no IN VARCHAR2,
                                       l_d_bl_dt IN DATE,
                                       l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_r_res_import_decl_h
      (
       submission_car, --1
       submission_no, --2
       submission_dt, --3
       customs_office_cd, --4
       import_decl_no, --5
       import_decl_dt, --6
       bl_no, --7
       bl_dt, --8
       bc_1_1_cd, --9
       bc_1_1_no, --10
       bc_1_1_dt, --11
       bc_1_1_pos, --12
       bc_1_1_possub, --13
       bc_1_1_possubsub, --14
       supplier_name, --15
       supplier_addr, --16
       supplier_country, --17
       port_unloading_cd, --18
       port_unloading_desc, --19
       port_loading, --20
       port_loading_desc, --21
       vessel_name, --22
       voyage_no, --23
       voyage_flag, --24
       eta, --25
       cur_cd, --26
       cur_desc, --27
       cur_amount, --28
       ttl_amount, --29
       ttl_freight, --30
       ttl_insurance, --31
       ttl_cif, --32
       ttl_case, --33
       ttl_qty, --34
       duty_facility, --35
       res_cd, --36
       res_doc_no, --37
       res_doc_dt, --38
       id_tax_non_exemp_sum, --39
       id_tax_suspended_sum, --40
       id_tax_released_sum, --41
       id_tax_periodical_sum, --42
       id_tax_gov_borned_sum, --43
       va_tax_non_exemp_sum, --44
       va_tax_suspended_sum, --45
       va_tax_released_sum, --46
       va_tax_periodical_sum, --47
       va_tax_gov_borned_sum, --48
       lux_tax_non_exemp_sum, --49
       lux_tax_suspended_sum, --50
       lux_tax_released_sum, --51
       lux_tax_periodical_sum, --52
       lux_tax_gov_borned_sum, --53
       inc_tax_non_exemp_sum, --54
       inc_tax_suspended_sum, --55
       inc_tax_released_sum, --56
       inc_tax_periodical_sum, --57
       inc_tax_gov_borned_sum, --58
       created_by, --59
       created_dt, --60
       changed_by, --61
       changed_dt --62
      )
      (
       SELECT submission_car, --1
              submission_no, --2
              submission_dt, --3
              customs_office_cd, --4
              import_decl_no, --5
              import_decl_dt, --6
              bl_no, --7
              bl_dt, --8
              bc_1_1_cd, --9
              bc_1_1_no, --10
              bc_1_1_dt, --11
              bc_1_1_pos, --12
              bc_1_1_possub, --13
              bc_1_1_possubsub, --14
              supplier_name, --15
              supplier_addr, --16
              supplier_country, --17
              port_unloading_cd, --18
              port_unloading_desc, --19
              NULL, --port_loading, --20
              port_loading_desc, --21
              vessel_name, --22
              voyage_no, --23
              voyage_flag, --24
              eta, --25
              cur_cd, --26
              cur_desc, --27
              cur_amount, --28
              ttl_amount, --29
              ttl_freight, --30
              ttl_insurance, --31
              ttl_cif, --32
              ttl_case, --33
              ttl_qty, --34
              duty_facility, --35
              res_cd, --36
              res_doc_no, --37
              res_doc_dt, --38
              id_tax_non_exemp_sum, --39
              id_tax_suspended_sum, --40
              id_tax_released_sum, --41
              id_tax_periodical_sum, --42
              id_tax_gov_borned_sum, --43
              va_tax_non_exemp_sum, --44
              va_tax_suspended_sum, --45
              va_tax_released_sum, --46
              va_tax_periodical_sum, --47
              va_tax_gov_borned_sum, --48
              lux_tax_non_exemp_sum, --49
              lux_tax_suspended_sum, --50
              lux_tax_released_sum, --51
              lux_tax_periodical_sum, --52
              lux_tax_gov_borned_sum, --53
              inc_tax_non_exemp_sum, --54
              inc_tax_suspended_sum, --55
              inc_tax_released_sum, --56
              inc_tax_periodical_sum, --57
              inc_tax_gov_borned_sum, --58
              g_rec_status.v_user_id, --created_by, --59
              SYSDATE, --created_dt, --60
              g_rec_status.v_user_id, --changed_by, --61
              SYSDATE --changed_dt --62
         FROM tb_t_res_import_decl_h
        WHERE submission_no = l_v_submission_no
          AND submission_dt = l_d_submission_dt
          AND import_decl_no = l_v_import_decl_no
          AND import_decl_dt = l_d_import_decl_dt
          AND bl_no = l_v_bl_no
          AND bl_dt = l_d_bl_dt
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[Submission No] = [' || l_v_submission_no ||  '] [Submission Date] = [' || l_d_submission_dt || '] [Import Declaration No] = [' || l_v_import_decl_no || '] [Import Declaration Date] = [' || l_d_import_decl_dt || '] [BL No] = [' || l_v_bl_no || '] [BL Date] = [' || l_d_bl_dt || ']', 'RES Import Declaration Header');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_import_decl_h: ' || SQLERRM);
                     RETURN FALSE;
    END;

    FUNCTION f_ins_r_res_pibfas(l_v_car IN VARCHAR2,
                                l_n_serial IN NUMBER,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
      PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN

      INSERT INTO tb_r_res_pibfas
      (
       car, --1
       serial, --2
       kdfasbm, --3
       fasbm, --4
       kdfascuk, --5
       fascuk, --6
       kdfasppn, --7
       fasppn, --8
       kdfaspph, --9
       faspph, --10
       kdfaspbm, --11
       faspbm, --12
       kdfasbmad,
        fasbmad,
        bmads,
        kdfasbmtp,
        fasbmtp,
        bmtps,
        kdfasbmim,
        fasbmim,
        bmims,
        kdfasbmpb,
        fasbmpb,
        bmpbs,
       created_by, --13
       created_dt, --14
       changed_by, --15
       changed_dt --16
      )
      (
       SELECT car, --1
              serial, --2
              kdfasbm, --3
              fasbm, --4
              kdfascuk, --5
              fascuk, --6
              kdfasppn, --7
              fasppn, --8
              kdfaspph, --9
              faspph, --10
              kdfaspbm, --11
              faspbm, --12
              kdfasbmad,
              fasbmad,
              bmads,
              kdfasbmtp,
              fasbmtp,
              bmtps,
              kdfasbmim,
              fasbmim,
              bmims,
              kdfasbmpb,
              fasbmpb,
              bmpbs,

              g_rec_status.v_user_id, --created_by, --13
              SYSDATE, --created_dt, --14
              g_rec_status.v_user_id, --changed_by, --15
              SYSDATE --changed_dt --16
         FROM tb_t_res_pibfas
        WHERE car = l_v_car
          AND serial = l_n_serial
      );

      COMMIT;

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[CAR] = [' || l_v_car || '] [Seral] = [' || l_n_serial || ']', 'PIB FAS');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_pibfas: ' || SQLERRM);
                     RETURN FALSE;
    END;

    FUNCTION f_ins_r_res_pibpgt(l_v_car IN VARCHAR2,
                                l_v_kdbeban IN VARCHAR2,
                                l_v_kdfasil IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_r_res_pibpgt
      (
       car, --1
       kdbeban, --2
       kdfasil, --3
       nilbeban, --4
       npwp,
       created_by, --5
       created_dt, --6
       changed_by, --7
       changed_dt --8
      )
      (
       SELECT car, --1
              kdbeban, --2
              kdfasil, --3
              nilbeban, --4
              npwp,
              g_rec_status.v_user_id, --created_by, --5
              SYSDATE, --created_dt, --6
              g_rec_status.v_user_id, --changed_by, --7
              SYSDATE --changed_dt --8
         FROM tb_t_res_pibpgt
        WHERE car = l_v_car
          AND kdbeban = l_v_kdbeban
          AND kdfasil = l_v_kdfasil
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[CAR] = [' || l_v_car || '] [Beban Code] = [' || l_v_kdbeban || '] [Fasil Code] = [' || l_v_kdfasil || ']', 'PIB PGT');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_pibpgt: ' || SQLERRM);
                     RETURN FALSE;

    END;

    FUNCTION f_ins_r_res_pibres(l_v_car IN VARCHAR2,
                                l_v_reskd IN VARCHAR2,
                                l_d_restg IN DATE,
                                l_v_reswk IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_r_res_pibres
      (
       car, --1
       reskd, --2
       restg, --3
       reswk, --4
       dokresno, --5
       dokrestg, --6
       kpbc, --7
       pibno, --8
       pibtg, --9
       kdgudang, --10
       pejabat1, --11
       nip1, --12
       jabatan1, --13
       pejabat2, --14
       nip2, --15
       jatuhtempo, --16
       komtg, --17
       komwk, --18
       deskripsi, --19
       dibaca, --20
       jmkemas,
        nokemas,
        npwpimp,
        namaimp,
        alamatimp,
        idppjk,
        namappjk,
        alamatppjk,
        kodebill,
        tanggalbill,
        tanggaljttempo,
        tanggalaju,
        totalbayar,
        terbilang,
       created_by, --21
       created_dt, --22
       changed_by, --23
       changed_dt --24
      )
      (
       SELECT car, --1
              reskd, --2
              restg, --3
              reswk, --4
              dokresno, --5
              dokrestg, --6
              kpbc, --7
              pibno, --8
              pibtg, --9
              kdgudang, --10
              pejabat1, --11
              nip1, --12
              jabatan1, --13
              pejabat2, --14
              nip2, --15
              jatuhtempo, --16
              komtg, --17
              komwk, --18
              deskripsi, --19
              dibaca, --20
              jmkemas,
              nokemas,
              npwpimp,
              namaimp,
              alamatimp,
              idppjk,
              namappjk,
              alamatppjk,
              kodebill,
              tanggalbill,
              tanggaljttempo,
              tanggalaju,
              totalbayar,
              terbilang,
              g_rec_status.v_user_id, --created_by, --21
              SYSDATE, --created_dt, --22
              g_rec_status.v_user_id, --changed_by, --23
              SYSDATE --changed_dt --24
         FROM tb_t_res_pibres
        WHERE car = l_v_car
          AND reskd = l_v_reskd
          AND restg = l_d_restg
          AND reswk = l_v_reswk
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[CAR] = [' || l_v_car || '] [RES Code] = [' || l_v_reskd || '] [RES Date] = [' || l_d_restg || '] [RES WK] = [' || l_v_reswk || ']', 'PIB RES');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_pibres: ' || SQLERRM);
                     RETURN FALSE;

    END;

    FUNCTION f_ins_r_res_pibcon(l_v_car IN VARCHAR2,
                                l_v_contno IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_r_res_pibcon
      (
       car, --1
       contno, --2
       contukur, --3
       contipe, --4
       created_by, --5
       created_dt, --6
       changed_by, --7
       changed_dt --8
      )
      (
       SELECT car, --1
              contno, --2
              contukur, --3
              contipe, --4
              g_rec_status.v_user_id, --created_by, --5
              SYSDATE, --created_dt, --6
              g_rec_status.v_user_id, --changed_by, --7
              SYSDATE --changed_dt --8
         FROM tb_t_res_pibcon
        WHERE car = l_v_car
          AND contno = l_v_contno
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[CAR] = [' || l_v_car || '] [Container No] = [' || l_v_contno || ']', 'PIB Container');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_pibcon: ' || SQLERRM);
                     RETURN FALSE;

    END;

    FUNCTION f_ins_r_res_pibdok(l_v_car IN VARCHAR2,
                                l_v_dokkd IN VARCHAR2,
                                l_v_dokno IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_r_res_pibdok
      (
        car,
        dokkd,
        dokno,
        doktg,
        dokinst,
        nourut,
        kdgroupdok,

       created_by, --5
       created_dt, --6
       changed_by, --7
       changed_dt --8
      )
      (
       SELECT car, --1
              dokkd,
              dokno,
              doktg,
              dokinst,
              nourut,
              kdgroupdok,

              g_rec_status.v_user_id, --created_by, --5
              SYSDATE, --created_dt, --6
              g_rec_status.v_user_id, --changed_by, --7
              SYSDATE --changed_dt --8
         FROM tb_t_res_pibdok
        WHERE car = l_v_car
          AND dokkd = l_v_dokkd
          AND dokno = l_v_dokno
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[CAR] = [' || l_v_car || '] [Doc Code] = [' || l_v_dokkd || ']  [Doc No] = [' || l_v_dokno || ']', 'PIB Document');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_pibcon: ' || SQLERRM);
                     RETURN FALSE;

    END;
    
    FUNCTION f_ins_r_res_pibdtldok(l_v_car IN VARCHAR2,
                                l_v_dokkd IN VARCHAR2,
                                l_v_dokno IN VARCHAR2,
                                l_v_serial IN NUMBER,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_r_res_pibdtldok
      (
       car,
        serial,
        kdfasdtl,
        nourut,
        dokkd,
        dokno,
        doktg,
        kdgroupdok,
       created_by, --5
       created_dt, --6
       changed_by, --7
       changed_dt --8
      )
      (
       SELECT car,
              serial,
              kdfasdtl,
              nourut,
              dokkd,
              dokno,
              doktg,
              kdgroupdok,
              g_rec_status.v_user_id, --created_by, --5
              SYSDATE, --created_dt, --6
              g_rec_status.v_user_id, --changed_by, --7
              SYSDATE --changed_dt --8
         FROM tb_t_res_pibdtldok
        WHERE car = l_v_car
          AND dokkd = l_v_dokkd
          AND dokno = l_v_dokno
          AND serial = l_v_serial
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[CAR] = [' || l_v_car || '] [Doc Code] = [' || l_v_dokkd || '] [Doc No] = [' || l_v_dokno || '] [Serial] = [' || l_v_serial || ']', 'PIB Document');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_pibcon: ' || SQLERRM);
                     RETURN FALSE;

    END;
        
    FUNCTION f_ins_r_res_pibdtlvd(l_v_car IN VARCHAR2,
                                l_v_serial IN NUMBER,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_r_res_pibdtlvd
      (
       CAR,
        SERIAL,
        JENIS,
        NILAI,
        TGJATUHTEMPO,
       created_by, --5
       created_dt, --6
       changed_by, --7
       changed_dt --8
      )
      (
       SELECT CAR,
              SERIAL,
              JENIS,
              NILAI,
              TGJATUHTEMPO,
              g_rec_status.v_user_id, --created_by, --5
              SYSDATE, --created_dt, --6
              g_rec_status.v_user_id, --changed_by, --7
              SYSDATE --changed_dt --8
         FROM tb_t_res_pibdtlvd
        WHERE car = l_v_car
          AND serial = l_v_serial
          AND  jenis = l_v_jenis
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[CAR] = [' || l_v_car || '] [Jenis] = [' || l_v_jenis || '] [Serial] = [' || l_v_serial || ']', 'PIB Detail VD');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_pibcon: ' || SQLERRM);
                     RETURN FALSE;

    END;

    FUNCTION f_ins_r_res_pibdtlspekkhusus(l_v_car IN VARCHAR2,
                                l_v_serial IN NUMBER,
                                l_v_cas1 IN VARCHAR2,
                                l_v_cas2 IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

     INSERT INTO tb_r_res_pibdtlspekkhusus
      (
       CAR,
        SERIAL,
        cas1,
        cas2,
       created_by, --5
       created_dt, --6
       changed_by, --7
       changed_dt --8
      )
      (
       SELECT CAR,
              SERIAL,
              cas1,
              cas2,
              g_rec_status.v_user_id, --created_by, --5
              SYSDATE, --created_dt, --6
              g_rec_status.v_user_id, --changed_by, --7
              SYSDATE --changed_dt --8
         FROM tb_t_res_pibdtlspekkhusus
        WHERE car = l_v_car
          AND serial = l_v_serial
          AND cas1 = l_v_cas1
          AND cas2 = l_v_cas2
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[CAR] = [' || l_v_car || '] [Jenis] = [' || l_v_jenis || '] [Serial] = [' || l_v_serial || ']', 'PIB Detail VD');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_pibdtlspekkhusus: ' || SQLERRM);
                     RETURN FALSE;

    END;

    FUNCTION f_ins_r_res_pibkendaraan(l_v_car IN VARCHAR2,
                                l_v_serial IN NUMBER,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_r_res_pibkendaraan
      (
       CAR,
        SERIAL,
        NORANGKA,
        NOMESIN,
        SILINDER,
        TAHUN,
       created_by, --5
       created_dt, --6
       changed_by, --7
       changed_dt --8
      )
      (
       SELECT CAR,
              SERIAL,
              NORANGKA,
              NOMESIN,
              SILINDER,
              TAHUN,
              g_rec_status.v_user_id, --created_by, --5
              SYSDATE, --created_dt, --6
              g_rec_status.v_user_id, --changed_by, --7
              SYSDATE --changed_dt --8
         FROM tb_t_res_pibkendaraan
        WHERE car = l_v_car
          AND serial = l_v_serial
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[CAR] = [' || l_v_car || ']  Serial] = [' || l_v_serial || ']', 'PIB Kendaraan');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_pibkendaraan: ' || SQLERRM);
                     RETURN FALSE;

    END;

    FUNCTION f_ins_r_res_pibconr(l_v_car IN VARCHAR2,
                                l_v_contno IN VARCHAR2,
                                l_v_reskd IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_r_res_pibconr
      (
       car, --1
       contno, --2
       reskd,
       contukur, --3
       contipe, --4
       created_by, --5
       created_dt, --6
       changed_by, --7
       changed_dt --8
      )
      (
       SELECT car, --1
              contno, --2
              reskd,
              contukur, --3
              contipe, --4
              g_rec_status.v_user_id, --created_by, --5
              SYSDATE, --created_dt, --6
              g_rec_status.v_user_id, --changed_by, --7
              SYSDATE --changed_dt --8
         FROM tb_t_res_pibconr
        WHERE car = l_v_car
          AND contno = l_v_contno
          AND reskd = l_v_reskd
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[CAR] = [' || l_v_car || '] [Container No] = [' || l_v_contno || ']  [Response Code] = [' || l_v_reskd || ']', 'PIB Container R');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_pibcon: ' || SQLERRM);
                     RETURN FALSE;

    END;
    
    FUNCTION f_ins_r_res_pibkms(l_v_car IN VARCHAR2,
                                l_v_jnkemas IN VARCHAR2,
                                l_v_merkkemas IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_r_res_pibkms
      (
       car,
        jnkemas,
        jmkemas,
        merkkemas,
       created_by, --5
       created_dt, --6
       changed_by, --7
       changed_dt --8
      )
      (
       SELECT car,
              jnkemas,
              jmkemas,
              merkkemas,
             g_rec_status.v_user_id, --created_by, --5
              SYSDATE, --created_dt, --6
              g_rec_status.v_user_id, --changed_by, --7
              SYSDATE --changed_dt --8
         FROM tb_t_res_pibkms
        WHERE car = l_v_car
          AND dokkd = l_v_dokkd
          AND dokno = l_v_dokno
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[CAR] = [' || l_v_car || '] [Jenis Kemas] = [' || l_v_jnkemas || ']  [Merk] = [' || l_v_merkkemas || ']', 'PIB Case');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_pibkms: ' || SQLERRM);
                     RETURN FALSE;

    END;
    
    FUNCTION f_ins_r_res_pibnpt(l_v_car IN VARCHAR2,
                                l_v_reskd IN VARCHAR2,
                                l_v_restg IN VARCHAR2,
                                l_v_reswk IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_r_res_pibnpt
      (
       car,
        reskd,
        restg,
        reswk,
        bm_asal,
        cuk_asal,
        ppn_asal,
        ppnbm_asal,
        pph_asal,
        bmbyr,
        cukbyr,
        ppnbyr,
        ppnbmbyr,
        pphbyr,
        denda,
        bm_kurang,
        cuk_kurang,
        ppn_kurang,
        ppnbm_kurang,
        pph_kurang,
        bm_lebih,
        cuk_lebih,
        ppn_lebih,
        ppnbm_lebih,
        pph_lebih,
        total_kurang,
        total_lebih,
        s_jnsbrg,
        s_jmlbrg,
        s_tarif,
        s_nilpab,
        bmad_asal,
        bmadbyr,
        bmad_kurang,
        bmad_lebih,
        bmi_asal,
        bmibyr,
        bmi_kurang,
        bmi_lebih,
        bmtp_asal,
        bmtpbyr,
        bmtp_kurang,
        bmtp_lebih,
        bmads_asal,
        bmadsbyr,
        bmads_kurang,
        bmads_lebih,
        bmis_asal,
        bmisbyr,
        bmis_kurang,
        bmis_lebih,
        bmtps_asal,
        bmtpsbyr,
        bmtps_kurang,
        bmtps_lebih,
        bmkt_asal,
        bmkt,
        bmkt_kurang,
        bmkt_lebih,
       created_by, --5
       created_dt, --6
       changed_by, --7
       changed_dt --8
      )
      (
       SELECT car,
              reskd,
              restg,
              reswk,
              bm_asal,
              cuk_asal,
              ppn_asal,
              ppnbm_asal,
              pph_asal,
              bmbyr,
              cukbyr,
              ppnbyr,
              ppnbmbyr,
              pphbyr,
              denda,
              bm_kurang,
              cuk_kurang,
              ppn_kurang,
              ppnbm_kurang,
              pph_kurang,
              bm_lebih,
              cuk_lebih,
              ppn_lebih,
              ppnbm_lebih,
              pph_lebih,
              total_kurang,
              total_lebih,
              s_jnsbrg,
              s_jmlbrg,
              s_tarif,
              s_nilpab,
              bmad_asal,
              bmadbyr,
              bmad_kurang,
              bmad_lebih,
              bmi_asal,
              bmibyr,
              bmi_kurang,
              bmi_lebih,
              bmtp_asal,
              bmtpbyr,
              bmtp_kurang,
              bmtp_lebih,
              bmads_asal,
              bmadsbyr,
              bmads_kurang,
              bmads_lebih,
              bmis_asal,
              bmisbyr,
              bmis_kurang,
              bmis_lebih,
              bmtps_asal,
              bmtpsbyr,
              bmtps_kurang,
              bmtps_lebih,
              bmkt_asal,
              bmkt,
              bmkt_kurang,
              bmkt_lebih,
             g_rec_status.v_user_id, --created_by, --5
              SYSDATE, --created_dt, --6
              g_rec_status.v_user_id, --changed_by, --7
              SYSDATE --changed_dt --8
         FROM tb_t_res_pibnpt
        WHERE car = l_v_car
          AND reskd = l_v_reskd
          AND restg = l_v_restg
          AND reswk =l_v_reswk
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[CAR] = [' || l_v_car || '] [Kode Respon] = [' || l_v_reskd || ']  [Tanggal Respon] = [' || l_v_restg || '] [Waktu Respon] = [' || l_v_reswk || ']', 'PIB Case');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_pibnpt: ' || SQLERRM);
                     RETURN FALSE;

    END;

    FUNCTION f_ins_r_res_pibtrf(l_v_car IN VARCHAR2,
                                l_v_nohs IN VARCHAR2,
                                l_n_seritrp IN NUMBER,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_r_res_pibtrf
      (
       process_id, --1
       car, --2
       nohs, --3
       seritrp, --4
       kdtrpbm, --5
       kdsatbm, --6
       trpbm, --7
       kdcuk, --8
       kdtrpcuk, --9
       kdsatcuk, --10
       trpcuk, --11
       trpppn, --12
       trppbm, --13
       trppph,
        kdtrpbmad,
        trpbmad,
        kdtrpbmtp,
        trpbmtp,
        kdtrpbmim,
        trpbmim,
        kdtrpbmpb,
        trpbmpb,
        kdcuksub,
        hjecuk,
        kdkmscuk,
        isiperkmscuk,
       created_by, --14
       created_dt, --15
       changed_by, --16
       changed_dt --17
      )
      (
       SELECT g_rec_status.v_process_id, --process_id, --1
              car, --2
              nohs, --3
              seritrp, --4
              kdtrpbm, --5
              kdsatbm, --6
              trpbm, --7
              kdcuk, --8
              kdtrpcuk, --9
              kdsatcuk, --10
              trpcuk, --11
              trpppn, --12
              trppbm, --13
              trppph,
              kdtrpbmad,
              trpbmad,
              kdtrpbmtp,
              trpbmtp,
              kdtrpbmim,
              trpbmim,
              kdtrpbmpb,
              trpbmpb,
              kdcuksub,
              hjecuk,
              kdkmscuk,
              isiperkmscuk,
              g_rec_status.v_user_id, --created_by, --14
              SYSDATE, --created_dt, --15
              g_rec_status.v_user_id, --changed_by, --16
              SYSDATE --changed_dt --17
         FROM tb_t_res_pibtrf
        WHERE car = l_v_car
          AND nohs = l_v_nohs
          AND seritrp = l_n_seritrp
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[CAR] = [' || l_v_car || '] [NOHS] = [' || l_v_nohs || '] [Seri TRP] = [' || l_n_seritrp || ']', 'PIB Tariff');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_pibtrf: ' || SQLERRM);
                     RETURN FALSE;

    END;

    FUNCTION f_ins_r_res_pibdtl(l_v_car IN VARCHAR2,
                                l_v_serial IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_r_res_pibdtl
      (
       process_id, --1
       car, --2
       serial, --3
       nohs, --4
       seritrp, --5
       brgurai, --6
       merk, --7
       tipe, --8
       spflain, --9
       brgasal, --10
       dnilinv, --11
       dcif, --12
       kdsat, --13
       jmlsat, --14
       kemasjn, --15
       kemasjm, --16
       satbmjm, --17
       satcukjm, --18
       nettodtl, --19
       kdfasdtl, --20
       dtlok, --21
       --teguh 20180215
       flbarangbaru,
        fllartas,
        katlartas,
        spektarif,
        dnilcuk,
        jmpc,
        saldoawalpc,
        saldoakhirpc,
       --end teguh
       created_by, --22
       created_dt, --23
       changed_by, --24
       changed_dt --25
      )
      (
       SELECT g_rec_status.v_process_id, --process_id, --1
              car, --2
              serial, --3
              nohs, --4
              seritrp, --5
              brgurai, --6
              merk, --7
              tipe, --8
              spflain, --9
              brgasal, --10
              dnilinv, --11
              dcif, --12
              kdsat, --13
              jmlsat, --14
              kemasjn, --15
              kemasjm, --16
              satbmjm, --17
              satcukjm, --18
              nettodtl, --19
              kdfasdtl, --20
              dtlok, --21
              --teguh 20180215
             flbarangbaru,
              fllartas,
              katlartas,
              spektarif,
              dnilcuk,
              jmpc,
              saldoawalpc,
              saldoakhirpc,
             --end teguh
              g_rec_status.v_user_id, --created_by, --22
              SYSDATE, --created_dt, --23
              g_rec_status.v_user_id, --changed_by, --24
              SYSDATE --changed_dt --25
         FROM tb_t_res_pibdtl
        WHERE car = l_v_car
          AND serial = l_v_serial
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[CAR] = [' || l_v_car || '] [Serial] = [' || l_v_serial || ']', 'PIB Detail');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_pibdtl: ' || SQLERRM);
                     RETURN FALSE;
    END;

    FUNCTION f_ins_r_res_import_decl_doc(l_v_submission_no IN VARCHAR2,
                                         l_d_submission_dt IN DATE,
                                         l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_r_res_import_decl_doc
      (
       process_id, --1
       submission_car, --2
       submission_no, --3
       submission_dt, --4
       doc_cd, --5
       doc_desc, --6
       doc_no, --7
       doc_dt, --8
       doc_inst, --9
       created_by, --10
       created_dt, --11
       changed_by, --12
       changed_dt --13
      )
      (
       SELECT process_id, --1
              car, --2
              substr(car, 21, 6), --3
              to_date(substr(car, 13, 8), 'YYYYMMDD'), --4
              dokkd, --5
              dokdesc, --6
              dokno, --7
              doktg, --8
              dokinst, --9
              g_rec_status.v_user_id, --created_by, --10
              SYSDATE, --created_dt, --11
              g_rec_status.v_user_id, --changed_by, --12
              SYSDATE --changed_dt --13
         FROM tb_t_res_pibdok
        WHERE substr(car, 21, 6) = l_v_submission_no
          AND to_date(substr(car, 13, 8), 'YYYYMMDD') = l_d_submission_dt
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[Submission No] = [' || l_v_submission_no || '] [Submission Date] = [' || l_d_submission_dt || ']', 'Import Declaration Header');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_import_decl_h: ' || SQLERRM);
                     RETURN FALSE;
    END;

    FUNCTION f_ins_r_res_pibhdr(l_v_car IN VARCHAR2,
                                l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_r_res_pibhdr
      (
       process_id, --1
       car, --2
       kdkpbc, --3
       pibno, --4
       pibtg, --5
       jnpib, --6
       jnimp, --7
       jkwaktu, --8
       crbyr, --9
       doktupkd, --10
       doktupno, --11
       doktuptg, --12
       posno, --13
       possub, --14
       possubsub, --15
       impid, --16
       impnpwp, --17
       impnama, --18
       impalmt, --19
       imptstatus, --20
       apikd, --21
       apino, --22
       ppjkld, --23
       ppjknpwp, --24
       ppjknama, --25
       ppjkalmt, --26
       ppjkno, --27
       ppjktg, --28
       indid, --29
       indnpwp, --30
       indnama, --31
       indalmt, --32
       pasoknama, --33
       pasokalmt, --34
       pasokneg, --35
       pelbkr, --36
       pelmuat, --37
       peltransit, --38
       tmptbn, --39
       moda, --40
       angkutnama, --41
       angkutno, --42
       angkutfl, --43
       tgtiba, --44
       kdval, --45
       ndpbm, --46
       nilinv, --47
       freight, --48
       btambahan, --49
       diskon, --50
       kdass, --51
       asuransi, --52
       kdhrg, --53
       fob, --54
       cif, --55
       bruto, --56
       netto, --57
       jmcont, --58
       jmbrg, --59
       status, --60
       snrf, --61
       kdfas, --62
       lengkap, --63
       --teguh 20180215
       billnpwp,
       billnama,
       billalmt,
       penjualnama,
       penjualalmt,
       penjualneg,
       pernyataan,
       jnstrans,
       vd,
       versimodul,
       nilvd,
       --end teguh 20180215
       created_by, --64
       created_dt, --65
       changed_by, --66
       changed_dt --67
      )
      (
       SELECT g_rec_status.v_process_id, --process_id, --1
              car, --2
              kdkpbc, --3
              pibno, --4
              pibtg, --5
              jnpib, --6
              jnimp, --7
              jkwaktu, --8
              crbyr, --9
              doktupkd, --10
              doktupno, --11
              doktuptg, --12
              posno, --13
              possub, --14
              possubsub, --15
              impid, --16
              impnpwp, --17
              impnama, --18
              impalmt, --19
              NULL, --imptstatus, --20
              apikd, --21
              apino, --22
              NULL, --ppjkld, --23
              ppjknpwp, --24
              ppjknama, --25
              ppjkalmt, --26
              ppjkno, --27
              ppjktg, --28
              indid, --29
              indnpwp, --30
              indnama, --31
              indalmt, --32
              pasoknama, --33
              pasokalmt, --34
              pasokneg, --35
              pelbkr, --36
              pelmuat, --37
              peltransit, --38
              tmptbn, --39
              moda, --40
              angkutnama, --41
              angkutno, --42
              angkutfl, --43
              tgtiba, --44
              kdval, --45
              ndpbm, --46
              nilinv, --47
              freight, --48
              btambahan, --49
              diskon, --50
              kdass, --51
              asuransi, --52
              kdhrg, --53
              fob, --54
              cif, --55
              bruto, --56
              netto, --57
              jmcont, --58
              jmbrg, --59
              status, --60
              snrf, --61
              kdfas, --62
              lengkap, --63
              --teguh 20180215
              billnpwp,
              billnama,
              billalmt,
              penjualnama,
              penjualalmt,
              penjualneg,
              pernyataan,
              jnstrans,
              vd,
              versimodul,
              nilvd,
              --end teguh 20180215
              g_rec_status.v_user_id, --created_by, --64
              SYSDATE, --created_dt, --65
              g_rec_status.v_user_id, --changed_by, --66
              SYSDATE --changed_dt --67
         FROM tb_t_res_pibhdr
        WHERE car = l_v_car
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[CAR] = [' || l_v_car || ']', 'PIB Header');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_pibhdr: ' || SQLERRM);
                     RETURN FALSE;

    END;
    
    FUNCTION f_ins_r_res_dokemail(l_v_car IN VARCHAR2,
                                  l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      INSERT INTO tb_r_res_pibdok_email
      (
        pib_no,
        pib_dt,
        pi_no,
       created_by, --5
       created_dt
      )
      (
       SELECT car,
              jnkemas,
              jmkemas,
              merkkemas,
             g_rec_status.v_user_id, --created_by, --5
              SYSDATE, --created_dt, --6
              g_rec_status.v_user_id, --changed_by, --7
              SYSDATE --changed_dt --8
         FROM tb_t_res_pibkms
        WHERE car = l_v_car
          AND dokkd = l_v_dokkd
          AND dokno = l_v_dokno
      );

      RETURN TRUE;

      EXCEPTION WHEN dup_val_on_index THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00002ERR', '[CAR] = [' || l_v_car || '] [Jenis Kemas] = [' || l_v_jnkemas || ']  [Merk] = [' || l_v_merkkemas || ']', 'PIB Case');
                     RETURN FALSE;

                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_ins_r_res_pibkms: ' || SQLERRM);
                     RETURN FALSE;

    END;

    FUNCTION f_get_res_import_decl_h(l_v_submission_no IN VARCHAR2,
                                     l_d_submission_dt IN DATE,
                                     l_v_import_decl_no OUT VARCHAR2,
                                     l_d_import_decl_dt OUT DATE,
                                     l_v_res_doc_no OUT VARCHAR2,
                                     l_n_cur_amount OUT NUMBER,
                                     l_v_bl_no OUT VARCHAR2,
                                     l_d_bl_dt OUT DATE,
                                     l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      SELECT import_decl_no,
             import_decl_dt,
             res_doc_no,
             cur_amount,
             bl_no,
             bl_dt
        INTO l_v_import_decl_no,
             l_d_import_decl_dt,
             l_v_res_doc_no,
             l_n_cur_amount,
             l_v_bl_no,
             l_d_bl_dt
        FROM tb_r_res_import_decl_h
       WHERE submission_no = l_v_submission_no
         AND submission_dt = l_d_submission_dt
         ;

      RETURN TRUE;

      EXCEPTION WHEN too_many_rows THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Two or more records found in TB_R_RES_IMPORT_DECL_H for [Submission No] = [' || l_v_submission_no || '] [Submission Date] = [' || l_d_submission_dt || ']');
                     RETURN FALSE;
                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_get_res_import_decl_h: ' || SQLERRM || ' for [Submission No] = [' || l_v_submission_no || '] [Submission Date] = [' || l_d_submission_dt || ']');
                     RETURN FALSE;

    END;

    FUNCTION f_get_container_yard_dt(l_v_bl_no IN VARCHAR2,
                                     l_d_bl_dt IN DATE,
                                     l_v_inv_no OUT VARCHAR2,
                                     l_d_inv_dt OUT DATE,
                                     l_v_container_no OUT VARCHAR2,
                                     l_d_yard_arrival_dt OUT DATE,
                                     l_d_warehouse_arrival_dt OUT DATE,
                                     l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      SELECT inv_no, inv_dt, container_no, yard_arrival_dt, warehouse_arrival_dt
        INTO l_v_inv_no, l_d_inv_dt, l_v_container_no, l_d_yard_arrival_dt, l_d_warehouse_arrival_dt
        FROM (
              SELECT a.inv_no, a.inv_dt, a.container_no, a.yard_arrival_dt, a.warehouse_arrival_dt,
                     row_number() over (PARTITION BY b.bl_no, b.bl_dt ORDER BY yard_arrival_dt, warehouse_arrival_dt) rn
                FROM tb_r_sd_container a,
                     tb_r_sd_invoice b
               WHERE b.bl_no = l_v_bl_no
                 AND b.bl_dt = l_d_bl_dt
                 AND a.inv_no = b.inv_no
                 AND a.inv_dt = b.inv_dt
                 AND (a.yard_arrival_sts = 'Y'
                  OR  a.warehouse_arrival_sts = 'Y')
             )
       WHERE rn = 1;

      RETURN TRUE;

      EXCEPTION WHEN no_data_found THEN
                     l_v_inv_no := NULL;
                     l_d_inv_dt := NULL;
                     l_v_container_no := NULL;
                     l_d_yard_arrival_dt := NULL;
                     l_d_warehouse_arrival_dt := NULL;
                     RETURN TRUE;
                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_get_container_yard: ' || SQLERRM);
                     RETURN FALSE;

    END;

    FUNCTION f_get_unpacked_dt(l_v_bl_no IN VARCHAR2,
                               l_d_bl_dt IN DATE,
                               l_v_inv_no OUT VARCHAR2,
                               l_d_inv_dt OUT DATE,
                               l_v_container_no OUT VARCHAR2,
                               l_v_module_no OUT VARCHAR2,
                               l_v_case_no OUT VARCHAR2,
                               l_v_lot_no OUT VARCHAR2,
                               l_d_warehouse_arrival_dt OUT DATE,
                               l_d_unpacking_dt OUT VARCHAR2,
                               l_v_error_message OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN

      SELECT inv_no, inv_dt, container_no, module_no, case_no, lot_no, warehouse_arrival_dt, unpacking_dt
        INTO l_v_inv_no, l_d_inv_dt, l_v_container_no, l_v_module_no, l_v_case_no, l_v_lot_no, l_d_warehouse_arrival_dt, l_d_unpacking_dt
        FROM (
              SELECT a.inv_no, a.inv_dt, a.container_no, a.module_no, a.case_no, a.lot_no, a.warehouse_arrival_dt, a.unpacking_dt,
                     row_number() over (PARTITION BY b.bl_no, b.bl_dt ORDER BY a.warehouse_arrival_dt, a.unpacking_dt) rn
                FROM tb_r_sd_module a,
                     tb_r_sd_invoice b
               WHERE b.bl_no = l_v_bl_no
                 AND b.bl_dt = l_d_bl_dt
                 AND a.inv_no = b.inv_no
                 AND a.inv_dt = b.inv_dt
                 AND (a.unpacking_sts = 'Y'
                  OR  a.warehouse_arrival_sts = 'Y')
             )
       WHERE rn = 1;

      RETURN TRUE;

      EXCEPTION WHEN no_data_found THEN
                     l_v_inv_no := NULL;
                     l_d_inv_dt := NULL;
                     l_v_container_no := NULL;
                     l_v_module_no := NULL;
                     l_v_case_no := NULL;
                     l_v_lot_no := NULL;
                     l_d_warehouse_arrival_dt := NULL;
                     l_d_unpacking_dt := NULL;
                     RETURN TRUE;
                WHEN OTHERS THEN
                     l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_get_unpacked: ' || SQLERRM);
                     RETURN FALSE;

    END;

    FUNCTION f_get_replace_flag(l_v_error_message OUT VARCHAR2) RETURN BOOLEAN AS

    BEGIN

      SELECT replace_flag
        INTO g_rec_status.v_replace_flag
        FROM tb_r_res_pib_file_h
       WHERE rownum = 1;

  	RETURN TRUE;

    EXCEPTION WHEN no_data_found THEN
                   l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'No data found for Replace Flag in TB_R_RES_PIB_FILE_H');
                   RETURN FALSE;
              WHEN OTHERS THEN
                   l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'f_get_replace_flag: ' || SQLERRM);
                   RETURN FALSE;

    END;

  BEGIN

    --Initialization
    g_rec_status.b_error := FALSE;
    g_rec_status.b_error_per_submission := FALSE;
    g_rec_status.b_warning := FALSE;
    g_rec_status.b_lock := FALSE;

    --Get Process ID
    IF NOT g_rec_status.b_error THEN
      IF pkg_common_seq.fn_get_dt_next_seq('SEQ_PROCESS_ID', g_rec_status.v_process_id) IN (c_failed1, c_failed2) THEN
        g_rec_status.b_error := TRUE;
      END IF;
    END IF;

    --Create Log Header
    IF pkg_common_logger.fn_create_log_header(g_rec_status.v_process_id,
                                              SYSDATE,
                                              g_rec_status.v_user_id,
                                              c_function_id,
                                              c_on_progress,
                                              l_v_error_message) != 0 THEN
      g_rec_status.b_error := TRUE;
    END IF;

    IF NOT g_rec_status.b_error THEN
      --Create Start Log Detail
      l_v_error_message := pkg_common_general.fn_get_message('MSTD00336INF', c_function_name);
      g_rec_status.n_seq_no := g_rec_status.n_seq_no;
      IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                g_rec_status.n_seq_no,
                                                'Start Log Detail',
                                                substr(l_v_error_message, 1, 12),
                                                substr(l_v_error_message, 10, 3),
                                                l_v_error_message,
                                                l_v_error_message) != 0 THEN
        g_rec_status.b_error := TRUE;
      END IF;
    END IF;

    IF NOT g_rec_status.b_error THEN
      --Get Paid Status
      IF pkg_common_system_master.fn_get_by_system_id('PAID_STS',
                                                      '1',
                                                      SYSDATE,
                                                      l_v_non_paid,
                                                      l_n_temp,
                                                      l_d_temp,
                                                      l_v_error_message) != 0 THEN

        g_rec_status.b_error := TRUE;
        g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
        IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                  g_rec_status.n_seq_no,
                                                  'Get Paid Status',
                                                  substr(l_v_error_message, 1, 12),
                                                  substr(l_v_error_message, 10, 3),
                                                  l_v_error_message,
                                                  l_v_error_message) != 0 THEN
          g_rec_status.b_error := TRUE;
        END IF;

      END IF;

      IF pkg_common_system_master.fn_get_by_system_id('PAID_STS',
                                                      '2',
                                                      SYSDATE,
                                                      l_v_paid,
                                                      l_n_temp,
                                                      l_d_temp,
                                                      l_v_error_message) != 0 THEN

        g_rec_status.b_error := TRUE;
        g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
        IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                  g_rec_status.n_seq_no,
                                                  'Get Non Paid Status',
                                                  substr(l_v_error_message, 1, 12),
                                                  substr(l_v_error_message, 10, 3),
                                                  l_v_error_message,
                                                  l_v_error_message) != 0 THEN
          g_rec_status.b_error := TRUE;
        END IF;

      END IF;

      IF pkg_common_system_master.fn_get_by_system_id('PAID_STS_1',
                                                      '1',
                                                      SYSDATE,
                                                      l_v_paid_sts,
                                                      l_n_temp,
                                                      l_d_temp,
                                                      l_v_error_message) != 0 THEN

        g_rec_status.b_error := TRUE;
        g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
        IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                  g_rec_status.n_seq_no,
                                                  'Get Email From',
                                                  substr(l_v_error_message, 1, 12),
                                                  substr(l_v_error_message, 10, 3),
                                                  l_v_error_message,
                                                  l_v_error_message) != 0 THEN
          g_rec_status.b_error := TRUE;
        END IF;

      END IF;

      --Get Email Parameter
      IF pkg_common_system_master.fn_get_by_system_id('BIPMB471_PARAMETER',
                                                      'EMAIL_FROM',
                                                      SYSDATE,
                                                      l_v_email_from,
                                                      l_n_temp,
                                                      l_d_temp,
                                                      l_v_error_message) != 0 THEN

        g_rec_status.b_error := TRUE;
        g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
        IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                  g_rec_status.n_seq_no,
                                                  'Get Email From',
                                                  substr(l_v_error_message, 1, 12),
                                                  substr(l_v_error_message, 10, 3),
                                                  l_v_error_message,
                                                  l_v_error_message) != 0 THEN
          g_rec_status.b_error := TRUE;
        END IF;

      END IF;

      IF pkg_common_system_master.fn_get_by_system_id('BIPMB471_PARAMETER',
                                                      'EMAIL_TO',
                                                      SYSDATE,
                                                      l_v_email_to,
                                                      l_n_temp,
                                                      l_d_temp,
                                                      l_v_error_message) != 0 THEN

        g_rec_status.b_error := TRUE;
        g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
        IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                  g_rec_status.n_seq_no,
                                                  'Get Email To',
                                                  substr(l_v_error_message, 1, 12),
                                                  substr(l_v_error_message, 10, 3),
                                                  l_v_error_message,
                                                  l_v_error_message) != 0 THEN
          g_rec_status.b_error := TRUE;
        END IF;

      END IF;

      IF pkg_common_system_master.fn_get_by_system_id('BIPMB471_PARAMETER',
                                                      'EMAIL_CC',
                                                      SYSDATE,
                                                      l_v_email_cc,
                                                      l_n_temp,
                                                      l_d_temp,
                                                      l_v_error_message) != 0 THEN

        g_rec_status.b_error := TRUE;
        g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
        IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                  g_rec_status.n_seq_no,
                                                  'Get Email CC',
                                                  substr(l_v_error_message, 1, 12),
                                                  substr(l_v_error_message, 10, 3),
                                                  l_v_error_message,
                                                  l_v_error_message) != 0 THEN
          g_rec_status.b_error := TRUE;
        END IF;

      END IF;

      IF pkg_common_system_master.fn_get_by_system_id('BIPMB471_PARAMETER',
                                                      'EMAIL_SUBJECT',
                                                      SYSDATE,
                                                      l_v_email_subject,
                                                      l_n_temp,
                                                      l_d_temp,
                                                      l_v_error_message) != 0 THEN

        g_rec_status.b_error := TRUE;
        g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
        IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                  g_rec_status.n_seq_no,
                                                  'Get Email Subject',
                                                  substr(l_v_error_message, 1, 12),
                                                  substr(l_v_error_message, 10, 3),
                                                  l_v_error_message,
                                                  l_v_error_message) != 0 THEN
          g_rec_status.b_error := TRUE;
        END IF;

      END IF;

      IF pkg_common_system_master.fn_get_by_system_id('BIPMB471_PARAMETER',
                                                      'EMAIL_HEADER',
                                                      SYSDATE,
                                                      l_v_email_header,
                                                      l_n_temp,
                                                      l_d_temp,
                                                      l_v_error_message) != 0 THEN

        g_rec_status.b_error := TRUE;
        g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
        IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                  g_rec_status.n_seq_no,
                                                  'Get Email Header',
                                                  substr(l_v_error_message, 1, 12),
                                                  substr(l_v_error_message, 10, 3),
                                                  l_v_error_message,
                                                  l_v_error_message) != 0 THEN
          g_rec_status.b_error := TRUE;
        END IF;

      END IF;

      IF pkg_common_system_master.fn_get_by_system_id('BIPMB471_PARAMETER',
                                                      'EMAIL_FOOTER',
                                                      SYSDATE,
                                                      l_v_email_footer,
                                                      l_n_temp,
                                                      l_d_temp,
                                                      l_v_error_message) != 0 THEN

        g_rec_status.b_error := TRUE;
        g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
        IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                  g_rec_status.n_seq_no,
                                                  'Get Email Footer',
                                                  substr(l_v_error_message, 1, 12),
                                                  substr(l_v_error_message, 10, 3),
                                                  l_v_error_message,
                                                  l_v_error_message) != 0 THEN
          g_rec_status.b_error := TRUE;
        END IF;

      END IF;

    END IF;

    IF NOT g_rec_status.b_error THEN

      --Lock Application
      IF pkg_common_lock_record.fn_lock_record(c_lock_ref_key,
                                               g_rec_status.v_process_id,
                                               c_function_id,
                                               g_rec_status.v_user_id,
                                               l_v_error_message) IN (c_failed1, c_failed2) THEN

        g_rec_status.b_lock := FALSE;
        g_rec_status.b_error := TRUE;
        g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
        IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                  g_rec_status.n_seq_no,
                                                  'Lock per Application',
                                                  substr(l_v_error_message, 1, 12),
                                                  substr(l_v_error_message, 10, 3),
                                                  l_v_error_message,
                                                  l_v_error_message) != 0 THEN
          g_rec_status.b_error := TRUE;
        END IF;

      ELSE

        g_rec_status.b_lock := TRUE;

      END IF;

    END IF;

    IF NOT g_rec_status.b_error THEN

      --Get Replace Flag
      IF NOT f_get_replace_flag(l_v_error_message) THEN

        g_rec_status.b_error := TRUE;
        g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
        IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                  g_rec_status.n_seq_no,
                                                  'Get Replace Flag',
                                                  substr(l_v_error_message, 1, 12),
                                                  substr(l_v_error_message, 10, 3),
                                                  l_v_error_message,
                                                  l_v_error_message) != 0 THEN
          g_rec_status.b_error := TRUE;
        END IF;

      END IF;

    END IF;

    IF NOT g_rec_status.b_error THEN

      FOR cur_res_import_decl_h IN (SELECT submission_no, submission_dt, bl_no, bl_dt, import_decl_no, import_decl_dt
                                      FROM (
                                            SELECT submission_no, submission_dt, bl_no, bl_dt, import_decl_no, import_decl_dt,
                                                   row_number() over (PARTITION BY submission_no, submission_dt, bl_no, bl_dt, import_decl_no, import_decl_dt ORDER BY submission_no) rn
                                              FROM tb_t_res_import_decl_h
                                           )
                                     WHERE rn = 1) LOOP

        l_v_error_message := pkg_common_general.fn_get_message('MSTD00006INF', 'Start processing [Submission No] = [' || cur_res_import_decl_h.submission_no || '] [Submission Date] = [' || cur_res_import_decl_h.submission_dt || ']');
        g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
        IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                  g_rec_status.n_seq_no,
                                                  'Start Log Submission Info',
                                                  substr(l_v_error_message, 1, 12),
                                                  substr(l_v_error_message, 10, 3),
                                                  l_v_error_message,
                                                  l_v_error_message) != 0 THEN
          g_rec_status.b_error := TRUE;
        END IF;

        IF NOT f_get_unpacked_dt(cur_res_import_decl_h.bl_no,
                                 cur_res_import_decl_h.bl_dt,
                                 l_v_inv_no_unpacked,
                                 l_d_inv_dt_unpacked,
                                 l_v_container_no_unpacked,
                                 l_v_module_no_unpacked,
                                 l_v_case_no_unpacked,
                                 l_v_lot_no_unpacked,
                                 l_d_warehouse_dt_unpacked,
                                 l_d_unpacking_dt_unpacked,
                                 l_v_error_message) THEN

          g_rec_status.b_error := TRUE;
          g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
          IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                    g_rec_status.n_seq_no,
                                                    'Get Unpacked Warehouse Date',
                                                    substr(l_v_error_message, 1, 12),
                                                    substr(l_v_error_message, 10, 3),
                                                    l_v_error_message,
                                                    l_v_error_message) != 0 THEN
            g_rec_status.b_error := TRUE;
          END IF;

        END IF;

        IF NOT f_get_container_yard_dt(cur_res_import_decl_h.bl_no,
                                       cur_res_import_decl_h.bl_dt,
                                       l_v_inv_no_yard,
                                       l_d_inv_dt_yard,
                                       l_v_container_no_yard,
                                       l_d_yard_arrival_dt_yard,
                                       l_d_warehouse_arrival_dt_yard,
                                       l_v_error_message) THEN

          g_rec_status.b_error := TRUE;
          g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
          IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                    g_rec_status.n_seq_no,
                                                    'Get Container Yard Date',
                                                    substr(l_v_error_message, 1, 12),
                                                    substr(l_v_error_message, 10, 3),
                                                    l_v_error_message,
                                                    l_v_error_message) != 0 THEN
            g_rec_status.b_error := TRUE;
          END IF;

        END IF;

        IF cur_res_import_decl_h.import_decl_dt IS NULL THEN

          IF l_d_warehouse_dt_unpacked IS NOT NULL THEN

            g_rec_status.b_error := TRUE;
            l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'Error! At least one module has already arrived at Warehouse or Unpacked for [Invoice No] = [' || l_v_inv_no_unpacked || '] [Invoice Date] = [' || l_d_inv_dt_unpacked || '] [Container No] = [' || l_v_container_no_unpacked || '] [Module No] = [' || l_v_module_no_unpacked || '] [Case No] = [' || l_v_case_no_unpacked || '] [Lot No] = [' || l_v_lot_no_unpacked || ']');
            g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
            IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                      g_rec_status.n_seq_no,
                                                      'Check Unpacked at Warehouse',
                                                      substr(l_v_error_message, 1, 12),
                                                      substr(l_v_error_message, 10, 3),
                                                      l_v_error_message,
                                                      l_v_error_message) != 0 THEN
              g_rec_status.b_error := TRUE;
            END IF;

          END IF;

          IF l_d_warehouse_arrival_dt_yard IS NOT NULL THEN

            g_rec_status.b_error := TRUE;
            l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'Error! At least one module has already arrived at Warehouse or Unpacked for [Invoice No] = [' || l_v_inv_no_yard || '] [Invoice Date] = [' || l_d_inv_dt_yard || '] [Container No] = [' || l_v_container_no_yard || ']');
            g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
            IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                      g_rec_status.n_seq_no,
                                                      'Check Container at Container Yard',
                                                      substr(l_v_error_message, 1, 12),
                                                      substr(l_v_error_message, 10, 3),
                                                      l_v_error_message,
                                                      l_v_error_message) != 0 THEN
              g_rec_status.b_error := TRUE;
            END IF;

          END IF;

        ELSE

          IF cur_res_import_decl_h.import_decl_dt < cur_res_import_decl_h.submission_dt THEN

            g_rec_status.b_error := TRUE;
            l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'Error! Import Declaration Date is earlier than Submission Date');
            g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
            IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                      g_rec_status.n_seq_no,
                                                      'Check Container at Container Yard',
                                                      substr(l_v_error_message, 1, 12),
                                                      substr(l_v_error_message, 10, 3),
                                                      l_v_error_message,
                                                      l_v_error_message) != 0 THEN
              g_rec_status.b_error := TRUE;
            END IF;

          END IF;

          IF l_d_warehouse_arrival_dt_yard IS NOT NULL OR l_d_yard_arrival_dt_yard IS NOT NULL THEN

            IF cur_res_import_decl_h.import_decl_dt > l_d_warehouse_arrival_dt_yard
            OR cur_res_import_decl_h.import_decl_dt > l_d_yard_arrival_dt_yard THEN

              g_rec_status.b_error := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'Error! Yard Arrival Date or Warehouse Arrival Date is earlier than Import Declaration Date for [Invoice No|Invoice Date|Container No] = [' || l_v_inv_no_yard  || '|' || l_d_inv_dt_yard  || '|' || l_v_container_no_yard || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Container at Container Yard',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

          IF l_d_warehouse_dt_unpacked IS NOT NULL OR l_d_unpacking_dt_unpacked IS NOT NULL THEN

            IF cur_res_import_decl_h.import_decl_dt > l_d_warehouse_dt_unpacked
            OR cur_res_import_decl_h.import_decl_dt > l_d_unpacking_dt_unpacked THEN

              g_rec_status.b_error := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00349ERR', 'Error! Warehouse Arrival Date or Unpacking Date is earlier than Import Declaration Date for [Invoice No|Invoice Date|Container No|Module No|Case No|Lot No] = [' || l_v_inv_no_unpacked || '|' || l_d_inv_dt_unpacked || '|' || l_v_container_no_unpacked || '|' || l_v_module_no_unpacked || '|' || l_v_case_no_unpacked || '|' || l_v_lot_no_unpacked || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Container at Container Yard',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END IF;

      END LOOP;

    END IF;

    IF NOT g_rec_status.b_error THEN

      FOR cur_res_pib IN (SELECT a.car, a.submission_no, a.submission_dt, b.car car_r_res_pibhdr,
                                 a.new_kdkpbc,
                                 a.new_pibno,
                                 a.new_pibtg,
                                 a.new_jnpib,
                                 a.new_jnimp,
                                 a.new_jkwaktu,
                                 a.new_crbyr,
                                 a.new_doktupkd,
                                 a.new_doktupno,
                                 a.new_doktuptg,
                                 a.new_posno,
                                 a.new_possub,
                                 a.new_possubsub,
                                 a.new_impid,
                                 a.new_impnpwp,
                                 a.new_impnama,
                                 a.new_impalmt,
                                 a.new_apikd,
                                 a.new_apino,
                                 a.new_ppjknpwp,
                                 a.new_ppjknama,
                                 a.new_ppjkalmt,
                                 a.new_ppjkno,
                                 a.new_ppjktg,
                                 a.new_indid,
                                 a.new_indnpwp,
                                 a.new_indnama,
                                 a.new_indalmt,
                                 a.new_pasoknama,
                                 a.new_pasokalmt,
                                 a.new_pasokneg,
                                 a.new_pelbkr,
                                 a.new_pelmuat,
                                 a.new_peltransit,
                                 a.new_tmptbn,
                                 a.new_moda,
                                 a.new_angkutnama,
                                 a.new_angkutno,
                                 a.new_angkutfl,
                                 a.new_tgtiba,
                                 a.new_kdval,
                                 a.new_ndpbm,
                                 a.new_nilinv,
                                 a.new_freight,
                                 a.new_btambahan,
                                 a.new_diskon,
                                 a.new_kdass,
                                 a.new_asuransi,
                                 a.new_kdhrg,
                                 a.new_fob,
                                 a.new_cif,
                                 a.new_bruto,
                                 a.new_netto,
                                 a.new_jmcont,
                                 a.new_jmbrg,
                                 a.new_status,
                                 a.new_snrf,
                                 a.new_kdfas,
                                 a.new_lengkap,
                                 a.new_doc_cd,
                                 a.new_doc_no,
                                 a.new_doc_desc,
                                 a.new_doc_dt,
                                 a.new_doc_inst
                            FROM (SELECT a.car, substr(a.car, 21, 6) submission_no, to_date(substr(a.car, 13, 8), 'YYYYMMDD') submission_dt,
                                         a.kdkpbc new_kdkpbc,
                                         a.pibno new_pibno,
                                         a.pibtg new_pibtg,
                                         a.jnpib new_jnpib,
                                         a.jnimp new_jnimp,
                                         a.jkwaktu new_jkwaktu,
                                         a.crbyr new_crbyr,
                                         a.doktupkd new_doktupkd,
                                         a.doktupno new_doktupno,
                                         a.doktuptg new_doktuptg,
                                         a.posno new_posno,
                                         a.possub new_possub,
                                         a.possubsub new_possubsub,
                                         a.impid new_impid,
                                         a.impnpwp new_impnpwp,
                                         a.impnama new_impnama,
                                         a.impalmt new_impalmt,
                                         a.apikd new_apikd,
                                         a.apino new_apino,
                                         a.ppjknpwp new_ppjknpwp,
                                         a.ppjknama new_ppjknama,
                                         a.ppjkalmt new_ppjkalmt,
                                         a.ppjkno new_ppjkno,
                                         a.ppjktg new_ppjktg,
                                         a.indid new_indid,
                                         a.indnpwp new_indnpwp,
                                         a.indnama new_indnama,
                                         a.indalmt new_indalmt,
                                         a.pasoknama new_pasoknama,
                                         a.pasokalmt new_pasokalmt,
                                         a.pasokneg new_pasokneg,
                                         a.pelbkr new_pelbkr,
                                         a.pelmuat new_pelmuat,
                                         a.peltransit new_peltransit,
                                         a.tmptbn new_tmptbn,
                                         a.moda new_moda,
                                         a.angkutnama new_angkutnama,
                                         a.angkutno new_angkutno,
                                         a.angkutfl new_angkutfl,
                                         a.tgtiba new_tgtiba,
                                         a.kdval new_kdval,
                                         a.ndpbm new_ndpbm,
                                         a.nilinv new_nilinv,
                                         a.freight new_freight,
                                         a.btambahan new_btambahan,
                                         a.diskon new_diskon,
                                         a.kdass new_kdass,
                                         a.asuransi new_asuransi,
                                         a.kdhrg new_kdhrg,
                                         a.fob new_fob,
                                         a.cif new_cif,
                                         a.bruto new_bruto,
                                         a.netto new_netto,
                                         a.jmcont new_jmcont,
                                         a.jmbrg new_jmbrg,
                                         a.status new_status,
                                         a.snrf new_snrf,
                                         a.kdfas new_kdfas,
                                         a.lengkap new_lengkap,
                                         b.dokkd new_doc_cd,
                                         b.dokno new_doc_no,
                                         b.dokdesc new_doc_desc,
                                         b.doktg new_doc_dt,
                                         b.dokinst new_doc_inst
                                    FROM tb_t_res_pibhdr a,
                                         tb_t_res_pibdok b
                                   WHERE substr(a.car, 21, 6) = substr(b.car, 21, 6)
                                     AND substr(a.car, 13, 8) = substr(b.car, 13, 8)
                                     AND b.dokkd = '705') a,
                                 (SELECT a.car, b.submission_no, b.submission_dt
                                    FROM tb_r_res_pibhdr a,
                                         tb_r_res_import_decl_doc b
                                   WHERE substr(a.car, 21, 6) = b.submission_no
                                     AND to_date(substr(a.car, 13, 8), 'YYYYMMDD') = b.submission_dt
                                     AND b.doc_cd = '705') b
                           WHERE a.car = b.car(+)
                             AND a.submission_no = b.submission_no(+)
                             AND a.submission_dt = b.submission_dt(+)
                         ) LOOP

        --Check Duplication
        IF cur_res_pib.car_r_res_pibhdr IS NOT NULL THEN

          IF g_rec_status.v_replace_flag = 'N' THEN

            g_rec_status.b_warning := TRUE;
            g_rec_status.b_error_per_submission := TRUE;
            l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Duplication found for [Submission No] = [' || cur_res_pib.submission_no || '] [Submission Date] = [' || cur_res_pib.submission_dt || ']');
            g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
            IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                      g_rec_status.n_seq_no,
                                                      'Check Duplication',
                                                      substr(l_v_error_message, 1, 12),
                                                      substr(l_v_error_message, 10, 3),
                                                      l_v_error_message,
                                                      l_v_error_message) != 0 THEN
              g_rec_status.b_error := TRUE;
            END IF;

          ELSE

            IF NOT f_upd_r_res_pibhdr(cur_res_pib.car,
                                      cur_res_pib.new_kdkpbc,
                                      cur_res_pib.new_pibno,
                                      cur_res_pib.new_pibtg,
                                      cur_res_pib.new_jnpib,
                                      cur_res_pib.new_jnimp,
                                      cur_res_pib.new_jkwaktu,
                                      cur_res_pib.new_crbyr,
                                      cur_res_pib.new_doktupkd,
                                      cur_res_pib.new_doktupno,
                                      cur_res_pib.new_doktuptg,
                                      cur_res_pib.new_posno,
                                      cur_res_pib.new_possub,
                                      cur_res_pib.new_possubsub,
                                      cur_res_pib.new_impid,
                                      cur_res_pib.new_impnpwp,
                                      cur_res_pib.new_impnama,
                                      cur_res_pib.new_impalmt,
                                      cur_res_pib.new_apikd,
                                      cur_res_pib.new_apino,
                                      cur_res_pib.new_ppjknpwp,
                                      cur_res_pib.new_ppjknama,
                                      cur_res_pib.new_ppjkalmt,
                                      cur_res_pib.new_ppjkno,
                                      cur_res_pib.new_ppjktg,
                                      cur_res_pib.new_indid,
                                      cur_res_pib.new_indnpwp,
                                      cur_res_pib.new_indnama,
                                      cur_res_pib.new_indalmt,
                                      cur_res_pib.new_pasoknama,
                                      cur_res_pib.new_pasokalmt,
                                      cur_res_pib.new_pasokneg,
                                      cur_res_pib.new_pelbkr,
                                      cur_res_pib.new_pelmuat,
                                      cur_res_pib.new_peltransit,
                                      cur_res_pib.new_tmptbn,
                                      cur_res_pib.new_moda,
                                      cur_res_pib.new_angkutnama,
                                      cur_res_pib.new_angkutno,
                                      cur_res_pib.new_angkutfl,
                                      cur_res_pib.new_tgtiba,
                                      cur_res_pib.new_kdval,
                                      cur_res_pib.new_ndpbm,
                                      cur_res_pib.new_nilinv,
                                      cur_res_pib.new_freight,
                                      cur_res_pib.new_btambahan,
                                      cur_res_pib.new_diskon,
                                      cur_res_pib.new_kdass,
                                      cur_res_pib.new_asuransi,
                                      cur_res_pib.new_kdhrg,
                                      cur_res_pib.new_fob,
                                      cur_res_pib.new_cif,
                                      cur_res_pib.new_bruto,
                                      cur_res_pib.new_netto,
                                      cur_res_pib.new_jmcont,
                                      cur_res_pib.new_jmbrg,
                                      cur_res_pib.new_status,
                                      cur_res_pib.new_snrf,
                                      cur_res_pib.new_kdfas,
                                      cur_res_pib.new_lengkap,
                                      l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update PIB Header',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

            ELSE

              IF NOT f_upd_r_res_import_decl_doc(cur_res_pib.car,
                                                 cur_res_pib.submission_no,
                                                 cur_res_pib.submission_dt,
                                                 cur_res_pib.new_doc_no,
                                                 cur_res_pib.new_doc_cd,
                                                 cur_res_pib.new_doc_desc,
                                                 cur_res_pib.new_doc_dt,
                                                 cur_res_pib.new_doc_inst,
                                                 l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update Import Declaration Doc',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

            END IF;

          END IF;

        ELSE

          IF NOT f_ins_r_res_pibhdr(cur_res_pib.car,
                                    l_v_error_message) THEN

            g_rec_status.b_error := TRUE;
            g_rec_status.b_warning := TRUE;
            g_rec_status.b_error_per_submission := TRUE;
            g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
            IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                      g_rec_status.n_seq_no,
                                                      'Insert PIB Header',
                                                      substr(l_v_error_message, 1, 12),
                                                      substr(l_v_error_message, 10, 3),
                                                      l_v_error_message,
                                                      l_v_error_message) != 0 THEN
              g_rec_status.b_error := TRUE;
            END IF;

          ELSE

            IF NOT f_ins_r_res_import_decl_doc(cur_res_pib.submission_no,
                                               cur_res_pib.submission_dt,
                                               l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Insert Import Declaration Doc',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END IF;

        FOR cur_duplicate_res_pibdtl IN (SELECT a.car, a.serial, b.car car_r_res_pibdtl
                                           FROM tb_t_res_pibdtl a,
                                                tb_r_res_pibdtl b
                                          WHERE substr(a.car, 21, 6) = cur_res_pib.submission_no
                                            AND to_date(substr(a.car, 13, 8), 'YYYYMMDD') = cur_res_pib.submission_dt
                                            AND a.car = b.car(+)
                                            AND a.serial = b.serial(+)) LOOP

          IF cur_duplicate_res_pibdtl.car_r_res_pibdtl IS NOT NULL THEN

            IF g_rec_status.v_replace_flag = 'N' THEN

              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Duplication found in TB_T_RES_PIBDTL for [CAR] = [' || cur_duplicate_res_pibdtl.car || '] [Serial] = [' || cur_duplicate_res_pibdtl.serial || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Duplication',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            ELSE

              IF NOT f_upd_r_res_pibdtl(cur_duplicate_res_pibdtl.car,
                                        cur_duplicate_res_pibdtl.serial,
                                        l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update PIB Detail',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

            END IF;

          ELSE

            IF NOT f_ins_r_res_pibdtl(cur_duplicate_res_pibdtl.car,
                                      cur_duplicate_res_pibdtl.serial,
                                      l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Insert PIB Detail',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END LOOP;

        FOR cur_duplicate_res_pibtrf IN (SELECT a.car, a.nohs, a.seritrp, b.car car_r_res_pibtrf
                                           FROM tb_t_res_pibtrf a,
                                                tb_r_res_pibtrf b
                                          WHERE substr(a.car, 21, 6) = cur_res_pib.submission_no
                                            AND to_date(substr(a.car, 13, 8), 'YYYYMMDD') = cur_res_pib.submission_dt
                                            AND a.car = b.car(+)
                                            AND a.nohs = b.nohs(+)
                                            AND a.seritrp = b.seritrp(+)) LOOP

          IF cur_duplicate_res_pibtrf.car_r_res_pibtrf IS NOT NULL THEN

            IF g_rec_status.v_replace_flag = 'N' THEN

              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Duplication found in TB_T_RES_PIBTRF for [CAR] = [' || cur_duplicate_res_pibtrf.car || '] [NOHS] = [' || cur_duplicate_res_pibtrf.nohs || '] [Serial] = [' || cur_duplicate_res_pibtrf.seritrp || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Duplication',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            ELSE

              IF NOT f_upd_r_res_pibtrf(cur_duplicate_res_pibtrf.car,
                                        cur_duplicate_res_pibtrf.nohs,
                                        cur_duplicate_res_pibtrf.seritrp,
                                        l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update PIB Transfer',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

            END IF;

          ELSE

            IF NOT f_ins_r_res_pibtrf(cur_duplicate_res_pibtrf.car,
                                      cur_duplicate_res_pibtrf.nohs,
                                      cur_duplicate_res_pibtrf.seritrp,
                                      l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Insert PIB Transfer',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

          END IF;

        END LOOP;

        FOR cur_duplicate_res_pibcon IN (SELECT a.car, a.contno, b.car car_r_res_pibcon
                                           FROM tb_t_res_pibcon a,
                                                tb_r_res_pibcon b
                                          WHERE substr(a.car, 21, 6) = cur_res_pib.submission_no
                                            AND to_date(substr(a.car, 13, 8), 'YYYYMMDD') = cur_res_pib.submission_dt
                                            AND a.car = b.car(+)
                                            AND a.contno = b.contno(+)) LOOP

          IF cur_duplicate_res_pibcon.car_r_res_pibcon IS NOT NULL THEN

            IF g_rec_status.v_replace_flag = 'N' THEN

              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Duplication found in TB_T_RES_PIBCON for [CAR] = [' || cur_duplicate_res_pibcon.car || '] [Container No] = [' || cur_duplicate_res_pibcon.contno || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Duplication',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            ELSE

              IF NOT f_upd_r_res_pibcon(cur_duplicate_res_pibcon.car,
                                        cur_duplicate_res_pibcon.contno,
                                        l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update PIB Container',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

            END IF;

          ELSE

            IF NOT f_ins_r_res_pibcon(cur_duplicate_res_pibcon.car,
                                      cur_duplicate_res_pibcon.contno,
                                      l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Insert PIB Container',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END LOOP;

        FOR cur_duplicate_res_pibres IN (SELECT a.car, a.reskd, a.restg, a.reswk, b.car car_r_res_pibres
                                           FROM tb_t_res_pibres a,
                                                tb_r_res_pibres b
                                          WHERE substr(a.car, 21, 6) = cur_res_pib.submission_no
                                            AND to_date(substr(a.car, 13, 8), 'YYYYMMDD') = cur_res_pib.submission_dt
                                            AND a.car = b.car(+)
                                            AND a.reskd = b.reskd(+)
                                            AND a.restg = b.restg(+)
                                            AND a.reswk = b.reswk(+)) LOOP

          IF cur_duplicate_res_pibres.car_r_res_pibres IS NOT NULL THEN

            IF g_rec_status.v_replace_flag = 'N' THEN

              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Duplication found in TB_T_RES_PIBRES for [CAR] = [' || cur_duplicate_res_pibres.car || '] [Response Code] = [' || cur_duplicate_res_pibres.reskd || '] [Response Date] = [' || cur_duplicate_res_pibres.restg || '] [Response Time] = [' || cur_duplicate_res_pibres.reswk || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Duplication',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            ELSE

              IF NOT f_upd_r_res_pibres(cur_duplicate_res_pibres.car,
                                        cur_duplicate_res_pibres.reskd,
                                        cur_duplicate_res_pibres.restg,
                                        cur_duplicate_res_pibres.reswk,
                                        l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update PIB Res',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

            END IF;

          ELSE

            IF NOT f_ins_r_res_pibres(cur_duplicate_res_pibres.car,
                                      cur_duplicate_res_pibres.reskd,
                                      cur_duplicate_res_pibres.restg,
                                      cur_duplicate_res_pibres.reswk,
                                      l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Insert PIB Res',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END LOOP;

        FOR cur_duplicate_res_pibpgt IN (SELECT a.car, a.kdbeban, a.kdfasil, b.car car_r_res_pibpgt
                                           FROM tb_t_res_pibpgt a,
                                                tb_r_res_pibpgt b
                                          WHERE substr(a.car, 21, 6) = cur_res_pib.submission_no
                                            AND to_date(substr(a.car, 13, 8), 'YYYYMMDD') = cur_res_pib.submission_dt
                                            AND a.car = b.car(+)
                                            AND a.kdbeban = b.kdbeban(+)
                                            AND a.kdfasil = b.kdfasil(+)) LOOP

          IF cur_duplicate_res_pibpgt.car_r_res_pibpgt IS NOT NULL THEN
            IF g_rec_status.v_replace_flag = 'N' THEN

              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Duplication found in TB_T_RES_PIBPGT for [CAR] = [' || cur_duplicate_res_pibpgt.car || '] [Tax Code] = [' || cur_duplicate_res_pibpgt.kdbeban || '] [Tariff Type] = [' || cur_duplicate_res_pibpgt.kdfasil || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Duplication',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            ELSE

              IF NOT f_upd_r_res_pibpgt(cur_duplicate_res_pibpgt.car,
                                        cur_duplicate_res_pibpgt.kdbeban,
                                        cur_duplicate_res_pibpgt.kdfasil,
                                        l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update PIB PGT',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

            END IF;

          ELSE

            IF NOT f_ins_r_res_pibpgt(cur_duplicate_res_pibpgt.car,
                                      cur_duplicate_res_pibpgt.kdbeban,
                                      cur_duplicate_res_pibpgt.kdfasil,
                                      l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Insert PIB PGT',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END LOOP;

        FOR cur_duplicate_res_pibfas IN (SELECT a.car, a.serial, b.car car_r_res_pibfas
                                           FROM tb_t_res_pibfas a,
                                                tb_r_res_pibfas b
                                          WHERE substr(a.car, 21, 6) = cur_res_pib.submission_no
                                            AND to_date(substr(a.car, 13, 8), 'YYYYMMDD') = cur_res_pib.submission_dt
                                            AND a.car = b.car(+)
                                            AND a.serial = b.serial(+)) LOOP

          IF cur_duplicate_res_pibfas.car_r_res_pibfas IS NOT NULL THEN

            IF g_rec_status.v_replace_flag = 'N' THEN

              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Duplication found in TB_T_RES_PIBFAS for [CAR] = [' || cur_duplicate_res_pibfas.car || '] [Serial] = [' || cur_duplicate_res_pibfas.serial || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Duplication',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            ELSE

              IF NOT f_upd_r_res_pibfas(cur_duplicate_res_pibfas.car,
                                        cur_duplicate_res_pibfas.serial,
                                        l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update PIB FAS',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

            END IF;

          ELSE

            IF NOT f_ins_r_res_pibfas(cur_duplicate_res_pibfas.car,
                                      cur_duplicate_res_pibfas.serial,
                                      l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Insert PIB PGT',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END LOOP;
        
        
        /* Teguh 20180225 */
        FOR cur_duplicate_res_pibdtldok IN (SELECT a.car, a.dokkd, a.dokno, a.serial, b.car car_r_res_pibdtldok
                                           FROM tb_t_res_pibdtldok a,
                                                tb_r_res_pibdtldok b
                                          WHERE substr(a.car, 21, 6) = cur_res_pib.submission_no
                                            AND to_date(substr(a.car, 13, 8), 'YYYYMMDD') = cur_res_pib.submission_dt
                                            AND a.car = b.car(+)
                                            AND a.dokkd = b.dokkd (+)
                                            AND a.dokno = b.dokno (+)
                                            AND a.serial = b.serial(+)) LOOP

          IF cur_duplicate_res_pibdtldok.car_r_res_pibdtldok IS NOT NULL THEN

            IF g_rec_status.v_replace_flag = 'N' THEN

              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Duplication found in TB_T_RES_PIBDTLDOK for [CAR] = [' || cur_duplicate_res_pibdtldok.car || '] [Dok Kd] = [' || cur_duplicate_res_pibdtldok.dokkd || '] [Dok No] = [' || cur_duplicate_res_pibdtldok.dokno || '] [Serial] = [' || cur_duplicate_res_pibdtldok.serial || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Duplication',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            ELSE

              IF NOT f_upd_r_res_pibdtldok (cur_duplicate_res_pibdtldok.car,
                                        cur_duplicate_res_pibdtldok.dokkd,
                                        cur_duplicate_res_pibdtldok.dokno,
                                        cur_duplicate_res_pibdtldok.serial,
                                        l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update PIB DTL DOK',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

            END IF;

          ELSE

            IF NOT f_ins_r_res_pibdtldok(cur_duplicate_res_pibdtldok.car,
                                        cur_duplicate_res_pibdtldok.dokkd,
                                        cur_duplicate_res_pibdtldok.dokno,
                                        cur_duplicate_res_pibdtldok.serial,
                                      l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Insert PIB DTL DOK',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END LOOP;
        
        FOR cur_duplicate_res_pibdok IN (SELECT a.car, a.dokkd, a.dokno, b.car car_r_res_pibdok
                                           FROM tb_t_res_pibdok a,
                                                tb_r_res_pibdok b
                                          WHERE substr(a.car, 21, 6) = cur_res_pib.submission_no
                                            AND to_date(substr(a.car, 13, 8), 'YYYYMMDD') = cur_res_pib.submission_dt
                                            AND a.car = b.car(+)
                                            AND a.dokkd = b.dokkd (+)
                                            AND a.dokno = b.dokno (+)) LOOP

          IF cur_duplicate_res_pibdok.car_r_res_pibdok IS NOT NULL THEN

            IF g_rec_status.v_replace_flag = 'N' THEN

              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Duplication found in TB_T_RES_pibdok for [CAR] = [' || cur_duplicate_res_pibdok.car || '] [Dok Kd] = [' || cur_duplicate_res_pibdok.dokkd || '] [Dok No] = [' || cur_duplicate_res_pibdok.dokno || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Duplication',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            ELSE

              IF NOT f_upd_r_res_pibdok (cur_duplicate_res_pibdok.car,
                                        cur_duplicate_res_pibdok.dokkd,
                                        cur_duplicate_res_pibdok.dokno,
                                        l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update PIB DOK',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

            END IF;

          ELSE

            IF NOT f_ins_r_res_pibdok(cur_duplicate_res_pibdok.car,
                                        cur_duplicate_res_pibdok.dokkd,
                                        cur_duplicate_res_pibdok.dokno,
                                      l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Insert PIB DOK',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END LOOP;
        
        FOR cur_duplicate_res_pibkms IN (SELECT a.car, a.jnkemas, a.merkkemas, b.car car_r_res_pibkms
                                           FROM tb_t_res_pibkms a,
                                                tb_r_res_pibkms b
                                          WHERE substr(a.car, 21, 6) = cur_res_pib.submission_no
                                            AND to_date(substr(a.car, 13, 8), 'YYYYMMDD') = cur_res_pib.submission_dt
                                            AND a.car = b.car(+)
                                            AND a.jnkemas = b.jnkemas(+)
                                            AND a.merkkemas = b.merkkemas (+)) LOOP

          IF cur_duplicate_res_pibkms.car_r_res_pibkms IS NOT NULL THEN

            IF g_rec_status.v_replace_flag = 'N' THEN

              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Duplication found in TB_T_RES_pibkms for [CAR] = [' || cur_duplicate_res_pibkms.car || '] [Jenis Kemas] = [' || cur_duplicate_res_pibkms.jnkemas || '] [Merk Kemas] = [' || cur_duplicate_res_pibkms.merkkemas || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Duplication',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            ELSE

              IF NOT f_upd_r_res_pibkms (cur_duplicate_res_pibkms.car,
                                        cur_duplicate_res_pibkms.jnkemas,
                                        cur_duplicate_res_pibkms.merkkemas,
                                        l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update PIB KMS',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

            END IF;

          ELSE

            IF NOT f_ins_r_res_pibkms(cur_duplicate_res_pibkms.car,
                                      cur_duplicate_res_pibkms.jnkemas,
                                      cur_duplicate_res_pibkms.merkkemas,
                                      l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Insert PIB KMS',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END LOOP;
        
        FOR cur_duplicate_res_pibdtlvd IN (SELECT a.car, a.serial, b.car car_r_res_pibdtlvd
                                           FROM tb_t_res_pibdtlvd a,
                                                tb_r_res_pibdtlvd b
                                          WHERE substr(a.car, 21, 6) = cur_res_pib.submission_no
                                            AND to_date(substr(a.car, 13, 8), 'YYYYMMDD') = cur_res_pib.submission_dt
                                            AND a.car = b.car(+)
                                            AND a.serial = b.serial(+)) LOOP

          IF cur_duplicate_res_pibdtlvd.car_r_res_pibdtlvd IS NOT NULL THEN

            IF g_rec_status.v_replace_flag = 'N' THEN

              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Duplication found in TB_T_RES_pibdtlvd for [CAR] = [' || cur_duplicate_res_pibdtlvd.car || '] [Serial] = [' || cur_duplicate_res_pibdtlvd.serial || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Duplication',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            ELSE

              IF NOT f_upd_r_res_pibdtlvd(cur_duplicate_res_pibdtlvd.car,
                                        cur_duplicate_res_pibdtlvd.serial,
                                        l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update PIB Dtlvd',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

            END IF;

          ELSE

            IF NOT f_ins_r_res_pibdtlvd(cur_duplicate_res_pibdtlvd.car,
                                      cur_duplicate_res_pibdtlvd.serial,
                                      l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Insert PIB DTL VD',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END LOOP;
        
        
        FOR cur_duplicate_res_pibkendaraan IN (SELECT a.car, a.serial, b.car car_r_res_pibkendaraan
                                           FROM tb_t_res_pibkendaraan a,
                                                tb_r_res_pibkendaraan b
                                          WHERE substr(a.car, 21, 6) = cur_res_pib.submission_no
                                            AND to_date(substr(a.car, 13, 8), 'YYYYMMDD') = cur_res_pib.submission_dt
                                            AND a.car = b.car(+)
                                            AND a.serial = b.serial(+)) LOOP

          IF cur_duplicate_res_pibkendaraan.car_r_res_pibkendaraan IS NOT NULL THEN

            IF g_rec_status.v_replace_flag = 'N' THEN

              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Duplication found in TB_T_RES_pibkendaraan for [CAR] = [' || cur_duplicate_res_pibkendaraan.car || '] [Serial] = [' || cur_duplicate_res_pibkendaraan.serial || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Duplication',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            ELSE

              IF NOT f_upd_r_res_pibkendaraan(cur_duplicate_res_pibkendaraan.car,
                                        cur_duplicate_res_pibkendaraan.serial,
                                        l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update PIB Kendaraan',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

            END IF;

          ELSE

            IF NOT f_ins_r_res_pibkendaraan(cur_duplicate_res_pibkendaraan.car,
                                      cur_duplicate_res_pibkendaraan.serial,
                                      l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Insert PIB Kendaraan',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END LOOP;
        
        FOR cur_dup_res_pibdtlspekkhusus IN (SELECT a.car, a.serial, a.cas1, a.cas2, b.car car_r_res_pibdtlspekkhusus
                                           FROM tb_t_res_pibdtlspekkhusus a,
                                                tb_r_res_pibdtlspekkhusus b
                                          WHERE substr(a.car, 21, 6) = cur_res_pib.submission_no
                                            AND to_date(substr(a.car, 13, 8), 'YYYYMMDD') = cur_res_pib.submission_dt
                                            AND a.car = b.car(+)
                                            AND a.serial = b.serial(+)
                                            AND a.cas1 = b.cas1 (+)
                                            AND a.cas2 = b.cas2 (+)) LOOP

          IF cur_dup_res_pibdtlspekkhusus.car_r_res_pibdtlspekkhusus IS NOT NULL THEN

            IF g_rec_status.v_replace_flag = 'N' THEN

              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Duplication found in TB_T_RES_pibdtlspekkhusus for [CAR] = [' || cur_dup_res_pibdtlspekkhusus.car || '] [Serial] = [' || cur_dup_res_pibdtlspekkhusus.serial || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Duplication',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          ELSE

            IF NOT f_ins_r_res_pibdtlspekkhusus(cur_dup_res_pibdtlspekkhusus.car,
                                      cur_dup_res_pibdtlspekkhusus.serial,
                                      cur_dup_res_pibdtlspekkhusus.cas1,
                                      cur_dup_res_pibdtlspekkhusus.cas2,
                                      l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Insert PIB DTL Spek Khusus',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END LOOP;
        
        FOR cur_duplicate_res_pibconr IN (SELECT a.car, a.contno, a.reskd, b.car car_r_res_pibconr
                                           FROM tb_t_res_pibconr a,
                                                tb_r_res_pibconr b
                                          WHERE substr(a.car, 21, 6) = cur_res_pib.submission_no
                                            AND to_date(substr(a.car, 13, 8), 'YYYYMMDD') = cur_res_pib.submission_dt
                                            AND a.car = b.car(+)
                                            AND a.contno = b.contno(+)
                                            AND a.reskd = b.reskd (+)) LOOP

          IF cur_duplicate_res_pibconr.car_r_res_pibconr IS NOT NULL THEN

            IF g_rec_status.v_replace_flag = 'N' THEN

              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Duplication found in TB_T_RES_pibconr for [CAR] = [' || cur_duplicate_res_pibconr.car || '] [Cont No] = [' || cur_duplicate_res_pibconr.contno || '] [Kode Respon] = [' || cur_duplicate_res_pibconr.reskd || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Duplication',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            ELSE

              IF NOT f_upd_r_res_pibconr(cur_duplicate_res_pibconr.car,
                                        cur_duplicate_res_pibconr.contno,
                                        cur_duplicate_res_pibconr.reskd,
                                        l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update PIB CON R',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

            END IF;

          ELSE

            IF NOT f_ins_r_res_pibconr(cur_duplicate_res_pibconr.car,
                                        cur_duplicate_res_pibconr.contno,
                                        cur_duplicate_res_pibconr.reskd,
                                      l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Insert PIB Con R',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END LOOP;
        
        FOR cur_duplicate_res_pibnpt IN (SELECT a.car, a.reskd, a.restg, a.reswk, b.car car_r_res_pibnpt
                                           FROM tb_t_res_pibnpt a,
                                                tb_r_res_pibnpt b
                                          WHERE substr(a.car, 21, 6) = cur_res_pib.submission_no
                                            AND to_date(substr(a.car, 13, 8), 'YYYYMMDD') = cur_res_pib.submission_dt
                                            AND a.car = b.car(+)
                                            AND a.reskd = b.reskd (+)
                                            ANd a.restg = b.restg (+)
                                            AND a.reswk = b.reswk (+)) LOOP

          IF cur_duplicate_res_pibnpt.car_r_res_pibnpt IS NOT NULL THEN

            IF g_rec_status.v_replace_flag = 'N' THEN

              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Duplication found in TB_T_RES_pibnpt for [CAR] = [' || cur_duplicate_res_pibnpt.car || '] [Kode Respon] = [' || cur_duplicate_res_pibnpt.reskd || ']  [Tanggal Respon] = [' || cur_duplicate_res_pibnpt.restg || ']  [Waktu Respon] = [' || cur_duplicate_res_pibnpt.reswk || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Duplication',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            ELSE

              IF NOT f_upd_r_res_pibnpt(cur_duplicate_res_pibnpt.car,
                                        cur_duplicate_res_pibnpt.reskd,
                                        cur_duplicate_res_pibnpt.restg,
                                        cur_duplicate_res_pibnpt.reswk,
                                        l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update PIB NPT',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

            END IF;

          ELSE

            IF NOT f_ins_r_res_pibnpt(cur_duplicate_res_pibnpt.car,
                                      cur_duplicate_res_pibnpt.reskd,
                                      cur_duplicate_res_pibnpt.restg,
                                      cur_duplicate_res_pibnpt.reswk,
                                      l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Insert PIB NPT',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END LOOP;
        /*End Teguh */

        FOR cur_duplicate_res_imp_decl_h IN (SELECT a.submission_no, a.submission_dt, a.import_decl_no, a.import_decl_dt, a.bl_no, a.bl_dt, b.submission_no submission_no_res_imp_decl_h
                                               FROM tb_t_res_import_decl_h a,
                                                    tb_r_res_import_decl_h b
                                              WHERE a.submission_no = cur_res_pib.submission_no
                                                AND a.submission_dt = cur_res_pib.submission_dt
                                                AND a.submission_no = b.submission_no(+)
                                                AND a.submission_dt = b.submission_dt(+)
                                                /* Remarked By Iwang #20100527 8UA-B4-0040
                                                AND a.import_decl_no = b.import_decl_no(+)
                                                AND a.import_decl_dt = b.import_decl_dt(+)*/
                                                AND a.bl_no = b.bl_no(+)
                                                AND a.bl_dt = b.bl_dt(+)) LOOP

          IF cur_duplicate_res_imp_decl_h.submission_no_res_imp_decl_h IS NOT NULL THEN

            IF g_rec_status.v_replace_flag = 'N' THEN

              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Duplication found in TB_R_RES_IMPORT_DECL_H for [Submission No] = [' || cur_duplicate_res_imp_decl_h.submission_no || '] [Submission Date] = [' || cur_duplicate_res_imp_decl_h.submission_dt || '] [BL No] = [' || cur_duplicate_res_imp_decl_h.bl_no || '] [BL Date] = [' || cur_duplicate_res_imp_decl_h.bl_dt || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Duplication',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            ELSE

              IF NOT f_upd_r_res_import_decl_h(cur_duplicate_res_imp_decl_h.submission_no,
                                               cur_duplicate_res_imp_decl_h.submission_dt,
                                               cur_duplicate_res_imp_decl_h.import_decl_no,
                                               cur_duplicate_res_imp_decl_h.import_decl_dt,
                                               cur_duplicate_res_imp_decl_h.bl_no,
                                               cur_duplicate_res_imp_decl_h.bl_dt,
                                               l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update Import Declaration Header',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

            END IF;

          ELSE

            IF NOT f_ins_r_res_import_decl_h(cur_duplicate_res_imp_decl_h.submission_no,
                                             cur_duplicate_res_imp_decl_h.submission_dt,
                                             cur_duplicate_res_imp_decl_h.import_decl_no,
                                             cur_duplicate_res_imp_decl_h.import_decl_dt,
                                             cur_duplicate_res_imp_decl_h.bl_no,
                                             cur_duplicate_res_imp_decl_h.bl_dt,
                                             l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Insert Import Declaration Header',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END LOOP;

        FOR cur_duplicate_res_imp_decl_d IN (SELECT a.submission_no, a.submission_dt, a.serial, a.hs_no, a.tariff_serial, b.submission_no submission_no_res_imp_decl_d
                                               FROM tb_t_res_import_decl_d a,
                                                    tb_r_res_import_decl_d b
                                              WHERE a.submission_no = cur_res_pib.submission_no
                                                AND a.submission_dt = cur_res_pib.submission_dt
                                                AND a.submission_no = b.submission_no(+)
                                                AND a.submission_dt = b.submission_dt(+)
                                                AND a.serial = b.serial(+)
                                                AND a.hs_no = b.hs_no(+)
                                                AND a.tariff_serial = b.tariff_serial(+)) LOOP

          IF cur_duplicate_res_imp_decl_d.submission_no_res_imp_decl_d IS NOT NULL THEN

            IF g_rec_status.v_replace_flag = 'N' THEN

              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Duplication found in TB_T_RES_IMPORT_DECL_D for [Submission No] = [' || cur_duplicate_res_imp_decl_d.submission_no || '] [Submission Date] = [' || cur_duplicate_res_imp_decl_d.submission_dt || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Duplication',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            ELSE

              IF NOT f_upd_r_res_import_decl_d(cur_duplicate_res_imp_decl_d.submission_no,
                                               cur_duplicate_res_imp_decl_d.submission_dt,
                                               cur_duplicate_res_imp_decl_d.serial,
                                               cur_duplicate_res_imp_decl_d.hs_no,
                                               cur_duplicate_res_imp_decl_d.tariff_serial,
                                               l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update Import Declaration Header',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

            END IF;

          ELSE

            IF NOT f_ins_r_res_import_decl_d(cur_duplicate_res_imp_decl_d.submission_no,
                                             cur_duplicate_res_imp_decl_d.submission_dt,
                                             cur_duplicate_res_imp_decl_d.serial,
                                             cur_duplicate_res_imp_decl_d.hs_no,
                                             cur_duplicate_res_imp_decl_d.tariff_serial,
                                             l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Insert Import Declaration Header',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END LOOP;

        IF NOT g_rec_status.b_error_per_submission THEN

          IF NOT f_get_res_import_decl_h(cur_res_pib.submission_no,
                                         cur_res_pib.submission_dt,
                                         l_v_import_decl_no,
                                         l_d_import_decl_dt,
                                         l_v_res_doc_no,
                                         l_n_cur_amount,
                                         l_v_bl_no,
                                         l_d_bl_dt,
                                         l_v_error_message) THEN

            g_rec_status.b_warning := TRUE;
            g_rec_status.b_error_per_submission := TRUE;
            g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
            IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                      g_rec_status.n_seq_no,
                                                      'Get Import Declaration Header',
                                                      substr(l_v_error_message, 1, 12),
                                                      substr(l_v_error_message, 10, 3),
                                                      l_v_error_message,
                                                      l_v_error_message) != 0 THEN
              g_rec_status.b_error := TRUE;
            END IF;

          END IF;

        END IF;

        IF NOT g_rec_status.b_error_per_submission THEN

          IF NOT f_upd_r_import_decl_h(cur_res_pib.submission_no,
                                       cur_res_pib.submission_dt,
                                       l_v_import_decl_no,
                                       l_d_import_decl_dt,
                                       /*Modify By Iwang#20100804
                                       Confirm With. Mr. Daus & Mr. Agung
                                       substr(l_v_res_doc_no, 1, 5),*/
                                       substr(l_v_res_doc_no, 1, 6),
                                       l_v_res_doc_no,
                                       g_rec_status.v_user_id,
                                       SYSDATE,
                                       g_rec_status.v_user_id,
                                       'Y',
                                       'Y', --CR, added, 17-05-2010
                                       l_v_error_message) THEN

            g_rec_status.b_error := TRUE;
            g_rec_status.b_warning := TRUE;
            g_rec_status.b_error_per_submission := TRUE;
            g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
            IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                      g_rec_status.n_seq_no,
                                                      'Update Import Declaration Header',
                                                      substr(l_v_error_message, 1, 12),
                                                      substr(l_v_error_message, 10, 3),
                                                      l_v_error_message,
                                                      l_v_error_message) != 0 THEN
              g_rec_status.b_error := TRUE;
            END IF;

          END IF;

        END IF;

        --Part Quantity, CIF and Status Validation
        IF NOT g_rec_status.b_error_per_submission THEN

          FOR cur_compare_submission IN (SELECT a.submission_no,
                                                b.submission_dt,
                                                a.submission_item_no,
                                                SUM(a.part_qty) import_decl_part_qty,
                                                MAX(b.part_qty) res_import_decl_part_qty,
                                                SUM(a.part_cif) import_decl_part_cif,
                                                MAX(b.part_cif) res_import_decl_part_cif,
                                                MAX(a.paid_sts) import_decl_paid_sts,
                                                MAX(c.res_import_decl_paid_sts) res_import_decl_paid_sts
                                           FROM tb_r_import_decl_d a,
                                                tb_r_res_import_decl_d b,
                                                (SELECT a.car,
                                                        a.serial,
                                                        CASE
                                                          WHEN b.system_type = 'PAID_STS_1' THEN l_v_non_paid
                                                          ELSE l_v_paid
                                                        END res_import_decl_paid_sts
                                                   FROM tb_r_res_pibfas a,
                                                        tb_m_system b
                                                  WHERE b.system_type LIKE 'PAID_STS%'
                                                    AND a.kdfasbm = b.system_value_txt) c
                                          WHERE a.submission_no = cur_res_pib.submission_no
                                            AND a.submission_dt = cur_res_pib.submission_dt
                                            AND a.submission_no = b.submission_no
                                            AND a.submission_dt = b.submission_dt
                                            AND a.submission_item_no = b.serial
                                            AND a.submission_no = substr(c.car, 21, 6)
                                            AND a.submission_dt = to_date(substr(c.car, 13, 8), 'YYYYMMDD')
                                            AND a.submission_item_no = c.serial
                                          GROUP BY a.submission_no,
                                                   b.submission_dt,
                                                   a.submission_item_no) LOOP

            IF cur_compare_submission.import_decl_part_qty != cur_compare_submission.res_import_decl_part_qty THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Part Quantity between PIB Response Data = [' || cur_compare_submission.res_import_decl_part_qty ||
                                                                                     '] and existing Import Declaration Detail = [' || cur_compare_submission.import_decl_part_qty ||
                                                                                     '] is not same, for [Submission No] = [' || cur_compare_submission.submission_no ||
                                                                                     '] [Submission Date] = [' || cur_compare_submission.submission_dt ||
                                                                                     '] [Submission Item No] = [' || cur_compare_submission.submission_item_no ||
                                                                                     '] [Paid Status] = [' || cur_compare_submission.import_decl_paid_sts || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Invalid Submission',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

            IF cur_compare_submission.import_decl_part_cif != cur_compare_submission.res_import_decl_part_cif THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Part CIF between PIB Response Data = [' || cur_compare_submission.res_import_decl_part_cif ||
                                                                                     '] and existing Import Declaration Detail = [' || cur_compare_submission.import_decl_part_cif ||
                                                                                     '] is not same, for [Submission No] = [' || cur_compare_submission.submission_no ||
                                                                                     '] [Submission Date] = [' || cur_compare_submission.submission_dt ||
                                                                                     '] [Submission Item No] = [' || cur_compare_submission.submission_item_no ||
                                                                                     '] [Paid Status] = [' || cur_compare_submission.import_decl_paid_sts || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Invalid Submission',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

            IF cur_compare_submission.import_decl_paid_sts != cur_compare_submission.res_import_decl_paid_sts THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              l_v_error_message := pkg_common_general.fn_get_message('MSTD00006ERR', 'Paid Status between PIB Response Data = [' || cur_compare_submission.res_import_decl_paid_sts ||
                                                                                     '] and existing Import Declaration Detail = [' || cur_compare_submission.import_decl_paid_sts ||
                                                                                     '] is not same, for [Submission No] = [' || cur_compare_submission.submission_no ||
                                                                                     '] [Submission Date] = [' || cur_compare_submission.submission_dt ||
                                                                                     '] [Submission Item No] = [' || cur_compare_submission.submission_item_no ||
                                                                                     '] [Paid Status] = [' || cur_compare_submission.import_decl_paid_sts || ']');
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Check Invalid Submission',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

            IF cur_compare_submission.import_decl_part_qty = cur_compare_submission.res_import_decl_part_qty AND
               cur_compare_submission.import_decl_part_cif = cur_compare_submission.res_import_decl_part_cif AND
               cur_compare_submission.import_decl_paid_sts = cur_compare_submission.res_import_decl_paid_sts THEN

              IF NOT f_upd_r_import_decl_d(cur_compare_submission.submission_no,
                                           cur_compare_submission.submission_dt,
                                           cur_compare_submission.submission_item_no,
                                           cur_compare_submission.import_decl_paid_sts,
                                           l_v_import_decl_no,
                                           l_d_import_decl_dt,
                                           l_v_error_message) THEN

                g_rec_status.b_error := TRUE;
                g_rec_status.b_warning := TRUE;
                g_rec_status.b_error_per_submission := TRUE;
                g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
                IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                          g_rec_status.n_seq_no,
                                                          'Update Import Declaration Detail',
                                                          substr(l_v_error_message, 1, 12),
                                                          substr(l_v_error_message, 10, 3),
                                                          l_v_error_message,
                                                          l_v_error_message) != 0 THEN
                  g_rec_status.b_error := TRUE;
                END IF;

              END IF;

            END IF;

          END LOOP;

        END IF;

        IF NOT g_rec_status.b_error_per_submission THEN

          IF NOT f_upd_r_sd_inv_pxp(l_v_bl_no,
                                    l_d_bl_dt,
                                    l_n_cur_amount,
                                    l_v_error_message) THEN

            g_rec_status.b_error := TRUE;
            g_rec_status.b_warning := TRUE;
            g_rec_status.b_error_per_submission := TRUE;
            g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
            IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                      g_rec_status.n_seq_no,
                                                      'Update SD Invoice PxP',
                                                      substr(l_v_error_message, 1, 12),
                                                      substr(l_v_error_message, 10, 3),
                                                      l_v_error_message,
                                                      l_v_error_message) != 0 THEN
              g_rec_status.b_error := TRUE;
            END IF;

          END IF;

        END IF;

        IF f_check_not_arrived_unpacked THEN

          IF g_rec_status.b_error_per_submission THEN

            IF NOT f_upd_r_sd_invoice(l_v_bl_no,
                                      l_d_bl_dt,
                                      'CCLR',
                                      l_d_import_decl_dt,
                                      l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Update SD Invoice',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

          IF NOT g_rec_status.b_error_per_submission THEN

            IF NOT f_upd_r_sd_container(l_v_bl_no,
                                        l_d_bl_dt,
                                        'CCLR',
                                        l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Update SD Container',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

          IF NOT g_rec_status.b_error_per_submission THEN

            IF NOT f_upd_r_sd_module(l_v_bl_no,
                                     l_d_bl_dt,
                                     'CCLR',
                                     l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Update SD Container',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        END IF;

        IF NOT g_rec_status.b_error_per_submission THEN

          IF NOT f_upd_r_sd_import_decl_d(l_v_bl_no,
                                          l_d_bl_dt,
                                          l_v_import_decl_no,
                                          l_d_import_decl_dt,
                                          l_v_error_message) THEN

            g_rec_status.b_error := TRUE;
            g_rec_status.b_warning := TRUE;
            g_rec_status.b_error_per_submission := TRUE;
            g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
            IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                      g_rec_status.n_seq_no,
                                                      'Update SD Import Declaration Detail',
                                                      substr(l_v_error_message, 1, 12),
                                                      substr(l_v_error_message, 10, 3),
                                                      l_v_error_message,
                                                      l_v_error_message) != 0 THEN
              g_rec_status.b_error := TRUE;
            END IF;

          END IF;

        END IF;

        IF NOT g_rec_status.b_error_per_submission THEN

          COMMIT;

        ELSE

          ROLLBACK;

        END IF;

        g_rec_status.b_error_per_submission := FALSE;

      END LOOP;

    END IF;

    IF NOT g_rec_status.b_error THEN

      FOR cur_duplicate_exc_rate IN (SELECT a.curr_cd, a.valid_fr, b.curr_cd curr_cd_m_exc_rate
                                       FROM tb_t_exchange_rate a,
                                            tb_m_exchange_rate b
                                      WHERE a.curr_cd = b.curr_cd(+)
                                        AND a.valid_fr = b.valid_fr(+)) LOOP

        IF cur_duplicate_exc_rate.curr_cd_m_exc_rate IS NOT NULL THEN

          IF g_rec_status.v_replace_flag = 'N' THEN

            g_rec_status.b_error := TRUE;
            g_rec_status.b_error_per_submission := TRUE;
            l_v_error_message := pkg_common_general.fn_get_message('MSTD00006WRN', 'Duplication found in TB_T_EXCHANGE_RATE for [Currency Code] = [' || cur_duplicate_exc_rate.curr_cd || '] [Valid From] = [' || cur_duplicate_exc_rate.valid_fr || ']');
            g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
            IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                      g_rec_status.n_seq_no,
                                                      'Check Duplication',
                                                      substr(l_v_error_message, 1, 12),
                                                      substr(l_v_error_message, 10, 3),
                                                      l_v_error_message,
                                                      l_v_error_message) != 0 THEN
              g_rec_status.b_error := TRUE;
            END IF;

          ELSE

            IF NOT f_upd_m_exc_rate(cur_duplicate_exc_rate.curr_cd,
                                    cur_duplicate_exc_rate.valid_fr,
                                    l_v_error_message) THEN

              g_rec_status.b_error := TRUE;
              g_rec_status.b_warning := TRUE;
              g_rec_status.b_error_per_submission := TRUE;
              g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
              IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                        g_rec_status.n_seq_no,
                                                        'Update Exchange Rate',
                                                        substr(l_v_error_message, 1, 12),
                                                        substr(l_v_error_message, 10, 3),
                                                        l_v_error_message,
                                                        l_v_error_message) != 0 THEN
                g_rec_status.b_error := TRUE;
              END IF;

            END IF;

          END IF;

        ELSE

          IF NOT f_ins_m_exc_rate(cur_duplicate_exc_rate.curr_cd,
                                  cur_duplicate_exc_rate.valid_fr,
                                  l_v_error_message) THEN

            g_rec_status.b_error := TRUE;
            g_rec_status.b_warning := TRUE;
            g_rec_status.b_error_per_submission := TRUE;
            g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
            IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                      g_rec_status.n_seq_no,
                                                      'Insert Exchange Rate',
                                                      substr(l_v_error_message, 1, 12),
                                                      substr(l_v_error_message, 10, 3),
                                                      l_v_error_message,
                                                      l_v_error_message) != 0 THEN
              g_rec_status.b_error := TRUE;
            END IF;

          END IF;

        END IF;

        IF NOT g_rec_status.b_error_per_submission THEN

          COMMIT;

        ELSE

          ROLLBACK;

        END IF;

      END LOOP;

    END IF;

    IF g_rec_status.b_lock THEN

      IF pkg_common_lock_record.fn_unlock_record(c_lock_ref_key,
                                                 l_v_error_message) IN (c_failed1, c_failed2) THEN

        g_rec_status.b_error := TRUE;
        g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
        IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                  g_rec_status.n_seq_no,
                                                  'Release Locking Process',
                                                  substr(l_v_error_message, 1, 12),
                                                  substr(l_v_error_message, 10, 3),
                                                  l_v_error_message,
                                                  l_v_error_message) != 0 THEN
          g_rec_status.b_error := TRUE;
        END IF;

      END IF;

    END IF;

    IF g_rec_status.b_error THEN

      l_v_email_body := l_v_email_header || c_new_line || c_new_line ||
                        'Process ID: ' || g_rec_status.v_process_id || c_new_line ||
                        'Process Date: ' || to_char(SYSDATE, 'DD-Mon-YYYY') || c_new_line ||
                        'Process Status: ERROR' || c_new_line || c_new_line ||
                        'Error Log: ' || c_new_line;

      FOR cur_err_log_d IN (SELECT err_message
                              FROM tb_r_log_d
                             WHERE process_id = g_rec_status.v_process_id
                               AND msg_type = 'ERR'
                             ORDER BY seq_no ASC) LOOP

        IF length(l_v_email_body) + length(cur_err_log_d.err_message || c_new_line) + length(l_v_email_footer) + 25 < 34767 THEN

          l_v_email_body := l_v_email_body || cur_err_log_d.err_message || c_new_line;

        ELSE

          l_v_email_body := l_v_email_body || c_new_line || '<Message Truncated>';
          EXIT;

        END IF;

      END LOOP;

      l_v_email_body := l_v_email_body || c_new_line || c_new_line || l_v_email_footer;

      IF pkg_common_email.fn_send_email(l_v_email_from,
                                        l_v_email_to,
                                        l_v_email_cc,
                                        l_v_email_subject || c_function_id || ':' || c_function_name || ' Notification',
                                        l_v_email_body,
                                        l_v_error_message) IN (c_failed1, c_failed2, c_warning) THEN

        g_rec_status.b_error := TRUE;
        g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
        IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                  g_rec_status.n_seq_no,
                                                  'Send Email Process',
                                                  substr(l_v_error_message, 1, 12),
                                                  substr(l_v_error_message, 10, 3),
                                                  l_v_error_message,
                                                  l_v_error_message) != 0 THEN
          g_rec_status.b_error := TRUE;
        END IF;

      END IF;

    END IF;

    IF NOT g_rec_status.b_error AND NOT g_rec_status.b_warning THEN

      --Create End Log Detail
      l_v_error_message := pkg_common_general.fn_get_message('MSTD00305INF', c_function_name);
      g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
      IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                g_rec_status.n_seq_no,
                                                'End Log Detail',
                                                substr(l_v_error_message, 1, 12),
                                                substr(l_v_error_message, 10, 3),
                                                l_v_error_message,
                                                l_v_error_message) != 0 THEN
        g_rec_status.b_error := TRUE;
      END IF;

      --Update Status in Log Header
      IF NOT pkg_common_logger.fn_update_log_header(g_rec_status.v_process_id,
                                                    c_success,
                                                    l_v_error_message) != 0 THEN

        g_rec_status.b_error := TRUE;

      END IF;

      RETURN c_success;

    ELSIF g_rec_status.b_error THEN

      --Create End Log Detail
      l_v_error_message := pkg_common_general.fn_get_message('MSTD00307INF', c_function_name);
      g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
      IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                g_rec_status.n_seq_no,
                                                'End Log Detail',
                                                substr(l_v_error_message, 1, 12),
                                                substr(l_v_error_message, 10, 3),
                                                l_v_error_message,
                                                l_v_error_message) != 0 THEN
        g_rec_status.b_error := TRUE;
      END IF;

      --Update Status in Log Header
      IF NOT pkg_common_logger.fn_update_log_header(g_rec_status.v_process_id,
                                                    c_failed1,
                                                    l_v_error_message) != 0 THEN

        g_rec_status.b_error := TRUE;

      END IF;

      RETURN c_failed1;

    ELSIF g_rec_status.b_warning THEN

      --Create End Log Detail
      l_v_error_message := pkg_common_general.fn_get_message('MSTD00308INF', c_function_name);
      g_rec_status.n_seq_no := g_rec_status.n_seq_no + 1;
      IF pkg_common_logger.fn_create_log_detail(g_rec_status.v_process_id,
                                                g_rec_status.n_seq_no,
                                                'End Log Detail',
                                                substr(l_v_error_message, 1, 12),
                                                substr(l_v_error_message, 10, 3),
                                                l_v_error_message,
                                                l_v_error_message) != 0 THEN
        g_rec_status.b_error := TRUE;
      END IF;

      --Update Status in Log Header
      IF NOT pkg_common_logger.fn_update_log_header(g_rec_status.v_process_id,
                                                    c_warning,
                                                    l_v_error_message) != 0 THEN

        g_rec_status.b_error := TRUE;

      END IF;

      RETURN c_warning;

    END IF;

  END;

END;
/
