-- Session API example: mark each rising edge.
-- api_version 3 follows the same flow as a sigrok protocol decoder:
-- start registers outputs, reset clears state, metadata receives the sample
-- rate, and decode calls wait until the capture ends.
local lv = logicview

return {
  api_version = 3,
  id = "session_edges",
  name = "Session edges",
  longname = "Rising-edge markers",
  desc = "Marks each rising edge on one line.",
  license = "gplv3+",
  inputs = { "logic" },
  outputs = { "session_edges" },
  tags = { "Debug/trace" },
  channels = { { id = "data", name = "Data", desc = "Sampled line" } },
  optional_channels = {},
  annotations = { { "edge", "Rising edge" } },
  annotation_rows = { { "edges", "Edges", { 0 } } },
  binary = { { "raw", "One marker byte per edge" } },

  start = function(self)
    self.out_ann = self:register(lv.OUTPUT_ANN)
    self.out_python = self:register(lv.OUTPUT_PYTHON)
    self.out_bin = self:register(lv.OUTPUT_BINARY)
    self.out_meta = self:register(lv.OUTPUT_META, "edges")
  end,

  reset = function(self)
    self.count = 0
  end,

  metadata = function(self, key, value)
    if key == lv.SRD_CONF_SAMPLERATE then self.samplerate = value end
  end,

  decode = function(self)
    while true do
      self:wait({ [0] = "r" })
      self.count = self.count + 1
      local sample = self.samplenum
      self:put(sample, sample, self.out_ann, { 0, { "Rise", "R" } })
      self:put(sample, sample, self.out_python, { "EDGE", self.count })
      self:put(sample, sample, self.out_bin, { 0, string.char(1) })
      self:put(sample, sample, self.out_meta, self.count)
    end
  end,
}
