local F9, ESCAPE, ENTER = 120, 27, 13
local LEFT, UP, RIGHT, DOWN = 37, 38, 39, 40
local PAGE_UP, PAGE_DOWN = 33, 34
local BATTLE_IDLE = 1
local MENU_FOOTER = "F9 or Esc: close"
local Panel = { classname = "BookwormDebugPanel", base = LuaWidget }
Panel.mt = { __index = Panel }
setmetatable(Panel, { __index = LuaWidget })

local panel, held
local bonusOwner, savedBonuses
local letters = {}
for code = 65, 90 do letters[code - 64] = string.char(code) end

local gems = {
  [1] = { label = "Amethyst", name = "AmethystTile" },
  [2] = { label = "Sapphire", name = "SapphireTile" },
  [3] = { label = "Emerald", name = "EmeraldTile" },
  [4] = { label = "Garnet", name = "GarnetTile" },
  [5] = { label = "Ruby", name = "RubyTile" },
  [6] = { label = "Topaz", name = "TopazTile" },
  [7] = { label = "Crystal", name = "CrystalTile" },
  [8] = { label = "Diamond", name = "DiamondTile" },
}

local potions = {
  [1] = { label = "Healing potion", name = "HealthItem" },
  [2] = { label = "Attack potion", name = "AttackItem" },
  [3] = { label = "Purify potion", name = "PurifyItem" },
}

local function createBurn(definition) return definition:new(1, 1, 1, 0) end
local function createPoison(definition) return definition:new(1, 1, 3, 0) end
local function createShortEffect(definition) return definition:new(1) end
local function createLongEffect(definition) return definition:new(2) end
local function createPowerUp(definition) return definition:new(1.25, 1, true, true, true) end

local effects = {
  [1] = { label = "Clear ailments", name = false },
  [2] = { label = "Burning", name = "FireAilment", create = createBurn },
  [3] = { label = "Poisoned", name = "PoisonAilment", create = createPoison },
  [4] = { label = "Stunned", name = "StunEffect", create = createShortEffect },
  [5] = { label = "Frozen", name = "FreezeEffect", create = createLongEffect },
  [6] = { label = "Petrified", name = "PetrifyEffect", create = createLongEffect },
  [7] = { label = "Powered up", name = "DamageMultiplierEffect", create = createPowerUp },
}

local treasureNames = {
  [1] = "ArtemisBow", [2] = "AegisOfAthena", [3] = "ArchOfApollo",
  [4] = "CloakOfShades", [5] = "EndlessGemPouch", [6] = "FatesCoin",
  [7] = "GargantuanGirdle", [8] = "GoldenFleece", [9] = "GorgonHead",
  [10] = "HandOfHercules", [11] = "HephaestusHammer", [12] = "HopeOfQua",
  [13] = "IcarusSandals", [14] = "ImmortalWrappings", [15] = "JeweledKey",
  [16] = "MagicGenieLamp", [17] = "MagicPen", [18] = "MagistratesMap",
  [19] = "PoseidonsShield", [20] = "RobeOfTheShiftingEye", [21] = "ScimitarOfJustice",
  [22] = "SilverCompass", [23] = "SlayerTalisman", [24] = "SphinxLantern",
  [25] = "TabletOfTheAges", [26] = "TheseusBoots", [27] = "TomeOfTheAncients",
  [28] = "WanderersCharm", [29] = "WolfbaneNecklace", [30] = "WoodenParrot",
}

local pages = {
  [1] = {
    title = "Board",
    rows = {
      [1] = { label = "Grid row", field = "gridY" },
      [2] = { label = "Grid column", field = "gridX" },
      [3] = { label = "Letter", field = "letter" },
      [4] = { label = "Gem / bonus tile", field = "gem" },
      [5] = { label = "Random gem", field = "randomGem" },
      [6] = { label = "Letter bonus", field = "letterBonus" },
    },
  },
  [2] = {
    title = "Battle",
    rows = {
      [1] = { label = "Lex health", field = "lexHealth" },
      [2] = { label = "Opponent health", field = "enemyHealth" },
      [3] = { label = "Potion / power-up", field = "potion" },
      [4] = { label = "Status target", field = "target" },
      [5] = { label = "Status effect", field = "effect" },
      [6] = { label = "Equip treasure", field = "treasure" },
    },
  },
}

local function global(name)
  return rawget(_G, name)
end

local function choiceCount(list)
  local count = 0
  while list[count + 1] ~= nil do
    count = count + 1
  end
  return count
end

local function activeBattle()
  local battle = global("gBattleEngine")
  if not battle or global("gTimedMode") or global("gMiniGame") then
    return nil
  end
  if battle.mPlayerPtr and battle.mEnemyPtr and battle.mCObj:GetState() == BATTLE_IDLE
      and battle.mPlayerPtr.mHealth > 0 and battle.mEnemyPtr.mHealth > 0
      and not gCApp:DoingCurtainTransition() then
    return battle
  end
end

local function indexed(value, step, count)
  if count < 1 then return 1 end
  value = value + step
  if value < 1 then return count end
  if value > count then return 1 end
  return value
end

local function selectedTile(menu)
  return gTileTable[menu.board.mCObj:GridGetTile(menu.gridX - 1, menu.gridY - 1)]
end

local function addRandomGem(menu)
  local candidates, gemTypes = {}, {}
  local board = menu.board.mCObj
  local tileCount, gemCount = 0, 0
  for y = 0, gTilesHigh - 1 do
    for x = 0, gTilesWide - 1 do
      local tile = gTileTable[board:GridGetTile(x, y)]
      if tile and tile.mLetter and tile.mLetter ~= "" and not tile:IsGem() then
        tileCount = tileCount + 1
        candidates[tileCount] = { tile = tile, row = y + 1, column = x + 1 }
      end
    end
  end
  if tileCount == 0 then return "Every occupied tile already has a gem." end

  for i = 1, choiceCount(gems) do
    local gem = gems[i]
    local definition = global(gem.name)
    if definition then
      gemCount = gemCount + 1
      gemTypes[gemCount] = { label = gem.label, definition = definition }
    end
  end
  if gemCount == 0 then return "Gem types are unavailable in this battle." end

  local chosen = candidates[math.mod(sexy.NextRand(), tileCount) + 1]
  local gem = gemTypes[math.mod(sexy.NextRand(), gemCount) + 1]
  chosen.tile:AddAttribute(gem.definition)
  return gem.label .. " added at row " .. chosen.row .. ", column " .. chosen.column .. "."
end

local function refreshLetter(menu)
  local tile = selectedTile(menu)
  local letter = tile and tile.mLetter
  menu.letter = 1
  for i = 1, choiceCount(letters) do
    if letters[i] == letter then menu.letter = i; break end
  end
  local bonuses = global("LETTER_BONUSES")
  menu.letterBonus = bonuses and bonuses[letters[menu.letter]] or 0
end

local function availableTreasures()
  local list = {}
  for i = 1, choiceCount(treasureNames) do
    local name = treasureNames[i]
    local definition = global(name)
    if definition and definition.BOOK and definition.NUMBER then
      local image = "IMAGE_TREASURE_" .. definition.BOOK .. "_" .. definition.NUMBER .. "_sml"
      local ok, value = pcall(gCApp.GetImage, gCApp, image)
      if ok and value then
        list[choiceCount(list) + 1] = {
          label = string.gsub(name, "(%l)(%u)", "%1 %2"),
          definition = definition,
        }
      end
    end
  end
  return list
end

local function closeMenu()
  if not panel then return end
  local closing = panel
  panel = nil
  local manager = gCApp:GetWidgetManager()
  manager:RemoveWidget(closing.mCObj)
  if closing.board == global("gLuaBoard") then
    manager:SetFocus(closing.board.mCObj)
  end
  gCApp:SafeDeleteWidget(closing.mCObj)
end

local function openMenu(board, battle, manager)
  local menu = gApp:CreateLuaWidget(Panel)
  menu.board, menu.battle = board, battle
  menu.width, menu.height = gAppWidth, gAppHeight
  menu.page = 1
  menu.row, menu.gridX, menu.gridY = 1, 1, 1
  menu.gem, menu.potion, menu.target, menu.effect, menu.treasure = 1, 1, 2, 2, 1
  menu.lexHealth = battle.mPlayerPtr.mHealth
  menu.enemyHealth = battle.mEnemyPtr.mHealth
  menu.treasures = availableTreasures()
  menu.message = MENU_FOOTER
  menu.drawFailed = false
  menu.randomGemKeyHeld = false
  refreshLetter(menu)
  menu.mCObj:Resize(0, 0, menu.width, menu.height)
  manager:AddWidget(menu.mCObj)
  panel = menu
  manager:SetFocus(menu.mCObj)
end

local function adjust(self, field, step)
  if field == "gridX" then
    self.gridX = indexed(self.gridX, step, gTilesWide)
    refreshLetter(self)
  elseif field == "gridY" then
    self.gridY = indexed(self.gridY, step, gTilesHigh)
    refreshLetter(self)
  elseif field == "lexHealth" then
    self.lexHealth = math.max(1, math.min(self.battle.mPlayerPtr.mMaxHealth, self.lexHealth + step))
  elseif field == "enemyHealth" then
    self.enemyHealth = math.max(1, math.min(self.battle.mEnemyPtr.mMaxHealth, self.enemyHealth + step))
  elseif field == "letterBonus" then
    self.letterBonus = math.max(0, math.min(3, self.letterBonus + step * 0.25))
  elseif field == "randomGem" then
    return
  else
    local counts = {
      letter = choiceCount(letters), gem = choiceCount(gems), potion = choiceCount(potions),
      target = 2, effect = choiceCount(effects), treasure = choiceCount(self.treasures),
    }
    self[field] = indexed(self[field], step, counts[field])
    if field == "letter" then
      local bonuses = global("LETTER_BONUSES")
      self.letterBonus = bonuses and bonuses[letters[self.letter]] or 0
    end
  end
end

local function apply(self, field)
  if activeBattle() ~= self.battle then return "Wait for your turn." end
  if field == "randomGem" then return addRandomGem(self) end
  local lex, enemy = self.battle.mPlayerPtr, self.battle.mEnemyPtr
  if field == "letter" or field == "gem" then
    local tile = selectedTile(self)
    if not tile then return "Choose an occupied tile." end
    if field == "letter" then
      tile:SetLetter(letters[self.letter])
      return "Letter changed."
    end
    if tile.IsGem and tile:IsGem() then return "That tile already has a gem." end
    local gem = gems[self.gem]
    local definition = global(gem.name)
    if not definition then return "This gem is unavailable here." end
    tile:AddAttribute(definition)
    return gem.label .. " added."
  elseif field == "lexHealth" then
    lex:SetHealth(self.lexHealth, lex.mMaxHealth, true)
    self.lexHealth = lex.mHealth
    return "Lex health updated."
  elseif field == "enemyHealth" then
    enemy:SetHealth(self.enemyHealth, enemy.mMaxHealth, true)
    self.enemyHealth = enemy.mHealth
    return "Opponent health updated."
  elseif field == "potion" then
    local potion = potions[self.potion]
    local definition = global(potion.name)
    if not definition then return "This potion is unavailable here." end
    lex:AddItem(definition:new())
    return potion.label .. " added."
  elseif field == "effect" then
    local choice = effects[self.effect]
    local isEnemy = self.target == 2
    local target = isEnemy and enemy or lex
    if not choice.name then
      target:Purify(isEnemy)
      return "Purify applied."
    end
    local definition = global(choice.name)
    if not definition then return "This status effect is unavailable here." end
    local effect = choice.create(definition)
    if choice.name == "DamageMultiplierEffect" and target:StatusEffectExists(effect) then
      return "That combatant is already powered up."
    end
    effect:Apply(target, false)
    return choice.label .. " applied."
  elseif field == "treasure" then
    local treasure = self.treasures[self.treasure]
    if not treasure then return "No treasure assets loaded in this battle." end
    if (lex.mNumEnabledTreasures or 0) >= 3 then return "All three treasure slots are occupied." end
    local definition = treasure.definition
    for _, equipped in pairs(lex.mTreasures or {}) do
      if type(equipped) == "table" and equipped.mEnabled
          and equipped.BOOK == definition.BOOK and equipped.NUMBER == definition.NUMBER then
        return "That treasure is already equipped."
      end
    end
    lex:AddTreasure(definition, true, false)
    return treasure.label .. " equipped."
  elseif field == "letterBonus" then
    local tile = selectedTile(self)
    local bonuses = global("LETTER_BONUSES")
    if not tile or not bonuses then return "Choose an occupied letter tile." end
    local letter = tile.mLetter
    if letter ~= letters[self.letter] then return "Apply the selected letter first." end
    if not savedBonuses then savedBonuses = {}; bonusOwner = enemy end
    if savedBonuses[letter] == nil then savedBonuses[letter] = bonuses[letter] or 0 end
    bonuses[letter] = self.letterBonus
    local nativeBoard = self.board.mCObj
    for y = 0, gTilesHigh - 1 do
      for x = 0, gTilesWide - 1 do
        local gridTile = gTileTable[nativeBoard:GridGetTile(x, y)]
        if gridTile and gridTile.mLetter == letter then gridTile:SetLetter(letter) end
      end
    end
    return letter .. " bonus updated for this encounter."
  end
  return "Use Left and Right to change this selection."
end

local function keyDown(self, key)
  local rows = pages[self.page].rows
  if key == F9 and not held then
    held = true
    closeMenu()
    return
  elseif key == ESCAPE then
    closeMenu()
    return
  elseif key == PAGE_UP or key == PAGE_DOWN then
    self.page = indexed(self.page, key == PAGE_UP and -1 or 1, choiceCount(pages))
    self.row = 1
    self.message = MENU_FOOTER
  elseif key == UP or key == DOWN then
    self.row = indexed(self.row, key == UP and -1 or 1, choiceCount(rows))
    self.message = MENU_FOOTER
  elseif key == LEFT or key == RIGHT then
    self:Adjust(rows[self.row].field, key == LEFT and -1 or 1)
    self.message = MENU_FOOTER
  elseif key == ENTER then
    local field = rows[self.row].field
    if field == "randomGem" then
      if self.randomGemKeyHeld then return end
      self.randomGemKeyHeld = true
    end
    local ok, message = pcall(self.Apply, self, field)
    self.message = ok and message or "Action could not be applied in this battle."
  else
    return
  end
  self.mCObj:MarkDirty()
end

local function keyUp(self, key)
  if key == ENTER then self.randomGemKeyHeld = false end
end

local function draw(self, g)
  local page = pages[self.page]
  local rows = page.rows
  local treasure = self.treasures[self.treasure]
  local values = {
    gridY = self.gridY,
    gridX = self.gridX,
    letter = letters[self.letter],
    gem = gems[self.gem].label,
    randomGem = "Enter to add",
    lexHealth = tostring(self.lexHealth) .. " / " .. tostring(self.battle.mPlayerPtr.mMaxHealth),
    enemyHealth = tostring(self.enemyHealth) .. " / " .. tostring(self.battle.mEnemyPtr.mMaxHealth),
    potion = potions[self.potion].label,
    target = self.target == 1 and "Lex" or "Opponent",
    effect = effects[self.effect].label,
    treasure = treasure and treasure.label or "Unavailable",
    letterBonus = letters[self.letter] .. " +" .. tostring(self.letterBonus),
  }
  local rowsPerColumn = math.floor((choiceCount(rows) + 1) / 2)
  local width, height = math.min(self.width - 32, 712), 104 + rowsPerColumn * 20
  local x, y = math.floor((self.width - width) / 2), 20
  local columnWidth = math.floor((width - 44) / 2)
  g:SetColor(-14737633)
  g:FillRect(x, y, width, height)
  g:SetColor(-2188760)
  g:DrawRect(x, y, width, height)
  g:SetFont(FONT_MEDIUM)
  g:DrawString("Battle debug", x + 22, y + 31)
  g:DrawString(page.title .. " " .. self.page .. "/" .. choiceCount(pages), x + width - 130, y + 31)
  g:SetColor(-1)
  g:DrawString("Up/Down: choose   Left/Right: change   Enter: apply   PgUp/PgDn: page", x + 22, y + 56)
  local i = 1
  local row = rows[i]
  while row do
    local column = math.floor((i - 1) / rowsPerColumn)
    local line = i - 1 - column * rowsPerColumn
    local left = x + 22 + column * columnWidth
    local lineY = y + 81 + line * 20
    if i == self.row then
      g:SetColor(-11250579)
      g:FillRect(left - 7, lineY - 16, columnWidth - 5, 20)
    end
    g:SetColor(-1)
    g:DrawString(row.label, left, lineY)
    g:DrawString(tostring(values[row.field]), left + 146, lineY)
    i = i + 1
    row = rows[i]
  end
  g:SetColor(-2188760)
  g:DrawString(self.message, x + 22, y + height - 23)
end

local function guardedKeyDown(self, key)
  local ok = pcall(keyDown, self, key)
  if not ok then
    self.message = "The control could not be used in this battle."
  end
end

local function guardedDraw(self, graphics)
  if self.drawFailed then return end
  local ok = pcall(draw, self, graphics)
  if not ok then
    self.drawFailed = true
  end
end

local function updateMenu(board)
  if board ~= global("gLuaBoard") then return end
  local manager = gCApp:GetWidgetManager()
  local down = manager:IsKeyDown(F9)
  local pressed = down and not held
  held = down
  if panel and panel.randomGemKeyHeld and not manager:IsKeyDown(ENTER) then
    panel.randomGemKeyHeld = false
  end
  local rawBattle = global("gBattleEngine")
  if savedBonuses and (not rawBattle or rawBattle.mEnemyPtr ~= bonusOwner) then
    local bonuses = global("LETTER_BONUSES")
    if bonuses then
      for letter, value in pairs(savedBonuses) do bonuses[letter] = value end
    end
    savedBonuses, bonusOwner = nil, nil
  end
  local battle = activeBattle()
  if panel and (panel.drawFailed or panel.battle ~= battle or pressed) then
    closeMenu()
  elseif pressed and battle and not panel then
    openMenu(board, battle, manager)
  end
end

local boardUpdate = Board.Update
local function updateBoard(self)
  boardUpdate(self)
  local ok = pcall(updateMenu, self)
  if not ok then
    pcall(closeMenu)
  end
end

Panel.Adjust = adjust
Panel.Apply = apply
Panel.KeyDown = guardedKeyDown
Panel.KeyUp = keyUp
Panel.Draw = guardedDraw
Board.Update = updateBoard
