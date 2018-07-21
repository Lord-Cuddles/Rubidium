dplugin.version = "1.0"
server = plugin.getServer()
config = plugin.getStorageObject( "config.yml" )
entities = import("$.entity.EntityType")
gamemode = import("$.GameMode")

plugin.onEnable(
  function()
    config:setDefaultValue( "worldName", "Game" )
    config:setDefaultValue( "worldSize", 1000 )
    config:setDefaultValue( "warpSize", 350 )
    config:setDefaultValue( "playerLimit", 8 )
    config:setDefaultValue( "allowOcean", false )
    config:setDefaultValue( "allowDesert", true )
    config:setDefaultValue( "allowMountain", true )
    config:setDefaultValue( "allowJungle", true )
    config:setDefaultValue( "allowFeast", true )
    config:setDefaultValue( "largeBiomes", true )
    config:setDefaultValue( "difficulty", 3 )
    config:setDefaultValue( "shrinkDelay", 900 )
    config:save()
    logger.info("Enabled Rubidium "..plugin.version )
    server:broadcast("§4Rubidium §7"..plugin.version.."§4 has been enabled", "rubidium.alerts")
  end
)

plugin.onDisable(
  function()
    if game then
      deleteGame()
    end
    logger.info("Unloaded Rubidium")
  end
)

function deleteGame()
  game = nil
  server:dispatchCommand( server:getConsoleSender(), "mvdelete "..config:getValue("worldName") )
  server:dispatchCommand( server:getConsoleSender(), "mvconfirm" )
end

function isMember( name )
  if not game.members then error("Attempted to check table that doesnt exist") end

  for e = 1, #game.members do
    if string.lower(name) == string.lower(game.members[e]) then
      return true
    end
  end
  return false
end

function addMember( name )
  if not isMember( name ) then
    table.insert( game.members, name )
    return true
  else
    return false
  end
end

function delMember( name )
  if not name then error("Missing a name argument") end
  if not game.members then error("Attempted to remove member from a table that doesnt exist") end
  for e = 1, #game.members do
    if string.lower( game.members[e] ) == string.lower( name ) then
      table.remove( game.members, e )
      return true
    end
  end
  return false
end

function newGame( options )
  local temp = {}
  local name = config:getValue( "worldName" )

  logger.info("Creating a new world...")

  temp.stage = "CREATING"
  temp.creator = options.creator or "???"
  temp.gameType = options.gameType or "Elimination"
  temp.border = config:getValue( "worldSize" )
  temp.open = false
  temp.members = {}
  temp.participants = {}
  temp.spectators = {}
  temp.warps = {}

  if string.lower(options.gameType) == "elimination" then

    if config:getValue( "largeBiomes" ) == true then
      server:dispatchCommand( server:getConsoleSender(), "mvc "..name.." normal -t largebiomes")
    else
      server:dispatchCommand( server:getConsoleSender(), "mvc "..name.." normal" )
    end

    server:dispatchCommand( server:getConsoleSender(), "mvm set respawnWorld "..name.." "..name)
    server:dispatchCommand( server:getConsoleSender(), "mvm set difficulty 0 "..name)
    server:dispatchCommand( server:getConsoleSender(), "mvm set bedRespawn false "..name)
    server:dispatchCommand( server:getConsoleSender(), "mv gamerule doDaylightCycle false "..name)

    local world = server:getWorld(name)
    local border = world:getWorldBorder()
    border:setCenter(0.0, 0.0)
    border:setDamageAmount(0.1)
    border:setSize( tonumber(config:getValue( "worldSize")) )
    border:setWarningTime( 30 )

  end

  logger.info("World has been created")

  return temp
end

function addWarps()
  if not game then error("Attempted to add warps to a non existant game") end
  local world = server:getWorld(config:getValue("worldName"))
  if not world then error("Missing world userdata") end
  local cmod = config:getValue("warpSize")
  local coords = {
    {0.5+cmod, 0.5+cmod},
    {-0.5-cmod, -0.5-cmod},
    {0.5+cmod, -0.5-cmod},
    {-0.5-cmod, 0.5+cmod},
    {0.5, 0.5+cmod},
    {0.5, -0.5-cmod},
    {0.5+cmod, 0.5},
    {-0.5-cmod, 0.5},
  }
  for c = 1, #coords do
    game.warps[c] = {}
    game.warps[c].x = coords[c][1]
    game.warps[c].z = coords[c][2]
    game.warps[c].y = world:getHighestBlockYAt(coords[c][1], coords[c][2]) + 0.5
    server:getWorld( config:getValue("worldName")):loadChunk(game.warps[c].x, game.warps[c].z, true )
  end
end

function checkWarps()
  local unsafe = {}
  if config:getValue("allowOcean") == false then
    table.insert(unsafe, "OCEAN")
    table.insert(unsafe, "DEEP_OCEAN")
    table.insert(unsafe, "FROZEN_OCEAN")
  end
  if config:getValue("allowDesert") == false then
    table.insert(unsafe, "DESERT")
    table.insert(unsafe, "DESERT_HILLS")
  end
  if config:getValue("allowJungle") == false then
    table.insert(unsafe, "JUNGLE")
    table.insert(unsafe, "JUNGLE_EDGE")
    table.insert(unsafe, "JUNGLE_HILLS")
    table.insert(unsafe, "JUNGLE_MOUNTAINS")
  end
  if config:getValue("allowMountain") == false then
    table.insert(unsafe, "EXTREME_HILLS")
    table.insert(unsafe, "EXTREME_HILLS_PLUS")
    table.insert(unsafe, "EXTREME_HILLS_PLUS_MOUNTAINS")
    table.insert(unsafe, "EXTREME_HILLS_MOUNTAINS")
  end

  logger.info("There are "..#unsafe.." banned biomes. Begin check")

  for warp = 1, #game.warps do

    local biome = server:getWorld( config:getValue("worldName")):getBiome( game.warps[warp].x, game.warps[warp].z )

    logger.info(warp..": "..tostring(biome))
    for b = 1, #unsafe do
      if tostring(biome) == tostring(unsafe[b]) then
        return true, warp, tostring(biome)
      end
    end

    local blocks = { 17, 0, 0, 0 }
    local positions = { {0, 0}, {1, 1}, {1, 0}, {1, -1}, {0, 1}, {0, -1}, {-1, 1}, {-1, 0}, {-1, -1}, }
    local world = server:getWorld( config:getValue( "worldName" ))
    local floor = world:getHighestBlockYAt( positions[1][1]+game.warps[warp].x, positions[1][2]+game.warps[warp].z ) - 1
    server:broadcastMessage(positions[1][1]+game.warps[warp].x .. " " .. positions[1][2]+game.warps[warp].z)
    for y = 1, #blocks do
      for pos = 1, #positions do
        yPos = y + floor - 1
        world:getBlockAt( math.floor(positions[pos][1] + game.warps[warp].x) , yPos, math.floor(positions[pos][2] + game.warps[warp].z)):setTypeId(blocks[y])
      end
    end

  end

  table.insert(unsafe, "RIVER")
  table.insert(unsafe, "FROZEN_RIVER")

  local biome = server:getWorld( config:getValue("worldName")):getBiome( 0, 0 )

  logger.info( "Spawn: "..tostring(biome) )
  for b = 1, #unsafe do
    if tostring(biome) == tostring(unsafe[b]) then
      return true, warp, tostring(biome)
    end
  end
  local blocks = { 98, 0, 0, 0 }
  local positions = { {0, 0}, {1, 1}, {1, 0}, {1, -1}, {0, 1}, {0, -1}, {-1, 1}, {-1, 0}, {-1, -1}, }
  local world = server:getWorld( config:getValue( "worldName" ))
  local floor = world:getHighestBlockYAt( positions[1][1], positions[1][2] ) - 1

  for y = 1, #blocks do
    for pos = 1, #positions do
      yPos = y + floor - 1
      if not world then error("Failed to load world object in this loop") end
      world:getBlockAt( positions[pos][1], yPos, positions[pos][2] ):setTypeId(blocks[y])
    end
  end

  world:setSpawnLocation( 0, floor, 0 )

  return false

end

function startGame()
  server:broadcastMessage("Game starting")
  local world = server:getWorld( config:getValue("worldName"))
  server:dispatchCommand( server:getConsoleSender(), "mvm set gamemode 0 "..config:getValue("worldName"))
  server:dispatchCommand( server:getConsoleSender(), "mv gamerule doDaylightCycle true "..config:getValue("worldName"))
  server:dispatchCommand( server:getConsoleSender(), "mvm set difficulty "..config:getValue("difficulty").." "..config:getValue("worldName"))

  local border = world:getWorldBorder()
  border:setCenter( 0.0, 0.0 )
  border:setDamageAmount( 0.1 )
  border:setSize( config:getValue("worldSize") )
  border:setWarningTime( 30 )

  local players = {}
  for n = 1, #game.members do
    players[n] = server:getOfflinePlayer(game.members[n])
    local pos = world:getSpawnLocation()
    pos:setX( game.warps[n].x )
    pos:setZ( game.warps[n].z )
    pos:setY( world:getHighestBlockYAt( pos:getX(), pos:getZ()) + 0.5 )
    players[n]:teleport( pos )
    players[n]:setFoodLevel(20)
    players[n]:setSaturation(20.0)
    players[n]:setHealth( players[n]:getMaxHealth() )
    players[n]:getInventory():clear()
  end
  game.stage = "RUNNING"

  util.runAsync(
    function()
      if not game then return end
      if game.stage == "RUNNING" then
        server:broadcastMessage("The border is now shrinking")
        border:setSize( 64, 120 )
      end
    end,
    config:getValue("shrinkDelay") * 1000
  )

end

plugin.addCommand({
  name = "game",
  description = "Main command for managing games",
},
  function( command )
    local sender, args = command.getSender(), command.getArgs()
    if not args[1] or args[1] == "help" then

      -- /game help

      local page = 1
      if not args[2] then else page = tonumber(args[2]) end
      local title = "§e-------- Rubidium Help --- Page "..page.." --------"
      local topics = {
        "/game help - Show a list of commands",
        "/game version - Show the plugin version",
        "/game create - Create a new streamer game",
        "/game delete - Deletes any existing game or world",
        "/game modes - Show a list of available modes",
        "/game info - Show current game information",
        "/game check - Check the current warp in the world",
        "/game open - Permit players to join the game",
        "/game close - Prevent players from joining",
        "/game add - Add a player to the member list",
        "/game del - Remove a player from the member list",
        "/game start - Start a prepared game",
        "/game config - Change a config value",
      }
      sender:sendMessage( title )
      for entry = ( page * 8) - 7, ( page * 8 ) do
        if entry <= #topics then
          sender:sendMessage( topics[ entry ] )
          if entry == page * 8 then
            local nextpage = page + 1
            sender:sendMessage("§7Type /game help "..nextpage.." for more help")
          elseif entry == #topics then
            sender:sendMessage("§7This is the final help entry")
          return end
        elseif entry > #topics then
          sender:sendMessage("§7This page is empty")
        end
      end

    elseif args[1] == "create" then

      if game then
        sender:sendMessage("§7There is already a game created.") return
      end
      if not args[2] then
        sender:sendMessage("§7Usage: /game create [mode]") return
      end
      server:broadcastMessage( "§7Creating new instance of §a"..args[2] )
      game = newGame({gameType=string.lower(args[2]), creator=sender:getName()})
      addWarps()
      local isUnsafe, unsafe, biome = checkWarps()
      if isUnsafe then
        server:broadcastMessage("§7Game creation §cfailed§7: Warp "..tostring(unsafe).." was "..tostring(biome))
        deleteGame()
        return
      end

      server:broadcastMessage("§7A new instance of §a".. game.gameType .." §7was created successfully")
      game.stage = "WAITING"
      server:dispatchCommand( server:getConsoleSender(), "mvm set gamemode spectator "..config:getValue( "worldName" ))
      if sender == server:getConsoleSender() then return end
      server:dispatchCommand( server:getConsoleSender(), "mvtp "..sender:getName().." "..config:getValue( "worldName" ))

    elseif args[1] == "delete" then

      deleteGame()
      sender:sendMessage("The game has been deleted")

    elseif args[1] == "open" then

      if not game then sender:sendMessage("§7A game has not been created yet") return end
      if game.stage == "WAITING" or game.stage == "READY" or game.stage == "CLOSED" then
        game.open = true
        sender:sendMessage("§7Now allowing players to join")
        game.stage = "OPEN"
      else
        sender:sendMessage("§7You cannot open the game now")
      end

    elseif args[1] == "close" then

      if not game then sender:sendMessage("§7A game has not been created yet") return end
      if game.stage == "OPEN" then
        game.open = false
        sender:sendMessage("§7Now preventing players from joining")
        if #game.members < 2 then
          game.stage = "CLOSED"
        else
          game.stage = "READY"
        end
      else
        sender:sendMessage("§7The game is not open, cannot close")
        game.open = false
      end

    elseif args[1] == "add" then

      if not game then sender:sendMessage("§7There is not an active game") return end
      if game.open == false then sender:sendMessage("§7The game is not accepting joining") return end
      if not args[2] then sender:sendMessage("§7Usage: /game add [username]") return end

      local player = server:getOfflinePlayer( args[2] )
      if not player:isOnline() then sender:sendMessage("§7That player is not online") return end
      if addMember( args[2] ) == true then
        sender:sendMessage("§7Added "..server:getOfflinePlayer(args[2]):getPlayer():getName())
      else
        sender:sendMessage("§7"..args[2].." is already joined")
      end
      game.participants = game.members

    elseif args[1] == "del" then

      if not game then sender:sendMessage("§7There is not an active game") return end
      if game.open == false then sender:sendMessage("§7You cannot remove members from closed games") return end
      if not args[2] then sender:sendMessage("§7Usage: /game add [username]") return end
      if delMember( args[2] ) == true then
        sender:sendMessage("§7Removed "..args[2])
      else
        sender:sendMessage("§7"..args[2].." has not joined")
      end
      game.participants = game.members

    elseif args[1] == "start" then

      if not game then sender:sendMessage("No active game") return end
      if not game.stage == "READY" then sender:sendMessage("Game not ready") return end

      game.stage = "STARTING"
      startGame()
      if game.stage == "RUNNING" then
        sender:sendMessage("Game is now running")
      else
        sender:sendMessage("Game failed to run")
      end

    elseif args[1] == "modes" then

      local page = 1
      if not args[2] then else page = tonumber(args[2]) end
      local title = "§e-------- Game Mode List --- Page "..page.." --------"
      local topics = {
        "Elimination",
        " §7§o8 player FFA in a shrinking border",
        " §7§oType §f§o/game create elimination§7§o to create",
      }
      sender:sendMessage( title )
      for entry = ( page * 8 ) - 7, ( page * 8 ) do
        if entry <= #topics then
          sender:sendMessage( topics[ entry ] )
          if entry == #topics then return end
        elseif entry > #topics then
          sender:sendMessage("§7This page is empty")
        end
      end

    elseif args[1] == "check" then

      -- /game check [warp]

      if not game then sender:sendMessage("§7A game has not yet been created") return end
      if game.stage == "WAITING" or game.stage == "CLOSED" or game.stage == "OPEN" then

        if sender == server:getConsoleSender() then
          sender:sendMessage("You cannot do this from the console") return
        end
        if not args[2] then
          sender:sendMessage("Usage: /game check [warp]")
        return end
        local world = server:getWorld( config:getValue("worldName") )
        if args[2] == "spawn" then

          local loc = world:getSpawnLocation()
          loc:setX(0.5)
          loc:setZ(0.5)
          loc:setY( world:getHighestBlockYAt(0, 0) )
          sender:teleport( loc )

        elseif tonumber(args[2]) >= 1 and tonumber(args[2]) <= #game.warps then

          local loc = world:getSpawnLocation()
          loc:setX(game.warps[tonumber(args[2])].x)
          loc:setZ(game.warps[tonumber(args[2])].z)
          loc:setY( world:getHighestBlockYAt(loc:getX(), loc:getZ()))
          sender:teleport( loc )

        else

          sender:sendMessage("That location is not valid")

        end

      else sender:sendMessage("You cannot do that now") return end

    elseif args[1] == "info" then

      -- /game info

      sender:sendMessage("§e-------- Rubidium --- Game Info --------")

      if not game then
        sender:sendMessage("§7There is not currently an active game.") return
      end

      if game.stage == "CREATING" then
        sender:sendMessage("Current stage: CREATING")
        sender:sendMessage("Please wait for creation to finish!")
      elseif game.stage == "WAITING" then
        sender:sendMessage("Current stage: WAITING")
        sender:sendMessage("The creator is setting things up!")
      elseif game.stage == "CLOSED" then
        sender:sendMessage("Current stage: CLOSED")
        game.participants = game.members
      elseif game.stage == "OPEN" then
        sender:sendMessage("Current stage: OPEN")
        sender:sendMessage("Type /join to join the game")
        game.participants = game.members
      elseif game.stage == "READY" then
        sender:sendMessage("Current stage: READY")
        game.participants = game.members
      elseif game.stage == "RUNNING" then
        sender:sendMessage("Current stage: RUNNING")
        sender:sendMessage("Type /spectate to watch the game")
      elseif game.stage == "OVER" then
        sender:sendMessage("Current stage: OVER")
        sender:sendMessage("Winner: "..game.members[1])
        sender:sendMessage("Thanks for playing, everyone!")
      else
        sender:sendMessage("Unknown stage: "..tostring(game.stage))
      end

      sender:sendMessage("Created by: "..game.creator)
      sender:sendMessage("Members (".. #game.members .."/".. #game.participants .."): "..table.concat( game.members, ", ") )

    elseif args[1] == "version" then

      -- /game version

      sender:sendMessage("You are running Rubidium "..plugin.version)

    else

      -- Invalid argument

      sender:sendMessage("Unknown argument. Type \"/game help\" for help.")

    end
  end
)

plugin.registerEvent("PlayerChangedWorldEvent",
  function( event )
    local gamemode = import("$.GameMode")
    if not game then return end
    local player = event:getPlayer()
    local world = player:getWorld()
    if game.stage == "STARTING" then
      player:setGameMode(gamemode.SURVIVAL)
    else
      event:getPlayer():setGameMode(gamemode.SPECTATOR)
    end
  end
)

plugin.registerEvent("PlayerDeathEvent",
  function( event )
    if event:getEntityType() == entities.PLAYER then
      local player = event:getEntity():getPlayer()
      local location = player:getLocation()
      player:getWorld():strikeLightningEffect( location )
      if not game then return end
      if game.stage == "RUNNING" then
        if delMember( event:getEntity():getName() ) == true then
          event:setDeathMessage("§4"..player:getName().." was eliminated.")
          if #game.members == 1 then

            game.stage = "OVER"
            server:broadcastMessage("§b"..game.members[1].." §3wins the game! §bCongratulations!")
            local winner = server:getOfflinePlayer(game.members[1]):getPlayer()

            local world = server:getWorld("Lobby")
            local spawnpos = world:getSpawnLocation()

            util.runAsync(
              function()
                for n = 1, #game.participants do
                  local player = server:getOfflinePlayer(game.participants[n])
                  if not player:getWorld() == world then
                    player:teleport(spawnpos)
                    player:getInventory():clear()
                  end
                end
                for n = 1, #game.spectators do
                  local player = server:getOfflinePlayer(game.spectators[n])
                  if not player:getWorld() == world then
                    player:teleport(spawnpos)
                    player:getInventory():clear()
                  end
                end
                deleteGame()
              end, 30000
            )

          else
            server:broadcastMessage("§dThere are "..#game.members.." players remaining!")
          end
        end
      end
    end
  end
)

plugin.registerEvent("PlayerRespawnEvent",
  function( event )
    if not game then return end
    if game.stage == "RUNNING" then
      event:getPlayer():setGameMode(gamemode.SPECTATOR)
    end
  end
)
