local handlers = {}
FONTS = {}
local function widget()
  local w = {}
  setmetatable(w, {__index=function(t,k)
    if k=="IsShown" then return function() return t._shown end end
    if k=="SetPoint" then return function(self,...) t._pt={...} end end
    if k=="SetAlpha" then return function(self,v) t._alpha=v end end
    if k=="GetAlpha" then return function() return t._alpha or 1 end end
    if k=="CreateFontString" then return function() local w=widget(); table.insert(FONTS,w); return w end end
    if k=="SetEnabled" then return function(self,v) t._enabled=v end end
    if k=="IsEnabled" then return function() return t._enabled ~= false end end
    if k=="SetText" then return function(self,v) t._text=v end end
    if k=="GetText" then return function() return t._text end end
    if k=="GetVerticalScrollRange" then return function() return RANGE or 0 end end
    if k=="GetVerticalScroll" then return function() return t._vs or 0 end end
    if k=="SetVerticalScroll" then return function(self,v) t._vs=v; if t._OnVerticalScroll then t._OnVerticalScroll(t,v) end end end
    if k=="GetHeight" then return function() return t._h or 300 end end
    if k=="SetHeight" then return function(self,v) t._h=v end end
    if k=="GetEffectiveScale" then return function() return 1 end end
    if k=="GetRegions" or k=="GetChildren" then return function() end end
    if k=="GetWidth" then return function() return rawget(t,"_w") or 300 end end
    if k=="CanWordWrap" or k=="IsWordWrapped" then return function() return true end end
    if k=="GetRight" then return function() return rawget(t,"_right") or 1900 end end
    if k=="GetLeft" then return function() return rawget(t,"_left") or 400 end end
    if k=="GetTop" then return function() return rawget(t,"_top") or 400 end end
    if k=="GetBottom" then return function() return rawget(t,"_bottom") or 100 end end
    if k=="GetStringHeight" then return function() return 20 end end
    if k=="GetFrameLevel" then return function() return 1 end end
    return function(self, ...) 
      if k=="Show" then t._shown=true elseif k=="Hide" then t._shown=false end
      if k=="SetScript" then local ev,fn=...; t["_"..ev]=fn end
      if k=="GetPoint" then return "CENTER",nil,"CENTER",0,0 end
      return widget()
    end end})
  return w
end
frames = {}
function CreateFrame(kind,name,...) local f=widget(); f._kind=kind; table.insert(frames,f)
  if name then _G[name]=f end return f end
UIParent=widget(); QuestFont={}; 
UISpecialFrames={}; tinsert=table.insert
function CreateFont() return widget() end
GameTooltip = GameTooltip or widget()
StaticPopupDialogs={}; function StaticPopup_Show(n) _G.__popup=n end
SlashCmdList={}
function GetLocale() return _G.__locale or "ptBR" end
local zone="Elwynn Forest"
function GetZoneText() return zone end
function SetZone(z) zone=z end
function GetTitleText() return "Wolves Across the Border" end
C_QuestLog={GetTitleForQuestID=function() return nil end}
function strtrim(s) return (s:gsub("^%s+",""):gsub("%s+$","")) end
function unpack(...) return table.unpack(...) end
unpack = table.unpack
date=os.date
print_out={}
function print(...) table.insert(print_out, table.concat({...}," ")) end
time=os.time
C_Map={GetBestMapForUnit=function() return 37 end,
 GetPlayerMapPosition=function() return {GetXY=function() return 0.42,0.61 end} end}
issecretvalue=nil

CURSOR=0
function GetCursorPosition() return 0, CURSOR end
