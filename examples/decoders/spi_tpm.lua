-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2021 ghecko - Jordan Ovrè <ghecko78@gmail.com>

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
local re, deque, fifo_registers2, fifo_registers1, Ann, Operation, TransactionState, Transaction, Decoder, RangeDict, __all__, Color, Node, node_color, in_order, height
local _decoder

re = logicview.re
collections = { namedtuple = function(_n, fields) if _type(fields) == 'string' then fields = logicview.split(fields, ' ') end return logicview.namedtuple(fields) end, OrderedDict = function(t) return logicview.dict(t or {}) end, deque = function() return {} end }
deque = collections.deque
__all__ = { "RangeDict" }
Color = {}
Color.__index = Color
Color.BLACK = 0
Color.RED = 1
Node = {}
Node.__index = Node
Node.__slots__ = { "r", "left", "right", "value", "color", "parent" }
function Node.__init__(self, r, value, parent, color)
  if parent == nil then parent = nil end
  if color == nil then color = Color.RED end
  self.r = r
  self.value = value
  self.parent = parent
  self.color = color
  self.left = nil
  self.right = nil
end
function Node.value_copy(self, other)
  self.r = other.r
  self.value = other.value
end
function Node.new(...)
  local self = _setmetatable({}, Node)
  Node.__init__(self, ...)
  return self
end
RangeDict = {}
RangeDict.__index = RangeDict
_setmetatable(RangeDict, { __index = dict })
function RangeDict.__init__(self)
  self._root = nil
end
function RangeDict.__setitem__(self, r, v)
  local node
  if logicview.truth((logicview.idx(r, 1) < logicview.idx(r, 0))) then
    _error(KeyError, 0)
  end
  node = self:_insert(r, v)
  self:_insert_adjust(node)
end
function RangeDict._insert(self, r, v)
  local cur
  if logicview.truth((not logicview.truth(self._root))) then
    self._root = Node.new(r, v)
    return self._root
  end
  cur = self._root
  while true do
    if logicview.truth((logicview.idx(r, 1) < logicview.idx(cur.r, 0))) then
      if logicview.truth((not logicview.truth(cur.left))) then
        cur.left = Node.new(r, v, cur)
        return cur.left
      end
      cur = cur.left
    elseif logicview.truth((logicview.idx(r, 0) > logicview.idx(cur.r, 1))) then
      if logicview.truth((not logicview.truth(cur.right))) then
        cur.right = Node.new(r, v, cur)
        return cur.right
      end
      cur = cur.right
    else
      _error(KeyError, 0)
    end
    ::continue_1::
  end
end
function RangeDict._insert_adjust(self, node)
  local uncle, parent, grandparent
  if logicview.truth((not logicview.truth(node.parent))) then
    node.color = Color.BLACK
    return
  end
  if logicview.truth(logicview.eq(node.parent.color, Color.BLACK)) then
    return
  end
  uncle = self:sibling(node.parent)
  if logicview.truth(logicview.eq(node_color(uncle), Color.RED)) then
    node.parent.color = Color.BLACK
    uncle.color = Color.BLACK
    node.parent.parent.color = Color.RED
    return self:_insert_adjust(node.parent.parent)
  end
  parent = node.parent
  grandparent = parent.parent
  if logicview.truth(self:is_left_son(parent, grandparent)) then
    if logicview.truth(self:is_left_son(node, parent)) then
      self:right_rotate(grandparent)
      grandparent.color = Color.RED
      parent.color = Color.BLACK
    else
      self:left_rotate(parent)
      self:right_rotate(grandparent)
      grandparent.color = Color.RED
      node.color = Color.BLACK
    end
  elseif logicview.truth(self:is_left_son(node, parent)) then
    self:right_rotate(parent)
    self:left_rotate(grandparent)
    grandparent.color = Color.RED
    node.color = Color.BLACK
  else
    self:left_rotate(grandparent)
    grandparent.color = Color.RED
    parent.color = Color.BLACK
  end
end
function RangeDict._find_key(self, key)
  local cur
  cur = self._root
  while logicview.truth(cur) do
    if logicview.truth((key > logicview.idx(cur.r, 1))) then
      cur = cur.right
    elseif logicview.truth((key < logicview.idx(cur.r, 0))) then
      cur = cur.left
    else
      break
    end
    ::continue_2::
  end
  return cur
end
function RangeDict._find_range(self, r)
  local cur
  cur = self._root
  while logicview.truth(cur) do
    if logicview.truth((logicview.idx(r, 1) < logicview.idx(cur.r, 0))) then
      cur = cur.left
    elseif logicview.truth((logicview.idx(r, 0) > logicview.idx(cur.r, 1))) then
      cur = cur.right
    elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(r, 0), logicview.idx(cur.r, 0))
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(r, 1), logicview.idx(cur.r, 1))
  return _v
end)()) then
      return cur
    else
      _error(KeyError, 0)
    end
    ::continue_3::
  end
  _error(KeyError, 0)
end
function RangeDict.__getitem__(self, key)
  local tar
  tar = self:_find_key(key)
  if logicview.truth(tar) then
    return tar.value
  end
  _error(KeyError, 0)
end
function RangeDict.__contains__(self, key)
  return logicview.truth(self:_find_key(key))
end
function RangeDict.__delitem__(self, r)
  local node, left_rightest_child
  node = self:_find_range(r)
  if logicview.truth((function()
  local _v
  _v = node.left
  if not logicview.truth(_v) then return _v end
  _v = node.right
  return _v
end)()) then
    left_rightest_child = self:find_rightest(node.left)
    node:value_copy(left_rightest_child)
    node = left_rightest_child
  end
  self:_delete(node)
end
function RangeDict._delete(self, node)
  local child, parent
  child = (function() if logicview.truth(node.left) then return node.left else return node.right end end)()
  if logicview.truth((not logicview.truth(node.parent))) then
    self._root = child
    if logicview.truth(self._root) then
      self._root.parent = nil
      self._root.color = Color.BLACK
    end
    return
  end
  parent = node.parent
  if logicview.truth((not logicview.truth(child))) then
    child = Node.new(nil, nil, parent, Color.BLACK)
  end
  if logicview.truth(self:is_left_son(node, parent)) then
    parent.left = child
  else
    parent.right = child
  end
  child.parent = parent
  if logicview.truth(logicview.eq(node.color, Color.RED)) then
    return
  end
  if logicview.truth(logicview.eq(node_color(child), Color.RED)) then
    child.color = Color.BLACK
    return
  end
  self:_delete_adjust(child)
  if logicview.truth((not logicview.truth(child.r))) then
    parent = child.parent
    if logicview.truth(self:is_left_son(child, parent)) then
      parent.left = nil
    else
      parent.right = nil
    end
  end
end
function RangeDict._delete_adjust(self, node)
  local parent, sibling
  if logicview.truth((not logicview.truth(node.parent))) then
    node.color = Color.BLACK
    return
  end
  parent = node.parent
  sibling = self:sibling(node)
  if logicview.truth(logicview.eq(node_color(sibling), Color.RED)) then
    if logicview.truth(self:is_left_son(node, parent)) then
      self:left_rotate(parent)
    else
      self:right_rotate(parent)
    end
    parent.color = Color.RED
    sibling.color = Color.BLACK
    sibling = self:sibling(node)
  end
  if logicview.truth((function()
  local _v
  _v = (not logicview.truth(self:is_black(parent)))
  if not logicview.truth(_v) then return _v end
  _v = self:is_black(sibling.left)
  if not logicview.truth(_v) then return _v end
  _v = self:is_black(sibling.right)
  return _v
end)()) then
    parent.color = Color.BLACK
    sibling.color = Color.RED
    return
  end
  if logicview.truth((function()
  local _v
  _v = self:is_black(parent)
  if not logicview.truth(_v) then return _v end
  _v = self:is_black(sibling.left)
  if not logicview.truth(_v) then return _v end
  _v = self:is_black(sibling.right)
  return _v
end)()) then
    sibling.color = Color.RED
    return self:_delete_adjust(parent)
  end
  if logicview.truth(self:is_left_son(node, parent)) then
    if logicview.truth((function()
  local _v
  _v = (not logicview.truth(self:is_black(sibling.left)))
  if not logicview.truth(_v) then return _v end
  _v = self:is_black(sibling.right)
  return _v
end)()) then
      sibling.left.color = Color.BLACK
      sibling.color = Color.RED
      self:right_rotate(sibling)
      sibling = sibling.parent
    end
    sibling.color = parent.color
    parent.color = Color.BLACK
    sibling.right.color = Color.BLACK
    self:left_rotate(parent)
  else
    if logicview.truth((function()
  local _v
  _v = (not logicview.truth(self:is_black(sibling.right)))
  if not logicview.truth(_v) then return _v end
  _v = self:is_black(sibling.left)
  return _v
end)()) then
      sibling.right.color = Color.BLACK
      sibling.color = Color.RED
      self:left_rotate(parent)
      sibling = sibling.parent
    end
    sibling.color = parent.color
    parent.color = Color.BLACK
    sibling.left.color = Color.RED
    self:right_rotate(parent)
  end
end
function RangeDict.left_rotate(self, node)
  local right_son
  right_son = node.right
  if logicview.truth((not logicview.truth(node.parent))) then
    self._root = right_son
  elseif logicview.truth(self:is_left_son(node, node.parent)) then
    node.parent.left = right_son
  else
    node.parent.right = right_son
  end
  right_son.parent = node.parent
  node.parent = right_son
  node.right = right_son.left
  right_son.left = node
end
function RangeDict.right_rotate(self, node)
  local left_son
  left_son = node.left
  if logicview.truth((not logicview.truth(node.parent))) then
    self._root = left_son
  elseif logicview.truth(self:is_left_son(node, node.parent)) then
    node.parent.left = left_son
  else
    node.parent.right = left_son
  end
  left_son.parent = node.parent
  node.parent = left_son
  node.left = left_son.right
  left_son.right = node
end
function RangeDict.sibling(node)
  if logicview.truth(logicview.eq(node.parent.left, node)) then
    return node.parent.right
  else
    return node.parent.left
  end
end
function RangeDict.is_left_son(child, parent)
  if logicview.truth(logicview.eq(parent.left, child)) then
    return true
  else
    return false
  end
end
function RangeDict.find_rightest(node)
  while logicview.truth(node.right) do
    node = node.right
    ::continue_4::
  end
  return node
end
function RangeDict.is_black(node)
  return logicview.eq(node_color(node), Color.BLACK)
end
function RangeDict.new(...)
  local self = _setmetatable({}, RangeDict)
  RangeDict.__init__(self, ...)
  return self
end
node_color = function(node)
  if logicview.truth((not logicview.truth(node))) then
    return Color.BLACK
  end
  return node.color
end
in_order = function(root)
  local ret
  ret = {  }
  if logicview.truth((not logicview.truth(root))) then
    return {  }
  end
  return logicview.add(logicview.add(in_order(root.left), { root.value }), in_order(root.right))
end
height = function(root)
  if logicview.truth((not logicview.truth(root))) then
    return 0
  end
  return logicview.add(1, _math.max(height(root.left), height(root.right)))
end
if logicview.truth(logicview.eq(__name__, "__main__")) then
end

fifo_registers2 = RangeDict.new()
logicview.setidx(fifo_registers2, logicview.tkey(0, 0), "TPM_ACCESS_0")
logicview.setidx(fifo_registers2, logicview.tkey(1, 7), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(8, 11), "TPM_INT_ENABLE_0")
logicview.setidx(fifo_registers2, logicview.tkey(12, 12), "TPM_INT_VECTOR_0")
logicview.setidx(fifo_registers2, logicview.tkey(13, 15), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(16, 19), "TPM_INT_STATUS_0")
logicview.setidx(fifo_registers2, logicview.tkey(20, 23), "TPM_INTF_CAPABILITY_0")
logicview.setidx(fifo_registers2, logicview.tkey(24, 27), "TPM_STS_0")
logicview.setidx(fifo_registers2, logicview.tkey(28, 35), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(36, 39), "TPM_DATA_FIFO_0")
logicview.setidx(fifo_registers2, logicview.tkey(40, 47), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(48, 51), "TPM_INTERFACE_ID_0")
logicview.setidx(fifo_registers2, logicview.tkey(52, 127), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(128, 131), "TPM_XDATA_FIFO_0")
logicview.setidx(fifo_registers2, logicview.tkey(132, 2177), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(3840, 3843), "TPM_DID_VID_0")
logicview.setidx(fifo_registers2, logicview.tkey(3844, 3844), "TPM_RID_0")
logicview.setidx(fifo_registers2, logicview.tkey(3984, 4095), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(4096, 4096), "TPM_ACCESS_1")
logicview.setidx(fifo_registers2, logicview.tkey(4097, 4103), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(4104, 4107), "TPM_INT_ENABLE_1")
logicview.setidx(fifo_registers2, logicview.tkey(4108, 4108), "TPM_INT_VECTOR_1")
logicview.setidx(fifo_registers2, logicview.tkey(4109, 4111), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(4112, 4115), "TPM_INT_STATUS_1")
logicview.setidx(fifo_registers2, logicview.tkey(4116, 4119), "TPM_INTF_CAPABILITY_1")
logicview.setidx(fifo_registers2, logicview.tkey(4120, 4123), "TPM_STS_1")
logicview.setidx(fifo_registers2, logicview.tkey(4124, 4131), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(4132, 4135), "TPM_DATA_FIFO_1")
logicview.setidx(fifo_registers2, logicview.tkey(4136, 4143), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(4144, 4144), "TPM_INTERFACE_ID_1")
logicview.setidx(fifo_registers2, logicview.tkey(4151, 4223), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(4224, 4227), "TPM_XDATA_FIFO_1")
logicview.setidx(fifo_registers2, logicview.tkey(4228, 7935), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(7936, 7939), "TPM_DID_VID_1")
logicview.setidx(fifo_registers2, logicview.tkey(7940, 7940), "TPM_RID_1")
logicview.setidx(fifo_registers2, logicview.tkey(7941, 8191), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(8192, 8192), "TPM_ACCESS_2")
logicview.setidx(fifo_registers2, logicview.tkey(8193, 8199), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(8200, 8203), "TPM_INT_ENABLE_2")
logicview.setidx(fifo_registers2, logicview.tkey(8204, 8204), "TPM_INT_VECTOR_2")
logicview.setidx(fifo_registers2, logicview.tkey(8205, 8207), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(8208, 8211), "TPM_INT_STATUS_2")
logicview.setidx(fifo_registers2, logicview.tkey(8212, 8215), "TPM_INTF_CAPABILITY_2")
logicview.setidx(fifo_registers2, logicview.tkey(8216, 8219), "TPM_STS_2")
logicview.setidx(fifo_registers2, logicview.tkey(8220, 8227), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(8228, 8231), "TPM_DATA_FIFO_2")
logicview.setidx(fifo_registers2, logicview.tkey(8232, 8239), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(8240, 8243), "TPM_INTERFACE_ID_2")
logicview.setidx(fifo_registers2, logicview.tkey(8244, 8319), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(8320, 8323), "TPM_XDATA_FIFO_2")
logicview.setidx(fifo_registers2, logicview.tkey(8324, 12031), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(12032, 12035), "TPM_DID_VID_2")
logicview.setidx(fifo_registers2, logicview.tkey(12036, 12036), "TPM_RID_2")
logicview.setidx(fifo_registers2, logicview.tkey(12037, 12287), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(12288, 12288), "TPM_ACCESS_3")
logicview.setidx(fifo_registers2, logicview.tkey(12289, 12295), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(12296, 12299), "TPM_INT_ENABLE_3")
logicview.setidx(fifo_registers2, logicview.tkey(12300, 12300), "TPM_INT_VECTOR_3")
logicview.setidx(fifo_registers2, logicview.tkey(12301, 12303), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(12304, 12307), "TPM_INT_STATUS_3")
logicview.setidx(fifo_registers2, logicview.tkey(12308, 12311), "TPM_INTF_CAPABILITY_3")
logicview.setidx(fifo_registers2, logicview.tkey(12312, 12315), "TPM_STS_3")
logicview.setidx(fifo_registers2, logicview.tkey(12316, 12323), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(12324, 12327), "TPM_DATA_FIFO_3")
logicview.setidx(fifo_registers2, logicview.tkey(12328, 12335), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(12336, 12339), "TPM_INTERFACE_ID_3")
logicview.setidx(fifo_registers2, logicview.tkey(12340, 12415), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(12416, 12419), "TPM_XDATA_FIFO_3")
logicview.setidx(fifo_registers2, logicview.tkey(12420, 16127), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(16128, 16131), "TPM_DID_VID_3")
logicview.setidx(fifo_registers2, logicview.tkey(16132, 16132), "TPM_RID_3")
logicview.setidx(fifo_registers2, logicview.tkey(16133, 16383), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(16384, 16384), "TPM_ACCESS_4")
logicview.setidx(fifo_registers2, logicview.tkey(16385, 16391), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(16392, 16395), "TPM_INT_ENABLE_4")
logicview.setidx(fifo_registers2, logicview.tkey(16396, 16396), "TPM_INT_VECTOR_4")
logicview.setidx(fifo_registers2, logicview.tkey(16397, 16399), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(16400, 16403), "TPM_INT_STATUS_4")
logicview.setidx(fifo_registers2, logicview.tkey(16404, 16407), "TPM_INTF_CAPABILITY_4")
logicview.setidx(fifo_registers2, logicview.tkey(16408, 16411), "TPM_STS_4")
logicview.setidx(fifo_registers2, logicview.tkey(16412, 16415), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(16416, 16419), "TPM_HASH_END")
logicview.setidx(fifo_registers2, logicview.tkey(16420, 16423), "TPM_DATA_FIFO_4")
logicview.setidx(fifo_registers2, logicview.tkey(16424, 16431), "TPM_HASH_START")
logicview.setidx(fifo_registers2, logicview.tkey(16432, 16435), "TPM_INTERFACE_ID_4")
logicview.setidx(fifo_registers2, logicview.tkey(16436, 16511), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(16512, 16515), "TPM_XDATA_FIFO_4")
logicview.setidx(fifo_registers2, logicview.tkey(16516, 20223), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(20224, 20227), "TPM_DID_VID_4")
logicview.setidx(fifo_registers2, logicview.tkey(20228, 20228), "TPM_RID_4")
logicview.setidx(fifo_registers2, logicview.tkey(20229, 20479), "Reserved")
logicview.setidx(fifo_registers2, logicview.tkey(20480, 24575), "Reserved")
fifo_registers1 = RangeDict.new()
logicview.setidx(fifo_registers1, logicview.tkey(0, 0), "TPM_ACCESS_0")
logicview.setidx(fifo_registers1, logicview.tkey(8, 11), "TPM_INT_ENABLE_0")
logicview.setidx(fifo_registers1, logicview.tkey(12, 12), "TPM_INT_VECTOR_0")
logicview.setidx(fifo_registers1, logicview.tkey(16, 19), "TPM_INT_STATUS_0")
logicview.setidx(fifo_registers1, logicview.tkey(20, 23), "TPM_INTF_CAPABILITY_0")
logicview.setidx(fifo_registers1, logicview.tkey(24, 26), "TPM_STS_0")
logicview.setidx(fifo_registers1, logicview.tkey(36, 39), "TPM_DATA_FIFO_0")
logicview.setidx(fifo_registers1, logicview.tkey(128, 131), "TPM_XDATA_FIFO_0")
logicview.setidx(fifo_registers1, logicview.tkey(132, 191), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(3840, 3843), "TPM_DID_VID_0")
logicview.setidx(fifo_registers1, logicview.tkey(3844, 3844), "TPM_RID_0")
logicview.setidx(fifo_registers1, logicview.tkey(3845, 3967), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(3968, 3968), "FIRST_LEGACY_ADDRESS_0")
logicview.setidx(fifo_registers1, logicview.tkey(3972, 3972), "FIRST_LEGACY_ADDRESS_EXTENSION_0")
logicview.setidx(fifo_registers1, logicview.tkey(3976, 3976), "SECOND_LEGACY_ADDRESS_0")
logicview.setidx(fifo_registers1, logicview.tkey(3980, 3980), "SECOND_LEGACY_ADDRESS_EXTENSION_0")
logicview.setidx(fifo_registers1, logicview.tkey(3984, 4095), "VENDOR_DEFINED")
logicview.setidx(fifo_registers1, logicview.tkey(4096, 4096), "TPM_ACCESS_1")
logicview.setidx(fifo_registers1, logicview.tkey(4104, 4107), "TPM_INT_ENABLE_1")
logicview.setidx(fifo_registers1, logicview.tkey(4108, 4108), "TPM_INT_VECTOR_1")
logicview.setidx(fifo_registers1, logicview.tkey(4112, 4115), "TPM_INT_STATUS_1")
logicview.setidx(fifo_registers1, logicview.tkey(4116, 4119), "TPM_INTF_CAPABILITY_1")
logicview.setidx(fifo_registers1, logicview.tkey(4120, 4122), "TPM_STS_1")
logicview.setidx(fifo_registers1, logicview.tkey(4132, 4135), "TPM_DATA_FIFO_1")
logicview.setidx(fifo_registers1, logicview.tkey(4224, 4227), "TPM_XDATA_FIFO_1")
logicview.setidx(fifo_registers1, logicview.tkey(4228, 4287), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(7936, 7939), "TPM_DID_VID_1")
logicview.setidx(fifo_registers1, logicview.tkey(7940, 7940), "TPM_RID_1")
logicview.setidx(fifo_registers1, logicview.tkey(7941, 8063), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(8064, 8064), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(8068, 8068), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(8072, 8072), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(8076, 8076), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(8080, 8191), "VENDOR_DEFINED")
logicview.setidx(fifo_registers1, logicview.tkey(8192, 8192), "TPM_ACCESS_2")
logicview.setidx(fifo_registers1, logicview.tkey(8200, 8203), "TPM_INT_ENABLE_2")
logicview.setidx(fifo_registers1, logicview.tkey(8204, 8204), "TPM_INT_VECTOR_2")
logicview.setidx(fifo_registers1, logicview.tkey(8208, 8211), "TPM_INT_STATUS_2")
logicview.setidx(fifo_registers1, logicview.tkey(8212, 8215), "TPM_INTF_CAPABILITY_2")
logicview.setidx(fifo_registers1, logicview.tkey(8216, 8218), "TPM_STS_2")
logicview.setidx(fifo_registers1, logicview.tkey(8228, 8231), "TPM_DATA_FIFO_2")
logicview.setidx(fifo_registers1, logicview.tkey(8320, 8323), "TPM_XDATA_FIFO_2")
logicview.setidx(fifo_registers1, logicview.tkey(8324, 8383), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(12032, 12035), "TPM_DID_VID_2")
logicview.setidx(fifo_registers1, logicview.tkey(12036, 12036), "TPM_RID_2")
logicview.setidx(fifo_registers1, logicview.tkey(12037, 12159), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(12160, 12160), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(12164, 12164), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(12168, 12168), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(12172, 12172), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(12176, 12287), "VENDOR_DEFINED")
logicview.setidx(fifo_registers1, logicview.tkey(12288, 12288), "TPM_ACCESS_3")
logicview.setidx(fifo_registers1, logicview.tkey(12296, 12299), "TPM_INT_ENABLE_3")
logicview.setidx(fifo_registers1, logicview.tkey(12300, 12300), "TPM_INT_VECTOR_3")
logicview.setidx(fifo_registers1, logicview.tkey(12304, 12307), "TPM_INT_STATUS_3")
logicview.setidx(fifo_registers1, logicview.tkey(12308, 12311), "TPM_INTF_CAPABILITY_3")
logicview.setidx(fifo_registers1, logicview.tkey(12312, 12314), "TPM_STS_3")
logicview.setidx(fifo_registers1, logicview.tkey(12324, 12327), "TPM_DATA_FIFO_3")
logicview.setidx(fifo_registers1, logicview.tkey(12416, 12419), "TPM_XDATA_FIFO_3")
logicview.setidx(fifo_registers1, logicview.tkey(12420, 12479), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(16128, 16131), "TPM_DID_VID_3")
logicview.setidx(fifo_registers1, logicview.tkey(16132, 16132), "TPM_RID_3")
logicview.setidx(fifo_registers1, logicview.tkey(16133, 16255), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(16256, 16256), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(16260, 16260), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(16264, 16264), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(16268, 16268), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(16272, 16383), "VENDOR_DEFINED")
logicview.setidx(fifo_registers1, logicview.tkey(16384, 16384), "TPM_ACCESS_4")
logicview.setidx(fifo_registers1, logicview.tkey(16392, 16395), "TPM_INT_ENABLE_4")
logicview.setidx(fifo_registers1, logicview.tkey(16396, 16396), "TPM_INT_VECTOR_4")
logicview.setidx(fifo_registers1, logicview.tkey(16400, 16403), "TPM_INT_STATUS_4")
logicview.setidx(fifo_registers1, logicview.tkey(16404, 16407), "TPM_INTF_CAPABILITY_4")
logicview.setidx(fifo_registers1, logicview.tkey(16408, 16410), "TPM_STS_4")
logicview.setidx(fifo_registers1, logicview.tkey(16416, 16416), "TPM_HASH_END")
logicview.setidx(fifo_registers1, logicview.tkey(16420, 16423), "TPM_DATA_FIFO_4")
logicview.setidx(fifo_registers1, logicview.tkey(16424, 16424), "TPM_HASH_START")
logicview.setidx(fifo_registers1, logicview.tkey(16512, 16515), "TPM_XDATA_FIFO_4")
logicview.setidx(fifo_registers1, logicview.tkey(16516, 16575), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(20224, 20227), "TPM_DID_VID_4")
logicview.setidx(fifo_registers1, logicview.tkey(20228, 20228), "TPM_RID_4")
logicview.setidx(fifo_registers1, logicview.tkey(20229, 20351), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(20352, 20352), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(20356, 20356), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(20360, 20360), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(20364, 20364), "Reserved")
logicview.setidx(fifo_registers1, logicview.tkey(20368, 20479), "VENDOR_DEFINED")

Ann = {}
Ann.__index = Ann
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(6) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.READ = logicview.idx(_lv_seq, 0)
  Ann.WRITE = logicview.idx(_lv_seq, 1)
  Ann.ADDRESS = logicview.idx(_lv_seq, 2)
  Ann.WAIT = logicview.idx(_lv_seq, 3)
  Ann.DATA = logicview.idx(_lv_seq, 4)
  Ann.VMK = logicview.idx(_lv_seq, 5)
end
Operation = {}
Operation.__index = Operation
Operation.READ = 128
Operation.WRITE = 0
TransactionState = {}
TransactionState.__index = TransactionState
TransactionState.READ = 0
TransactionState.WRITE = 1
TransactionState.READ_ADDRESS = 2
TransactionState.WAIT = 3
TransactionState.TRANSFER_DATA = 4
Transaction = {}
Transaction.__index = Transaction
function Transaction.__init__(self, start_sample, operation, transfer_size)
  self.start_sample = start_sample
  self.end_sample_op = nil
  self.end_sample_addr = nil
  self.end_sample_data = nil
  self.end_sample_wait = nil
  self.operation = operation
  self.address = logicview.bytes(nil)
  self.data = logicview.bytes(nil)
  self.size = transfer_size
  self.wait_count = 0
end
function Transaction.is_complete(self)
  return (function()
  local _v
  _v = self:is_address_complete()
  if not logicview.truth(_v) then return _v end
  _v = self:is_data_complete()
  return _v
end)()
end
function Transaction.is_data_complete(self)
  return logicview.eq(logicview.len(self.data), self.size)
end
function Transaction.is_address_complete(self)
  return logicview.eq(logicview.len(self.address), 3)
end
function Transaction.frame(self, fifo_registers)
  local register_name, data_str, op_ann, wait_ann, addr_ann, data_ann
  if logicview.truth(self:is_complete()) then
    register_name = ""
    do
      local _lv_return = false
      local _lv_value = nil
      local _ok, _err = _pcall(function()
        register_name = logicview.idx(fifo_registers, (logicview.from_bytes(self.address, "big") & 65535))
      end)
      if _lv_return then return _lv_value end
      if not _ok then
        if (_type(_err) == 'table' and _err._exc == "KeyError") then
          register_name = "Unknown"
        else
          _error(_err, 0)
        end
      end
    end
    data_str = logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.data) do
    x = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pyformat("{:02x}", { x }, logicview.dict({}))
  end
  return _lv_out
end)())
    op_ann = (function() if logicview.truth(logicview.eq(self.operation, Operation.READ)) then return { "Read", "Rd" } else return { "Write", "Wr" } end end)()
    wait_ann = { "Wait", "Wt" }
    addr_ann = { logicview.pyformat("Register: {}", { register_name }, logicview.dict({})), logicview.pyformat("{}", { register_name }, logicview.dict({})) }
    data_ann = { logicview.pyformat("{}", { data_str }, logicview.dict({})), logicview.pyformat("{}", { data_str }, logicview.dict({})), data_str }
    if logicview.truth((self.wait_count > 0)) then
      return { { self.start_sample, self.end_sample_op, op_ann }, { self.end_sample_op, self.end_sample_addr, addr_ann }, { self.end_sample_addr, self.end_sample_wait, wait_ann }, { self.end_sample_wait, self.end_sample_data, data_ann } }
    else
      return { { self.start_sample, self.end_sample_op, op_ann }, { self.end_sample_op, self.end_sample_addr, addr_ann }, { self.end_sample_addr, self.end_sample_data, data_ann } }
    end
  end
  return nil
end
function Transaction.new(...)
  local self = _setmetatable({}, Transaction)
  Transaction.__init__(self, ...)
  return self
end
_decoder = {
  api_version = 3,
  id = "spi_tpm",
  name = "SPI TPM",
  longname = "SPI TPM transactions",
  desc = "Parses TPM transactions from SPI bus with automatic VMK extraction for BitLocker.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "IC", "TPM", "BitLocker" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "tpm_version", desc = "TPM Version 1.2 or 2.0", default = "2.0", values = { "2.0", "1.2" } }) },
  annotations = { { "Read", "Read register operation" }, { "Write", "Write register operation" }, { "Address", "Register address" }, { "Data", "Data" }, { "Wait", "Wait" }, { "VMK", "Extracted BitLocker VMK" } },
  annotation_rows = { { "Transactions", "TPM transactions", { 0, 1, 2, 3, 4 } }, { "B-VMK", "BitLocker Volume Master Key", { 5 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self.end_wait = 1
  self.operation_mask = 128
  self.address_mask = 63
  self.queue = deque()
  self.vmk_meta = logicview.dict({ s_queue = deque(), vmk_ss = 0, vmk_es = 0 })
  self.saving_vmk = false
  self.vmk = {  }
  self:reset()
  self.state_machine = nil
  self:init_state_machine()
  self.fifo_registers = nil
end
function _decoder.reset(self)
  do
    local _lv_chain = 0
    self.ss = _lv_chain
    self.es = _lv_chain
  end
  self.state = nil
  self.current_transaction = nil
end
function _decoder.end_current_transaction(self)
  self:reset()
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  if logicview.truth(logicview.eq(logicview.idx(self.options, "tpm_version"), "2.0")) then
    self.wait_mask = 0
    self.fifo_registers = fifo_registers2
  else
    self.wait_mask = 254
    self.fifo_registers = fifo_registers1
  end
end
function _decoder.init_state_machine(self)
  self.state_machine = logicview.dict({ [TransactionState.READ] = self._transaction_read, [TransactionState.WRITE] = self._transaction_write, [TransactionState.READ_ADDRESS] = self._transaction_read_addr, [TransactionState.WAIT] = self._transaction_wait, [TransactionState.TRANSFER_DATA] = self._transaction_data, [logicview.NIL] = self._return })
end
function _decoder._return(self, mosi, miso)
  return
end
function _decoder.transaction_state(self, mosi)
  if logicview.truth(logicview.eq((mosi & self.operation_mask), Operation.READ)) then
    return TransactionState.READ
  elseif logicview.truth(logicview.eq((mosi & self.operation_mask), Operation.WRITE)) then
    return TransactionState.WRITE
  else
    return nil
  end
end
function _decoder._transaction_wait(self, mosi, miso)
  self.current_transaction.wait_count = logicview.add(self.current_transaction.wait_count, 1)
  if logicview.truth(logicview.eq(miso, self.end_wait)) then
    self.current_transaction.end_sample_wait = self.es
    self.state = TransactionState.TRANSFER_DATA
    return
  end
end
function _decoder._transaction_read(self, mosi, miso)
  local transfer_size
  transfer_size = logicview.add((mosi & 63), 1)
  self.current_transaction = Transaction.new(self.ss, Operation.READ, transfer_size)
  self.current_transaction.end_sample_op = self.es
  self.state = TransactionState.READ_ADDRESS
end
function _decoder._transaction_write(self, mosi, miso)
  local transfer_size
  transfer_size = logicview.add((mosi & 63), 1)
  self.current_transaction = Transaction.new(self.ss, Operation.WRITE, transfer_size)
  self.current_transaction.end_sample_op = self.es
  self.state = TransactionState.READ_ADDRESS
end
function _decoder._transaction_read_addr(self, mosi, miso)
  logicview.extend(self.current_transaction.address, logicview.to_bytes(mosi, 1, 'big'))
  if logicview.truth(self.current_transaction:is_address_complete()) then
    self.current_transaction.end_sample_addr = self.es
    if logicview.truth(logicview.eq(miso, self.wait_mask)) then
      self.state = TransactionState.WAIT
    else
      self.state = TransactionState.TRANSFER_DATA
    end
    return
  end
end
function _decoder._transaction_data(self, mosi, miso)
  local annotation, op_ss, op_es, op_ann, addr_ss, addr_es, addr_ann, data_ss, data_es, data_ann, wait_ss, wait_es, wait_ann
  self.current_transaction.end_sample_data = self.es
  if logicview.truth(logicview.eq(self.current_transaction.operation, Operation.READ)) then
    logicview.extend(self.current_transaction.data, logicview.to_bytes(miso, 1, 'big'))
    self:recover_vmk(miso)
  elseif logicview.truth(logicview.eq(self.current_transaction.operation, Operation.WRITE)) then
    logicview.extend(self.current_transaction.data, logicview.to_bytes(mosi, 1, 'big'))
  end
  annotation = self.current_transaction:frame(self.fifo_registers)
  if logicview.truth(annotation) then
    if logicview.truth(logicview.eq(self.current_transaction.wait_count, 0)) then
      do
        local _lv_seq = annotation
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        do
          local _lv_sub = logicview.idx(_lv_seq, 0)
          op_ss = logicview.idx(_lv_sub, 0)
          op_es = logicview.idx(_lv_sub, 1)
          op_ann = logicview.idx(_lv_sub, 2)
        end
        do
          local _lv_sub = logicview.idx(_lv_seq, 1)
          addr_ss = logicview.idx(_lv_sub, 0)
          addr_es = logicview.idx(_lv_sub, 1)
          addr_ann = logicview.idx(_lv_sub, 2)
        end
        do
          local _lv_sub = logicview.idx(_lv_seq, 2)
          data_ss = logicview.idx(_lv_sub, 0)
          data_es = logicview.idx(_lv_sub, 1)
          data_ann = logicview.idx(_lv_sub, 2)
        end
      end
      self:put(op_ss, op_es, self.out_ann, { (function() if logicview.truth(logicview.eq(self.current_transaction.operation, Operation.READ)) then return Ann.READ else return Ann.WRITE end end)(), op_ann })
      self:put(addr_ss, addr_es, self.out_ann, { Ann.ADDRESS, addr_ann })
      self:put(data_ss, data_es, self.out_ann, { Ann.DATA, data_ann })
    else
      do
        local _lv_seq = annotation
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        do
          local _lv_sub = logicview.idx(_lv_seq, 0)
          op_ss = logicview.idx(_lv_sub, 0)
          op_es = logicview.idx(_lv_sub, 1)
          op_ann = logicview.idx(_lv_sub, 2)
        end
        do
          local _lv_sub = logicview.idx(_lv_seq, 1)
          addr_ss = logicview.idx(_lv_sub, 0)
          addr_es = logicview.idx(_lv_sub, 1)
          addr_ann = logicview.idx(_lv_sub, 2)
        end
        do
          local _lv_sub = logicview.idx(_lv_seq, 2)
          wait_ss = logicview.idx(_lv_sub, 0)
          wait_es = logicview.idx(_lv_sub, 1)
          wait_ann = logicview.idx(_lv_sub, 2)
        end
        do
          local _lv_sub = logicview.idx(_lv_seq, 3)
          data_ss = logicview.idx(_lv_sub, 0)
          data_es = logicview.idx(_lv_sub, 1)
          data_ann = logicview.idx(_lv_sub, 2)
        end
      end
      self:put(op_ss, op_es, self.out_ann, { (function() if logicview.truth(logicview.eq(self.current_transaction.operation, Operation.READ)) then return Ann.READ else return Ann.WRITE end end)(), op_ann })
      self:put(addr_ss, addr_es, self.out_ann, { Ann.ADDRESS, addr_ann })
      self:put(wait_ss, wait_es, self.out_ann, { Ann.WAIT, wait_ann })
      self:put(data_ss, data_es, self.out_ann, { Ann.DATA, data_ann })
    end
    self:end_current_transaction()
  end
end
function _decoder._is_vmk_transaction(self)
  do
    local _lv_return = false
    local _lv_value = nil
    local _ok, _err = _pcall(function()
      if logicview.truth(logicview.eq(logicview.idx(self.fifo_registers, (logicview.from_bytes(self.current_transaction.address, "big") & 65535)), "TPM_DATA_FIFO_0")) then
        _lv_return = true
        _lv_value = true
        return
      else
        _lv_return = true
        _lv_value = false
        return
      end
    end)
    if _lv_return then return _lv_value end
    if not _ok then
      if (_type(_err) == 'table' and _err._exc == "KeyError") then
        return false
      else
        _error(_err, 0)
      end
    end
  end
end
function _decoder.check_vmk_header(self)
  local potential_header
  if logicview.truth(logicview.eq(logicview.idx(self.queue, 0), 44)) then
    potential_header = logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.queue) do
    x = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pyformat("{:02x}", { x }, logicview.dict({}))
  end
  return _lv_out
end)())
    if logicview.truth(re.findall("2c000[0-6]000[1-9]000[0-1]000[0-5]200000", potential_header)) then
      self:put(logicview.idx(logicview.idx(self.vmk_meta, "s_queue"), 0), self.es, self.out_ann, { Ann.VMK, { logicview.pyformat("VMK header: {}", { potential_header }, logicview.dict({})) } })
      self.saving_vmk = true
    end
  end
end
function _decoder.recover_vmk(self, miso)
  if logicview.truth((not logicview.truth(self.saving_vmk))) then
    if logicview.truth(self:_is_vmk_transaction()) then
      _table.insert(self.queue, miso)
      _table.insert(logicview.idx(self.vmk_meta, "s_queue"), self.ss)
      self:check_vmk_header()
    end
  else
    if logicview.truth(logicview.eq(logicview.len(self.vmk), 0)) then
      logicview.setidx(self.vmk_meta, "vmk_ss", self.ss)
    end
    if logicview.truth((logicview.len(self.vmk) < 32)) then
      if logicview.truth(self:_is_vmk_transaction()) then
        _table.insert(self.vmk, miso)
        logicview.setidx(self.vmk_meta, "vmk_es", self.es)
      end
    else
      self.saving_vmk = false
      self:put(logicview.idx(self.vmk_meta, "vmk_ss"), logicview.idx(self.vmk_meta, "vmk_es"), self.out_ann, { Ann.VMK, { logicview.pyformat("VMK: {}", { logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.vmk) do
    x = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pyformat("{:02x}", { x }, logicview.dict({}))
  end
  return _lv_out
end)()) }, logicview.dict({})) } })
    end
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, mosi, miso
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ptype = logicview.idx(_lv_seq, 0)
      mosi = logicview.idx(_lv_seq, 1)
      miso = logicview.idx(_lv_seq, 2)
    end
    if logicview.truth(logicview.eq(ptype, "CS-CHANGE")) then
      self:end_current_transaction()
    end
    if logicview.truth((not logicview.eq(ptype, "DATA"))) then
      return
    end
    if logicview.truth((self.state == nil)) then
      self.state = self:transaction_state(mosi)
    end
    logicview.idx(self.state_machine, self.state)(mosi, miso)
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
