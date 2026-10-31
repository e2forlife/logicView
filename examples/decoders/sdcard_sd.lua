-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2015-2020 Uwe Hermann <uwe@hermann-uwe.de>

local _type = type
local _error = error
local _pcall = pcall
local _tostring = tostring
local _tonumber = tonumber
local _string = string
local _table = table
local _math = math
local _pairs = pairs
local _setmetatable = setmetatable
local _select = select
local _rawequal = rawequal
local _coroutine = coroutine
local SrdIntEnum, SrdStrEnum, cmd_names, acmd_names, accepted_voltages, sd_status, responses, token_fields, reg_card_status, reg_cid, reg_csd, Pin, a, Ann, s, St, Bit, Decoder
local _decoder

cmd_names = logicview.dict({ [0] = "GO_IDLE_STATE", [1] = "SEND_OP_COND", [2] = "ALL_SEND_CID", [3] = "SEND_RELATIVE_ADDR", [4] = "SET_DSR", [5] = "IO_SEND_OP_COND", [6] = "SWITCH_FUNC", [7] = "SELECT/DESELECT_CARD", [8] = "SEND_IF_COND", [9] = "SEND_CSD", [10] = "SEND_CID", [11] = "VOLTAGE_SWITCH", [12] = "STOP_TRANSMISSION", [13] = "SEND_STATUS", [15] = "GO_INACTIVE_STATE", [16] = "SET_BLOCKLEN", [17] = "READ_SINGLE_BLOCK", [18] = "READ_MULTIPLE_BLOCK", [19] = "SEND_TUNING_BLOCK", [20] = "SPEED_CLASS_CONTROL", [23] = "SET_BLOCK_COUNT", [24] = "WRITE_BLOCK", [25] = "WRITE_MULTIPLE_BLOCK", [26] = "Reserved for manufacturer", [27] = "PROGRAM_CSD", [28] = "SET_WRITE_PROT", [29] = "CLR_WRITE_PROT", [30] = "SEND_WRITE_PROT", [32] = "ERASE_WR_BLK_START", [33] = "ERASE_WR_BLK_END", [34] = "Reserved for CMD6", [35] = "Reserved for CMD6", [36] = "Reserved for CMD6", [37] = "Reserved for CMD6", [38] = "ERASE", [40] = "Reserved for security specification", [42] = "LOCK_UNLOCK", [50] = "Reserved for CMD6", [52] = "IO_RW_DIRECT", [53] = "IO_RW_EXTENDED", [54] = "Unknown", [55] = "APP_CMD", [56] = "GEN_CMD", [57] = "Reserved for CMD6", [58] = "READ_OCR", [59] = "CRC_ON_OFF", [60] = "Reserved for manufacturer", [61] = "Reserved for manufacturer", [62] = "Reserved for manufacturer", [63] = "Reserved for manufacturer" })
acmd_names = logicview.dict({ [6] = "SET_BUS_WIDTH", [13] = "SD_STATUS", [14] = "Reserved for Security Application", [15] = "Reserved for Security Application", [16] = "Reserved for Security Application", [18] = "Reserved for SD security applications", [22] = "SEND_NUM_WR_BLOCKS", [23] = "SET_WR_BLK_ERASE_COUNT", [25] = "Reserved for SD security applications", [26] = "Reserved for SD security applications", [27] = "Reserved for security specification", [28] = "Reserved for security specification", [30] = "Reserved for security specification", [31] = "Reserved for security specification", [32] = "Reserved for security specification", [33] = "Reserved for security specification", [34] = "Reserved for security specification", [35] = "Reserved for security specification", [38] = "Reserved for SD security applications", [41] = "SD_SEND_OP_COND", [42] = "SET_CLR_CARD_DETECT", [43] = "Reserved for SD security applications", [44] = "Reserved for SD security applications", [45] = "Reserved for SD security applications", [46] = "Reserved for SD security applications", [47] = "Reserved for SD security applications", [48] = "Reserved for SD security applications", [49] = "Reserved for SD security applications", [50] = "Unknown", [51] = "SEND_SCR", [52] = "Reserved for security specification", [53] = "Reserved for security specification", [54] = "Reserved for security specification", [55] = "Non-existant", [56] = "Reserved for security specification", [57] = "Reserved for security specification", [58] = "Reserved for security specification", [59] = "Reserved for security specification", [60] = "Unknown", [61] = "Unknown", [62] = "Unknown", [63] = "Unknown" })
accepted_voltages = logicview.dict({ [1] = "2.7-3.6V", [2] = "reserved for low voltage range", [4] = "reserved", [8] = "reserved" })
sd_status = logicview.dict({  })

responses = logicview.split("1 1b 2 3 6 7", nil, nil)
token_fields = logicview.split("START TRANSMISSION CMD ARG CRC END", nil, nil)
reg_card_status = logicview.split("OUT_OF_RANGE ADDRESS_ERROR BLOCK_LEN_ERROR ERASE_SEQ_ERROR     ERASE_PARAM WP_VIOLATION CARD_IS_LOCKED LOCK_UNLOCK_FAILED COM_CRC_ERROR     ILLEGAL_COMMAND CARD_ECC_FAILED CC_ERROR ERROR RSVD_DEFERRED_RESPONSE     CSD_OVERWRITE WP_ERASE_SKIP CARD_ECC_DISABLED ERASE_RESET CURRENT_STATE     READY_FOR_DATA RSVD FX_EVENT APP_CMD RSVD_SDIO AKE_SEQ_ERROR RSVD_APP_CMD     RSVD_TESTMODE", nil, nil)
reg_cid = logicview.split("MID OID PNM PRV PSN RSVD MDT CRC ONE", nil, nil)
reg_csd = logicview.split("CSD_STRUCTURE RSVD TAAC NSAC TRAN_SPEED CCC READ_BL_LEN     READ_BL_PARTIAL WRITE_BLK_MISALIGN READ_BLK_MISALIGN DSR_IMP C_SIZE     VDD_R_CURR_MIN VDD_R_CURR_MAX VDD_W_CURR_MIN VDD_W_CURR_MAX C_SIZE_MULT     ERASE_BLK_EN SECTOR_SIZE WP_GRP_SIZE WP_GRP_ENABLE R2W_FACTOR     WRITE_BL_LEN WRITE_BL_PARTIAL FILE_FORMAT_GRP COPY PERM_WRITE_PROTECT     TMP_WRITE_PROTECT FILE_FORMAT CRC ONE", nil, nil)
Pin = logicview.int_enum(logicview.split("CMD CLK DAT0 DAT1 DAT2 DAT3", ' '))
a = logicview.add(logicview.add(logicview.add(logicview.add(logicview.add(logicview.add(logicview.add(logicview.add((function()
  local _lv_out = {}
  for _lv_i in logicview.range(64) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = logicview.pymod("CMD%d", i)
  end
  return _lv_out
end)(), (function()
  local _lv_out = {}
  for _lv_i in logicview.range(64) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = logicview.pymod("ACMD%d", i)
  end
  return _lv_out
end)()), (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(responses) do
    r = _lv_item
    _lv_out[#_lv_out + 1] = logicview.add("RESPONSE_R", _string.upper(r))
  end
  return _lv_out
end)()), (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(reg_card_status) do
    r = _lv_item
    _lv_out[#_lv_out + 1] = logicview.add("R_STATUS_", r)
  end
  return _lv_out
end)()), (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(reg_cid) do
    r = _lv_item
    _lv_out[#_lv_out + 1] = logicview.add("R_CID_", r)
  end
  return _lv_out
end)()), (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(reg_csd) do
    r = _lv_item
    _lv_out[#_lv_out + 1] = logicview.add("R_CSD_", r)
  end
  return _lv_out
end)()), (function()
  local _lv_out = {}
  for _lv_item in logicview.iter({ "0", "1" }) do
    r = _lv_item
    _lv_out[#_lv_out + 1] = logicview.add("BIT_", r)
  end
  return _lv_out
end)()), (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(token_fields) do
    f = _lv_item
    _lv_out[#_lv_out + 1] = logicview.add("F_", f)
  end
  return _lv_out
end)()), { "DECODED_BIT", "DECODED_F" })
Ann = logicview.int_enum(a)
s = logicview.add(logicview.add(logicview.add({ "GET_COMMAND_TOKEN", "HANDLE_CMD999" }, (function()
  local _lv_out = {}
  for _lv_i in logicview.range(64) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = logicview.pymod("HANDLE_CMD%d", i)
  end
  return _lv_out
end)()), (function()
  local _lv_out = {}
  for _lv_i in logicview.range(64) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = logicview.pymod("HANDLE_ACMD%d", i)
  end
  return _lv_out
end)()), (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(responses) do
    r = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pymod("GET_RESPONSE_R%s", _string.upper(r))
  end
  return _lv_out
end)())
St = logicview.str_enum(s)
Bit = {}
Bit.__index = Bit
function Bit.__init__(self, s, e, b)
  do
    local _lv_a0, _lv_a1, _lv_a2 = s, e, b
    self.ss = _lv_a0
    self.es = _lv_a1
    self.bit = _lv_a2
  end
end
function Bit.new(...)
  local self = _setmetatable({}, Bit)
  Bit.__init__(self, ...)
  return self
end
_decoder = {
  api_version = 3,
  id = "sdcard_sd",
  name = "SD card (SD mode)",
  longname = "Secure Digital card (SD mode)",
  desc = "Secure Digital card (SD mode) low-level protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Memory" },
  channels = { logicview.dict({ id = "cmd", name = "CMD", desc = "Command" }), logicview.dict({ id = "clk", name = "CLK", desc = "Clock" }) },
  optional_channels = { logicview.dict({ id = "dat0", name = "DAT0", desc = "Data pin 0" }), logicview.dict({ id = "dat1", name = "DAT1", desc = "Data pin 1" }), logicview.dict({ id = "dat2", name = "DAT2", desc = "Data pin 2" }), logicview.dict({ id = "dat3", name = "DAT3", desc = "Data pin 3" }) },
  options = {  },
  annotations = { { "cmd0", "CMD0" }, { "cmd1", "CMD1" }, { "cmd2", "CMD2" }, { "cmd3", "CMD3" }, { "cmd4", "CMD4" }, { "cmd5", "CMD5" }, { "cmd6", "CMD6" }, { "cmd7", "CMD7" }, { "cmd8", "CMD8" }, { "cmd9", "CMD9" }, { "cmd10", "CMD10" }, { "cmd11", "CMD11" }, { "cmd12", "CMD12" }, { "cmd13", "CMD13" }, { "cmd14", "CMD14" }, { "cmd15", "CMD15" }, { "cmd16", "CMD16" }, { "cmd17", "CMD17" }, { "cmd18", "CMD18" }, { "cmd19", "CMD19" }, { "cmd20", "CMD20" }, { "cmd21", "CMD21" }, { "cmd22", "CMD22" }, { "cmd23", "CMD23" }, { "cmd24", "CMD24" }, { "cmd25", "CMD25" }, { "cmd26", "CMD26" }, { "cmd27", "CMD27" }, { "cmd28", "CMD28" }, { "cmd29", "CMD29" }, { "cmd30", "CMD30" }, { "cmd31", "CMD31" }, { "cmd32", "CMD32" }, { "cmd33", "CMD33" }, { "cmd34", "CMD34" }, { "cmd35", "CMD35" }, { "cmd36", "CMD36" }, { "cmd37", "CMD37" }, { "cmd38", "CMD38" }, { "cmd39", "CMD39" }, { "cmd40", "CMD40" }, { "cmd41", "CMD41" }, { "cmd42", "CMD42" }, { "cmd43", "CMD43" }, { "cmd44", "CMD44" }, { "cmd45", "CMD45" }, { "cmd46", "CMD46" }, { "cmd47", "CMD47" }, { "cmd48", "CMD48" }, { "cmd49", "CMD49" }, { "cmd50", "CMD50" }, { "cmd51", "CMD51" }, { "cmd52", "CMD52" }, { "cmd53", "CMD53" }, { "cmd54", "CMD54" }, { "cmd55", "CMD55" }, { "cmd56", "CMD56" }, { "cmd57", "CMD57" }, { "cmd58", "CMD58" }, { "cmd59", "CMD59" }, { "cmd60", "CMD60" }, { "cmd61", "CMD61" }, { "cmd62", "CMD62" }, { "cmd63", "CMD63" }, { "acmd0", "ACMD0" }, { "acmd1", "ACMD1" }, { "acmd2", "ACMD2" }, { "acmd3", "ACMD3" }, { "acmd4", "ACMD4" }, { "acmd5", "ACMD5" }, { "acmd6", "ACMD6" }, { "acmd7", "ACMD7" }, { "acmd8", "ACMD8" }, { "acmd9", "ACMD9" }, { "acmd10", "ACMD10" }, { "acmd11", "ACMD11" }, { "acmd12", "ACMD12" }, { "acmd13", "ACMD13" }, { "acmd14", "ACMD14" }, { "acmd15", "ACMD15" }, { "acmd16", "ACMD16" }, { "acmd17", "ACMD17" }, { "acmd18", "ACMD18" }, { "acmd19", "ACMD19" }, { "acmd20", "ACMD20" }, { "acmd21", "ACMD21" }, { "acmd22", "ACMD22" }, { "acmd23", "ACMD23" }, { "acmd24", "ACMD24" }, { "acmd25", "ACMD25" }, { "acmd26", "ACMD26" }, { "acmd27", "ACMD27" }, { "acmd28", "ACMD28" }, { "acmd29", "ACMD29" }, { "acmd30", "ACMD30" }, { "acmd31", "ACMD31" }, { "acmd32", "ACMD32" }, { "acmd33", "ACMD33" }, { "acmd34", "ACMD34" }, { "acmd35", "ACMD35" }, { "acmd36", "ACMD36" }, { "acmd37", "ACMD37" }, { "acmd38", "ACMD38" }, { "acmd39", "ACMD39" }, { "acmd40", "ACMD40" }, { "acmd41", "ACMD41" }, { "acmd42", "ACMD42" }, { "acmd43", "ACMD43" }, { "acmd44", "ACMD44" }, { "acmd45", "ACMD45" }, { "acmd46", "ACMD46" }, { "acmd47", "ACMD47" }, { "acmd48", "ACMD48" }, { "acmd49", "ACMD49" }, { "acmd50", "ACMD50" }, { "acmd51", "ACMD51" }, { "acmd52", "ACMD52" }, { "acmd53", "ACMD53" }, { "acmd54", "ACMD54" }, { "acmd55", "ACMD55" }, { "acmd56", "ACMD56" }, { "acmd57", "ACMD57" }, { "acmd58", "ACMD58" }, { "acmd59", "ACMD59" }, { "acmd60", "ACMD60" }, { "acmd61", "ACMD61" }, { "acmd62", "ACMD62" }, { "acmd63", "ACMD63" }, { "response_r1", "R1" }, { "response_r1b", "R1b" }, { "response_r2", "R2" }, { "response_r3", "R3" }, { "response_r6", "R6" }, { "response_r7", "R7" }, { "reg_status_out_of_range", "Status: OUT_OF_RANGE" }, { "reg_status_address_error", "Status: ADDRESS_ERROR" }, { "reg_status_block_len_error", "Status: BLOCK_LEN_ERROR" }, { "reg_status_erase_seq_error", "Status: ERASE_SEQ_ERROR" }, { "reg_status_erase_param", "Status: ERASE_PARAM" }, { "reg_status_wp_violation", "Status: WP_VIOLATION" }, { "reg_status_card_is_locked", "Status: CARD_IS_LOCKED" }, { "reg_status_lock_unlock_failed", "Status: LOCK_UNLOCK_FAILED" }, { "reg_status_com_crc_error", "Status: COM_CRC_ERROR" }, { "reg_status_illegal_command", "Status: ILLEGAL_COMMAND" }, { "reg_status_card_ecc_failed", "Status: CARD_ECC_FAILED" }, { "reg_status_cc_error", "Status: CC_ERROR" }, { "reg_status_error", "Status: ERROR" }, { "reg_status_rsvd_deferred_response", "Status: RSVD_DEFERRED_RESPONSE" }, { "reg_status_csd_overwrite", "Status: CSD_OVERWRITE" }, { "reg_status_wp_erase_skip", "Status: WP_ERASE_SKIP" }, { "reg_status_card_ecc_disabled", "Status: CARD_ECC_DISABLED" }, { "reg_status_erase_reset", "Status: ERASE_RESET" }, { "reg_status_current_state", "Status: CURRENT_STATE" }, { "reg_status_ready_for_data", "Status: READY_FOR_DATA" }, { "reg_status_rsvd", "Status: RSVD" }, { "reg_status_fx_event", "Status: FX_EVENT" }, { "reg_status_app_cmd", "Status: APP_CMD" }, { "reg_status_rsvd_sdio", "Status: RSVD_SDIO" }, { "reg_status_ake_seq_error", "Status: AKE_SEQ_ERROR" }, { "reg_status_rsvd_app_cmd", "Status: RSVD_APP_CMD" }, { "reg_status_rsvd_testmode", "Status: RSVD_TESTMODE" }, { "reg_cid_mid", "CID: MID" }, { "reg_cid_oid", "CID: OID" }, { "reg_cid_pnm", "CID: PNM" }, { "reg_cid_prv", "CID: PRV" }, { "reg_cid_psn", "CID: PSN" }, { "reg_cid_rsvd", "CID: RSVD" }, { "reg_cid_mdt", "CID: MDT" }, { "reg_cid_crc", "CID: CRC" }, { "reg_cid_one", "CID: ONE" }, { "reg_csd_csd_structure", "CSD: CSD_STRUCTURE" }, { "reg_csd_rsvd", "CSD: RSVD" }, { "reg_csd_taac", "CSD: TAAC" }, { "reg_csd_nsac", "CSD: NSAC" }, { "reg_csd_tran_speed", "CSD: TRAN_SPEED" }, { "reg_csd_ccc", "CSD: CCC" }, { "reg_csd_read_bl_len", "CSD: READ_BL_LEN" }, { "reg_csd_read_bl_partial", "CSD: READ_BL_PARTIAL" }, { "reg_csd_write_blk_misalign", "CSD: WRITE_BLK_MISALIGN" }, { "reg_csd_read_blk_misalign", "CSD: READ_BLK_MISALIGN" }, { "reg_csd_dsr_imp", "CSD: DSR_IMP" }, { "reg_csd_c_size", "CSD: C_SIZE" }, { "reg_csd_vdd_r_curr_min", "CSD: VDD_R_CURR_MIN" }, { "reg_csd_vdd_r_curr_max", "CSD: VDD_R_CURR_MAX" }, { "reg_csd_vdd_w_curr_min", "CSD: VDD_W_CURR_MIN" }, { "reg_csd_vdd_w_curr_max", "CSD: VDD_W_CURR_MAX" }, { "reg_csd_c_size_mult", "CSD: C_SIZE_MULT" }, { "reg_csd_erase_blk_en", "CSD: ERASE_BLK_EN" }, { "reg_csd_sector_size", "CSD: SECTOR_SIZE" }, { "reg_csd_wp_grp_size", "CSD: WP_GRP_SIZE" }, { "reg_csd_wp_grp_enable", "CSD: WP_GRP_ENABLE" }, { "reg_csd_r2w_factor", "CSD: R2W_FACTOR" }, { "reg_csd_write_bl_len", "CSD: WRITE_BL_LEN" }, { "reg_csd_write_bl_partial", "CSD: WRITE_BL_PARTIAL" }, { "reg_csd_file_format_grp", "CSD: FILE_FORMAT_GRP" }, { "reg_csd_copy", "CSD: COPY" }, { "reg_csd_perm_write_protect", "CSD: PERM_WRITE_PROTECT" }, { "reg_csd_tmp_write_protect", "CSD: TMP_WRITE_PROTECT" }, { "reg_csd_file_format", "CSD: FILE_FORMAT" }, { "reg_csd_crc", "CSD: CRC" }, { "reg_csd_one", "CSD: ONE" }, { "bit_0", "Bit 0" }, { "bit_1", "Bit 1" }, { "field-start", "START" }, { "field-transmission", "TRANSMISSION" }, { "field-cmd", "CMD" }, { "field-arg", "ARG" }, { "field-crc", "CRC" }, { "field-end", "END" }, { "decoded-bit", "Decoded bit" }, { "decoded-field", "Decoded field" } },
  annotation_rows = { { "raw-bits", "Raw bits", { 201, 202 } }, { "decoded-bits", "Decoded bits", { 209, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200 } }, { "decoded-fields", "Decoded fields", { 210 } }, { "fields", "Fields", { 203, 204, 205, 206, 207, 208 } }, { "commands", "Commands", { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = St.GET_COMMAND_TOKEN
  self.token = {  }
  self.is_acmd = false
  self.cmd = nil
  self.last_cmd = nil
  self.arg = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putt(self, data)
  self:put(logicview.idx(self.token, 0).ss, logicview.idx(self.token, 47).es, self.out_ann, data)
end
function _decoder.putf(self, s, e, data)
  self:put(logicview.idx(self.token, s).ss, logicview.idx(self.token, e).es, self.out_ann, data)
end
function _decoder.puta(self, s, e, data)
  self:put(logicview.idx(self.token, ((47 - 8) - e)).ss, logicview.idx(self.token, ((47 - 8) - s)).es, self.out_ann, data)
end
function _decoder.putc(self, desc)
  local cmd
  cmd = (function() if logicview.truth(self.is_acmd) then return logicview.add(Ann.ACMD0, self.cmd) else return self.cmd end end)()
  self.last_cmd = cmd
  self:putt({ cmd, { logicview.pymod("%s: %s", { self.cmd_str, desc }), self.cmd_str, logicview.idx(logicview.split(self.cmd_str, " ", nil), 0) } })
end
function _decoder.putr(self, r)
  self:putt({ r, { logicview.pymod("Response: %s", logicview.idx(logicview.split(r.name, "_", nil), 1)) } })
end
function _decoder.cmd_name(self, cmd)
  local c
  c = (function() if logicview.truth(self.is_acmd) then return acmd_names else return cmd_names end end)()
  return logicview.dget(c, cmd, "Unknown")
end
function _decoder.get_token_bits(self, cmd_pin, n)
  _table.insert(self.token, Bit.new(self.samplenum, self.samplenum, cmd_pin))
  if logicview.truth((logicview.len(self.token) > 0)) then
    logicview.idx(self.token, (logicview.len(self.token) - 2)).es = self.samplenum
  end
  if logicview.truth((logicview.len(self.token) < n)) then
    return false
  end
  logicview.idx(self.token, (n - 1)).es = logicview.add(logicview.idx(self.token, (n - 1)).es, (logicview.idx(self.token, (n - 1)).ss - logicview.idx(self.token, (n - 2)).ss))
  return true
end
function _decoder.is_from_host(self)
  return logicview.eq(logicview.idx(self.token, 1).bit, 1)
end
function _decoder.is_from_card(self)
  return logicview.eq(logicview.idx(self.token, 1).bit, 0)
end
function _decoder.handle_common_token_fields(self)
  local s, bit, t, c
  s = self.token
  for _lv_i in logicview.range(logicview.len(self.token)) do
    bit = _lv_i
    self:putf(bit, bit, { logicview.add(Ann.BIT_0, logicview.idx(s, bit).bit), { logicview.pymod("%d", logicview.idx(s, bit).bit) } })
    ::continue_1::
  end
  self:putf(0, 0, { Ann.F_START, { "Start bit", "Start", "S" } })
  t = (function() if logicview.truth(logicview.eq(logicview.idx(s, 1).bit, 1)) then return "host" else return "card" end end)()
  self:putf(1, 1, { Ann.F_TRANSMISSION, { logicview.add("Transmission: ", t), logicview.add("T: ", t), "T" } })
  self.cmd = logicview.tointeger(logicview.add("0b", logicview.join("", (function()
  local _lv_out = {}
  for _lv_i in logicview.range(2, 8) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = _tostring(logicview.idx(s, i).bit)
  end
  return _lv_out
end)())), 2)
  c = logicview.pymod("%s (%d)", { self:cmd_name(self.cmd), self.cmd })
  self:putf(2, 7, { Ann.F_CMD, { logicview.add("Command: ", c), logicview.add("Cmd: ", c), logicview.pymod("CMD%d", self.cmd), "Cmd", "C" } })
  self.arg = logicview.tointeger(logicview.add("0b", logicview.join("", (function()
  local _lv_out = {}
  for _lv_i in logicview.range(8, 40) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = _tostring(logicview.idx(s, i).bit)
  end
  return _lv_out
end)())), 2)
  self:putf(8, 39, { Ann.F_ARG, { logicview.pymod("Argument: 0x%08x", self.arg), "Arg", "A" } })
  self.crc = logicview.tointeger(logicview.add("0b", logicview.join("", (function()
  local _lv_out = {}
  for _lv_i in logicview.range(40, 47) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = _tostring(logicview.idx(s, i).bit)
  end
  return _lv_out
end)())), 2)
  self:putf(40, 46, { Ann.F_CRC, { logicview.pymod("CRC: 0x%x", self.crc), "CRC", "C" } })
  self:putf(47, 47, { Ann.F_END, { "End bit", "End", "E" } })
end
function _decoder.get_command_token(self, cmd_pin)
  if logicview.truth((not logicview.truth(self:get_token_bits(cmd_pin, 48)))) then
    return
  end
  if logicview.truth((not logicview.truth(self:is_from_host()))) then
    do
      local _lv_a0, _lv_a1 = {  }, St.GET_COMMAND_TOKEN
      self.token = _lv_a0
      self.state = _lv_a1
    end
    return
  end
  self:handle_cmd()
end
function _decoder.handle_cmd(self)
  local s
  self:handle_common_token_fields()
  s = (function() if logicview.truth(self.is_acmd) then return "ACMD" else return "CMD" end end)()
  self.cmd_str = logicview.pymod("%s%d (%s)", { s, self.cmd, self:cmd_name(self.cmd) })
  if logicview.truth((self[logicview.pymod("handle_%s%d", { _string.lower(s), self.cmd })] ~= nil)) then
    self.state = logicview.idx(St, logicview.pymod("HANDLE_CMD%d", self.cmd))
  else
    self.state = St.HANDLE_CMD999
    self:putc(logicview.pymod("%s%d", { s, self.cmd }))
  end
end
function _decoder.handle_cmd0(self)
  self:puta(0, 31, { Ann.DECODED_F, { "Stuff bits", "Stuff", "SB", "S" } })
  self:putc("Reset all SD cards")
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_COMMAND_TOKEN
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_cmd2(self)
  self:puta(0, 31, { Ann.DECODED_F, { "Stuff bits", "Stuff", "SB", "S" } })
  self:putc("Ask card for CID number")
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_RESPONSE_R2
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_cmd3(self)
  self:puta(0, 31, { Ann.DECODED_F, { "Stuff bits", "Stuff", "SB", "S" } })
  self:putc("Ask card for new relative card address (RCA)")
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_RESPONSE_R6
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_cmd6(self)
  self:putc("Switch/check card function")
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_RESPONSE_R1
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_cmd7(self)
  self:putc("Select / deselect card")
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_RESPONSE_R6
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_cmd8(self)
  self:puta(12, 31, { Ann.DECODED_F, { "Reserved", "Res", "R" } })
  self:puta(8, 11, { Ann.DECODED_F, { "Supply voltage", "Voltage", "VHS", "V" } })
  self:puta(0, 7, { Ann.DECODED_F, { "Check pattern", "Check pat", "Check", "C" } })
  self:putc("Send interface condition to card")
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_RESPONSE_R7
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_cmd9(self)
  self:puta(16, 31, { Ann.DECODED_F, { "RCA", "R" } })
  self:puta(0, 15, { Ann.DECODED_F, { "Stuff bits", "Stuff", "SB", "S" } })
  self:putc("Send card-specific data (CSD)")
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_RESPONSE_R2
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_cmd10(self)
  self:puta(16, 31, { Ann.DECODED_F, { "RCA", "R" } })
  self:puta(0, 15, { Ann.DECODED_F, { "Stuff bits", "Stuff", "SB", "S" } })
  self:putc("Send card identification data (CID)")
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_RESPONSE_R2
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_cmd13(self)
  self:puta(16, 31, { Ann.DECODED_F, { "RCA", "R" } })
  self:puta(0, 15, { Ann.DECODED_F, { "Stuff bits", "Stuff", "SB", "S" } })
  self:putc("Send card status register")
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_RESPONSE_R1
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_cmd16(self)
  self:puta(0, 31, { Ann.DECODED_F, { "Block length", "Blocklen", "BL", "B" } })
  self:putc(logicview.pymod("Set the block length to %d bytes", self.arg))
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_RESPONSE_R1
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_cmd55(self)
  self:puta(16, 31, { Ann.DECODED_F, { "RCA", "R" } })
  self:puta(0, 15, { Ann.DECODED_F, { "Stuff bits", "Stuff", "SB", "S" } })
  self:putc("Next command is an application-specific command")
  self.is_acmd = true
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_RESPONSE_R1
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_acmd6(self)
  self:putc("Read SD config register (SCR)")
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_RESPONSE_R1
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_acmd13(self)
  self:puta(0, 31, { Ann.DECODED_F, { "Stuff bits", "Stuff", "SB", "S" } })
  self:putc("Set SD status")
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_RESPONSE_R1
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_acmd41(self)
  self:puta(0, 23, { Ann.DECODED_F, { "VDD voltage window", "VDD volt", "VDD", "V" } })
  self:puta(24, 24, { Ann.DECODED_F, { "S18R" } })
  self:puta(25, 27, { Ann.DECODED_F, { "Reserved", "Res", "R" } })
  self:puta(28, 28, { Ann.DECODED_F, { "XPC" } })
  self:puta(29, 29, { Ann.DECODED_F, { "Reserved for eSD", "Reserved", "Res", "R" } })
  self:puta(30, 30, { Ann.DECODED_F, { "Host capacity support info", "Host capacity", "HCS", "H" } })
  self:puta(31, 31, { Ann.DECODED_F, { "Reserved", "Res", "R" } })
  self:putc("Send HCS info and activate the card init process")
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_RESPONSE_R3
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_acmd51(self)
  self:putc("Read SD config register (SCR)")
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_RESPONSE_R1
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_cmd999(self)
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_RESPONSE_R1
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_acmd999(self)
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_RESPONSE_R1
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_reg_status(self)
  self:putf(8, 8, { Ann.R_STATUS_OUT_OF_RANGE, { "OUT_OF_RANGE" } })
  self:putf(9, 9, { Ann.R_STATUS_ADDRESS_ERROR, { "ADDRESS_ERROR" } })
  self:putf(10, 10, { Ann.R_STATUS_BLOCK_LEN_ERROR, { "BLOCK_LEN_ERROR" } })
  self:putf(11, 11, { Ann.R_STATUS_ERASE_SEQ_ERROR, { "ERASE_SEQ_ERROR" } })
  self:putf(12, 12, { Ann.R_STATUS_ERASE_PARAM, { "ERASE_PARAM" } })
  self:putf(13, 13, { Ann.R_STATUS_WP_VIOLATION, { "WP_VIOLATION" } })
  self:putf(14, 14, { Ann.R_STATUS_CARD_IS_LOCKED, { "CARD_IS_LOCKED" } })
  self:putf(15, 15, { Ann.R_STATUS_LOCK_UNLOCK_FAILED, { "LOCK_UNLOCK_FAILED" } })
  self:putf(16, 16, { Ann.R_STATUS_COM_CRC_ERROR, { "COM_CRC_ERROR" } })
  self:putf(17, 17, { Ann.R_STATUS_ILLEGAL_COMMAND, { "ILLEGAL_COMMAND" } })
  self:putf(18, 18, { Ann.R_STATUS_CARD_ECC_FAILED, { "CARD_ECC_FAILED" } })
  self:putf(19, 19, { Ann.R_STATUS_CC_ERROR, { "CC_ERROR" } })
  self:putf(20, 20, { Ann.R_STATUS_ERROR, { "ERROR" } })
  self:putf(21, 21, { Ann.R_STATUS_RSVD, { "Reserved", "RSVD", "R" } })
  self:putf(22, 22, { Ann.R_STATUS_RSVD_DEFERRED_RESPONSE, { "Reserved for DEFERRED_RESPONSE", "RSVD_DEFERRED_RESPONSE" } })
  self:putf(23, 23, { Ann.R_STATUS_CSD_OVERWRITE, { "CSD_OVERWRITE" } })
  self:putf(24, 24, { Ann.R_STATUS_WP_ERASE_SKIP, { "WP_ERASE_SKIP" } })
  self:putf(25, 25, { Ann.R_STATUS_CARD_ECC_DISABLED, { "CARD_ECC_DISABLED" } })
  self:putf(26, 26, { Ann.R_STATUS_ERASE_RESET, { "ERASE_RESET" } })
  self:putf(27, 30, { Ann.R_STATUS_CURRENT_STATE, { "CURRENT_STATE" } })
  self:putf(31, 31, { Ann.R_STATUS_READY_FOR_DATA, { "READY_FOR_DATA" } })
  self:putf(32, 32, { Ann.R_STATUS_RSVD, { "RSVD" } })
  self:putf(33, 33, { Ann.R_STATUS_FX_EVENT, { "FX_EVENT" } })
  self:putf(34, 34, { Ann.R_STATUS_APP_CMD, { "APP_CMD" } })
  self:putf(35, 35, { Ann.R_STATUS_RSVD_SDIO, { "Reserved for SDIO card", "RSVD_SDIO" } })
  self:putf(36, 36, { Ann.R_STATUS_AKE_SEQ_ERROR, { "AKE_SEQ_ERROR" } })
  self:putf(37, 37, { Ann.R_STATUS_RSVD_APP_CMD, { "Reserved for application specific commands", "RSVD_APP_CMD" } })
  self:putf(38, 39, { Ann.R_STATUS_RSVD_TESTMODE, { "Reserved for manufacturer test mode", "RSVD_TESTMODE" } })
end
function _decoder.handle_reg_cid(self)
  self:putf(8, 15, { Ann.R_CID_MID, { "Manufacturer ID", "MID" } })
  self:putf(16, 31, { Ann.R_CID_OID, { "OEM/application ID", "OID" } })
  self:putf(32, 71, { Ann.R_CID_PNM, { "Product name", "PNM" } })
  self:putf(72, 79, { Ann.R_CID_PRV, { "Product revision", "PRV" } })
  self:putf(80, 111, { Ann.R_CID_PSN, { "Product serial number", "PSN" } })
  self:putf(112, 115, { Ann.R_CID_RSVD, { "Reserved", "RSVD", "R" } })
  self:putf(116, 127, { Ann.R_CID_MDT, { "Manufacturing date", "MDT" } })
  self:putf(128, 134, { Ann.R_CID_CRC, { "CRC7 checksum", "CRC" } })
  self:putf(135, 135, { Ann.R_CID_ONE, { "Always 1", "1" } })
end
function _decoder.handle_reg_csd(self)
  self:putf(8, 9, { Ann.R_CSD_CSD_STRUCTURE, { "CSD structure", "CSD_STRUCTURE" } })
  self:putf(10, 15, { Ann.R_CSD_RSVD, { "Reserved", "RSVD", "R" } })
  self:putf(16, 23, { Ann.R_CSD_TAAC, { "Data read access-time - 1", "TAAC" } })
  self:putf(24, 31, { Ann.R_CSD_NSAC, { "Data read access-time - 2 in CLK cycles (NSAC * 100)", "NSAC" } })
  self:putf(32, 39, { Ann.R_CSD_TRAN_SPEED, { "Max. data transfer rate", "TRAN_SPEED" } })
  self:putf(40, 51, { Ann.R_CSD_CCC, { "Card command classes", "CCC" } })
  self:putf(52, 55, { Ann.R_CSD_READ_BL_LEN, { "Max. read data block length", "READ_BL_LEN" } })
  self:putf(56, 56, { Ann.R_CSD_READ_BL_PARTIAL, { "Partial blocks for read allowed", "READ_BL_PARTIAL" } })
  self:putf(57, 57, { Ann.R_CSD_WRITE_BLK_MISALIGN, { "Write block misalignment", "WRITE_BLK_MISALIGN" } })
  self:putf(58, 58, { Ann.R_CSD_READ_BLK_MISALIGN, { "Read block misalignment", "READ_BLK_MISALIGN" } })
  self:putf(59, 59, { Ann.R_CSD_DSR_IMP, { "DSR implemented", "DSR_IMP" } })
  self:putf(60, 61, { Ann.R_CSD_RSVD, { "Reserved", "RSVD", "R" } })
  self:putf(62, 73, { Ann.R_CSD_C_SIZE, { "Device size", "C_SIZE" } })
  self:putf(74, 76, { Ann.R_CSD_VDD_R_CURR_MIN, { "Max. read current @VDD min", "VDD_R_CURR_MIN" } })
  self:putf(77, 79, { Ann.R_CSD_VDD_R_CURR_MAX, { "Max. read current @VDD max", "VDD_R_CURR_MAX" } })
  self:putf(80, 82, { Ann.R_CSD_VDD_W_CURR_MIN, { "Max. write current @VDD min", "VDD_W_CURR_MIN" } })
  self:putf(83, 85, { Ann.R_CSD_VDD_W_CURR_MAX, { "Max. write current @VDD max", "VDD_W_CURR_MAX" } })
  self:putf(86, 88, { Ann.R_CSD_C_SIZE_MULT, { "Device size multiplier", "C_SIZE_MULT" } })
  self:putf(89, 89, { Ann.R_CSD_ERASE_BLK_EN, { "Erase single block enable", "ERASE_BLK_EN" } })
  self:putf(90, 96, { Ann.R_CSD_SECTOR_SIZE, { "Erase sector size", "SECTOR_SIZE" } })
  self:putf(97, 103, { Ann.R_CSD_WP_GRP_SIZE, { "Write protect group size", "WP_GRP_SIZE" } })
  self:putf(104, 104, { Ann.R_CSD_WP_GRP_ENABLE, { "Write protect group enable", "WP_GRP_ENABLE" } })
  self:putf(105, 106, { Ann.R_CSD_RSVD, { "Reserved", "RSVD", "R" } })
  self:putf(107, 109, { Ann.R_CSD_R2W_FACTOR, { "Write speed factor", "R2W_FACTOR" } })
  self:putf(110, 113, { Ann.R_CSD_WRITE_BL_LEN, { "Max. write data block length", "WRITE_BL_LEN" } })
  self:putf(114, 114, { Ann.R_CSD_WRITE_BL_PARTIAL, { "Partial blocks for write allowed", "WRITE_BL_PARTIAL" } })
  self:putf(115, 119, { Ann.R_CSD_RSVD, { "Reserved", "RSVD" } })
  self:putf(120, 120, { Ann.R_CSD_FILE_FORMAT_GRP, { "File format group", "FILE_FORMAT_GRP" } })
  self:putf(121, 121, { Ann.R_CSD_COPY, { "Copy flag", "COPY" } })
  self:putf(122, 122, { Ann.R_CSD_PERM_WRITE_PROTECT, { "Permanent write protection", "PERM_WRITE_PROTECT" } })
  self:putf(123, 123, { Ann.R_CSD_TMP_WRITE_PROTECT, { "Temporary write protection", "TMP_WRITE_PROTECT" } })
  self:putf(124, 125, { Ann.R_CSD_FILE_FORMAT, { "File format", "FILE_FORMAT" } })
  self:putf(126, 127, { Ann.R_CSD_RSVD, { "Reserved", "RSVD", "R" } })
  self:putf(128, 134, { Ann.R_CSD_CRC, { "CRC", "CRC", "C" } })
  self:putf(135, 135, { Ann.R_CSD_ONE, { "Always 1", "1" } })
end
function _decoder.handle_response_r1(self, cmd_pin)
  if logicview.truth((not logicview.truth(self:get_token_bits(cmd_pin, 48)))) then
    return
  end
  if not logicview.truth(self:is_from_card()) then _error("assertion failed") end
  self:handle_common_token_fields()
  self:putr(Ann.RESPONSE_R1)
  self:puta(0, 31, { Ann.DECODED_F, { "Card status", "Status", "S" } })
  self:handle_reg_status()
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_COMMAND_TOKEN
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_response_r1b(self, cmd_pin)
  if logicview.truth((not logicview.truth(self:get_token_bits(cmd_pin, 48)))) then
    return
  end
  if not logicview.truth(self:is_from_card()) then _error("assertion failed") end
  self:handle_common_token_fields()
  self:puta(0, 31, { Ann.DECODED_F, { "Card status", "Status", "S" } })
  self:putr(Ann.RESPONSE_R1B)
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_COMMAND_TOKEN
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_response_r2(self, cmd_pin)
  local bit, t
  if logicview.truth((not logicview.truth(self:get_token_bits(cmd_pin, 136)))) then
    return
  end
  if not logicview.truth(self:is_from_card()) then _error("assertion failed") end
  for _lv_i in logicview.range(logicview.len(self.token)) do
    bit = _lv_i
    self:putf(bit, bit, { logicview.add(Ann.BIT_0, logicview.idx(self.token, bit).bit), { logicview.pymod("%d", logicview.idx(self.token, bit).bit) } })
    ::continue_2::
  end
  self:putf(0, 0, { Ann.F_START, { "Start bit", "Start", "S" } })
  t = (function() if logicview.truth(logicview.eq(logicview.idx(self.token, 1).bit, 1)) then return "host" else return "card" end end)()
  self:putf(1, 1, { Ann.F_TRANSMISSION, { logicview.add("Transmission: ", t), logicview.add("T: ", t), "T" } })
  self:putf(2, 7, { Ann.F_CMD, { "Reserved", "Res", "R" } })
  self:putf(8, 134, { Ann.F_ARG, { "Argument", "Arg", "A" } })
  self:putf(135, 135, { Ann.F_END, { "End bit", "End", "E" } })
  self:putf(8, 134, { Ann.DECODED_F, { "CID/CSD register", "CID/CSD", "C" } })
  self:putf(0, 135, { Ann.RESPONSE_R2, { "Response: R2" } })
  if logicview.truth(logicview.contains({ Ann.CMD2, Ann.CMD10 }, self.last_cmd)) then
    self:handle_reg_cid()
  end
  if logicview.truth(logicview.eq(self.last_cmd, Ann.CMD9)) then
    self:handle_reg_csd()
  end
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_COMMAND_TOKEN
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_response_r3(self, cmd_pin)
  local bit, t
  if logicview.truth((not logicview.truth(self:get_token_bits(cmd_pin, 48)))) then
    return
  end
  if not logicview.truth(self:is_from_card()) then _error("assertion failed") end
  self:putr(Ann.RESPONSE_R3)
  for _lv_i in logicview.range(logicview.len(self.token)) do
    bit = _lv_i
    self:putf(bit, bit, { logicview.add(Ann.BIT_0, logicview.idx(self.token, bit).bit), { logicview.pymod("%d", logicview.idx(self.token, bit).bit) } })
    ::continue_3::
  end
  self:putf(0, 0, { Ann.F_START, { "Start bit", "Start", "S" } })
  t = (function() if logicview.truth(logicview.eq(logicview.idx(self.token, 1).bit, 1)) then return "host" else return "card" end end)()
  self:putf(1, 1, { Ann.F_TRANSMISSION, { logicview.add("Transmission: ", t), logicview.add("T: ", t), "T" } })
  self:putf(2, 7, { Ann.F_CMD, { "Reserved", "Res", "R" } })
  self:putf(8, 39, { Ann.F_ARG, { "Argument", "Arg", "A" } })
  self:putf(40, 46, { Ann.F_CRC, { "Reserved", "Res", "R" } })
  self:putf(47, 47, { Ann.F_END, { "End bit", "End", "E" } })
  self:puta(0, 31, { Ann.DECODED_F, { "OCR register", "OCR reg", "OCR", "O" } })
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_COMMAND_TOKEN
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_response_r6(self, cmd_pin)
  if logicview.truth((not logicview.truth(self:get_token_bits(cmd_pin, 48)))) then
    return
  end
  if not logicview.truth(self:is_from_card()) then _error("assertion failed") end
  self:handle_common_token_fields()
  self:puta(0, 15, { Ann.DECODED_F, { "Card status bits", "Status", "S" } })
  self:puta(16, 31, { Ann.DECODED_F, { "Relative card address", "RCA", "R" } })
  self:putr(Ann.RESPONSE_R6)
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_COMMAND_TOKEN
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_response_r7(self, cmd_pin)
  local v, av
  if logicview.truth((not logicview.truth(self:get_token_bits(cmd_pin, 48)))) then
    return
  end
  if not logicview.truth(self:is_from_card()) then _error("assertion failed") end
  self:handle_common_token_fields()
  self:putr(Ann.RESPONSE_R7)
  self:puta(12, 31, { Ann.DECODED_F, { "Reserved", "Res", "R" } })
  v = logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.token, 28, 32, nil)) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = _tostring(i.bit)
  end
  return _lv_out
end)())
  av = logicview.dget(accepted_voltages, logicview.tointeger(logicview.add("0b", v), 2), "Unknown")
  self:puta(8, 11, { Ann.DECODED_F, { logicview.add("Voltage accepted: ", av), "Voltage", "Volt", "V" } })
  self:puta(0, 7, { Ann.DECODED_F, { "Echo-back of check pattern", "Echo", "E" } })
  do
    local _lv_a0, _lv_a1 = {  }, St.GET_COMMAND_TOKEN
    self.token = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.decode(self)
  local conds, cmd_pin, clk, dat0, dat1, dat2, dat3, a, cmdstr, handle_cmd, s, handle_response
  while true do
    conds = logicview.dict({ [Pin.CLK] = "r" })
    if logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = logicview.eq(self.state, St.GET_COMMAND_TOKEN)
  if logicview.truth(_v) then return _v end
  _v = logicview.startswith(self.state.value, "GET_RESPONSE")
  return _v
end)()
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.len(self.token), 0)
  return _v
end)()) then
      logicview.dict_update(conds, logicview.dict({ [Pin.CMD] = "l" }))
    end
    do
      local _lv_seq = self:wait(conds)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      cmd_pin = logicview.idx(_lv_seq, 0)
      clk = logicview.idx(_lv_seq, 1)
      dat0 = logicview.idx(_lv_seq, 2)
      dat1 = logicview.idx(_lv_seq, 3)
      dat2 = logicview.idx(_lv_seq, 4)
      dat3 = logicview.idx(_lv_seq, 5)
    end
    if logicview.truth(logicview.eq(self.state, St.GET_COMMAND_TOKEN)) then
      self:get_command_token(cmd_pin)
    elseif logicview.truth(logicview.startswith(self.state.value, "HANDLE_CMD")) then
      do
        local _lv_a0, _lv_a1 = (function() if logicview.truth(self.is_acmd) then return "a" else return "" end end)(), _string.lower(logicview.slice(self.state.value, 10, nil, nil))
        a = _lv_a0
        cmdstr = _lv_a1
      end
      handle_cmd = (function() local _v = self[logicview.pymod("handle_%scmd%s", { a, cmdstr })]; if _v == nil then return nil end; return _v end)()
      handle_cmd()
      if logicview.truth((function()
  local _v
  _v = self.is_acmd
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.contains({ "55", "63" }, cmdstr))
  return _v
end)()) then
        self.is_acmd = false
      end
    elseif logicview.truth(logicview.startswith(self.state.value, "GET_RESPONSE")) then
      s = logicview.pymod("handle_response_%s", _string.lower(logicview.slice(self.state.value, 13, nil, nil)))
      handle_response = (function() local _v = self[s]; if _v == nil then return nil end; return _v end)()
      do
        local _lv_return = false
        local _lv_value = nil
        local _ok, _err = _pcall(function()
          handle_response(cmd_pin)
        end)
        if _lv_return then return _lv_value end
        if not _ok then
          if (_type(_err) == 'table' and _err._exc == "AssertionError") then
            self:handle_cmd()
          else
            _error(_err, 0)
          end
        end
      end
    end
    ::continue_4::
  end
end

return _decoder
