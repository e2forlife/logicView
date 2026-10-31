-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv3+
-- Copyright (C) 2014 Daniel Elstner <daniel.kitta@gmail.com>

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
local reduce, instr_table_by_prefix, string, Ann, Row, Pin, Cycle, AsmFormatter, formatter, ann_data_cycle_map, reduce_bus, signed_byte, Decoder, main_instructions, extended_instructions, bit_instructions, index_instructions, index_bit_instructions
local _decoder

reduce = function(fn, seq, init)
  local acc, start_at = init, 1
  if acc == nil then acc = seq[1]; start_at = 2 end
  for _i = start_at, #seq do acc = fn(acc, seq[_i]) end
  return acc
end
main_instructions = logicview.dict({ [0] = { 0, 0, 0, 0, false, "NOP" }, [1] = { 0, 2, 0, 0, false, "LD BC,{i:04H}h" }, [2] = { 0, 0, 0, 1, false, "LD (BC),A" }, [3] = { 0, 0, 0, 0, false, "INC BC" }, [4] = { 0, 0, 0, 0, false, "INC B" }, [5] = { 0, 0, 0, 0, false, "DEC B" }, [6] = { 0, 1, 0, 0, false, "LD B,{i:02H}h" }, [7] = { 0, 0, 0, 0, false, "RLCA" }, [8] = { 0, 0, 0, 0, false, "EX AF,AF'" }, [9] = { 0, 0, 0, 0, false, "ADD HL,BC" }, [10] = { 0, 0, 1, 0, false, "LD A,(BC)" }, [11] = { 0, 0, 0, 0, false, "DEC BC" }, [12] = { 0, 0, 0, 0, false, "INC C" }, [13] = { 0, 0, 0, 0, false, "DEC C" }, [14] = { 0, 1, 0, 0, false, "LD C,{i:02H}h" }, [15] = { 0, 0, 0, 0, false, "RRCA" }, [16] = { 1, 0, 0, 0, false, "DJNZ ${j:+d}" }, [17] = { 0, 2, 0, 0, false, "LD DE,{i:04H}h" }, [18] = { 0, 0, 0, 1, false, "LD (DE),A" }, [19] = { 0, 0, 0, 0, false, "INC DE" }, [20] = { 0, 0, 0, 0, false, "INC D" }, [21] = { 0, 0, 0, 0, false, "DEC D" }, [22] = { 0, 1, 0, 0, false, "LD D,{i:02H}h" }, [23] = { 0, 0, 0, 0, false, "RLA" }, [24] = { 1, 0, 0, 0, false, "JR ${j:+d}" }, [25] = { 0, 0, 0, 0, false, "ADD HL,DE" }, [26] = { 0, 0, 1, 0, false, "LD A,(DE)" }, [27] = { 0, 0, 0, 0, false, "DEC DE" }, [28] = { 0, 0, 0, 0, false, "INC E" }, [29] = { 0, 0, 0, 0, false, "DEC E" }, [30] = { 0, 1, 0, 0, false, "LD E,{i:02H}h" }, [31] = { 0, 0, 0, 0, false, "RRA" }, [32] = { 1, 0, 0, 0, false, "JR NZ,${j:+d}" }, [33] = { 0, 2, 0, 0, false, "LD HL,{i:04H}h" }, [34] = { 0, 2, 0, 2, false, "LD ({i:04H}h),HL" }, [35] = { 0, 0, 0, 0, false, "INC HL" }, [36] = { 0, 0, 0, 0, false, "INC H" }, [37] = { 0, 0, 0, 0, false, "DEC H" }, [38] = { 0, 1, 0, 0, false, "LD H,{i:02H}h" }, [39] = { 0, 0, 0, 0, false, "DAA" }, [40] = { 1, 0, 0, 0, false, "JR Z,${j:+d}" }, [41] = { 0, 0, 0, 0, false, "ADD HL,HL" }, [42] = { 0, 2, 2, 0, false, "LD HL,({i:04H}h)" }, [43] = { 0, 0, 0, 0, false, "DEC HL" }, [44] = { 0, 0, 0, 0, false, "INC L" }, [45] = { 0, 0, 0, 0, false, "DEC L" }, [46] = { 0, 1, 0, 0, false, "LD L,{i:02H}h" }, [47] = { 0, 0, 0, 0, false, "CPL" }, [48] = { 1, 0, 0, 0, false, "JR NC,${j:+d}" }, [49] = { 0, 2, 0, 0, false, "LD SP,{i:04H}h" }, [50] = { 0, 2, 0, 1, false, "LD ({i:04H}h),A" }, [51] = { 0, 0, 0, 0, false, "INC SP" }, [52] = { 0, 0, 1, 1, false, "INC (HL)" }, [53] = { 0, 0, 1, 1, false, "DEC (HL)" }, [54] = { 0, 1, 0, 1, false, "LD (HL),{i:02H}h" }, [55] = { 0, 0, 0, 0, false, "SCF" }, [56] = { 1, 0, 0, 0, false, "JR C,${j:+d}" }, [57] = { 0, 0, 0, 0, false, "ADD HL,SP" }, [58] = { 0, 2, 1, 0, false, "LD A,({i:04H}h)" }, [59] = { 0, 0, 0, 0, false, "DEC SP" }, [60] = { 0, 0, 0, 0, false, "INC A" }, [61] = { 0, 0, 0, 0, false, "DEC A" }, [62] = { 0, 1, 0, 0, false, "LD A,{i:02H}h" }, [63] = { 0, 0, 0, 0, false, "CCF" }, [64] = { 0, 0, 0, 0, false, "LD B,B" }, [65] = { 0, 0, 0, 0, false, "LD B,C" }, [66] = { 0, 0, 0, 0, false, "LD B,D" }, [67] = { 0, 0, 0, 0, false, "LD B,E" }, [68] = { 0, 0, 0, 0, false, "LD B,H" }, [69] = { 0, 0, 0, 0, false, "LD B,L" }, [70] = { 0, 0, 1, 0, false, "LD B,(HL)" }, [71] = { 0, 0, 0, 0, false, "LD B,A" }, [72] = { 0, 0, 0, 0, false, "LD C,B" }, [73] = { 0, 0, 0, 0, false, "LD C,C" }, [74] = { 0, 0, 0, 0, false, "LD C,D" }, [75] = { 0, 0, 0, 0, false, "LD C,E" }, [76] = { 0, 0, 0, 0, false, "LD C,H" }, [77] = { 0, 0, 0, 0, false, "LD C,L" }, [78] = { 0, 0, 1, 0, false, "LD C,(HL)" }, [79] = { 0, 0, 0, 0, false, "LD C,A" }, [80] = { 0, 0, 0, 0, false, "LD D,B" }, [81] = { 0, 0, 0, 0, false, "LD D,C" }, [82] = { 0, 0, 0, 0, false, "LD D,D" }, [83] = { 0, 0, 0, 0, false, "LD D,E" }, [84] = { 0, 0, 0, 0, false, "LD D,H" }, [85] = { 0, 0, 0, 0, false, "LD D,L" }, [86] = { 0, 0, 1, 0, false, "LD D,(HL)" }, [87] = { 0, 0, 0, 0, false, "LD D,A" }, [88] = { 0, 0, 0, 0, false, "LD E,B" }, [89] = { 0, 0, 0, 0, false, "LD E,C" }, [90] = { 0, 0, 0, 0, false, "LD E,D" }, [91] = { 0, 0, 0, 0, false, "LD E,E" }, [92] = { 0, 0, 0, 0, false, "LD E,H" }, [93] = { 0, 0, 0, 0, false, "LD E,L" }, [94] = { 0, 0, 1, 0, false, "LD E,(HL)" }, [95] = { 0, 0, 0, 0, false, "LD E,A" }, [96] = { 0, 0, 0, 0, false, "LD H,B" }, [97] = { 0, 0, 0, 0, false, "LD H,C" }, [98] = { 0, 0, 0, 0, false, "LD H,D" }, [99] = { 0, 0, 0, 0, false, "LD H,E" }, [100] = { 0, 0, 0, 0, false, "LD H,H" }, [101] = { 0, 0, 0, 0, false, "LD H,L" }, [102] = { 0, 0, 1, 0, false, "LD H,(HL)" }, [103] = { 0, 0, 0, 0, false, "LD H,A" }, [104] = { 0, 0, 0, 0, false, "LD L,B" }, [105] = { 0, 0, 0, 0, false, "LD L,C" }, [106] = { 0, 0, 0, 0, false, "LD L,D" }, [107] = { 0, 0, 0, 0, false, "LD L,E" }, [108] = { 0, 0, 0, 0, false, "LD L,H" }, [109] = { 0, 0, 0, 0, false, "LD L,L" }, [110] = { 0, 0, 1, 0, false, "LD L,(HL)" }, [111] = { 0, 0, 0, 0, false, "LD L,A" }, [112] = { 0, 0, 0, 1, false, "LD (HL),B" }, [113] = { 0, 0, 0, 1, false, "LD (HL),C" }, [114] = { 0, 0, 0, 1, false, "LD (HL),D" }, [115] = { 0, 0, 0, 1, false, "LD (HL),E" }, [116] = { 0, 0, 0, 1, false, "LD (HL),H" }, [117] = { 0, 0, 0, 1, false, "LD (HL),L" }, [118] = { 0, 0, 0, 0, false, "HALT" }, [119] = { 0, 0, 0, 1, false, "LD (HL),A" }, [120] = { 0, 0, 0, 0, false, "LD A,B" }, [121] = { 0, 0, 0, 0, false, "LD A,C" }, [122] = { 0, 0, 0, 0, false, "LD A,D" }, [123] = { 0, 0, 0, 0, false, "LD A,E" }, [124] = { 0, 0, 0, 0, false, "LD A,H" }, [125] = { 0, 0, 0, 0, false, "LD A,L" }, [126] = { 0, 0, 1, 0, false, "LD A,(HL)" }, [127] = { 0, 0, 0, 0, false, "LD A,A" }, [128] = { 0, 0, 0, 0, false, "ADD A,B" }, [129] = { 0, 0, 0, 0, false, "ADD A,C" }, [130] = { 0, 0, 0, 0, false, "ADD A,D" }, [131] = { 0, 0, 0, 0, false, "ADD A,E" }, [132] = { 0, 0, 0, 0, false, "ADD A,H" }, [133] = { 0, 0, 0, 0, false, "ADD A,L" }, [134] = { 0, 0, 1, 0, false, "ADD A,(HL)" }, [135] = { 0, 0, 0, 0, false, "ADD A,A" }, [136] = { 0, 0, 0, 0, false, "ADC A,B" }, [137] = { 0, 0, 0, 0, false, "ADC A,C" }, [138] = { 0, 0, 0, 0, false, "ADC A,D" }, [139] = { 0, 0, 0, 0, false, "ADC A,E" }, [140] = { 0, 0, 0, 0, false, "ADC A,H" }, [141] = { 0, 0, 0, 0, false, "ADC A,L" }, [142] = { 0, 0, 1, 0, false, "ADC A,(HL)" }, [143] = { 0, 0, 0, 0, false, "ADC A,A" }, [144] = { 0, 0, 0, 0, false, "SUB B" }, [145] = { 0, 0, 0, 0, false, "SUB C" }, [146] = { 0, 0, 0, 0, false, "SUB D" }, [147] = { 0, 0, 0, 0, false, "SUB E" }, [148] = { 0, 0, 0, 0, false, "SUB H" }, [149] = { 0, 0, 0, 0, false, "SUB L" }, [150] = { 0, 0, 1, 0, false, "SUB (HL)" }, [151] = { 0, 0, 0, 0, false, "SUB A" }, [152] = { 0, 0, 0, 0, false, "SBC A,B" }, [153] = { 0, 0, 0, 0, false, "SBC A,C" }, [154] = { 0, 0, 0, 0, false, "SBC A,D" }, [155] = { 0, 0, 0, 0, false, "SBC A,E" }, [156] = { 0, 0, 0, 0, false, "SBC A,H" }, [157] = { 0, 0, 0, 0, false, "SBC A,L" }, [158] = { 0, 0, 1, 0, false, "SBC A,(HL)" }, [159] = { 0, 0, 0, 0, false, "SBC A,A" }, [160] = { 0, 0, 0, 0, false, "AND B" }, [161] = { 0, 0, 0, 0, false, "AND C" }, [162] = { 0, 0, 0, 0, false, "AND D" }, [163] = { 0, 0, 0, 0, false, "AND E" }, [164] = { 0, 0, 0, 0, false, "AND H" }, [165] = { 0, 0, 0, 0, false, "AND L" }, [166] = { 0, 0, 1, 0, false, "AND (HL)" }, [167] = { 0, 0, 0, 0, false, "AND A" }, [168] = { 0, 0, 0, 0, false, "XOR B" }, [169] = { 0, 0, 0, 0, false, "XOR C" }, [170] = { 0, 0, 0, 0, false, "XOR D" }, [171] = { 0, 0, 0, 0, false, "XOR E" }, [172] = { 0, 0, 0, 0, false, "XOR H" }, [173] = { 0, 0, 0, 0, false, "XOR L" }, [174] = { 0, 0, 1, 0, false, "XOR (HL)" }, [175] = { 0, 0, 0, 0, false, "XOR A" }, [176] = { 0, 0, 0, 0, false, "OR B" }, [177] = { 0, 0, 0, 0, false, "OR C" }, [178] = { 0, 0, 0, 0, false, "OR D" }, [179] = { 0, 0, 0, 0, false, "OR E" }, [180] = { 0, 0, 0, 0, false, "OR H" }, [181] = { 0, 0, 0, 0, false, "OR L" }, [182] = { 0, 0, 1, 0, false, "OR (HL)" }, [183] = { 0, 0, 0, 0, false, "OR A" }, [184] = { 0, 0, 0, 0, false, "CP B" }, [185] = { 0, 0, 0, 0, false, "CP C" }, [186] = { 0, 0, 0, 0, false, "CP D" }, [187] = { 0, 0, 0, 0, false, "CP E" }, [188] = { 0, 0, 0, 0, false, "CP H" }, [189] = { 0, 0, 0, 0, false, "CP L" }, [190] = { 0, 0, 1, 0, false, "CP (HL)" }, [191] = { 0, 0, 0, 0, false, "CP A" }, [192] = { 0, 0, 2, 0, false, "RET NZ" }, [193] = { 0, 0, 2, 0, false, "POP BC" }, [194] = { 0, 2, 0, 0, false, "JP NZ,{i:04H}h" }, [195] = { 0, 2, 0, 0, false, "JP {i:04H}h" }, [196] = { 0, 2, 0, (-2), false, "CALL NZ,{i:04H}h" }, [197] = { 0, 0, 0, (-2), false, "PUSH BC" }, [198] = { 0, 1, 0, 0, false, "ADD A,{i:02H}h" }, [199] = { 0, 0, 0, (-2), false, "RST 00h" }, [200] = { 0, 0, 2, 0, false, "RET Z" }, [201] = { 0, 0, 2, 0, false, "RET" }, [202] = { 0, 2, 0, 0, false, "JP Z,{i:04H}h" }, [204] = { 0, 2, 0, (-2), false, "CALL Z,{i:04H}h" }, [205] = { 0, 2, 0, (-2), false, "CALL {i:04H}h" }, [206] = { 0, 1, 0, 0, false, "ADC A,{i:02H}h" }, [207] = { 0, 0, 0, (-2), false, "RST 08h" }, [208] = { 0, 0, 2, 0, false, "RET NC" }, [209] = { 0, 0, 2, 0, false, "POP DE" }, [210] = { 0, 2, 0, 0, false, "JP NC,{i:04H}h" }, [211] = { 0, 1, 0, 1, false, "OUT ({i:02H}h),A" }, [212] = { 0, 2, 0, (-2), false, "CALL NC,{i:04H}h" }, [213] = { 0, 0, 0, (-2), false, "PUSH DE" }, [214] = { 0, 1, 0, 0, false, "SUB {i:02H}h" }, [215] = { 0, 0, 0, (-2), false, "RST 10h" }, [216] = { 0, 0, 2, 0, false, "RET C" }, [217] = { 0, 0, 0, 0, false, "EXX" }, [218] = { 0, 2, 0, 0, false, "JP C,{i:04H}h" }, [219] = { 0, 1, 1, 0, false, "IN A,({i:02H}h)" }, [220] = { 0, 2, 0, (-2), false, "CALL C,{i:04H}h" }, [222] = { 0, 1, 0, 0, false, "SBC A,{i:02H}h" }, [223] = { 0, 0, 0, (-2), false, "RST 18h" }, [224] = { 0, 0, 2, 0, false, "RET PO" }, [225] = { 0, 0, 2, 0, false, "POP HL" }, [226] = { 0, 2, 0, 0, false, "JP PO,{i:04H}h" }, [227] = { 0, 0, 2, 2, false, "EX (SP),HL" }, [228] = { 0, 2, 0, (-2), false, "CALL PO,{i:04H}h" }, [229] = { 0, 0, 0, (-2), false, "PUSH HL" }, [230] = { 0, 1, 0, 0, false, "AND {i:02H}h" }, [231] = { 0, 0, 0, (-2), false, "RST 20h" }, [232] = { 0, 0, 2, 0, false, "RET PE" }, [233] = { 0, 0, 0, 0, false, "JP (HL)" }, [234] = { 0, 2, 0, 0, false, "JP PE,{i:04H}h" }, [235] = { 0, 0, 0, 0, false, "EX DE,HL" }, [236] = { 0, 2, 0, (-2), false, "CALL PE,{i:04H}h" }, [238] = { 0, 1, 0, 0, false, "XOR {i:02H}h" }, [239] = { 0, 0, 0, (-2), false, "RST 28h" }, [240] = { 0, 0, 2, 0, false, "RET P" }, [241] = { 0, 0, 2, 0, false, "POP AF" }, [242] = { 0, 2, 0, 0, false, "JP P,{i:04H}h" }, [243] = { 0, 0, 0, 0, false, "DI" }, [244] = { 0, 2, 0, (-2), false, "CALL P,{i:04H}h" }, [245] = { 0, 0, 0, (-2), false, "PUSH AF" }, [246] = { 0, 1, 0, 0, false, "OR {i:02H}h" }, [247] = { 0, 0, 0, (-2), false, "RST 30h" }, [248] = { 0, 0, 2, 0, false, "RET M" }, [249] = { 0, 0, 0, 0, false, "LD SP,HL" }, [250] = { 0, 2, 0, 0, false, "JP M,{i:04H}h" }, [251] = { 0, 0, 0, 0, false, "EI" }, [252] = { 0, 2, 0, (-2), false, "CALL M,{i:04H}h" }, [254] = { 0, 1, 0, 0, false, "CP {i:02H}h" }, [255] = { 0, 0, 0, (-2), false, "RST 38h" } })
extended_instructions = logicview.dict({ [64] = { 0, 0, 1, 0, false, "IN B,(C)" }, [65] = { 0, 0, 0, 1, false, "OUT (C),B" }, [66] = { 0, 0, 0, 0, false, "SBC HL,BC" }, [67] = { 0, 2, 0, 2, false, "LD ({i:04H}h),BC" }, [68] = { 0, 0, 0, 0, false, "NEG" }, [69] = { 0, 0, 2, 0, false, "RETN" }, [70] = { 0, 0, 0, 0, false, "IM 0" }, [71] = { 0, 0, 0, 0, false, "LD I,A" }, [72] = { 0, 0, 1, 0, false, "IN C,(C)" }, [73] = { 0, 0, 0, 1, false, "OUT (C),C" }, [74] = { 0, 0, 0, 0, false, "ADC HL,BC" }, [75] = { 0, 2, 2, 0, false, "LD BC,({i:04H}h)" }, [76] = { 0, 0, 0, 0, false, "NEG" }, [77] = { 0, 0, 2, 0, false, "RETI" }, [78] = { 0, 0, 0, 0, false, "IM 0/1" }, [79] = { 0, 0, 0, 0, false, "LD R,A" }, [80] = { 0, 0, 1, 0, false, "IN D,(C)" }, [81] = { 0, 0, 0, 1, false, "OUT (C),D" }, [82] = { 0, 0, 0, 0, false, "SBC HL,DE" }, [83] = { 0, 2, 0, 2, false, "LD ({i:04H}h),DE" }, [84] = { 0, 0, 0, 0, false, "NEG" }, [85] = { 0, 0, 2, 0, false, "RETN" }, [86] = { 0, 0, 0, 0, false, "IM 1" }, [87] = { 0, 0, 0, 0, false, "LD A,I" }, [88] = { 0, 0, 1, 0, false, "IN E,(C)" }, [89] = { 0, 0, 0, 1, false, "OUT (C),E" }, [90] = { 0, 0, 0, 0, false, "ADC HL,DE" }, [91] = { 0, 2, 2, 0, false, "LD DE,({i:04H}h)" }, [92] = { 0, 0, 0, 0, false, "NEG" }, [93] = { 0, 0, 2, 0, false, "RETN" }, [94] = { 0, 0, 0, 0, false, "IM 2" }, [95] = { 0, 0, 0, 0, false, "LD A,R" }, [96] = { 0, 0, 1, 0, false, "IN H,(C)" }, [97] = { 0, 0, 0, 1, false, "OUT (C),H" }, [98] = { 0, 0, 0, 0, false, "SBC HL,HL" }, [99] = { 0, 2, 0, 2, false, "LD ({i:04H}h),HL" }, [100] = { 0, 0, 0, 0, false, "NEG" }, [101] = { 0, 0, 2, 0, false, "RETN" }, [102] = { 0, 0, 0, 0, false, "IM 0" }, [103] = { 0, 0, 1, 1, false, "RRD" }, [104] = { 0, 0, 1, 0, false, "IN L,(C)" }, [105] = { 0, 0, 0, 1, false, "OUT (C),L" }, [106] = { 0, 0, 0, 0, false, "ADC HL,HL" }, [107] = { 0, 2, 2, 0, false, "LD HL,({i:04H}h)" }, [108] = { 0, 0, 0, 0, false, "NEG" }, [109] = { 0, 0, 2, 0, false, "RETN" }, [110] = { 0, 0, 0, 0, false, "IM 0/1" }, [111] = { 0, 0, 1, 1, false, "RLD" }, [112] = { 0, 0, 1, 0, false, "IN (C)" }, [113] = { 0, 0, 0, 1, false, "OUT (C),0" }, [114] = { 0, 0, 0, 0, false, "SBC HL,SP" }, [115] = { 0, 2, 0, 2, false, "LD ({i:04H}h),SP" }, [116] = { 0, 0, 0, 0, false, "NEG" }, [117] = { 0, 0, 2, 0, false, "RETN" }, [118] = { 0, 0, 0, 0, false, "IM 1" }, [120] = { 0, 0, 1, 0, false, "IN A,(C)" }, [121] = { 0, 0, 0, 1, false, "OUT (C),A" }, [122] = { 0, 0, 0, 0, false, "ADC HL,SP" }, [123] = { 0, 2, 2, 0, false, "LD SP,({i:04H}h)" }, [124] = { 0, 0, 0, 0, false, "NEG" }, [125] = { 0, 0, 2, 0, false, "RETN" }, [126] = { 0, 0, 0, 0, false, "IM 2" }, [160] = { 0, 0, 1, 1, false, "LDI" }, [161] = { 0, 0, 1, 0, false, "CPI" }, [162] = { 0, 0, 1, 1, false, "INI" }, [163] = { 0, 0, 1, 1, false, "OUTI" }, [168] = { 0, 0, 1, 1, false, "LDD" }, [169] = { 0, 0, 1, 0, false, "CPD" }, [170] = { 0, 0, 1, 1, false, "IND" }, [171] = { 0, 0, 1, 1, false, "OUTD" }, [176] = { 0, 0, 1, 1, true, "LDIR" }, [177] = { 0, 0, 1, 0, true, "CPIR" }, [178] = { 0, 0, 1, 1, true, "INIR" }, [179] = { 0, 0, 1, 1, true, "OTIR" }, [184] = { 0, 0, 1, 1, true, "LDDR" }, [185] = { 0, 0, 1, 0, true, "CPDR" }, [186] = { 0, 0, 1, 1, true, "INDR" }, [187] = { 0, 0, 1, 1, true, "OTDR" } })
bit_instructions = logicview.dict({ [0] = { 0, 0, 0, 0, false, "RLC B" }, [1] = { 0, 0, 0, 0, false, "RLC C" }, [2] = { 0, 0, 0, 0, false, "RLC D" }, [3] = { 0, 0, 0, 0, false, "RLC E" }, [4] = { 0, 0, 0, 0, false, "RLC H" }, [5] = { 0, 0, 0, 0, false, "RLC L" }, [6] = { 0, 0, 1, 1, false, "RLC (HL)" }, [7] = { 0, 0, 0, 0, false, "RLC A" }, [8] = { 0, 0, 0, 0, false, "RRC B" }, [9] = { 0, 0, 0, 0, false, "RRC C" }, [10] = { 0, 0, 0, 0, false, "RRC D" }, [11] = { 0, 0, 0, 0, false, "RRC E" }, [12] = { 0, 0, 0, 0, false, "RRC H" }, [13] = { 0, 0, 0, 0, false, "RRC L" }, [14] = { 0, 0, 1, 1, false, "RRC (HL)" }, [15] = { 0, 0, 0, 0, false, "RRC A" }, [16] = { 0, 0, 0, 0, false, "RL B" }, [17] = { 0, 0, 0, 0, false, "RL C" }, [18] = { 0, 0, 0, 0, false, "RL D" }, [19] = { 0, 0, 0, 0, false, "RL E" }, [20] = { 0, 0, 0, 0, false, "RL H" }, [21] = { 0, 0, 0, 0, false, "RL L" }, [22] = { 0, 0, 1, 1, false, "RL (HL)" }, [23] = { 0, 0, 0, 0, false, "RL A" }, [24] = { 0, 0, 0, 0, false, "RR B" }, [25] = { 0, 0, 0, 0, false, "RR C" }, [26] = { 0, 0, 0, 0, false, "RR D" }, [27] = { 0, 0, 0, 0, false, "RR E" }, [28] = { 0, 0, 0, 0, false, "RR H" }, [29] = { 0, 0, 0, 0, false, "RR L" }, [30] = { 0, 0, 1, 1, false, "RR (HL)" }, [31] = { 0, 0, 0, 0, false, "RR A" }, [32] = { 0, 0, 0, 0, false, "SLA B" }, [33] = { 0, 0, 0, 0, false, "SLA C" }, [34] = { 0, 0, 0, 0, false, "SLA D" }, [35] = { 0, 0, 0, 0, false, "SLA E" }, [36] = { 0, 0, 0, 0, false, "SLA H" }, [37] = { 0, 0, 0, 0, false, "SLA L" }, [38] = { 0, 0, 1, 1, false, "SLA (HL)" }, [39] = { 0, 0, 0, 0, false, "SLA A" }, [40] = { 0, 0, 0, 0, false, "SRA B" }, [41] = { 0, 0, 0, 0, false, "SRA C" }, [42] = { 0, 0, 0, 0, false, "SRA D" }, [43] = { 0, 0, 0, 0, false, "SRA E" }, [44] = { 0, 0, 0, 0, false, "SRA H" }, [45] = { 0, 0, 0, 0, false, "SRA L" }, [46] = { 0, 0, 1, 1, false, "SRA (HL)" }, [47] = { 0, 0, 0, 0, false, "SRA A" }, [48] = { 0, 0, 0, 0, false, "SLL B" }, [49] = { 0, 0, 0, 0, false, "SLL C" }, [50] = { 0, 0, 0, 0, false, "SLL D" }, [51] = { 0, 0, 0, 0, false, "SLL E" }, [52] = { 0, 0, 0, 0, false, "SLL H" }, [53] = { 0, 0, 0, 0, false, "SLL L" }, [54] = { 0, 0, 1, 1, false, "SLL (HL)" }, [55] = { 0, 0, 0, 0, false, "SLL A" }, [56] = { 0, 0, 0, 0, false, "SRL B" }, [57] = { 0, 0, 0, 0, false, "SRL C" }, [58] = { 0, 0, 0, 0, false, "SRL D" }, [59] = { 0, 0, 0, 0, false, "SRL E" }, [60] = { 0, 0, 0, 0, false, "SRL H" }, [61] = { 0, 0, 0, 0, false, "SRL L" }, [62] = { 0, 0, 1, 1, false, "SRL (HL)" }, [63] = { 0, 0, 0, 0, false, "SRL A" }, [64] = { 0, 0, 0, 0, false, "BIT 0,B" }, [65] = { 0, 0, 0, 0, false, "BIT 0,C" }, [66] = { 0, 0, 0, 0, false, "BIT 0,D" }, [67] = { 0, 0, 0, 0, false, "BIT 0,E" }, [68] = { 0, 0, 0, 0, false, "BIT 0,H" }, [69] = { 0, 0, 0, 0, false, "BIT 0,L" }, [70] = { 0, 0, 1, 0, false, "BIT 0,(HL)" }, [71] = { 0, 0, 0, 0, false, "BIT 0,A" }, [72] = { 0, 0, 0, 0, false, "BIT 1,B" }, [73] = { 0, 0, 0, 0, false, "BIT 1,C" }, [74] = { 0, 0, 0, 0, false, "BIT 1,D" }, [75] = { 0, 0, 0, 0, false, "BIT 1,E" }, [76] = { 0, 0, 0, 0, false, "BIT 1,H" }, [77] = { 0, 0, 0, 0, false, "BIT 1,L" }, [78] = { 0, 0, 1, 0, false, "BIT 1,(HL)" }, [79] = { 0, 0, 0, 0, false, "BIT 1,A" }, [80] = { 0, 0, 0, 0, false, "BIT 2,B" }, [81] = { 0, 0, 0, 0, false, "BIT 2,C" }, [82] = { 0, 0, 0, 0, false, "BIT 2,D" }, [83] = { 0, 0, 0, 0, false, "BIT 2,E" }, [84] = { 0, 0, 0, 0, false, "BIT 2,H" }, [85] = { 0, 0, 0, 0, false, "BIT 2,L" }, [86] = { 0, 0, 1, 0, false, "BIT 2,(HL)" }, [87] = { 0, 0, 0, 0, false, "BIT 2,A" }, [88] = { 0, 0, 0, 0, false, "BIT 3,B" }, [89] = { 0, 0, 0, 0, false, "BIT 3,C" }, [90] = { 0, 0, 0, 0, false, "BIT 3,D" }, [91] = { 0, 0, 0, 0, false, "BIT 3,E" }, [92] = { 0, 0, 0, 0, false, "BIT 3,H" }, [93] = { 0, 0, 0, 0, false, "BIT 3,L" }, [94] = { 0, 0, 1, 0, false, "BIT 3,(HL)" }, [95] = { 0, 0, 0, 0, false, "BIT 3,A" }, [96] = { 0, 0, 0, 0, false, "BIT 4,B" }, [97] = { 0, 0, 0, 0, false, "BIT 4,C" }, [98] = { 0, 0, 0, 0, false, "BIT 4,D" }, [99] = { 0, 0, 0, 0, false, "BIT 4,E" }, [100] = { 0, 0, 0, 0, false, "BIT 4,H" }, [101] = { 0, 0, 0, 0, false, "BIT 4,L" }, [102] = { 0, 0, 1, 0, false, "BIT 4,(HL)" }, [103] = { 0, 0, 0, 0, false, "BIT 4,A" }, [104] = { 0, 0, 0, 0, false, "BIT 5,B" }, [105] = { 0, 0, 0, 0, false, "BIT 5,C" }, [106] = { 0, 0, 0, 0, false, "BIT 5,D" }, [107] = { 0, 0, 0, 0, false, "BIT 5,E" }, [108] = { 0, 0, 0, 0, false, "BIT 5,H" }, [109] = { 0, 0, 0, 0, false, "BIT 5,L" }, [110] = { 0, 0, 1, 0, false, "BIT 5,(HL)" }, [111] = { 0, 0, 0, 0, false, "BIT 5,A" }, [112] = { 0, 0, 0, 0, false, "BIT 6,B" }, [113] = { 0, 0, 0, 0, false, "BIT 6,C" }, [114] = { 0, 0, 0, 0, false, "BIT 6,D" }, [115] = { 0, 0, 0, 0, false, "BIT 6,E" }, [116] = { 0, 0, 0, 0, false, "BIT 6,H" }, [117] = { 0, 0, 0, 0, false, "BIT 6,L" }, [118] = { 0, 0, 1, 0, false, "BIT 6,(HL)" }, [119] = { 0, 0, 0, 0, false, "BIT 6,A" }, [120] = { 0, 0, 0, 0, false, "BIT 7,B" }, [121] = { 0, 0, 0, 0, false, "BIT 7,C" }, [122] = { 0, 0, 0, 0, false, "BIT 7,D" }, [123] = { 0, 0, 0, 0, false, "BIT 7,E" }, [124] = { 0, 0, 0, 0, false, "BIT 7,H" }, [125] = { 0, 0, 0, 0, false, "BIT 7,L" }, [126] = { 0, 0, 1, 0, false, "BIT 7,(HL)" }, [127] = { 0, 0, 0, 0, false, "BIT 7,A" }, [128] = { 0, 0, 0, 0, false, "RES 0,B" }, [129] = { 0, 0, 0, 0, false, "RES 0,C" }, [130] = { 0, 0, 0, 0, false, "RES 0,D" }, [131] = { 0, 0, 0, 0, false, "RES 0,E" }, [132] = { 0, 0, 0, 0, false, "RES 0,H" }, [133] = { 0, 0, 0, 0, false, "RES 0,L" }, [134] = { 0, 0, 1, 1, false, "RES 0,(HL)" }, [135] = { 0, 0, 0, 0, false, "RES 0,A" }, [136] = { 0, 0, 0, 0, false, "RES 1,B" }, [137] = { 0, 0, 0, 0, false, "RES 1,C" }, [138] = { 0, 0, 0, 0, false, "RES 1,D" }, [139] = { 0, 0, 0, 0, false, "RES 1,E" }, [140] = { 0, 0, 0, 0, false, "RES 1,H" }, [141] = { 0, 0, 0, 0, false, "RES 1,L" }, [142] = { 0, 0, 1, 1, false, "RES 1,(HL)" }, [143] = { 0, 0, 0, 0, false, "RES 1,A" }, [144] = { 0, 0, 0, 0, false, "RES 2,B" }, [145] = { 0, 0, 0, 0, false, "RES 2,C" }, [146] = { 0, 0, 0, 0, false, "RES 2,D" }, [147] = { 0, 0, 0, 0, false, "RES 2,E" }, [148] = { 0, 0, 0, 0, false, "RES 2,H" }, [149] = { 0, 0, 0, 0, false, "RES 2,L" }, [150] = { 0, 0, 1, 1, false, "RES 2,(HL)" }, [151] = { 0, 0, 0, 0, false, "RES 2,A" }, [152] = { 0, 0, 0, 0, false, "RES 3,B" }, [153] = { 0, 0, 0, 0, false, "RES 3,C" }, [154] = { 0, 0, 0, 0, false, "RES 3,D" }, [155] = { 0, 0, 0, 0, false, "RES 3,E" }, [156] = { 0, 0, 0, 0, false, "RES 3,H" }, [157] = { 0, 0, 0, 0, false, "RES 3,L" }, [158] = { 0, 0, 1, 1, false, "RES 3,(HL)" }, [159] = { 0, 0, 0, 0, false, "RES 3,A" }, [160] = { 0, 0, 0, 0, false, "RES 4,B" }, [161] = { 0, 0, 0, 0, false, "RES 4,C" }, [162] = { 0, 0, 0, 0, false, "RES 4,D" }, [163] = { 0, 0, 0, 0, false, "RES 4,E" }, [164] = { 0, 0, 0, 0, false, "RES 4,H" }, [165] = { 0, 0, 0, 0, false, "RES 4,L" }, [166] = { 0, 0, 1, 1, false, "RES 4,(HL)" }, [167] = { 0, 0, 0, 0, false, "RES 4,A" }, [168] = { 0, 0, 0, 0, false, "RES 5,B" }, [169] = { 0, 0, 0, 0, false, "RES 5,C" }, [170] = { 0, 0, 0, 0, false, "RES 5,D" }, [171] = { 0, 0, 0, 0, false, "RES 5,E" }, [172] = { 0, 0, 0, 0, false, "RES 5,H" }, [173] = { 0, 0, 0, 0, false, "RES 5,L" }, [174] = { 0, 0, 1, 1, false, "RES 5,(HL)" }, [175] = { 0, 0, 0, 0, false, "RES 5,A" }, [176] = { 0, 0, 0, 0, false, "RES 6,B" }, [177] = { 0, 0, 0, 0, false, "RES 6,C" }, [178] = { 0, 0, 0, 0, false, "RES 6,D" }, [179] = { 0, 0, 0, 0, false, "RES 6,E" }, [180] = { 0, 0, 0, 0, false, "RES 6,H" }, [181] = { 0, 0, 0, 0, false, "RES 6,L" }, [182] = { 0, 0, 1, 1, false, "RES 6,(HL)" }, [183] = { 0, 0, 0, 0, false, "RES 6,A" }, [184] = { 0, 0, 0, 0, false, "RES 7,B" }, [185] = { 0, 0, 0, 0, false, "RES 7,C" }, [186] = { 0, 0, 0, 0, false, "RES 7,D" }, [187] = { 0, 0, 0, 0, false, "RES 7,E" }, [188] = { 0, 0, 0, 0, false, "RES 7,H" }, [189] = { 0, 0, 0, 0, false, "RES 7,L" }, [190] = { 0, 0, 1, 1, false, "RES 7,(HL)" }, [191] = { 0, 0, 0, 0, false, "RES 7,A" }, [192] = { 0, 0, 0, 0, false, "SET 0,B" }, [193] = { 0, 0, 0, 0, false, "SET 0,C" }, [194] = { 0, 0, 0, 0, false, "SET 0,D" }, [195] = { 0, 0, 0, 0, false, "SET 0,E" }, [196] = { 0, 0, 0, 0, false, "SET 0,H" }, [197] = { 0, 0, 0, 0, false, "SET 0,L" }, [198] = { 0, 0, 1, 1, false, "SET 0,(HL)" }, [199] = { 0, 0, 0, 0, false, "SET 0,A" }, [200] = { 0, 0, 0, 0, false, "SET 1,B" }, [201] = { 0, 0, 0, 0, false, "SET 1,C" }, [202] = { 0, 0, 0, 0, false, "SET 1,D" }, [203] = { 0, 0, 0, 0, false, "SET 1,E" }, [204] = { 0, 0, 0, 0, false, "SET 1,H" }, [205] = { 0, 0, 0, 0, false, "SET 1,L" }, [206] = { 0, 0, 1, 1, false, "SET 1,(HL)" }, [207] = { 0, 0, 0, 0, false, "SET 1,A" }, [208] = { 0, 0, 0, 0, false, "SET 2,B" }, [209] = { 0, 0, 0, 0, false, "SET 2,C" }, [210] = { 0, 0, 0, 0, false, "SET 2,D" }, [211] = { 0, 0, 0, 0, false, "SET 2,E" }, [212] = { 0, 0, 0, 0, false, "SET 2,H" }, [213] = { 0, 0, 0, 0, false, "SET 2,L" }, [214] = { 0, 0, 1, 1, false, "SET 2,(HL)" }, [215] = { 0, 0, 0, 0, false, "SET 2,A" }, [216] = { 0, 0, 0, 0, false, "SET 3,B" }, [217] = { 0, 0, 0, 0, false, "SET 3,C" }, [218] = { 0, 0, 0, 0, false, "SET 3,D" }, [219] = { 0, 0, 0, 0, false, "SET 3,E" }, [220] = { 0, 0, 0, 0, false, "SET 3,H" }, [221] = { 0, 0, 0, 0, false, "SET 3,L" }, [222] = { 0, 0, 1, 1, false, "SET 3,(HL)" }, [223] = { 0, 0, 0, 0, false, "SET 3,A" }, [224] = { 0, 0, 0, 0, false, "SET 4,B" }, [225] = { 0, 0, 0, 0, false, "SET 4,C" }, [226] = { 0, 0, 0, 0, false, "SET 4,D" }, [227] = { 0, 0, 0, 0, false, "SET 4,E" }, [228] = { 0, 0, 0, 0, false, "SET 4,H" }, [229] = { 0, 0, 0, 0, false, "SET 4,L" }, [230] = { 0, 0, 1, 1, false, "SET 4,(HL)" }, [231] = { 0, 0, 0, 0, false, "SET 4,A" }, [232] = { 0, 0, 0, 0, false, "SET 5,B" }, [233] = { 0, 0, 0, 0, false, "SET 5,C" }, [234] = { 0, 0, 0, 0, false, "SET 5,D" }, [235] = { 0, 0, 0, 0, false, "SET 5,E" }, [236] = { 0, 0, 0, 0, false, "SET 5,H" }, [237] = { 0, 0, 0, 0, false, "SET 5,L" }, [238] = { 0, 0, 1, 1, false, "SET 5,(HL)" }, [239] = { 0, 0, 0, 0, false, "SET 5,A" }, [240] = { 0, 0, 0, 0, false, "SET 6,B" }, [241] = { 0, 0, 0, 0, false, "SET 6,C" }, [242] = { 0, 0, 0, 0, false, "SET 6,D" }, [243] = { 0, 0, 0, 0, false, "SET 6,E" }, [244] = { 0, 0, 0, 0, false, "SET 6,H" }, [245] = { 0, 0, 0, 0, false, "SET 6,L" }, [246] = { 0, 0, 1, 1, false, "SET 6,(HL)" }, [247] = { 0, 0, 0, 0, false, "SET 6,A" }, [248] = { 0, 0, 0, 0, false, "SET 7,B" }, [249] = { 0, 0, 0, 0, false, "SET 7,C" }, [250] = { 0, 0, 0, 0, false, "SET 7,D" }, [251] = { 0, 0, 0, 0, false, "SET 7,E" }, [252] = { 0, 0, 0, 0, false, "SET 7,H" }, [253] = { 0, 0, 0, 0, false, "SET 7,L" }, [254] = { 0, 0, 1, 1, false, "SET 7,(HL)" }, [255] = { 0, 0, 0, 0, false, "SET 7,A" } })
index_instructions = logicview.dict({ [9] = { 0, 0, 0, 0, false, "ADD {r},BC" }, [25] = { 0, 0, 0, 0, false, "ADD {r},DE" }, [33] = { 0, 2, 0, 0, false, "LD {r},{i:04H}h" }, [34] = { 0, 2, 0, 2, false, "LD ({i:04H}h),{r}" }, [35] = { 0, 0, 0, 0, false, "INC {r}" }, [36] = { 0, 0, 0, 0, false, "INC {r}h" }, [37] = { 0, 0, 0, 0, false, "DEC {r}h" }, [38] = { 0, 1, 0, 0, false, "LD {r}h,{i:02H}h" }, [41] = { 0, 0, 0, 0, false, "ADD {r},{r}" }, [42] = { 0, 2, 2, 0, false, "LD {r},({i:04H}h)" }, [43] = { 0, 0, 0, 0, false, "DEC {r}" }, [44] = { 0, 0, 0, 0, false, "INC {r}l" }, [45] = { 0, 0, 0, 0, false, "DEC {r}l" }, [46] = { 0, 1, 0, 0, false, "LD {r}l,{i:02H}h" }, [52] = { 1, 0, 1, 1, false, "INC ({r}{d:+d})" }, [53] = { 1, 0, 1, 1, false, "DEC ({r}{d:+d})" }, [54] = { 1, 1, 0, 1, false, "LD ({r}{d:+d}),{i:02H}h" }, [57] = { 0, 0, 0, 0, false, "ADD {r},SP" }, [68] = { 0, 0, 0, 0, false, "LD B,{r}h" }, [69] = { 0, 0, 0, 0, false, "LD B,{r}l" }, [70] = { 1, 0, 1, 0, false, "LD B,({r}{d:+d})" }, [76] = { 0, 0, 0, 0, false, "LD C,{r}h" }, [77] = { 0, 0, 0, 0, false, "LD C,{r}l" }, [78] = { 1, 0, 1, 0, false, "LD C,({r}{d:+d})" }, [84] = { 0, 0, 0, 0, false, "LD D,{r}h" }, [85] = { 0, 0, 0, 0, false, "LD D,{r}l" }, [86] = { 1, 0, 1, 0, false, "LD D,({r}{d:+d})" }, [92] = { 0, 0, 0, 0, false, "LD E,{r}h" }, [93] = { 0, 0, 0, 0, false, "LD E,{r}l" }, [94] = { 1, 0, 1, 0, false, "LD E,({r}{d:+d})" }, [96] = { 0, 0, 0, 0, false, "LD {r}h,B" }, [97] = { 0, 0, 0, 0, false, "LD {r}h,C" }, [98] = { 0, 0, 0, 0, false, "LD {r}h,D" }, [99] = { 0, 0, 0, 0, false, "LD {r}h,E" }, [100] = { 0, 0, 0, 0, false, "LD {r}h,{r}h" }, [101] = { 0, 0, 0, 0, false, "LD {r}h,{r}l" }, [102] = { 1, 0, 1, 0, false, "LD H,({r}{d:+d})" }, [103] = { 0, 0, 0, 0, false, "LD {r}h,A" }, [104] = { 0, 0, 0, 0, false, "LD {r}l,B" }, [105] = { 0, 0, 0, 0, false, "LD {r}l,C" }, [106] = { 0, 0, 0, 0, false, "LD {r}l,D" }, [107] = { 0, 0, 0, 0, false, "LD {r}l,E" }, [108] = { 0, 0, 0, 0, false, "LD {r}l,{r}h" }, [109] = { 0, 0, 0, 0, false, "LD {r}l,{r}l" }, [110] = { 1, 0, 1, 0, false, "LD L,({r}{d:+d})" }, [111] = { 0, 0, 0, 0, false, "LD {r}l,A" }, [112] = { 1, 0, 0, 1, false, "LD ({r}{d:+d}),B" }, [113] = { 1, 0, 0, 1, false, "LD ({r}{d:+d}),C" }, [114] = { 1, 0, 0, 1, false, "LD ({r}{d:+d}),D" }, [115] = { 1, 0, 0, 1, false, "LD ({r}{d:+d}),E" }, [116] = { 1, 0, 0, 1, false, "LD ({r}{d:+d}),H" }, [117] = { 1, 0, 0, 1, false, "LD ({r}{d:+d}),L" }, [119] = { 1, 0, 0, 1, false, "LD ({r}{d:+d}),A" }, [124] = { 0, 0, 0, 0, false, "LD A,{r}h" }, [125] = { 0, 0, 0, 0, false, "LD A,{r}l" }, [126] = { 1, 0, 1, 0, false, "LD A,({r}{d:+d})" }, [132] = { 0, 0, 0, 0, false, "ADD A,{r}h" }, [133] = { 0, 0, 0, 0, false, "ADD A,{r}l" }, [134] = { 1, 0, 1, 0, false, "ADD A,({r}{d:+d})" }, [140] = { 0, 0, 0, 0, false, "ADC A,{r}h" }, [141] = { 0, 0, 0, 0, false, "ADC A,{r}l" }, [142] = { 1, 0, 1, 0, false, "ADC A,({r}{d:+d})" }, [148] = { 0, 0, 0, 0, false, "SUB {r}h" }, [149] = { 0, 0, 0, 0, false, "SUB {r}l" }, [150] = { 1, 0, 1, 0, false, "SUB ({r}{d:+d})" }, [156] = { 0, 0, 0, 0, false, "SBC A,{r}h" }, [157] = { 0, 0, 0, 0, false, "SBC A,{r}l" }, [158] = { 1, 0, 1, 0, false, "SBC A,({r}{d:+d})" }, [164] = { 0, 0, 0, 0, false, "AND {r}h" }, [165] = { 0, 0, 0, 0, false, "AND {r}l" }, [166] = { 1, 0, 1, 0, false, "AND ({r}{d:+d})" }, [172] = { 0, 0, 0, 0, false, "XOR {r}h" }, [173] = { 0, 0, 0, 0, false, "XOR {r}l" }, [174] = { 1, 0, 1, 0, false, "XOR ({r}{d:+d})" }, [180] = { 0, 0, 0, 0, false, "OR {r}h" }, [181] = { 0, 0, 0, 0, false, "OR {r}l" }, [182] = { 1, 0, 1, 0, false, "OR ({r}{d:+d})" }, [188] = { 0, 0, 0, 0, false, "CP {r}h" }, [189] = { 0, 0, 0, 0, false, "CP {r}l" }, [190] = { 1, 0, 1, 0, false, "CP ({r}{d:+d})" }, [225] = { 0, 0, 2, 0, false, "POP {r}" }, [227] = { 0, 0, 2, 2, false, "EX (SP),{r}" }, [229] = { 0, 0, 0, (-2), false, "PUSH {r}" }, [233] = { 0, 0, 0, 0, false, "JP ({r})" }, [249] = { 0, 0, 0, 0, false, "LD SP,{r}" } })
index_bit_instructions = logicview.dict({ [0] = { 0, 0, 1, 1, false, "RLC ({r}{d:+d}),B" }, [1] = { 0, 0, 1, 1, false, "RLC ({r}{d:+d}),C" }, [2] = { 0, 0, 1, 1, false, "RLC ({r}{d:+d}),D" }, [3] = { 0, 0, 1, 1, false, "RLC ({r}{d:+d}),E" }, [4] = { 0, 0, 1, 1, false, "RLC ({r}{d:+d}),H" }, [5] = { 0, 0, 1, 1, false, "RLC ({r}{d:+d}),L" }, [6] = { 0, 0, 1, 1, false, "RLC ({r}{d:+d})" }, [7] = { 0, 0, 1, 1, false, "RLC ({r}{d:+d}),A" }, [8] = { 0, 0, 1, 1, false, "RRC ({r}{d:+d}),B" }, [9] = { 0, 0, 1, 1, false, "RRC ({r}{d:+d}),C" }, [10] = { 0, 0, 1, 1, false, "RRC ({r}{d:+d}),D" }, [11] = { 0, 0, 1, 1, false, "RRC ({r}{d:+d}),E" }, [12] = { 0, 0, 1, 1, false, "RRC ({r}{d:+d}),H" }, [13] = { 0, 0, 1, 1, false, "RRC ({r}{d:+d}),L" }, [14] = { 0, 0, 1, 1, false, "RRC ({r}{d:+d})" }, [15] = { 0, 0, 1, 1, false, "RRC ({r}{d:+d}),A" }, [16] = { 0, 0, 1, 1, false, "RL ({r}{d:+d}),B" }, [17] = { 0, 0, 1, 1, false, "RL ({r}{d:+d}),C" }, [18] = { 0, 0, 1, 1, false, "RL ({r}{d:+d}),D" }, [19] = { 0, 0, 1, 1, false, "RL ({r}{d:+d}),E" }, [20] = { 0, 0, 1, 1, false, "RL ({r}{d:+d}),H" }, [21] = { 0, 0, 1, 1, false, "RL ({r}{d:+d}),L" }, [22] = { 0, 0, 1, 1, false, "RL ({r}{d:+d})" }, [23] = { 0, 0, 1, 1, false, "RL ({r}{d:+d}),A" }, [24] = { 0, 0, 1, 1, false, "RR ({r}{d:+d}),B" }, [25] = { 0, 0, 1, 1, false, "RR ({r}{d:+d}),C" }, [26] = { 0, 0, 1, 1, false, "RR ({r}{d:+d}),D" }, [27] = { 0, 0, 1, 1, false, "RR ({r}{d:+d}),E" }, [28] = { 0, 0, 1, 1, false, "RR ({r}{d:+d}),H" }, [29] = { 0, 0, 1, 1, false, "RR ({r}{d:+d}),L" }, [30] = { 0, 0, 1, 1, false, "RR ({r}{d:+d})" }, [31] = { 0, 0, 1, 1, false, "RR ({r}{d:+d}),A" }, [32] = { 0, 0, 1, 1, false, "SLA ({r}{d:+d}),B" }, [33] = { 0, 0, 1, 1, false, "SLA ({r}{d:+d}),C" }, [34] = { 0, 0, 1, 1, false, "SLA ({r}{d:+d}),D" }, [35] = { 0, 0, 1, 1, false, "SLA ({r}{d:+d}),E" }, [36] = { 0, 0, 1, 1, false, "SLA ({r}{d:+d}),H" }, [37] = { 0, 0, 1, 1, false, "SLA ({r}{d:+d}),L" }, [38] = { 0, 0, 1, 1, false, "SLA ({r}{d:+d})" }, [39] = { 0, 0, 1, 1, false, "SLA ({r}{d:+d}),A" }, [40] = { 0, 0, 1, 1, false, "SRA ({r}{d:+d}),B" }, [41] = { 0, 0, 1, 1, false, "SRA ({r}{d:+d}),C" }, [42] = { 0, 0, 1, 1, false, "SRA ({r}{d:+d}),D" }, [43] = { 0, 0, 1, 1, false, "SRA ({r}{d:+d}),E" }, [44] = { 0, 0, 1, 1, false, "SRA ({r}{d:+d}),H" }, [45] = { 0, 0, 1, 1, false, "SRA ({r}{d:+d}),L" }, [46] = { 0, 0, 1, 1, false, "SRA ({r}{d:+d})" }, [47] = { 0, 0, 1, 1, false, "SRA ({r}{d:+d}),A" }, [48] = { 0, 0, 1, 1, false, "SLL ({r}{d:+d}),B" }, [49] = { 0, 0, 1, 1, false, "SLL ({r}{d:+d}),C" }, [50] = { 0, 0, 1, 1, false, "SLL ({r}{d:+d}),D" }, [51] = { 0, 0, 1, 1, false, "SLL ({r}{d:+d}),E" }, [52] = { 0, 0, 1, 1, false, "SLL ({r}{d:+d}),H" }, [53] = { 0, 0, 1, 1, false, "SLL ({r}{d:+d}),L" }, [54] = { 0, 0, 1, 1, false, "SLL ({r}{d:+d})" }, [55] = { 0, 0, 1, 1, false, "SLL ({r}{d:+d}),A" }, [56] = { 0, 0, 1, 1, false, "SRL ({r}{d:+d}),B" }, [57] = { 0, 0, 1, 1, false, "SRL ({r}{d:+d}),C" }, [58] = { 0, 0, 1, 1, false, "SRL ({r}{d:+d}),D" }, [59] = { 0, 0, 1, 1, false, "SRL ({r}{d:+d}),E" }, [60] = { 0, 0, 1, 1, false, "SRL ({r}{d:+d}),H" }, [61] = { 0, 0, 1, 1, false, "SRL ({r}{d:+d}),L" }, [62] = { 0, 0, 1, 1, false, "SRL ({r}{d:+d})" }, [63] = { 0, 0, 1, 1, false, "SRL ({r}{d:+d}),A" }, [64] = { 0, 0, 1, 0, false, "BIT 0,({r}{d:+d})" }, [65] = { 0, 0, 1, 0, false, "BIT 0,({r}{d:+d})" }, [66] = { 0, 0, 1, 0, false, "BIT 0,({r}{d:+d})" }, [67] = { 0, 0, 1, 0, false, "BIT 0,({r}{d:+d})" }, [68] = { 0, 0, 1, 0, false, "BIT 0,({r}{d:+d})" }, [69] = { 0, 0, 1, 0, false, "BIT 0,({r}{d:+d})" }, [70] = { 0, 0, 1, 0, false, "BIT 0,({r}{d:+d})" }, [71] = { 0, 0, 1, 0, false, "BIT 0,({r}{d:+d})" }, [72] = { 0, 0, 1, 0, false, "BIT 1,({r}{d:+d})" }, [73] = { 0, 0, 1, 0, false, "BIT 1,({r}{d:+d})" }, [74] = { 0, 0, 1, 0, false, "BIT 1,({r}{d:+d})" }, [75] = { 0, 0, 1, 0, false, "BIT 1,({r}{d:+d})" }, [76] = { 0, 0, 1, 0, false, "BIT 1,({r}{d:+d})" }, [77] = { 0, 0, 1, 0, false, "BIT 1,({r}{d:+d})" }, [78] = { 0, 0, 1, 0, false, "BIT 1,({r}{d:+d})" }, [79] = { 0, 0, 1, 0, false, "BIT 1,({r}{d:+d})" }, [80] = { 0, 0, 1, 0, false, "BIT 2,({r}{d:+d})" }, [81] = { 0, 0, 1, 0, false, "BIT 2,({r}{d:+d})" }, [82] = { 0, 0, 1, 0, false, "BIT 2,({r}{d:+d})" }, [83] = { 0, 0, 1, 0, false, "BIT 2,({r}{d:+d})" }, [84] = { 0, 0, 1, 0, false, "BIT 2,({r}{d:+d})" }, [85] = { 0, 0, 1, 0, false, "BIT 2,({r}{d:+d})" }, [86] = { 0, 0, 1, 0, false, "BIT 2,({r}{d:+d})" }, [87] = { 0, 0, 1, 0, false, "BIT 2,({r}{d:+d})" }, [88] = { 0, 0, 1, 0, false, "BIT 3,({r}{d:+d})" }, [89] = { 0, 0, 1, 0, false, "BIT 3,({r}{d:+d})" }, [90] = { 0, 0, 1, 0, false, "BIT 3,({r}{d:+d})" }, [91] = { 0, 0, 1, 0, false, "BIT 3,({r}{d:+d})" }, [92] = { 0, 0, 1, 0, false, "BIT 3,({r}{d:+d})" }, [93] = { 0, 0, 1, 0, false, "BIT 3,({r}{d:+d})" }, [94] = { 0, 0, 1, 0, false, "BIT 3,({r}{d:+d})" }, [95] = { 0, 0, 1, 0, false, "BIT 3,({r}{d:+d})" }, [96] = { 0, 0, 1, 0, false, "BIT 4,({r}{d:+d})" }, [97] = { 0, 0, 1, 0, false, "BIT 4,({r}{d:+d})" }, [98] = { 0, 0, 1, 0, false, "BIT 4,({r}{d:+d})" }, [99] = { 0, 0, 1, 0, false, "BIT 4,({r}{d:+d})" }, [100] = { 0, 0, 1, 0, false, "BIT 4,({r}{d:+d})" }, [101] = { 0, 0, 1, 0, false, "BIT 4,({r}{d:+d})" }, [102] = { 0, 0, 1, 0, false, "BIT 4,({r}{d:+d})" }, [103] = { 0, 0, 1, 0, false, "BIT 4,({r}{d:+d})" }, [104] = { 0, 0, 1, 0, false, "BIT 5,({r}{d:+d})" }, [105] = { 0, 0, 1, 0, false, "BIT 5,({r}{d:+d})" }, [106] = { 0, 0, 1, 0, false, "BIT 5,({r}{d:+d})" }, [107] = { 0, 0, 1, 0, false, "BIT 5,({r}{d:+d})" }, [108] = { 0, 0, 1, 0, false, "BIT 5,({r}{d:+d})" }, [109] = { 0, 0, 1, 0, false, "BIT 5,({r}{d:+d})" }, [110] = { 0, 0, 1, 0, false, "BIT 5,({r}{d:+d})" }, [111] = { 0, 0, 1, 0, false, "BIT 5,({r}{d:+d})" }, [112] = { 0, 0, 1, 0, false, "BIT 6,({r}{d:+d})" }, [113] = { 0, 0, 1, 0, false, "BIT 6,({r}{d:+d})" }, [114] = { 0, 0, 1, 0, false, "BIT 6,({r}{d:+d})" }, [115] = { 0, 0, 1, 0, false, "BIT 6,({r}{d:+d})" }, [116] = { 0, 0, 1, 0, false, "BIT 6,({r}{d:+d})" }, [117] = { 0, 0, 1, 0, false, "BIT 6,({r}{d:+d})" }, [118] = { 0, 0, 1, 0, false, "BIT 6,({r}{d:+d})" }, [119] = { 0, 0, 1, 0, false, "BIT 6,({r}{d:+d})" }, [120] = { 0, 0, 1, 0, false, "BIT 7,({r}{d:+d})" }, [121] = { 0, 0, 1, 0, false, "BIT 7,({r}{d:+d})" }, [122] = { 0, 0, 1, 0, false, "BIT 7,({r}{d:+d})" }, [123] = { 0, 0, 1, 0, false, "BIT 7,({r}{d:+d})" }, [124] = { 0, 0, 1, 0, false, "BIT 7,({r}{d:+d})" }, [125] = { 0, 0, 1, 0, false, "BIT 7,({r}{d:+d})" }, [126] = { 0, 0, 1, 0, false, "BIT 7,({r}{d:+d})" }, [127] = { 0, 0, 1, 0, false, "BIT 7,({r}{d:+d})" }, [128] = { 0, 0, 1, 1, false, "RES 0,({r}{d:+d}),B" }, [129] = { 0, 0, 1, 1, false, "RES 0,({r}{d:+d}),C" }, [130] = { 0, 0, 1, 1, false, "RES 0,({r}{d:+d}),D" }, [131] = { 0, 0, 1, 1, false, "RES 0,({r}{d:+d}),E" }, [132] = { 0, 0, 1, 1, false, "RES 0,({r}{d:+d}),H" }, [133] = { 0, 0, 1, 1, false, "RES 0,({r}{d:+d}),L" }, [134] = { 0, 0, 1, 1, false, "RES 0,({r}{d:+d})" }, [135] = { 0, 0, 1, 1, false, "RES 0,({r}{d:+d}),A" }, [136] = { 0, 0, 1, 1, false, "RES 1,({r}{d:+d}),B" }, [137] = { 0, 0, 1, 1, false, "RES 1,({r}{d:+d}),C" }, [138] = { 0, 0, 1, 1, false, "RES 1,({r}{d:+d}),D" }, [139] = { 0, 0, 1, 1, false, "RES 1,({r}{d:+d}),E" }, [140] = { 0, 0, 1, 1, false, "RES 1,({r}{d:+d}),H" }, [141] = { 0, 0, 1, 1, false, "RES 1,({r}{d:+d}),L" }, [142] = { 0, 0, 1, 1, false, "RES 1,({r}{d:+d})" }, [143] = { 0, 0, 1, 1, false, "RES 1,({r}{d:+d}),A" }, [144] = { 0, 0, 1, 1, false, "RES 2,({r}{d:+d}),B" }, [145] = { 0, 0, 1, 1, false, "RES 2,({r}{d:+d}),C" }, [146] = { 0, 0, 1, 1, false, "RES 2,({r}{d:+d}),D" }, [147] = { 0, 0, 1, 1, false, "RES 2,({r}{d:+d}),E" }, [148] = { 0, 0, 1, 1, false, "RES 2,({r}{d:+d}),H" }, [149] = { 0, 0, 1, 1, false, "RES 2,({r}{d:+d}),L" }, [150] = { 0, 0, 1, 1, false, "RES 2,({r}{d:+d})" }, [151] = { 0, 0, 1, 1, false, "RES 2,({r}{d:+d}),A" }, [152] = { 0, 0, 1, 1, false, "RES 3,({r}{d:+d}),B" }, [153] = { 0, 0, 1, 1, false, "RES 3,({r}{d:+d}),C" }, [154] = { 0, 0, 1, 1, false, "RES 3,({r}{d:+d}),D" }, [155] = { 0, 0, 1, 1, false, "RES 3,({r}{d:+d}),E" }, [156] = { 0, 0, 1, 1, false, "RES 3,({r}{d:+d}),H" }, [157] = { 0, 0, 1, 1, false, "RES 3,({r}{d:+d}),L" }, [158] = { 0, 0, 1, 1, false, "RES 3,({r}{d:+d})" }, [159] = { 0, 0, 1, 1, false, "RES 3,({r}{d:+d}),A" }, [160] = { 0, 0, 1, 1, false, "RES 4,({r}{d:+d}),B" }, [161] = { 0, 0, 1, 1, false, "RES 4,({r}{d:+d}),C" }, [162] = { 0, 0, 1, 1, false, "RES 4,({r}{d:+d}),D" }, [163] = { 0, 0, 1, 1, false, "RES 4,({r}{d:+d}),E" }, [164] = { 0, 0, 1, 1, false, "RES 4,({r}{d:+d}),H" }, [165] = { 0, 0, 1, 1, false, "RES 4,({r}{d:+d}),L" }, [166] = { 0, 0, 1, 1, false, "RES 4,({r}{d:+d})" }, [167] = { 0, 0, 1, 1, false, "RES 4,({r}{d:+d}),A" }, [168] = { 0, 0, 1, 1, false, "RES 5,({r}{d:+d}),B" }, [169] = { 0, 0, 1, 1, false, "RES 5,({r}{d:+d}),C" }, [170] = { 0, 0, 1, 1, false, "RES 5,({r}{d:+d}),D" }, [171] = { 0, 0, 1, 1, false, "RES 5,({r}{d:+d}),E" }, [172] = { 0, 0, 1, 1, false, "RES 5,({r}{d:+d}),H" }, [173] = { 0, 0, 1, 1, false, "RES 5,({r}{d:+d}),L" }, [174] = { 0, 0, 1, 1, false, "RES 5,({r}{d:+d})" }, [175] = { 0, 0, 1, 1, false, "RES 5,({r}{d:+d}),A" }, [176] = { 0, 0, 1, 1, false, "RES 6,({r}{d:+d}),B" }, [177] = { 0, 0, 1, 1, false, "RES 6,({r}{d:+d}),C" }, [178] = { 0, 0, 1, 1, false, "RES 6,({r}{d:+d}),D" }, [179] = { 0, 0, 1, 1, false, "RES 6,({r}{d:+d}),E" }, [180] = { 0, 0, 1, 1, false, "RES 6,({r}{d:+d}),H" }, [181] = { 0, 0, 1, 1, false, "RES 6,({r}{d:+d}),L" }, [182] = { 0, 0, 1, 1, false, "RES 6,({r}{d:+d})" }, [183] = { 0, 0, 1, 1, false, "RES 6,({r}{d:+d}),A" }, [184] = { 0, 0, 1, 1, false, "RES 7,({r}{d:+d}),B" }, [185] = { 0, 0, 1, 1, false, "RES 7,({r}{d:+d}),C" }, [186] = { 0, 0, 1, 1, false, "RES 7,({r}{d:+d}),D" }, [187] = { 0, 0, 1, 1, false, "RES 7,({r}{d:+d}),E" }, [188] = { 0, 0, 1, 1, false, "RES 7,({r}{d:+d}),H" }, [189] = { 0, 0, 1, 1, false, "RES 7,({r}{d:+d}),L" }, [190] = { 0, 0, 1, 1, false, "RES 7,({r}{d:+d})" }, [191] = { 0, 0, 1, 1, false, "RES 7,({r}{d:+d}),A" }, [192] = { 0, 0, 1, 1, false, "SET 0,({r}{d:+d}),B" }, [193] = { 0, 0, 1, 1, false, "SET 0,({r}{d:+d}),C" }, [194] = { 0, 0, 1, 1, false, "SET 0,({r}{d:+d}),D" }, [195] = { 0, 0, 1, 1, false, "SET 0,({r}{d:+d}),E" }, [196] = { 0, 0, 1, 1, false, "SET 0,({r}{d:+d}),H" }, [197] = { 0, 0, 1, 1, false, "SET 0,({r}{d:+d}),L" }, [198] = { 0, 0, 1, 1, false, "SET 0,({r}{d:+d})" }, [199] = { 0, 0, 1, 1, false, "SET 0,({r}{d:+d}),A" }, [200] = { 0, 0, 1, 1, false, "SET 1,({r}{d:+d}),B" }, [201] = { 0, 0, 1, 1, false, "SET 1,({r}{d:+d}),C" }, [202] = { 0, 0, 1, 1, false, "SET 1,({r}{d:+d}),D" }, [203] = { 0, 0, 1, 1, false, "SET 1,({r}{d:+d}),E" }, [204] = { 0, 0, 1, 1, false, "SET 1,({r}{d:+d}),H" }, [205] = { 0, 0, 1, 1, false, "SET 1,({r}{d:+d}),L" }, [206] = { 0, 0, 1, 1, false, "SET 1,({r}{d:+d})" }, [207] = { 0, 0, 1, 1, false, "SET 1,({r}{d:+d}),A" }, [208] = { 0, 0, 1, 1, false, "SET 2,({r}{d:+d}),B" }, [209] = { 0, 0, 1, 1, false, "SET 2,({r}{d:+d}),C" }, [210] = { 0, 0, 1, 1, false, "SET 2,({r}{d:+d}),D" }, [211] = { 0, 0, 1, 1, false, "SET 2,({r}{d:+d}),E" }, [212] = { 0, 0, 1, 1, false, "SET 2,({r}{d:+d}),H" }, [213] = { 0, 0, 1, 1, false, "SET 2,({r}{d:+d}),L" }, [214] = { 0, 0, 1, 1, false, "SET 2,({r}{d:+d})" }, [215] = { 0, 0, 1, 1, false, "SET 2,({r}{d:+d}),A" }, [216] = { 0, 0, 1, 1, false, "SET 3,({r}{d:+d}),B" }, [217] = { 0, 0, 1, 1, false, "SET 3,({r}{d:+d}),C" }, [218] = { 0, 0, 1, 1, false, "SET 3,({r}{d:+d}),D" }, [219] = { 0, 0, 1, 1, false, "SET 3,({r}{d:+d}),E" }, [220] = { 0, 0, 1, 1, false, "SET 3,({r}{d:+d}),H" }, [221] = { 0, 0, 1, 1, false, "SET 3,({r}{d:+d}),L" }, [222] = { 0, 0, 1, 1, false, "SET 3,({r}{d:+d})" }, [223] = { 0, 0, 1, 1, false, "SET 3,({r}{d:+d}),A" }, [224] = { 0, 0, 1, 1, false, "SET 4,({r}{d:+d}),B" }, [225] = { 0, 0, 1, 1, false, "SET 4,({r}{d:+d}),C" }, [226] = { 0, 0, 1, 1, false, "SET 4,({r}{d:+d}),D" }, [227] = { 0, 0, 1, 1, false, "SET 4,({r}{d:+d}),E" }, [228] = { 0, 0, 1, 1, false, "SET 4,({r}{d:+d}),H" }, [229] = { 0, 0, 1, 1, false, "SET 4,({r}{d:+d}),L" }, [230] = { 0, 0, 1, 1, false, "SET 4,({r}{d:+d})" }, [231] = { 0, 0, 1, 1, false, "SET 4,({r}{d:+d}),A" }, [232] = { 0, 0, 1, 1, false, "SET 5,({r}{d:+d}),B" }, [233] = { 0, 0, 1, 1, false, "SET 5,({r}{d:+d}),C" }, [234] = { 0, 0, 1, 1, false, "SET 5,({r}{d:+d}),D" }, [235] = { 0, 0, 1, 1, false, "SET 5,({r}{d:+d}),E" }, [236] = { 0, 0, 1, 1, false, "SET 5,({r}{d:+d}),H" }, [237] = { 0, 0, 1, 1, false, "SET 5,({r}{d:+d}),L" }, [238] = { 0, 0, 1, 1, false, "SET 5,({r}{d:+d})" }, [239] = { 0, 0, 1, 1, false, "SET 5,({r}{d:+d}),A" }, [240] = { 0, 0, 1, 1, false, "SET 6,({r}{d:+d}),B" }, [241] = { 0, 0, 1, 1, false, "SET 6,({r}{d:+d}),C" }, [242] = { 0, 0, 1, 1, false, "SET 6,({r}{d:+d}),D" }, [243] = { 0, 0, 1, 1, false, "SET 6,({r}{d:+d}),E" }, [244] = { 0, 0, 1, 1, false, "SET 6,({r}{d:+d}),H" }, [245] = { 0, 0, 1, 1, false, "SET 6,({r}{d:+d}),L" }, [246] = { 0, 0, 1, 1, false, "SET 6,({r}{d:+d})" }, [247] = { 0, 0, 1, 1, false, "SET 6,({r}{d:+d}),A" }, [248] = { 0, 0, 1, 1, false, "SET 7,({r}{d:+d}),B" }, [249] = { 0, 0, 1, 1, false, "SET 7,({r}{d:+d}),C" }, [250] = { 0, 0, 1, 1, false, "SET 7,({r}{d:+d}),D" }, [251] = { 0, 0, 1, 1, false, "SET 7,({r}{d:+d}),E" }, [252] = { 0, 0, 1, 1, false, "SET 7,({r}{d:+d}),H" }, [253] = { 0, 0, 1, 1, false, "SET 7,({r}{d:+d}),L" }, [254] = { 0, 0, 1, 1, false, "SET 7,({r}{d:+d})" }, [255] = { 0, 0, 1, 1, false, "SET 7,({r}{d:+d}),A" } })
instr_table_by_prefix = logicview.dict({ [0] = { main_instructions, "" }, [237] = { extended_instructions, "" }, [203] = { bit_instructions, "" }, [221] = { index_instructions, "IX" }, [253] = { index_instructions, "IY" }, [56779] = { index_bit_instructions, "IX" }, [64971] = { index_bit_instructions, "IY" } })

string = logicview.dict({ hexdigits = '0123456789abcdefABCDEF', digits = '0123456789', ascii_lowercase = 'abcdefghijklmnopqrstuvwxyz', ascii_uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', ascii_letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', whitespace = ' \t\n\r\v\f' })
Ann = {}
Ann.__index = Ann
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(9) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.ADDR = logicview.idx(_lv_seq, 0)
  Ann.MEMRD = logicview.idx(_lv_seq, 1)
  Ann.MEMWR = logicview.idx(_lv_seq, 2)
  Ann.IORD = logicview.idx(_lv_seq, 3)
  Ann.IOWR = logicview.idx(_lv_seq, 4)
  Ann.INSTR = logicview.idx(_lv_seq, 5)
  Ann.ROP = logicview.idx(_lv_seq, 6)
  Ann.WOP = logicview.idx(_lv_seq, 7)
  Ann.WARN = logicview.idx(_lv_seq, 8)
end
Row = {}
Row.__index = Row
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(5) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Row.ADDRBUS = logicview.idx(_lv_seq, 0)
  Row.DATABUS = logicview.idx(_lv_seq, 1)
  Row.INSTRUCTIONS = logicview.idx(_lv_seq, 2)
  Row.OPERANDS = logicview.idx(_lv_seq, 3)
  Row.WARNINGS = logicview.idx(_lv_seq, 4)
end
Pin = {}
Pin.__index = Pin
do
  local _lv_a0, _lv_a1 = 0, 7
  Pin.D0 = _lv_a0
  Pin.D7 = _lv_a1
end
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(8, 13) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Pin.M1 = logicview.idx(_lv_seq, 0)
  Pin.RD = logicview.idx(_lv_seq, 1)
  Pin.WR = logicview.idx(_lv_seq, 2)
  Pin.MREQ = logicview.idx(_lv_seq, 3)
  Pin.IORQ = logicview.idx(_lv_seq, 4)
end
do
  local _lv_a0, _lv_a1 = 13, 28
  Pin.A0 = _lv_a0
  Pin.A15 = _lv_a1
end
Cycle = {}
Cycle.__index = Cycle
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(7) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Cycle.NONE = logicview.idx(_lv_seq, 0)
  Cycle.MEMRD = logicview.idx(_lv_seq, 1)
  Cycle.MEMWR = logicview.idx(_lv_seq, 2)
  Cycle.IORD = logicview.idx(_lv_seq, 3)
  Cycle.IOWR = logicview.idx(_lv_seq, 4)
  Cycle.FETCH = logicview.idx(_lv_seq, 5)
  Cycle.INTACK = logicview.idx(_lv_seq, 6)
end
AsmFormatter = {}
AsmFormatter.__index = AsmFormatter
function AsmFormatter.format_field(self, value, format_spec)
  local result
  if logicview.truth(logicview.endswith(format_spec, "H")) then
    result = logicview.format(value, logicview.add(logicview.slice(format_spec, nil, (-1), nil), "X"))
    return (function() if logicview.truth(logicview.contains(string.digits, logicview.idx(result, 0))) then return result else return logicview.add("0", result) end end)()
  else
    return logicview.format(value, format_spec)
  end
end
function AsmFormatter.new(...)
  local self = _setmetatable({}, AsmFormatter)
  return self
end
formatter = AsmFormatter.new()
ann_data_cycle_map = logicview.dict({ [Cycle.MEMRD] = Ann.MEMRD, [Cycle.MEMWR] = Ann.MEMWR, [Cycle.IORD] = Ann.IORD, [Cycle.IOWR] = Ann.IOWR, [Cycle.FETCH] = Ann.MEMRD, [Cycle.INTACK] = Ann.IORD })
reduce_bus = function(bus)
  if logicview.truth(logicview.contains(bus, 255)) then
    return nil
  else
    return reduce((function(a, b) return ((a << 1) | b) end), logicview.reversed(bus))
  end
end
signed_byte = function(byte)
  return (function() if logicview.truth((byte < 128)) then return byte else return (byte - 256) end end)()
end
_decoder = {
  api_version = 3,
  id = "z80",
  name = "Z80",
  longname = "Zilog Z80 CPU",
  desc = "Zilog Z80 microprocessor disassembly.",
  license = "gplv3+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Retro computing" },
  channels = { logicview.dict({ id = "d0", name = "D0", desc = "Data bus line 0" }), logicview.dict({ id = "d1", name = "D1", desc = "Data bus line 1" }), logicview.dict({ id = "d2", name = "D2", desc = "Data bus line 2" }), logicview.dict({ id = "d3", name = "D3", desc = "Data bus line 3" }), logicview.dict({ id = "d4", name = "D4", desc = "Data bus line 4" }), logicview.dict({ id = "d5", name = "D5", desc = "Data bus line 5" }), logicview.dict({ id = "d6", name = "D6", desc = "Data bus line 6" }), logicview.dict({ id = "d7", name = "D7", desc = "Data bus line 7" }), logicview.dict({ id = "m1", name = "/M1", desc = "Machine cycle 1" }), logicview.dict({ id = "rd", name = "/RD", desc = "Memory or I/O read" }), logicview.dict({ id = "wr", name = "/WR", desc = "Memory or I/O write" }) },
  optional_channels = { logicview.dict({ id = "mreq", name = "/MREQ", desc = "Memory request" }), logicview.dict({ id = "iorq", name = "/IORQ", desc = "I/O request" }), logicview.dict({ id = "a0", name = "A0", desc = "Address bus line 0" }), logicview.dict({ id = "a1", name = "A1", desc = "Address bus line 1" }), logicview.dict({ id = "a2", name = "A2", desc = "Address bus line 2" }), logicview.dict({ id = "a3", name = "A3", desc = "Address bus line 3" }), logicview.dict({ id = "a4", name = "A4", desc = "Address bus line 4" }), logicview.dict({ id = "a5", name = "A5", desc = "Address bus line 5" }), logicview.dict({ id = "a6", name = "A6", desc = "Address bus line 6" }), logicview.dict({ id = "a7", name = "A7", desc = "Address bus line 7" }), logicview.dict({ id = "a8", name = "A8", desc = "Address bus line 8" }), logicview.dict({ id = "a9", name = "A9", desc = "Address bus line 9" }), logicview.dict({ id = "a10", name = "A10", desc = "Address bus line 10" }), logicview.dict({ id = "a11", name = "A11", desc = "Address bus line 11" }), logicview.dict({ id = "a12", name = "A12", desc = "Address bus line 12" }), logicview.dict({ id = "a13", name = "A13", desc = "Address bus line 13" }), logicview.dict({ id = "a14", name = "A14", desc = "Address bus line 14" }), logicview.dict({ id = "a15", name = "A15", desc = "Address bus line 15" }) },
  options = {  },
  annotations = { { "addr", "Memory or I/O address" }, { "memrd", "Byte read from memory" }, { "memwr", "Byte written to memory" }, { "iord", "Byte read from I/O port" }, { "iowr", "Byte written to I/O port" }, { "instr", "Z80 CPU instruction" }, { "rop", "Value of input operand" }, { "wop", "Value of output operand" }, { "warn", "Warning message" } },
  annotation_rows = { { "addrbus", "Address bus", { 0 } }, { "databus", "Data bus", { 1, 2, 3, 4 } }, { "instructions", "Instructions", { 5 } }, { "operands", "Operands", { 6, 7 } }, { "warnings", "Warnings", { 8 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.prev_cycle = Cycle.NONE
  self.op_state = self.state_IDLE
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.bus_data = nil
  self.samplenum = nil
  self.addr_start = nil
  self.data_start = nil
  self.dasm_start = nil
  self.pend_addr = nil
  self.pend_data = nil
  self.ann_data = nil
  self.ann_dasm = nil
  self.prev_cycle = Cycle.NONE
  self.op_state = self.state_IDLE
  self.instr_len = 0
end
function _decoder.decode(self)
  local d0, d1, d2, d3, d4, d5, d6, d7, m1, rd, wr, mreq, iorq, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, pins, cycle
  while true do
    do
      local _lv_seq = self:wait()
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      d0 = logicview.idx(_lv_seq, 0)
      d1 = logicview.idx(_lv_seq, 1)
      d2 = logicview.idx(_lv_seq, 2)
      d3 = logicview.idx(_lv_seq, 3)
      d4 = logicview.idx(_lv_seq, 4)
      d5 = logicview.idx(_lv_seq, 5)
      d6 = logicview.idx(_lv_seq, 6)
      d7 = logicview.idx(_lv_seq, 7)
      m1 = logicview.idx(_lv_seq, 8)
      rd = logicview.idx(_lv_seq, 9)
      wr = logicview.idx(_lv_seq, 10)
      mreq = logicview.idx(_lv_seq, 11)
      iorq = logicview.idx(_lv_seq, 12)
      a0 = logicview.idx(_lv_seq, 13)
      a1 = logicview.idx(_lv_seq, 14)
      a2 = logicview.idx(_lv_seq, 15)
      a3 = logicview.idx(_lv_seq, 16)
      a4 = logicview.idx(_lv_seq, 17)
      a5 = logicview.idx(_lv_seq, 18)
      a6 = logicview.idx(_lv_seq, 19)
      a7 = logicview.idx(_lv_seq, 20)
      a8 = logicview.idx(_lv_seq, 21)
      a9 = logicview.idx(_lv_seq, 22)
      a10 = logicview.idx(_lv_seq, 23)
      a11 = logicview.idx(_lv_seq, 24)
      a12 = logicview.idx(_lv_seq, 25)
      a13 = logicview.idx(_lv_seq, 26)
      a14 = logicview.idx(_lv_seq, 27)
      a15 = logicview.idx(_lv_seq, 28)
    end
    pins = { d0, d1, d2, d3, d4, d5, d6, d7, m1, rd, wr, mreq, iorq, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15 }
    cycle = Cycle.NONE
    if logicview.truth((not logicview.eq(logicview.idx(pins, Pin.MREQ), 1))) then
      if logicview.truth(logicview.eq(logicview.idx(pins, Pin.RD), 0)) then
        cycle = (function() if logicview.truth(logicview.eq(logicview.idx(pins, Pin.M1), 0)) then return Cycle.FETCH else return Cycle.MEMRD end end)()
      elseif logicview.truth(logicview.eq(logicview.idx(pins, Pin.WR), 0)) then
        cycle = Cycle.MEMWR
      end
    elseif logicview.truth(logicview.eq(logicview.idx(pins, Pin.IORQ), 0)) then
      if logicview.truth(logicview.eq(logicview.idx(pins, Pin.M1), 0)) then
        cycle = Cycle.INTACK
      elseif logicview.truth(logicview.eq(logicview.idx(pins, Pin.RD), 0)) then
        cycle = Cycle.IORD
      elseif logicview.truth(logicview.eq(logicview.idx(pins, Pin.WR), 0)) then
        cycle = Cycle.IOWR
      end
    end
    if logicview.truth((not logicview.eq(cycle, Cycle.NONE))) then
      self.bus_data = reduce_bus(logicview.slice(pins, Pin.D0, logicview.add(Pin.D7, 1), nil))
    end
    if logicview.truth((not logicview.eq(cycle, self.prev_cycle))) then
      if logicview.truth(logicview.eq(self.prev_cycle, Cycle.NONE)) then
        self:on_cycle_begin(reduce_bus(logicview.slice(pins, Pin.A0, logicview.add(Pin.A15, 1), nil)))
      elseif logicview.truth(logicview.eq(cycle, Cycle.NONE)) then
        self:on_cycle_end()
      else
        self:on_cycle_trans()
      end
    end
    self.prev_cycle = cycle
    ::continue_1::
  end
end
function _decoder.on_cycle_begin(self, bus_addr)
  if logicview.truth((self.pend_addr ~= nil)) then
    self:put_text(self.addr_start, Ann.ADDR, logicview.pyformat("{:04X}", { self.pend_addr }, logicview.dict({})))
  end
  self.addr_start = self.samplenum
  self.pend_addr = bus_addr
end
function _decoder.on_cycle_end(self)
  self.instr_len = logicview.add(self.instr_len, 1)
  self.op_state = self:op_state()
  if logicview.truth((self.ann_dasm ~= nil)) then
    self:put_disasm()
  end
  if logicview.truth(logicview.eq(self.op_state, self.state_RESTART)) then
    self.op_state = self:state_IDLE()
  end
  if logicview.truth((self.ann_data ~= nil)) then
    self:put_text(self.data_start, self.ann_data, logicview.pyformat("{:02X}", { self.pend_data }, logicview.dict({})))
  end
  self.data_start = self.samplenum
  self.pend_data = self.bus_data
  self.ann_data = logicview.idx(ann_data_cycle_map, self.prev_cycle)
end
function _decoder.on_cycle_trans(self)
  self:put_text((self.samplenum - 1), Ann.WARN, "Illegal transition between control states")
  self.pend_addr = nil
  self.ann_data = nil
  self.ann_dasm = nil
end
function _decoder.put_disasm(self)
  local text
  text = logicview.pyformat(formatter, { self.mnemonic }, logicview.dict({ r = self.arg_reg, d = self.arg_dis, j = logicview.add(self.arg_dis, self.instr_len), i = self.arg_imm, ro = self.arg_read, wo = self.arg_write }))
  self:put_text(self.dasm_start, self.ann_dasm, text)
  self.ann_dasm = nil
  self.dasm_start = self.samplenum
end
function _decoder.put_text(self, ss, ann_idx, ann_text)
  self:put(ss, self.samplenum, self.out_ann, { ann_idx, { ann_text } })
end
function _decoder.state_RESTART(self)
  return self.state_IDLE
end
function _decoder.state_IDLE(self)
  if logicview.truth((not logicview.eq(self.prev_cycle, Cycle.FETCH))) then
    return self.state_IDLE
  end
  self.want_dis = 0
  self.want_imm = 0
  self.want_read = 0
  self.want_write = 0
  self.want_wr_be = false
  self.op_repeat = false
  self.arg_dis = 0
  self.arg_imm = 0
  self.arg_read = 0
  self.arg_write = 0
  self.arg_reg = ""
  self.mnemonic = ""
  self.instr_pend = false
  self.read_pend = false
  self.write_pend = false
  self.dasm_start = self.samplenum
  self.op_prefix = 0
  self.instr_len = 0
  if logicview.truth(logicview.contains({ 203, 237, 221, 253 }, self.bus_data)) then
    return self.state_PRE1
  else
    return self.state_OPCODE
  end
end
function _decoder.state_PRE1(self)
  if logicview.truth((not logicview.eq(self.prev_cycle, Cycle.FETCH))) then
    self.mnemonic = "Prefix not followed by fetch"
    self.ann_dasm = Ann.WARN
    return self.state_RESTART
  end
  self.op_prefix = self.pend_data
  if logicview.truth(logicview.contains({ 221, 253 }, self.op_prefix)) then
    if logicview.truth(logicview.eq(self.bus_data, 203)) then
      return self.state_PRE2
    end
    if logicview.truth(logicview.contains({ 221, 237, 253 }, self.bus_data)) then
      return self.state_PRE1
    end
  end
  return self.state_OPCODE
end
function _decoder.state_PRE2(self)
  if logicview.truth((not logicview.eq(self.prev_cycle, Cycle.MEMRD))) then
    self.mnemonic = "Missing displacement"
    self.ann_dasm = Ann.WARN
    return self.state_RESTART
  end
  self.op_prefix = ((self.op_prefix << 8) | self.pend_data)
  return self.state_PREDIS
end
function _decoder.state_PREDIS(self)
  if logicview.truth((not logicview.eq(self.prev_cycle, Cycle.MEMRD))) then
    self.mnemonic = "Missing opcode"
    self.ann_dasm = Ann.WARN
    return self.state_RESTART
  end
  self.arg_dis = signed_byte(self.pend_data)
  return self.state_OPCODE
end
function _decoder.state_OPCODE(self)
  local table, instruction, want_write
  do
    local _lv_seq = logicview.idx(instr_table_by_prefix, self.op_prefix)
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    table = logicview.idx(_lv_seq, 0)
    self.arg_reg = logicview.idx(_lv_seq, 1)
  end
  self.op_prefix = 0
  instruction = logicview.dget(table, self.pend_data, nil)
  if logicview.truth((instruction == nil)) then
    self.mnemonic = "Invalid instruction"
    self.ann_dasm = Ann.WARN
    return self.state_RESTART
  end
  do
    local _lv_seq = instruction
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    self.want_dis = logicview.idx(_lv_seq, 0)
    self.want_imm = logicview.idx(_lv_seq, 1)
    self.want_read = logicview.idx(_lv_seq, 2)
    want_write = logicview.idx(_lv_seq, 3)
    self.op_repeat = logicview.idx(_lv_seq, 4)
    self.mnemonic = logicview.idx(_lv_seq, 5)
  end
  self.want_write = _math.abs(want_write)
  self.want_wr_be = (want_write < 0)
  if logicview.truth((self.want_dis > 0)) then
    return self.state_POSTDIS
  end
  if logicview.truth((self.want_imm > 0)) then
    return self.state_IMM1
  end
  self.ann_dasm = Ann.INSTR
  if logicview.truth((function()
  local _v
  _v = (self.want_read > 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains({ Cycle.MEMRD, Cycle.IORD }, self.prev_cycle)
  return _v
end)()) then
    return self.state_ROP1
  end
  if logicview.truth((function()
  local _v
  _v = (self.want_write > 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains({ Cycle.MEMWR, Cycle.IOWR }, self.prev_cycle)
  return _v
end)()) then
    return self.state_WOP1
  end
  return self.state_RESTART
end
function _decoder.state_POSTDIS(self)
  self.arg_dis = signed_byte(self.pend_data)
  if logicview.truth((self.want_imm > 0)) then
    return self.state_IMM1
  end
  self.ann_dasm = Ann.INSTR
  if logicview.truth((function()
  local _v
  _v = (self.want_read > 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains({ Cycle.MEMRD, Cycle.IORD }, self.prev_cycle)
  return _v
end)()) then
    return self.state_ROP1
  end
  if logicview.truth((function()
  local _v
  _v = (self.want_write > 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains({ Cycle.MEMWR, Cycle.IOWR }, self.prev_cycle)
  return _v
end)()) then
    return self.state_WOP1
  end
  return self.state_RESTART
end
function _decoder.state_IMM1(self)
  self.arg_imm = self.pend_data
  if logicview.truth((self.want_imm > 1)) then
    return self.state_IMM2
  end
  self.ann_dasm = Ann.INSTR
  if logicview.truth((function()
  local _v
  _v = (self.want_read > 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains({ Cycle.MEMRD, Cycle.IORD }, self.prev_cycle)
  return _v
end)()) then
    return self.state_ROP1
  end
  if logicview.truth((function()
  local _v
  _v = (self.want_write > 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains({ Cycle.MEMWR, Cycle.IOWR }, self.prev_cycle)
  return _v
end)()) then
    return self.state_WOP1
  end
  return self.state_RESTART
end
function _decoder.state_IMM2(self)
  self.arg_imm = (self.arg_imm | (self.pend_data << 8))
  self.ann_dasm = Ann.INSTR
  if logicview.truth((function()
  local _v
  _v = (self.want_read > 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains({ Cycle.MEMRD, Cycle.IORD }, self.prev_cycle)
  return _v
end)()) then
    return self.state_ROP1
  end
  if logicview.truth((function()
  local _v
  _v = (self.want_write > 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains({ Cycle.MEMWR, Cycle.IOWR }, self.prev_cycle)
  return _v
end)()) then
    return self.state_WOP1
  end
  return self.state_RESTART
end
function _decoder.state_ROP1(self)
  self.arg_read = self.pend_data
  if logicview.truth((self.want_read < 2)) then
    self.mnemonic = "{ro:02X}"
    self.ann_dasm = Ann.ROP
  end
  if logicview.truth((self.want_write > 0)) then
    return self.state_WOP1
  end
  if logicview.truth((self.want_read > 1)) then
    return self.state_ROP2
  end
  if logicview.truth((function()
  local _v
  _v = self.op_repeat
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains({ Cycle.MEMRD, Cycle.IORD }, self.prev_cycle)
  return _v
end)()) then
    return self.state_ROP1
  end
  return self.state_RESTART
end
function _decoder.state_ROP2(self)
  self.arg_read = (self.arg_read | (self.pend_data << 8))
  self.mnemonic = "{ro:04X}"
  self.ann_dasm = Ann.ROP
  if logicview.truth((function()
  local _v
  _v = (self.want_write > 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains({ Cycle.MEMWR, Cycle.IOWR }, self.prev_cycle)
  return _v
end)()) then
    return self.state_WOP1
  end
  return self.state_RESTART
end
function _decoder.state_WOP1(self)
  self.arg_write = self.pend_data
  if logicview.truth((self.want_read > 1)) then
    return self.state_ROP2
  end
  if logicview.truth((self.want_write > 1)) then
    return self.state_WOP2
  end
  self.mnemonic = "{wo:02X}"
  self.ann_dasm = Ann.WOP
  if logicview.truth((function()
  local _v
  _v = (self.want_read > 0)
  if not logicview.truth(_v) then return _v end
  _v = self.op_repeat
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains({ Cycle.MEMRD, Cycle.IORD }, self.prev_cycle)
  return _v
end)()) then
    return self.state_ROP1
  end
  return self.state_RESTART
end
function _decoder.state_WOP2(self)
  if logicview.truth(self.want_wr_be) then
    self.arg_write = ((self.arg_write << 8) | self.pend_data)
  else
    self.arg_write = (self.arg_write | (self.pend_data << 8))
  end
  self.mnemonic = "{wo:04X}"
  self.ann_dasm = Ann.WOP
  return self.state_RESTART
end

return _decoder
