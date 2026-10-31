-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2013-2016 Uwe Hermann <uwe@hermann-uwe.de>
-- Copyright (C) 2016 Chris Dreher <chrisdreher@hotmail.com>

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
local RX, TX, Decoder, status_bytes, universal_sysex_nonrealtime, universal_sysex_realtime, sysex_manufacturer_ids, control_functions, gm_instruments, drum_kit, quarter_frame_type, smpte_type, chromatic_notes, percussion_notes
local _decoder

status_bytes = logicview.dict({ [128] = { "note off", "note off", "N off" }, [144] = { "note on", "note on", "N on" }, [160] = { "polyphonic key pressure / aftertouch", "key pressure", "KP" }, [176] = { "control change", "ctrl chg", "CC" }, [192] = { "program change", "prgm chg", "PC" }, [208] = { "channel pressure / aftertouch", "channel pressure", "CP" }, [224] = { "pitch bend change", "pitch bend", "PB" }, [240] = { "system exclusive", "SysEx", "SE" }, [241] = { "MIDI time code quarter frame", "MIDI time code", "MIDI time" }, [242] = { "song position pointer", "song position", "song pos" }, [243] = { "song select", "song select", "song sel" }, [244] = { "undefined 0xf4", "undef 0xf4", "undef" }, [245] = { "undefined 0xf5", "undef 0xf5", "undef" }, [246] = { "tune request", "tune request", "tune req" }, [247] = { "end of system exclusive (EOX)", "end of SysEx", "EOX" }, [248] = { "timing clock", "timing clock", "clock" }, [249] = { "undefined 0xf9", "undef 0xf9", "undef" }, [250] = { "start", "start", "s" }, [251] = { "continue", "continue", "cont" }, [252] = { "stop", "stop", "st" }, [253] = { "undefined 0xfd", "undef 0xfd", "undef" }, [254] = { "active sensing", "active sensing", "sensing" }, [255] = { "system reset", "reset", "rst" } })
universal_sysex_nonrealtime = logicview.dict({ [logicview.tkey(0, nil)] = "unused", [logicview.tkey(1, nil)] = "sample dump header", [logicview.tkey(2, nil)] = "sample data packet", [logicview.tkey(3, nil)] = "sample dump request", [logicview.tkey(4, nil)] = "MIDI time code", [logicview.tkey(4, 0)] = "special", [logicview.tkey(4, 1)] = "punch in points", [logicview.tkey(4, 2)] = "punch out points", [logicview.tkey(4, 3)] = "delete punch in point", [logicview.tkey(4, 4)] = "delete punch out point", [logicview.tkey(4, 5)] = "event start point", [logicview.tkey(4, 6)] = "event stop point", [logicview.tkey(4, 7)] = "event start points with additional info", [logicview.tkey(4, 8)] = "event stop points with additional info", [logicview.tkey(4, 9)] = "delete event start point", [logicview.tkey(4, 10)] = "delete event stop point", [logicview.tkey(4, 11)] = "cue points", [logicview.tkey(4, 12)] = "cue points with additional info", [logicview.tkey(4, 13)] = "delete cue point", [logicview.tkey(4, 14)] = "event name in additional info", [logicview.tkey(5, nil)] = "sample dump extensions", [logicview.tkey(5, 1)] = "multiple loop points", [logicview.tkey(5, 2)] = "loop points request", [logicview.tkey(6, nil)] = "general information", [logicview.tkey(6, 1)] = "identity request", [logicview.tkey(6, 2)] = "identity reply", [logicview.tkey(7, nil)] = "file dump", [logicview.tkey(7, 1)] = "header", [logicview.tkey(7, 2)] = "data packet", [logicview.tkey(7, 3)] = "request", [logicview.tkey(8, nil)] = "MIDI tuning standard", [logicview.tkey(8, 0)] = "bulk dump request", [logicview.tkey(8, 1)] = "bulk dump reply", [logicview.tkey(9, nil)] = "general MIDI", [logicview.tkey(9, 1)] = "general MIDI system on", [logicview.tkey(9, 2)] = "general MIDI system off", [logicview.tkey(123, nil)] = "end of file", [logicview.tkey(124, nil)] = "wait", [logicview.tkey(125, nil)] = "cancel", [logicview.tkey(126, nil)] = "nak", [logicview.tkey(127, nil)] = "ack" })
universal_sysex_realtime = logicview.dict({ [logicview.tkey(0, nil)] = "unused", [logicview.tkey(1, nil)] = "MIDI time code", [logicview.tkey(1, 1)] = "full message", [logicview.tkey(1, 2)] = "user bits", [logicview.tkey(2, nil)] = "MIDI show control", [logicview.tkey(2, 0)] = "MSC extensions", [logicview.tkey(3, nil)] = "notation information", [logicview.tkey(3, 1)] = "bar number", [logicview.tkey(3, 2)] = "time signature (immediate)", [logicview.tkey(3, 66)] = "time signature (delayed)", [logicview.tkey(4, nil)] = "device control", [logicview.tkey(4, 1)] = "master volume", [logicview.tkey(4, 2)] = "master balance", [logicview.tkey(5, nil)] = "real time MTC cueing", [logicview.tkey(5, 0)] = "special", [logicview.tkey(5, 1)] = "punch in points", [logicview.tkey(5, 2)] = "punch out points", [logicview.tkey(5, 3)] = "reserved", [logicview.tkey(5, 4)] = "reserved", [logicview.tkey(5, 5)] = "event start points", [logicview.tkey(5, 6)] = "event stop points", [logicview.tkey(5, 7)] = "event start points with additional info", [logicview.tkey(5, 8)] = "event stop points with additional info", [logicview.tkey(5, 9)] = "reserved", [logicview.tkey(5, 10)] = "reserved", [logicview.tkey(5, 11)] = "cue points", [logicview.tkey(5, 12)] = "cue points with additional info", [logicview.tkey(5, 13)] = "reserved", [logicview.tkey(5, 14)] = "event name in additional info", [logicview.tkey(6, nil)] = "MIDI machine control commands", [logicview.tkey(7, nil)] = "MIDI machine control responses", [logicview.tkey(8, nil)] = "MIDI tuning standard", [logicview.tkey(133, 2)] = "note change" })
sysex_manufacturer_ids = logicview.dict({ [logicview.tkey(1)] = "Sequential", [logicview.tkey(2)] = "IDP", [logicview.tkey(3)] = "Voyetra/Octave-Plateau", [logicview.tkey(4)] = "Moog", [logicview.tkey(5)] = "Passport Designs", [logicview.tkey(6)] = "Lexicon", [logicview.tkey(7)] = "Kurzweil", [logicview.tkey(8)] = "Fender", [logicview.tkey(9)] = "Gulbransen", [logicview.tkey(10)] = "AKG Acoustics", [logicview.tkey(11)] = "Voyce Music", [logicview.tkey(12)] = "Waveframe Corp", [logicview.tkey(13)] = "ADA Signal Processors", [logicview.tkey(14)] = "Garfield Electronics", [logicview.tkey(15)] = "Ensoniq", [logicview.tkey(16)] = "Oberheim", [logicview.tkey(17)] = "Apple Computer", [logicview.tkey(18)] = "Grey Matter Response", [logicview.tkey(19)] = "Digidesign", [logicview.tkey(20)] = "Palm Tree Instruments", [logicview.tkey(21)] = "JLCooper Electronics", [logicview.tkey(22)] = "Lowrey", [logicview.tkey(23)] = "Adams-Smith", [logicview.tkey(24)] = "Emu Systems", [logicview.tkey(25)] = "Harmony Systems", [logicview.tkey(26)] = "ART", [logicview.tkey(27)] = "Baldwin", [logicview.tkey(28)] = "Eventide", [logicview.tkey(29)] = "Inventronics", [logicview.tkey(31)] = "Clarity", [logicview.tkey(0, 0, 1)] = "Time Warner Interactive", [logicview.tkey(0, 0, 7)] = "Digital Music Corp.", [logicview.tkey(0, 0, 8)] = "IOTA Systems", [logicview.tkey(0, 0, 9)] = "New England Digital", [logicview.tkey(0, 0, 10)] = "Artisyn", [logicview.tkey(0, 0, 11)] = "IVL Technologies", [logicview.tkey(0, 0, 12)] = "Southern Music Systems", [logicview.tkey(0, 0, 13)] = "Lake Butler Sound Company", [logicview.tkey(0, 0, 14)] = "Alesis", [logicview.tkey(0, 0, 16)] = "DOD Electronics", [logicview.tkey(0, 0, 17)] = "Studer-Editech", [logicview.tkey(0, 0, 20)] = "Perfect Fretworks", [logicview.tkey(0, 0, 21)] = "KAT", [logicview.tkey(0, 0, 22)] = "Opcode", [logicview.tkey(0, 0, 23)] = "Rane Corp.", [logicview.tkey(0, 0, 24)] = "Anadi Inc.", [logicview.tkey(0, 0, 25)] = "KMX", [logicview.tkey(0, 0, 26)] = "Allen & Heath Brenell", [logicview.tkey(0, 0, 27)] = "Peavy Electronics", [logicview.tkey(0, 0, 28)] = "360 Systems", [logicview.tkey(0, 0, 29)] = "Spectrum Design and Development", [logicview.tkey(0, 0, 30)] = "Marquis Music", [logicview.tkey(0, 0, 31)] = "Zeta Systems", [logicview.tkey(0, 0, 32)] = "Axxes", [logicview.tkey(0, 0, 33)] = "Orban", [logicview.tkey(0, 0, 36)] = "KTI", [logicview.tkey(0, 0, 37)] = "Breakaway Technologies", [logicview.tkey(0, 0, 38)] = "CAE", [logicview.tkey(0, 0, 41)] = "Rocktron Corp.", [logicview.tkey(0, 0, 42)] = "PianoDisc", [logicview.tkey(0, 0, 43)] = "Cannon Research Group", [logicview.tkey(0, 0, 45)] = "Rogers Instrument Corp.", [logicview.tkey(0, 0, 46)] = "Blue Sky Logic", [logicview.tkey(0, 0, 47)] = "Encore Electronics", [logicview.tkey(0, 0, 48)] = "Uptown", [logicview.tkey(0, 0, 49)] = "Voce", [logicview.tkey(0, 0, 50)] = "CTI Audio, Inc. (Music. Intel Dev.)", [logicview.tkey(0, 0, 51)] = "S&S Research", [logicview.tkey(0, 0, 52)] = "Broderbund Software, Inc.", [logicview.tkey(0, 0, 53)] = "Allen Organ Co.", [logicview.tkey(0, 0, 55)] = "Music Quest", [logicview.tkey(0, 0, 56)] = "APHEX", [logicview.tkey(0, 0, 57)] = "Gallien Krueger", [logicview.tkey(0, 0, 58)] = "IBM", [logicview.tkey(0, 0, 60)] = "Hotz Instruments Technologies", [logicview.tkey(0, 0, 61)] = "ETA Lighting", [logicview.tkey(0, 0, 62)] = "NSI Corporation", [logicview.tkey(0, 0, 63)] = "Ad Lib, Inc.", [logicview.tkey(0, 0, 64)] = "Richmond Sound Design", [logicview.tkey(0, 0, 65)] = "Microsoft", [logicview.tkey(0, 0, 66)] = "The Software Toolworks", [logicview.tkey(0, 0, 67)] = "Niche/RJMG", [logicview.tkey(0, 0, 68)] = "Intone", [logicview.tkey(0, 0, 71)] = "GT Electronics / Groove Tubes", [logicview.tkey(0, 0, 73)] = "Timeline Vista", [logicview.tkey(0, 0, 74)] = "Mesa Boogie", [logicview.tkey(0, 0, 76)] = "Sequoia Development", [logicview.tkey(0, 0, 77)] = "Studio Electronics", [logicview.tkey(0, 0, 78)] = "Euphonix", [logicview.tkey(0, 0, 79)] = "InterMIDI, Inc.", [logicview.tkey(0, 0, 80)] = "MIDI Solutions", [logicview.tkey(0, 0, 81)] = "3DO Company", [logicview.tkey(0, 0, 82)] = "Lightwave Research", [logicview.tkey(0, 0, 83)] = "Micro-W", [logicview.tkey(0, 0, 84)] = "Spectral Synthesis", [logicview.tkey(0, 0, 85)] = "Lone Wolf", [logicview.tkey(0, 0, 86)] = "Studio Technologies", [logicview.tkey(0, 0, 87)] = "Peterson EMP", [logicview.tkey(0, 0, 88)] = "Atari", [logicview.tkey(0, 0, 89)] = "Marion Systems", [logicview.tkey(0, 0, 90)] = "Design Event", [logicview.tkey(0, 0, 91)] = "Winjammer Software", [logicview.tkey(0, 0, 92)] = "AT&T Bell Labs", [logicview.tkey(0, 0, 94)] = "Symetrix", [logicview.tkey(0, 0, 95)] = "MIDI the World", [logicview.tkey(0, 0, 96)] = "Desper Products", [logicview.tkey(0, 0, 97)] = "Micros'N MIDI", [logicview.tkey(0, 0, 98)] = "Accordians Intl", [logicview.tkey(0, 0, 99)] = "EuPhonics", [logicview.tkey(0, 0, 100)] = "Musonix", [logicview.tkey(0, 0, 101)] = "Turtle Beach Systems", [logicview.tkey(0, 0, 102)] = "Mackie Designs", [logicview.tkey(0, 0, 103)] = "Compuserve", [logicview.tkey(0, 0, 104)] = "BES Technologies", [logicview.tkey(0, 0, 105)] = "QRS Music Rolls", [logicview.tkey(0, 0, 106)] = "P G Music", [logicview.tkey(0, 0, 107)] = "Sierra Semiconductor", [logicview.tkey(0, 0, 108)] = "EpiGraf Audio Visual", [logicview.tkey(0, 0, 109)] = "Electronics Deiversified", [logicview.tkey(0, 0, 110)] = "Tune 1000", [logicview.tkey(0, 0, 111)] = "Advanced Micro Devices", [logicview.tkey(0, 0, 112)] = "Mediamation", [logicview.tkey(0, 0, 113)] = "Sabine Music", [logicview.tkey(0, 0, 114)] = "Woog Labs", [logicview.tkey(0, 0, 115)] = "Micropolis", [logicview.tkey(0, 0, 116)] = "Ta Horng Musical Inst.", [logicview.tkey(0, 0, 117)] = "eTek (formerly Forte)", [logicview.tkey(0, 0, 118)] = "Electrovoice", [logicview.tkey(0, 0, 119)] = "Midisoft", [logicview.tkey(0, 0, 120)] = "Q-Sound Labs", [logicview.tkey(0, 0, 121)] = "Westrex", [logicview.tkey(0, 0, 122)] = "NVidia", [logicview.tkey(0, 0, 123)] = "ESS Technology", [logicview.tkey(0, 0, 124)] = "MediaTrix Peripherals", [logicview.tkey(0, 0, 125)] = "Brooktree", [logicview.tkey(0, 0, 126)] = "Otari", [logicview.tkey(0, 0, 127)] = "Key Electronics", [logicview.tkey(0, 1, 1)] = "Crystalake Multimedia", [logicview.tkey(0, 1, 2)] = "Crystal Semiconductor", [logicview.tkey(0, 1, 3)] = "Rockwell Semiconductor", [logicview.tkey(32)] = "Passac", [logicview.tkey(33)] = "SIEL", [logicview.tkey(34)] = "Synthaxe", [logicview.tkey(36)] = "Hohner", [logicview.tkey(37)] = "Twister", [logicview.tkey(38)] = "Solton", [logicview.tkey(39)] = "Jellinghaus MS", [logicview.tkey(40)] = "Southworth Music Systems", [logicview.tkey(41)] = "PPG", [logicview.tkey(42)] = "JEN", [logicview.tkey(43)] = "SSL Limited", [logicview.tkey(44)] = "Audio Veritrieb", [logicview.tkey(47)] = "Elka", [logicview.tkey(48)] = "Dynacord", [logicview.tkey(49)] = "Viscount", [logicview.tkey(51)] = "Clavia Digital Instruments", [logicview.tkey(52)] = "Audio Architecture", [logicview.tkey(53)] = "GeneralMusic Corp.", [logicview.tkey(57)] = "Soundcraft Electronics", [logicview.tkey(59)] = "Wersi", [logicview.tkey(60)] = "Avab Elektronik Ab", [logicview.tkey(61)] = "Digigram", [logicview.tkey(62)] = "Waldorf Electronics", [logicview.tkey(63)] = "Quasimidi", [logicview.tkey(0, 32, 0)] = "Dream", [logicview.tkey(0, 32, 1)] = "Strand Lighting", [logicview.tkey(0, 32, 2)] = "Amek Systems", [logicview.tkey(0, 32, 4)] = "Böhm Electronic", [logicview.tkey(0, 32, 6)] = "Trident Audio", [logicview.tkey(0, 32, 7)] = "Real World Studio", [logicview.tkey(0, 32, 9)] = "Yes Technology", [logicview.tkey(0, 32, 10)] = "Audiomatica", [logicview.tkey(0, 32, 11)] = "Bontempi/Farfisa", [logicview.tkey(0, 32, 12)] = "F.B.T. Elettronica", [logicview.tkey(0, 32, 13)] = "MidiTemp", [logicview.tkey(0, 32, 14)] = "LA Audio (Larking Audio)", [logicview.tkey(0, 32, 15)] = "Zero 88 Lighting Limited", [logicview.tkey(0, 32, 16)] = "Micon Audio Electronics GmbH", [logicview.tkey(0, 32, 17)] = "Forefront Technology", [logicview.tkey(0, 32, 19)] = "Kenton Electronics", [logicview.tkey(0, 32, 21)] = "ADB", [logicview.tkey(0, 32, 22)] = "Marshall Products", [logicview.tkey(0, 32, 23)] = "DDA", [logicview.tkey(0, 32, 24)] = "BSS", [logicview.tkey(0, 32, 25)] = "MA Lighting Technology", [logicview.tkey(0, 32, 26)] = "Fatar", [logicview.tkey(0, 32, 27)] = "QSC Audio", [logicview.tkey(0, 32, 28)] = "Artisan Classic Organ", [logicview.tkey(0, 32, 29)] = "Orla Spa", [logicview.tkey(0, 32, 30)] = "Pinnacle Audio", [logicview.tkey(0, 32, 31)] = "TC Electronics", [logicview.tkey(0, 32, 32)] = "Doepfer Musikelektronik", [logicview.tkey(0, 32, 33)] = "Creative Technology Pte", [logicview.tkey(0, 32, 34)] = "Minami/Seiyddo", [logicview.tkey(0, 32, 35)] = "Goldstar", [logicview.tkey(0, 32, 36)] = "Midisoft s.a.s di M. Cima", [logicview.tkey(0, 32, 37)] = "Samick", [logicview.tkey(0, 32, 38)] = "Penny and Giles", [logicview.tkey(0, 32, 39)] = "Acorn Computer", [logicview.tkey(0, 32, 40)] = "LSC Electronics", [logicview.tkey(0, 32, 41)] = "Novation EMS", [logicview.tkey(0, 32, 42)] = "Samkyung Mechatronics", [logicview.tkey(0, 32, 43)] = "Medeli Electronics", [logicview.tkey(0, 32, 44)] = "Charlie Lab", [logicview.tkey(0, 32, 45)] = "Blue Chip Music Tech", [logicview.tkey(0, 32, 46)] = "BEE OH Corp", [logicview.tkey(64)] = "Kawai", [logicview.tkey(65)] = "Roland", [logicview.tkey(66)] = "Korg", [logicview.tkey(67)] = "Yamaha", [logicview.tkey(68)] = "Casio", [logicview.tkey(70)] = "Kamiya Studio", [logicview.tkey(71)] = "Akai", [logicview.tkey(72)] = "Japan Victor", [logicview.tkey(73)] = "Mesosha", [logicview.tkey(74)] = "Hoshino Gakki", [logicview.tkey(75)] = "Fujitsu Elect", [logicview.tkey(76)] = "Sony", [logicview.tkey(77)] = "Nisshin Onpa", [logicview.tkey(78)] = "TEAC", [logicview.tkey(80)] = "Matsushita Electric", [logicview.tkey(81)] = "Fostex", [logicview.tkey(82)] = "Zoom", [logicview.tkey(83)] = "Midori Electronics", [logicview.tkey(84)] = "Matsushita Communication Industrial", [logicview.tkey(85)] = "Suzuki Musical Inst. Mfg.", [logicview.tkey(125)] = "Non-Commercial", [logicview.tkey(126)] = "Universal Non-Realtime", [logicview.tkey(127)] = "Universal Realtime" })
control_functions = logicview.dict({ [0] = { "bank select MSB", "bank MSB", "bank-M" }, [1] = { "modulation wheel/lever MSB", "modulation MSB", "mod-M" }, [2] = { "breath controller MSB", "breath MSB", "breath-M" }, [4] = { "foot controller MSB", "foot MSB", "foot-M" }, [5] = { "portamento time MSB", "portamento MSB", "porta-M" }, [6] = { "data entry MSB", "data entry MSB", "data-M" }, [7] = { "channel volume MSB (formerly main volume)", "channel volume MSB", "ch vol-M" }, [8] = { "balance MSB", "bal MSB", "bal-M" }, [10] = { "pan MSB", "pan MSB", "pan-M" }, [11] = { "expression controller MSB", "expression MSB", "expr-M" }, [12] = { "effect control 1 MSB", "effect 1 MSB", "eff-1-M" }, [13] = { "effect control 2 MSB", "effect 2 MSB", "eff-2-M" }, [16] = { "general purpose controller 1 MSB", "GP ctrl 1 MSB", "GPC-1-M" }, [17] = { "general purpose controller 2 MSB", "GP ctrl 2 MSB", "GPC-2-M" }, [18] = { "general purpose controller 3 MSB", "GP ctrl 3 MSB", "GPC-3-M" }, [19] = { "general purpose controller 4 MSB", "GP ctrl 4 MSB", "GPC-4-M" }, [32] = { "bank select LSB", "bank LSB", "bank-L" }, [33] = { "modulation wheel/lever LSB", "modulation LSB", "mod-L" }, [34] = { "breath controller LSB", "breath LSB", "breath-L" }, [36] = { "foot controller LSB", "foot LSB", "foot-L" }, [37] = { "portamento time LSB", "portamento LSB", "porta-L" }, [38] = { "data entry LSB", "data entry LSB", "data-L" }, [39] = { "channel volume LSB (formerly main volume)", "channel volume LSB", "ch vol-L" }, [40] = { "balance LSB", "bal LSB", "bal-L" }, [42] = { "pan LSB", "pan LSB", "pan-L" }, [43] = { "expression controller LSB", "expression LSB", "expr-L" }, [44] = { "effect control 1 LSB", "effect 1 LSB", "eff-1-L" }, [45] = { "effect control 2 LSB", "effect 2 LSB", "eff-2-L" }, [48] = { "general purpose controller 1 LSB", "GP ctrl 1 LSB", "GPC-1-L" }, [49] = { "general purpose controller 2 LSB", "GP ctrl 2 LSB", "GPC-2-L" }, [50] = { "general purpose controller 3 LSB", "GP ctrl 3 LSB", "GPC-3-L" }, [51] = { "general purpose controller 4 LSB", "GP ctrl 4 LSB", "GPC-4-L" }, [64] = { "damper pedal (sustain)", "sustain", "sust" }, [65] = { "portamento on/off", "porta on/off", "porta on/off" }, [66] = { "sostenuto", "sostenuto", "sostenuto" }, [67] = { "soft pedal", "soft pedal", "soft pedal" }, [68] = { "legato footswitch", "legato switch", "legato" }, [69] = { "hold 2", "hold 2", "hold 2" }, [70] = { "sound controller 1 (default: sound variation)", "sound ctrl 1", "snd ctrl 1" }, [71] = { "sound controller 2 (default: timbre / harmonic intensity)", "sound ctrl 2", "snd ctrl 2" }, [72] = { "sound controller 3 (default: release time)", "sound ctrl 3", "snd ctrl 3" }, [73] = { "sound controller 4 (default: attack time)", "sound ctrl 4", "snd ctrl 4" }, [74] = { "sound controller 5 (default: brightness)", "sound ctrl 5", "snd ctrl 5" }, [75] = { "sound controller 6 (GM2 default: decay time)", "sound ctrl 6", "snd ctrl 6" }, [76] = { "sound controller 7 (GM2 default: vibrato rate)", "sound ctrl 7", "snd ctrl 7" }, [77] = { "sound controller 8 (GM2 default: vibrato depth)", "sound ctrl 8", "snd ctrl 8" }, [78] = { "sound controller 9 (GM2 default: vibrato delay)", "sound ctrl 9", "snd ctrl 9" }, [79] = { "sound controller 10", "sound ctrl 10", "snd ctrl 10" }, [80] = { "general purpose controller 5", "GP controller 5", "GPC-5" }, [81] = { "general purpose controller 6", "GP controller 6", "GPC-6" }, [82] = { "general purpose controller 7", "GP controller 7", "GPC-7" }, [83] = { "general purpose controller 8", "GP controller 8", "GPC-8" }, [84] = { "portamento control", "portamento ctrl", "porta ctrl" }, [91] = { "effects 1 depth (formerly external effects depth)", "effects 1 depth", "eff 1 depth" }, [92] = { "effects 2 depth (formerly tremolo depth)", "effects 2 depth", "eff 2 depth" }, [93] = { "effects 3 depth (formerly chorus depth)", "effects 3 depth", "eff 3 depth" }, [94] = { "effects 4 depth (formerly celeste/detune depth)", "effects 4 depth", "eff 4 depth" }, [95] = { "effects 5 depth (formerly phaser depth)", "effects 5 depth", "eff 5 depth" }, [96] = { "data increment", "data inc", "data++" }, [97] = { "data decrement", "data dec", "data--" }, [98] = { "Non-Registered Parameter Number LSB", "NRPN LSB", "NRPN-L" }, [99] = { "Non-Registered Parameter Number MSB", "NRPN MSB", "NRPN-M" }, [100] = { "Registered Parameter Number LSB", "RPN LSB", "RPN-L" }, [101] = { "Registered Parameter Number MSB", "RPN MSB", "RPN-M" }, [120] = { "all sound off", "all snd off", "snd off" }, [121] = { "reset all controllers", "reset all ctrls", "reset ctrls" }, [122] = { "local control", "local ctrl", "local ctrl" }, [123] = { "all notes off", "notes off", "notes off" }, [124] = { "omni mode off", "omni off", "omni off" }, [125] = { "omni mode on", "omni on", "omni on" }, [126] = { "mono mode on", "mono on", "mono" }, [127] = { "poly mode on", "poly on", "poly" } })
gm_instruments = logicview.dict({ [1] = "Acoustic Grand Piano", [2] = "Bright Acoustic Piano", [3] = "Electric Grand Piano", [4] = "Honky-tonk Piano", [5] = "Electric Piano 1", [6] = "Electric Piano 2", [7] = "Harpsichord", [8] = "Clavi", [9] = "Celesta", [10] = "Glockenspiel", [11] = "Music Box", [12] = "Vibraphone", [13] = "Marimba", [14] = "Xylophone", [15] = "Tubular Bells", [16] = "Dulcimer", [17] = "Drawbar Organ", [18] = "Percussive Organ", [19] = "Rock Organ", [20] = "Church Organ", [21] = "Reed Organ", [22] = "Accordion", [23] = "Harmonica", [24] = "Tango Accordion", [25] = "Acoustic Guitar (nylon)", [26] = "Acoustic Guitar (steel)", [27] = "Electric Guitar (jazz)", [28] = "Electric Guitar (clean)", [29] = "Electric Guitar (muted)", [30] = "Overdriven Guitar", [31] = "Distortion Guitar", [32] = "Guitar harmonics", [33] = "Acoustic Bass", [34] = "Electric Bass (finger)", [35] = "Electric Bass (pick)", [36] = "Fretless Bass", [37] = "Slap Bass 1", [38] = "Slap Bass 2", [39] = "Synth Bass 1", [40] = "Synth Bass 2", [41] = "Violin", [42] = "Viola", [43] = "Cello", [44] = "Contrabass", [45] = "Tremolo Strings", [46] = "Pizzicato Strings", [47] = "Orchestral Harp", [48] = "Timpani", [49] = "String Ensemble 1", [50] = "String Ensemble 2", [51] = "SynthStrings 1", [52] = "SynthStrings 2", [53] = "Choir Aahs", [54] = "Voice Oohs", [55] = "Synth Voice", [56] = "Orchestra Hit", [57] = "Trumpet", [58] = "Trombone", [59] = "Tuba", [60] = "Muted Trumpet", [61] = "French Horn", [62] = "Brass Section", [63] = "SynthBrass 1", [64] = "SynthBrass 2", [65] = "Soprano Sax", [66] = "Alto Sax", [67] = "Tenor Sax", [68] = "Baritone Sax", [69] = "Oboe", [70] = "English Horn", [71] = "Bassoon", [72] = "Clarinet", [73] = "Piccolo", [74] = "Flute", [75] = "Recorder", [76] = "Pan Flute", [77] = "Blown Bottle", [78] = "Shakuhachi", [79] = "Whistle", [80] = "Ocarina", [81] = "Lead 1 (square)", [82] = "Lead 2 (sawtooth)", [83] = "Lead 3 (calliope)", [84] = "Lead 4 (chiff)", [85] = "Lead 5 (charang)", [86] = "Lead 6 (voice)", [87] = "Lead 7 (fifths)", [88] = "Lead 8 (bass + lead)", [89] = "Pad 1 (new age)", [90] = "Pad 2 (warm)", [91] = "Pad 3 (polysynth)", [92] = "Pad 4 (choir)", [93] = "Pad 5 (bowed)", [94] = "Pad 6 (metallic)", [95] = "Pad 7 (halo)", [96] = "Pad 8 (sweep)", [97] = "FX 1 (rain)", [98] = "FX 2 (soundtrack)", [99] = "FX 3 (crystal)", [100] = "FX 4 (atmosphere)", [101] = "FX 5 (brightness)", [102] = "FX 6 (goblins)", [103] = "FX 7 (echoes)", [104] = "FX 8 (sci-fi)", [105] = "Sitar", [106] = "Banjo", [107] = "Shamisen", [108] = "Koto", [109] = "Kalimba", [110] = "Bag pipe", [111] = "Fiddle", [112] = "Shanai", [113] = "Tinkle Bell", [114] = "Agogo", [115] = "Steel Drums", [116] = "Woodblock", [117] = "Taiko Drum", [118] = "Melodic Tom", [119] = "Synth Drum", [120] = "Reverse Cymbal", [121] = "Guitar Fret Noise", [122] = "Breath Noise", [123] = "Seashore", [124] = "Bird Tweet", [125] = "Telephone Ring", [126] = "Helicopter", [127] = "Applause", [128] = "Gunshot" })
drum_kit = logicview.dict({ [1] = "GM Standard Kit", [9] = "GS Room Kit", [17] = "GS Power Kit", [25] = "GS Power Kit", [26] = "GS TR-808 Kit", [33] = "GS Jazz Kit", [41] = "GS Brush Kit", [49] = "GS Orchestra Kit", [57] = "GS Sound FX Kit", [128] = "GS CM-64/CM-32 Kit" })
quarter_frame_type = logicview.dict({ [0] = { "frame count LS nibble", "frame LSN" }, [1] = { "frame count MS nibble", "frame MSN" }, [2] = { "seconds LS nibble", "sec LSN" }, [3] = { "seconds MS nibble", "sec MSN" }, [4] = { "minutes LS nibble", "min LSN" }, [5] = { "minutes MS nibble", "min MSN" }, [6] = { "hours LS nibble", "hrs LSN" }, [7] = { "hours MS nibble and SMPTE type", "hrs MSN" } })
smpte_type = logicview.dict({ [0] = "24 fps", [1] = "25 fps", [2] = "30 fps (drop-frame)", [3] = "30 fps (non-drop)" })
chromatic_notes = logicview.dict({ [0] = "C-1", [1] = "C#-1", [2] = "D-1", [3] = "D#-1", [4] = "E-1", [5] = "F-1", [6] = "F#-1", [7] = "G-1", [8] = "G#-1", [9] = "A-1", [10] = "A#-1", [11] = "B-1", [12] = "C0", [13] = "C#0", [14] = "D0", [15] = "D#0", [16] = "E0", [17] = "F0", [18] = "F#0", [19] = "G0", [20] = "G#0", [21] = "A0", [22] = "A#0", [23] = "B0", [24] = "C1", [25] = "C#1", [26] = "D1", [27] = "D#1", [28] = "E1", [29] = "F1", [30] = "F#1", [31] = "G1", [32] = "G#1", [33] = "A1", [34] = "A#1", [35] = "B1", [36] = "C2", [37] = "C#2", [38] = "D2", [39] = "D#2", [40] = "E2", [41] = "F2", [42] = "F#2", [43] = "G2", [44] = "G#2", [45] = "A2", [46] = "A#2", [47] = "B2", [48] = "C3", [49] = "C#3", [50] = "D3", [51] = "D#3", [52] = "E3", [53] = "F3", [54] = "F#3", [55] = "G3", [56] = "G#3", [57] = "A3", [58] = "A#3", [59] = "B3", [60] = "C4", [61] = "C#4", [62] = "D4", [63] = "D#4", [64] = "E4", [65] = "F4", [66] = "F#4", [67] = "G4", [68] = "G#4", [69] = "A4", [70] = "A#4", [71] = "B4", [72] = "C5", [73] = "C#5", [74] = "D5", [75] = "D#5", [76] = "E5", [77] = "F5", [78] = "F#5", [79] = "G5", [80] = "G#5", [81] = "A5", [82] = "A#5", [83] = "B5", [84] = "C6", [85] = "C#6", [86] = "D6", [87] = "D#6", [88] = "E6", [89] = "F6", [90] = "F#6", [91] = "G6", [92] = "G#6", [93] = "A6", [94] = "A#6", [95] = "B6", [96] = "C7", [97] = "C#7", [98] = "D7", [99] = "D#7", [100] = "E7", [101] = "F7", [102] = "F#7", [103] = "G7", [104] = "G#7", [105] = "A7", [106] = "A#7", [107] = "B7", [108] = "C8", [109] = "C#8", [110] = "D8", [111] = "D#8", [112] = "E8", [113] = "F8", [114] = "F#8", [115] = "G8", [116] = "G#8", [117] = "A8", [118] = "A#8", [119] = "B8", [120] = "C9", [121] = "C#9", [122] = "D9", [123] = "D#9", [124] = "E9", [125] = "F9", [126] = "F#9", [127] = "G9" })
percussion_notes = logicview.dict({ [35] = "Acoustic Bass Drum", [36] = "Bass Drum 1", [37] = "Side Stick", [38] = "Acoustic Snare", [39] = "Hand Clap", [40] = "Electric Snare", [41] = "Low Floor Tom", [42] = "Closed Hi Hat", [43] = "High Floor Tom", [44] = "Pedal Hi-Hat", [45] = "Low Tom", [46] = "Open Hi-Hat", [47] = "Low-Mid Tom", [48] = "Hi Mid Tom", [49] = "Crash Cymbal 1", [50] = "High Tom", [51] = "Ride Cymbal 1", [52] = "Chinese Cymbal", [53] = "Ride Bell", [54] = "Tambourine", [55] = "Splash Cymbal", [56] = "Cowbell", [57] = "Crash Cymbal 2", [58] = "Vibraslap", [59] = "Ride Cymbal 2", [60] = "Hi Bongo", [61] = "Low Bongo", [62] = "Mute Hi Conga", [63] = "Open Hi Conga", [64] = "Low Conga", [65] = "High Timbale", [66] = "Low Timbale", [67] = "High Agogo", [68] = "Low Agogo", [69] = "Cabasa", [70] = "Maracas", [71] = "Short Whistle", [72] = "Long Whistle", [73] = "Short Guiro", [74] = "Long Guiro", [75] = "Claves", [76] = "Hi Wood Block", [77] = "Low Wood Block", [78] = "Mute Cuica", [79] = "Open Cuica", [80] = "Mute Triangle", [81] = "Open Triangle" })

RX = 0
TX = 1
_decoder = {
  api_version = 3,
  id = "midi",
  name = "MIDI",
  longname = "Musical Instrument Digital Interface",
  desc = "Musical Instrument Digital Interface (MIDI) protocol.",
  license = "gplv2+",
  inputs = { "uart" },
  outputs = {  },
  tags = { "Audio", "PC" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "text-verbose", "Human-readable text (verbose)" }, { "text-sysreal-verbose", "Human-readable SysReal text (verbose)" }, { "text-error", "Human-readable Error text" } },
  annotation_rows = { { "normal", "Normal", { 0, 2 } }, { "sys-real", "SysReal", { 1 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "IDLE"
  self.status_byte = 0
  self.explicit_status_byte = false
  self.cmd = {  }
  self.ss = nil
  self.es = nil
  self.ss_block = nil
  self.es_block = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss_block, self.es_block, self.out_ann, data)
end
function _decoder.get_note_name(self, channel, note)
  if logicview.truth((not logicview.eq(channel, 10))) then
    return logicview.idx(chromatic_notes, note)
  else
    return logicview.add("assuming ", logicview.dget(percussion_notes, note, "undefined"))
  end
end
function _decoder.check_for_garbage_flush(self, is_flushed)
  if logicview.truth(is_flushed) then
    if logicview.truth(self.explicit_status_byte) then
      logicview.list_insert(self.cmd, 0, self.status_byte)
    end
    self:handle_garbage_msg(nil)
  end
end
function _decoder.soft_clear_status_byte(self)
  self.explicit_status_byte = false
end
function _decoder.hard_clear_status_byte(self)
  self.status_byte = 0
  self.explicit_status_byte = false
end
function _decoder.set_status_byte(self, newbyte)
  self.status_byte = newbyte
  self.explicit_status_byte = true
end
function _decoder.handle_channel_msg_0x80(self, is_flushed)
  local c, msg, chan, note, velocity, note_name
  c = self.cmd
  if logicview.truth((logicview.len(c) < 2)) then
    self:check_for_garbage_flush(is_flushed)
    return
  end
  self.es_block = self.es
  do
    local _lv_a0, _lv_a1 = (self.status_byte & 240), logicview.add((self.status_byte & 15), 1)
    msg = _lv_a0
    chan = _lv_a1
  end
  do
    local _lv_a0, _lv_a1 = logicview.idx(c, 0), logicview.idx(c, 1)
    note = _lv_a0
    velocity = _lv_a1
  end
  note_name = self:get_note_name(chan, note)
  self:putx({ 0, { logicview.pymod("Channel %d: %s (note = %d '%s', velocity = %d)", { chan, logicview.idx(logicview.idx(status_bytes, msg), 0), note, note_name, velocity }), logicview.pymod("ch %d: %s %d, velocity = %d", { chan, logicview.idx(logicview.idx(status_bytes, msg), 1), note, velocity }), logicview.pymod("%d: %s %d, vel %d", { chan, logicview.idx(logicview.idx(status_bytes, msg), 2), note, velocity }) } })
  do
    local _lv_a0, _lv_a1 = {  }, "IDLE"
    self.cmd = _lv_a0
    self.state = _lv_a1
  end
  self:soft_clear_status_byte()
end
function _decoder.handle_channel_msg_0x90(self, is_flushed)
  local c, msg, chan, note, velocity, s, note_name
  c = self.cmd
  if logicview.truth((logicview.len(c) < 2)) then
    self:check_for_garbage_flush(is_flushed)
    return
  end
  self.es_block = self.es
  do
    local _lv_a0, _lv_a1 = (self.status_byte & 240), logicview.add((self.status_byte & 15), 1)
    msg = _lv_a0
    chan = _lv_a1
  end
  do
    local _lv_a0, _lv_a1 = logicview.idx(c, 0), logicview.idx(c, 1)
    note = _lv_a0
    velocity = _lv_a1
  end
  s = (function() if logicview.truth(logicview.eq(velocity, 0)) then return logicview.idx(status_bytes, 128) else return logicview.idx(status_bytes, msg) end end)()
  note_name = self:get_note_name(chan, note)
  self:putx({ 0, { logicview.pymod("Channel %d: %s (note = %d '%s', velocity = %d)", { chan, logicview.idx(s, 0), note, note_name, velocity }), logicview.pymod("ch %d: %s %d, velocity = %d", { chan, logicview.idx(s, 1), note, velocity }), logicview.pymod("%d: %s %d, vel %d", { chan, logicview.idx(s, 2), note, velocity }) } })
  do
    local _lv_a0, _lv_a1 = {  }, "IDLE"
    self.cmd = _lv_a0
    self.state = _lv_a1
  end
  self:soft_clear_status_byte()
end
function _decoder.handle_channel_msg_0xa0(self, is_flushed)
  local c, msg, chan, note, pressure, note_name
  c = self.cmd
  if logicview.truth((logicview.len(c) < 2)) then
    self:check_for_garbage_flush(is_flushed)
    return
  end
  self.es_block = self.es
  do
    local _lv_a0, _lv_a1 = (self.status_byte & 240), logicview.add((self.status_byte & 15), 1)
    msg = _lv_a0
    chan = _lv_a1
  end
  do
    local _lv_a0, _lv_a1 = logicview.idx(c, 0), logicview.idx(c, 1)
    note = _lv_a0
    pressure = _lv_a1
  end
  note_name = self:get_note_name(chan, note)
  self:putx({ 0, { logicview.pymod("Channel %d: %s of %d for note = %d '%s'", { chan, logicview.idx(logicview.idx(status_bytes, msg), 0), pressure, note, note_name }), logicview.pymod("ch %d: %s %d for note %d", { chan, logicview.idx(logicview.idx(status_bytes, msg), 1), pressure, note }), logicview.pymod("%d: %s %d, N %d", { chan, logicview.idx(logicview.idx(status_bytes, msg), 2), pressure, note }) } })
  do
    local _lv_a0, _lv_a1 = {  }, "IDLE"
    self.cmd = _lv_a0
    self.state = _lv_a1
  end
  self:soft_clear_status_byte()
end
function _decoder.handle_controller_0x44(self)
  local c, msg, chan, vv, t
  c = self.cmd
  do
    local _lv_a0, _lv_a1 = (self.status_byte & 240), logicview.add((self.status_byte & 15), 1)
    msg = _lv_a0
    chan = _lv_a1
  end
  vv = logicview.idx(c, 1)
  t = (function() if logicview.truth((vv <= 63)) then return { "normal", "no" } else return { "legato", "yes" } end end)()
  self:putx({ 0, { logicview.pymod("Channel %d: %s '%s' = %s", { chan, logicview.idx(logicview.idx(status_bytes, msg), 0), logicview.idx(logicview.idx(control_functions, 68), 0), logicview.idx(t, 0) }), logicview.pymod("ch %d: %s '%s' = %s", { chan, logicview.idx(logicview.idx(status_bytes, msg), 1), logicview.idx(logicview.idx(control_functions, 68), 1), logicview.idx(t, 0) }), logicview.pymod("%d: %s '%s' = %s", { chan, logicview.idx(logicview.idx(status_bytes, msg), 2), logicview.idx(logicview.idx(control_functions, 68), 2), logicview.idx(t, 1) }) } })
end
function _decoder.handle_controller_0x54(self)
  local c, msg, chan, kk, kk_name
  c = self.cmd
  do
    local _lv_a0, _lv_a1 = (self.status_byte & 240), logicview.add((self.status_byte & 15), 1)
    msg = _lv_a0
    chan = _lv_a1
  end
  kk = logicview.idx(c, 1)
  kk_name = self:get_note_name(chan, kk)
  self:putx({ 0, { logicview.pymod("Channel %d: %s '%s' (source note = %d / %s)", { chan, logicview.idx(logicview.idx(status_bytes, msg), 0), logicview.idx(logicview.idx(control_functions, 84), 0), kk, kk_name }), logicview.pymod("ch %d: %s '%s' (source note = %d)", { chan, logicview.idx(logicview.idx(status_bytes, msg), 1), logicview.idx(logicview.idx(control_functions, 84), 1), kk }), logicview.pymod("%d: %s '%s' (src N %d)", { chan, logicview.idx(logicview.idx(status_bytes, msg), 2), logicview.idx(logicview.idx(control_functions, 84), 2), kk }) } })
end
function _decoder.handle_controller_generic(self)
  local c, msg, chan, fn, param, default_name, ctrl_fn
  c = self.cmd
  do
    local _lv_a0, _lv_a1 = (self.status_byte & 240), logicview.add((self.status_byte & 15), 1)
    msg = _lv_a0
    chan = _lv_a1
  end
  do
    local _lv_a0, _lv_a1 = logicview.idx(c, 0), logicview.idx(c, 1)
    fn = _lv_a0
    param = _lv_a1
  end
  default_name = "undefined"
  ctrl_fn = logicview.dget(control_functions, fn, default_name)
  if logicview.truth(logicview.eq(ctrl_fn, default_name)) then
    ctrl_fn = { logicview.pymod("undefined 0x%02x", fn), logicview.pymod("undef 0x%02x", fn), logicview.pymod("0x%02x", fn) }
  end
  self:putx({ 0, { logicview.pymod("Channel %d: %s '%s' (param = 0x%02x)", { chan, logicview.idx(logicview.idx(status_bytes, msg), 0), logicview.idx(ctrl_fn, 0), param }), logicview.pymod("ch %d: %s '%s' (param = 0x%02x)", { chan, logicview.idx(logicview.idx(status_bytes, msg), 1), logicview.idx(ctrl_fn, 1), param }), logicview.pymod("%d: %s '%s' is 0x%02x", { chan, logicview.idx(logicview.idx(status_bytes, msg), 2), logicview.idx(ctrl_fn, 2), param }) } })
end
function _decoder.handle_channel_mode(self)
  local c, msg, chan, mm, vv, mode_fn, vv_string
  c = self.cmd
  do
    local _lv_a0, _lv_a1 = (self.status_byte & 240), logicview.add((self.status_byte & 15), 1)
    msg = _lv_a0
    chan = _lv_a1
  end
  do
    local _lv_a0, _lv_a1 = logicview.idx(c, 0), logicview.idx(c, 1)
    mm = _lv_a0
    vv = _lv_a1
  end
  mode_fn = logicview.dget(control_functions, mm, { "undefined", "undef", "undef" })
  vv_string = { "", "" }
  if logicview.truth(logicview.eq(mm, 122)) then
    if logicview.truth(logicview.eq(vv, 0)) then
      vv_string = { "off", "off" }
    elseif logicview.truth(logicview.eq(vv, 127)) then
      vv_string = { "on", "on" }
    else
      vv_string = { logicview.pymod("(non-standard param value of 0x%02x)", vv), logicview.pymod("0x%02x", vv) }
    end
  elseif logicview.truth(logicview.eq(mm, 126)) then
    if logicview.truth((not logicview.eq(vv, 0))) then
      vv_string = { logicview.pymod("(%d channels)", vv), logicview.pymod("(%d ch)", vv) }
    else
      vv_string = { "(channels 'basic' through 16)", "(ch 'basic' thru 16)" }
    end
  elseif logicview.truth((not logicview.eq(vv, 0))) then
    vv_string = { logicview.pymod("(non-standard param value of 0x%02x)", vv), logicview.pymod("0x%02x", vv) }
  end
  self:putx({ 0, { logicview.pymod("Channel %d: %s '%s' %s", { chan, logicview.idx(logicview.idx(status_bytes, msg), 0), logicview.idx(mode_fn, 0), logicview.idx(vv_string, 0) }), logicview.pymod("ch %d: %s '%s' %s", { chan, logicview.idx(logicview.idx(status_bytes, msg), 1), logicview.idx(mode_fn, 1), logicview.idx(vv_string, 1) }), logicview.pymod("%d: %s '%s' %s", { chan, logicview.idx(logicview.idx(status_bytes, msg), 2), logicview.idx(mode_fn, 2), logicview.idx(vv_string, 1) }) } })
  do
    local _lv_a0, _lv_a1 = {  }, "IDLE"
    self.cmd = _lv_a0
    self.state = _lv_a1
  end
  self:soft_clear_status_byte()
end
function _decoder.handle_channel_msg_0xb0(self, is_flushed)
  local c, handle_ctrl
  c = self.cmd
  if logicview.truth((logicview.len(c) < 2)) then
    self:check_for_garbage_flush(is_flushed)
    return
  end
  self.es_block = self.es
  if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(120, logicview.add(127, 1)) do _t[#_t + 1] = _v end; return _t end)(), logicview.idx(c, 0))) then
    self:handle_channel_mode()
    return
  end
  handle_ctrl = (function() local _v = self[logicview.pymod("handle_controller_0x%02x", logicview.idx(c, 0))]; if _v == nil then return self.handle_controller_generic end; return _v end)()
  handle_ctrl()
  do
    local _lv_a0, _lv_a1 = {  }, "IDLE"
    self.cmd = _lv_a0
    self.state = _lv_a1
  end
  self:soft_clear_status_byte()
end
function _decoder.handle_channel_msg_0xc0(self, is_flushed)
  local c, msg, chan, pp, change_type, name
  c = self.cmd
  if logicview.truth((logicview.len(c) < 1)) then
    self:check_for_garbage_flush(is_flushed)
    return
  end
  self.es_block = self.es
  do
    local _lv_a0, _lv_a1 = (self.status_byte & 240), logicview.add((self.status_byte & 15), 1)
    msg = _lv_a0
    chan = _lv_a1
  end
  pp = logicview.add(logicview.idx(self.cmd, 0), 1)
  change_type = "instrument"
  name = ""
  if logicview.truth((not logicview.eq(chan, 10))) then
    name = logicview.dget(gm_instruments, pp, "undefined")
  else
    change_type = "drum kit"
    name = logicview.dget(drum_kit, pp, "undefined")
  end
  self:putx({ 0, { logicview.pymod("Channel %d: %s to %s %d (assuming %s)", { chan, logicview.idx(logicview.idx(status_bytes, msg), 0), change_type, pp, name }), logicview.pymod("ch %d: %s to %s %d", { chan, logicview.idx(logicview.idx(status_bytes, msg), 1), change_type, pp }), logicview.pymod("%d: %s %d", { chan, logicview.idx(logicview.idx(status_bytes, msg), 2), pp }) } })
  do
    local _lv_a0, _lv_a1 = {  }, "IDLE"
    self.cmd = _lv_a0
    self.state = _lv_a1
  end
  self:soft_clear_status_byte()
end
function _decoder.handle_channel_msg_0xd0(self, is_flushed)
  local c, msg, chan, vv
  c = self.cmd
  if logicview.truth((logicview.len(c) < 1)) then
    self:check_for_garbage_flush(is_flushed)
    return
  end
  self.es_block = self.es
  do
    local _lv_a0, _lv_a1 = (self.status_byte & 240), logicview.add((self.status_byte & 15), 1)
    msg = _lv_a0
    chan = _lv_a1
  end
  vv = logicview.idx(self.cmd, 0)
  self:putx({ 0, { logicview.pymod("Channel %d: %s %d", { chan, logicview.idx(logicview.idx(status_bytes, msg), 0), vv }), logicview.pymod("ch %d: %s %d", { chan, logicview.idx(logicview.idx(status_bytes, msg), 1), vv }), logicview.pymod("%d: %s %d", { chan, logicview.idx(logicview.idx(status_bytes, msg), 2), vv }) } })
  do
    local _lv_a0, _lv_a1 = {  }, "IDLE"
    self.cmd = _lv_a0
    self.state = _lv_a1
  end
  self:soft_clear_status_byte()
end
function _decoder.handle_channel_msg_0xe0(self, is_flushed)
  local c, msg, chan, ll, mm, decimal
  c = self.cmd
  if logicview.truth((logicview.len(c) < 2)) then
    self:check_for_garbage_flush(is_flushed)
    return
  end
  self.es_block = self.es
  do
    local _lv_a0, _lv_a1 = (self.status_byte & 240), logicview.add((self.status_byte & 15), 1)
    msg = _lv_a0
    chan = _lv_a1
  end
  do
    local _lv_a0, _lv_a1 = logicview.idx(self.cmd, 0), logicview.idx(self.cmd, 1)
    ll = _lv_a0
    mm = _lv_a1
  end
  decimal = logicview.add((mm << 7), ll)
  self:putx({ 0, { logicview.pymod("Channel %d: %s 0x%02x 0x%02x (%d)", { chan, logicview.idx(logicview.idx(status_bytes, msg), 0), ll, mm, decimal }), logicview.pymod("ch %d: %s 0x%02x 0x%02x (%d)", { chan, logicview.idx(logicview.idx(status_bytes, msg), 1), ll, mm, decimal }), logicview.pymod("%d: %s (%d)", { chan, logicview.idx(logicview.idx(status_bytes, msg), 2), decimal }) } })
  do
    local _lv_a0, _lv_a1 = {  }, "IDLE"
    self.cmd = _lv_a0
    self.state = _lv_a1
  end
  self:soft_clear_status_byte()
end
function _decoder.handle_channel_msg_generic(self, is_flushed)
  local msg_type
  msg_type = (self.status_byte & 240)
  self.es_block = self.es
  self:putx({ 2, { logicview.pymod("Unknown channel message type: 0x%02x", msg_type) } })
  do
    local _lv_a0, _lv_a1 = {  }, "IDLE"
    self.cmd = _lv_a0
    self.state = _lv_a1
  end
  self:soft_clear_status_byte()
end
function _decoder.handle_channel_msg(self, newbyte)
  local msg_type, handle_msg
  if logicview.truth((newbyte ~= nil)) then
    if logicview.truth((newbyte >= 128)) then
      self:set_status_byte(newbyte)
    else
      _table.insert(self.cmd, newbyte)
    end
  end
  msg_type = (self.status_byte & 240)
  handle_msg = (function() local _v = self[logicview.pymod("handle_channel_msg_0x%02x", msg_type)]; if _v == nil then return self.handle_channel_msg_generic end; return _v end)()
  handle_msg((newbyte == nil))
end
function _decoder.handle_sysex_msg(self, newbyte)
  local msg, m1, manu, default_name, manu_name, payload0, payload1, byte, payload
  self:hard_clear_status_byte()
  if logicview.truth((function()
  local _v
  _v = (not logicview.eq(newbyte, 247))
  if not logicview.truth(_v) then return _v end
  _v = (newbyte ~= nil)
  return _v
end)()) then
    _table.insert(self.cmd, newbyte)
    return
  end
  self.es_block = self.es
  msg = logicview.list_pop(self.cmd, 0)
  if logicview.truth((logicview.len(self.cmd) < 1)) then
    self:putx({ 2, { logicview.pymod("%s: truncated manufacturer code (<1 bytes)", logicview.idx(logicview.idx(status_bytes, msg), 0)), logicview.pymod("%s: truncated manufacturer (<1 bytes)", logicview.idx(logicview.idx(status_bytes, msg), 1)), logicview.pymod("%s: trunc. manu.", logicview.idx(logicview.idx(status_bytes, msg), 2)) } })
    do
      local _lv_a0, _lv_a1 = {  }, "IDLE"
      self.cmd = _lv_a0
      self.state = _lv_a1
    end
    return
  end
  m1 = logicview.list_pop(self.cmd, 0)
  manu = { m1 }
  if logicview.truth(logicview.eq(m1, 0)) then
    if logicview.truth((logicview.len(self.cmd) < 2)) then
      self:putx({ 2, { logicview.pymod("%s: truncated manufacturer code (<3 bytes)", logicview.idx(logicview.idx(status_bytes, msg), 0)), logicview.pymod("%s: truncated manufacturer (<3 bytes)", logicview.idx(logicview.idx(status_bytes, msg), 1)), logicview.pymod("%s: trunc. manu.", logicview.idx(logicview.idx(status_bytes, msg), 2)) } })
      do
        local _lv_a0, _lv_a1 = {  }, "IDLE"
        self.cmd = _lv_a0
        self.state = _lv_a1
      end
      return
    end
    manu = { m1, logicview.list_pop(self.cmd, 0), logicview.list_pop(self.cmd, 0) }
  end
  default_name = "undefined"
  manu_name = logicview.dget(sysex_manufacturer_ids, manu, default_name)
  if logicview.truth(logicview.eq(manu_name, default_name)) then
    if logicview.truth(logicview.eq(logicview.len(manu), 3)) then
      manu_name = { logicview.pymod("%s (0x%02x 0x%02x 0x%02x)", { default_name, logicview.idx(manu, 0), logicview.idx(manu, 1), logicview.idx(manu, 2) }), default_name }
    else
      manu_name = { logicview.pymod("%s (0x%02x)", { default_name, logicview.idx(manu, 0) }), default_name }
    end
  else
    manu_name = { manu_name, manu_name }
  end
  payload0 = ""
  payload1 = ""
  while logicview.truth((logicview.len(self.cmd) > 0)) do
    byte = logicview.list_pop(self.cmd, 0)
    payload0 = logicview.add(payload0, logicview.pymod("0x%02x ", byte))
    payload1 = logicview.add(payload1, logicview.pymod("%02x ", byte))
    ::continue_1::
  end
  if logicview.truth(logicview.eq(payload0, "")) then
    payload0 = "<empty>"
    payload1 = "<>"
  end
  payload = { payload0, payload1 }
  self:putx({ 0, { logicview.pymod("%s: for '%s' with payload %s", { logicview.idx(logicview.idx(status_bytes, msg), 0), logicview.idx(manu_name, 0), logicview.idx(payload, 0) }), logicview.pymod("%s: '%s', payload %s", { logicview.idx(logicview.idx(status_bytes, msg), 1), logicview.idx(manu_name, 1), logicview.idx(payload, 1) }), logicview.pymod("%s: '%s', payload %s", { logicview.idx(logicview.idx(status_bytes, msg), 2), logicview.idx(manu_name, 1), logicview.idx(payload, 1) }) } })
  do
    local _lv_a0, _lv_a1 = {  }, "IDLE"
    self.cmd = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_syscommon_midi_time_code_quarter_frame_msg(self, newbyte)
  local c, msg, nn, dd, group, tt
  c = self.cmd
  if logicview.truth((logicview.len(c) < 2)) then
    if logicview.truth((newbyte == nil)) then
      self:handle_garbage_msg(nil)
    end
    return
  end
  msg = logicview.idx(c, 0)
  do
    local _lv_a0, _lv_a1 = ((logicview.idx(c, 1) & 112) >> 4), (logicview.idx(c, 1) & 15)
    nn = _lv_a0
    dd = _lv_a1
  end
  group = { "System Common", "SysCom", "SC" }
  self.es_block = self.es
  if logicview.truth((not logicview.eq(nn, 7))) then
    self:putx({ 0, { logicview.pymod("%s: %s of %s, value 0x%01x", { logicview.idx(group, 0), logicview.idx(logicview.idx(status_bytes, msg), 0), logicview.idx(logicview.idx(quarter_frame_type, nn), 0), dd }), logicview.pymod("%s: %s of %s, value 0x%01x", { logicview.idx(group, 1), logicview.idx(logicview.idx(status_bytes, msg), 1), logicview.idx(logicview.idx(quarter_frame_type, nn), 1), dd }), logicview.pymod("%s: %s of %s, value 0x%01x", { logicview.idx(group, 2), logicview.idx(logicview.idx(status_bytes, msg), 2), logicview.idx(logicview.idx(quarter_frame_type, nn), 1), dd }) } })
    do
      local _lv_a0, _lv_a1 = {  }, "IDLE"
      self.cmd = _lv_a0
      self.state = _lv_a1
    end
    return
  end
  tt = ((dd & 6) >> 1)
  self:putx({ 0, { logicview.pymod("%s: %s of %s, value 0x%01x for %s", { logicview.idx(group, 0), logicview.idx(logicview.idx(status_bytes, msg), 0), logicview.idx(logicview.idx(quarter_frame_type, nn), 0), dd, logicview.idx(smpte_type, tt) }), logicview.pymod("%s: %s of %s, value 0x%01x for %s", { logicview.idx(group, 1), logicview.idx(logicview.idx(status_bytes, msg), 1), logicview.idx(logicview.idx(quarter_frame_type, nn), 1), dd, logicview.idx(smpte_type, tt) }), logicview.pymod("%s: %s of %s, value 0x%01x for %s", { logicview.idx(group, 2), logicview.idx(logicview.idx(status_bytes, msg), 2), logicview.idx(logicview.idx(quarter_frame_type, nn), 1), dd, logicview.idx(smpte_type, tt) }) } })
  do
    local _lv_a0, _lv_a1 = {  }, "IDLE"
    self.cmd = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_syscommon_msg(self, newbyte)
  local c, msg, group, ll, mm, decimal, ss
  self:hard_clear_status_byte()
  if logicview.truth((newbyte ~= nil)) then
    _table.insert(self.cmd, newbyte)
  end
  c = self.cmd
  msg = logicview.idx(c, 0)
  group = { "System Common", "SysCom", "SC" }
  if logicview.truth(logicview.eq(msg, 241)) then
    self:handle_syscommon_midi_time_code_quarter_frame_msg(newbyte)
    return
  elseif logicview.truth(logicview.eq(msg, 242)) then
    if logicview.truth((logicview.len(c) < 3)) then
      if logicview.truth((newbyte == nil)) then
        self:handle_garbage_msg(nil)
      end
      return
    end
    do
      local _lv_a0, _lv_a1 = logicview.idx(c, 1), logicview.idx(c, 2)
      ll = _lv_a0
      mm = _lv_a1
    end
    decimal = logicview.add((mm << 7), ll)
    self.es_block = self.es
    self:putx({ 0, { logicview.pymod("%s: %s 0x%02x 0x%02x (%d)", { logicview.idx(group, 0), logicview.idx(logicview.idx(status_bytes, msg), 0), ll, mm, decimal }), logicview.pymod("%s: %s 0x%02x 0x%02x (%d)", { logicview.idx(group, 1), logicview.idx(logicview.idx(status_bytes, msg), 1), ll, mm, decimal }), logicview.pymod("%s: %s (%d)", { logicview.idx(group, 2), logicview.idx(logicview.idx(status_bytes, msg), 2), decimal }) } })
  elseif logicview.truth(logicview.eq(msg, 243)) then
    if logicview.truth((logicview.len(c) < 2)) then
      if logicview.truth((newbyte == nil)) then
        self:handle_garbage_msg(nil)
      end
      return
    end
    ss = logicview.idx(c, 1)
    self.es_block = self.es
    self:putx({ 0, { logicview.pymod("%s: %s number %d", { logicview.idx(group, 0), logicview.idx(logicview.idx(status_bytes, msg), 0), ss }), logicview.pymod("%s: %s number %d", { logicview.idx(group, 1), logicview.idx(logicview.idx(status_bytes, msg), 1), ss }), logicview.pymod("%s: %s # %d", { logicview.idx(group, 2), logicview.idx(logicview.idx(status_bytes, msg), 2), ss }) } })
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(msg, 244)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(msg, 245)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(msg, 246)
  return _v
end)()) then
    self.es_block = self.es
    self:putx({ 0, { logicview.pymod("%s: %s", { logicview.idx(group, 0), logicview.idx(logicview.idx(status_bytes, msg), 0) }), logicview.pymod("%s: %s", { logicview.idx(group, 1), logicview.idx(logicview.idx(status_bytes, msg), 1) }), logicview.pymod("%s: %s", { logicview.idx(group, 2), logicview.idx(logicview.idx(status_bytes, msg), 2) }) } })
  end
  do
    local _lv_a0, _lv_a1 = {  }, "IDLE"
    self.cmd = _lv_a0
    self.state = _lv_a1
  end
end
function _decoder.handle_sysrealtime_msg(self, newbyte)
  local old_ss_block, old_es_block, group
  do
    local _lv_a0, _lv_a1 = self.ss_block, self.es_block
    old_ss_block = _lv_a0
    old_es_block = _lv_a1
  end
  do
    local _lv_a0, _lv_a1 = self.ss, self.es
    self.ss_block = _lv_a0
    self.es_block = _lv_a1
  end
  group = { "System Realtime", "SysReal", "SR" }
  self:putx({ 1, { logicview.pymod("%s: %s", { logicview.idx(group, 0), logicview.idx(logicview.idx(status_bytes, newbyte), 0) }), logicview.pymod("%s: %s", { logicview.idx(group, 1), logicview.idx(logicview.idx(status_bytes, newbyte), 1) }), logicview.pymod("%s: %s", { logicview.idx(group, 2), logicview.idx(logicview.idx(status_bytes, newbyte), 2) }) } })
  do
    local _lv_a0, _lv_a1 = old_ss_block, old_es_block
    self.ss_block = _lv_a0
    self.es_block = _lv_a1
  end
end
function _decoder.handle_garbage_msg(self, newbyte)
  local payload, max_bytes, index
  self.es_block = self.es
  if logicview.truth((newbyte ~= nil)) then
    _table.insert(self.cmd, newbyte)
    return
  end
  payload = "<empty>"
  max_bytes = 16
  for _lv_i in logicview.range(logicview.len(self.cmd)) do
    index = _lv_i
    if logicview.truth(logicview.eq(index, max_bytes)) then
      payload = logicview.add(payload, " ...")
      break
    end
    if logicview.truth(logicview.eq(index, 0)) then
      payload = logicview.pymod("0x%02x", logicview.idx(self.cmd, index))
    else
      payload = logicview.add(payload, logicview.pymod(" 0x%02x", logicview.idx(self.cmd, index)))
    end
    ::continue_2::
  end
  self:putx({ 2, { logicview.pymod("UNHANDLED DATA: %s", payload), "UNHANDLED", "???", "?" } })
  do
    local _lv_a0, _lv_a1 = {  }, "IDLE"
    self.cmd = _lv_a0
    self.state = _lv_a1
  end
  self:hard_clear_status_byte()
end
function _decoder.handle_state(self, state, newbyte)
  if logicview.truth(logicview.eq(state, "HANDLE CHANNEL MSG")) then
    self:handle_channel_msg(newbyte)
  elseif logicview.truth(logicview.eq(state, "HANDLE SYSEX MSG")) then
    self:handle_sysex_msg(newbyte)
  elseif logicview.truth(logicview.eq(state, "HANDLE SYSCOMMON MSG")) then
    self:handle_syscommon_msg(newbyte)
  elseif logicview.truth(logicview.eq(state, "HANDLE SYSREALTIME MSG")) then
    self:handle_sysrealtime_msg(newbyte)
  elseif logicview.truth(logicview.eq(state, "BUFFER GARBAGE MSG")) then
    self:handle_garbage_msg(newbyte)
  end
end
function _decoder.get_next_state(self, newbyte)
  if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(128, logicview.add(239, 1)) do _t[#_t + 1] = _v end; return _t end)(), newbyte)) then
    return "HANDLE CHANNEL MSG"
  end
  if logicview.truth(logicview.eq(newbyte, 240)) then
    return "HANDLE SYSEX MSG"
  end
  if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(241, 247) do _t[#_t + 1] = _v end; return _t end)(), newbyte)) then
    return "HANDLE SYSCOMMON MSG"
  end
  if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(248, logicview.add(255, 1)) do _t[#_t + 1] = _v end; return _t end)(), newbyte)) then
    return "HANDLE SYSREALTIME MSG"
  end
  if logicview.truth(logicview.eq(newbyte, 247)) then
    return "BUFFER GARBAGE MSG"
  end
  if logicview.truth((self.status_byte < 128)) then
    return "BUFFER GARBAGE MSG"
  end
  return self:get_next_state(self.status_byte)
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, rxtx, pdata, state
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ptype = logicview.idx(_lv_seq, 0)
      rxtx = logicview.idx(_lv_seq, 1)
      pdata = logicview.idx(_lv_seq, 2)
    end
    state = "IDLE"
    if logicview.truth((not logicview.eq(ptype, "DATA"))) then
      return
    end
    pdata = logicview.idx(pdata, 0)
    if logicview.truth((function()
  local _v
  _v = (pdata >= 128)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(pdata, 247))
  return _v
end)()) then
      state = self:get_next_state(pdata)
      if logicview.truth((function()
  local _v
  _v = (not logicview.eq(state, "HANDLE SYSREALTIME MSG"))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(self.state, "IDLE"))
  return _v
end)()) then
        self:handle_state(self.state, nil)
      end
      do
        local _lv_a0, _lv_a1 = ss, es
        self.ss = _lv_a0
        self.es = _lv_a1
      end
      if logicview.truth((not logicview.eq(state, "HANDLE SYSREALTIME MSG"))) then
        self.ss_block = ss
      end
    elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.state, "IDLE")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.state, "BUFFER GARBAGE MSG")
  return _v
end)()) then
      do
        local _lv_a0, _lv_a1 = ss, es
        self.ss = _lv_a0
        self.es = _lv_a1
      end
      if logicview.truth(logicview.eq(self.state, "IDLE")) then
        self.ss_block = ss
      end
      state = self:get_next_state(pdata)
    else
      do
        local _lv_a0, _lv_a1 = ss, es
        self.ss = _lv_a0
        self.es = _lv_a1
      end
      state = self.state
    end
    if logicview.truth((not logicview.eq(state, "HANDLE SYSREALTIME MSG"))) then
      self.state = state
    end
    if logicview.truth(logicview.eq(state, "BUFFER GARBAGE MSG")) then
      self.status_byte = 0
    end
    self:handle_state(state, pdata)
  end
  if _type(packets) ~= 'table' then return _lv_packet(self, start_sample, end_sample, packets) end
  for _, _item in ipairs(packets) do
    local payload = _item.data
    if payload == nil then payload = _item end
    local ss = _item.start_sample or start_sample
    local es = _item.end_sample
    if es ~= nil then es = es - 1 end
    _lv_packet(self, ss, es, payload)
  end
end

return _decoder
