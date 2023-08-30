local lastActiveApp = nil
hs.application.enableSpotlightForNameSearches(true)

-- Function to check if Kitty app is open
local function isKittyOpen()
  local bundleID = "/Applications/kitty.app"
  local bundleIDList = hs.execute("ps aux")
  if bundleIDList ~= nil then
    print("match", bundleIDList:find(bundleID))
    return bundleIDList:find(bundleID) ~= nil
  else
    return false
  end
end

-- Function to open a new instance of Kitty
local function openKitty()
  hs.application.open("/Applications/kitty.app")
  hs.timer.doAfter(1, function()
    setWindowPosition("Kitty", 0, 0, 800, 400)
  end)
end

-- Function to close Kitty
local function closeKitty()
  os.execute("kill " .. getAppPID('kitty'))
end

-- Toggle Kitty open/close
local function toggleKitty()
    if isKittyOpen() then
        closeKitty()
    else
        openKitty()
    end
end

-- Set the position and size of a window
function setWindowPosition(appName, x, y, width, height)
  local app = hs.appfinder.appFromName(appName)
  if app then
      local window = app:mainWindow()
      if window then
          local frame = window:frame()
          frame.x = x
          frame.y = y
          frame.w = width
          frame.h = height
          window:setFrame(frame)
      end
  end
end

-- Get the PID of an application
function getAppPID(appName)
  local app = hs.application.get(appName)
  if app then
      return app:pid()
  else
      return nil
  end
end


-- Watch for application activations
hs.application.watcher.new(function(appName, eventType, _)
  if appName == "kitty" then
    lastActiveApp = "kitty"
  else
    lastActiveApp = nil
  end
end):start()

-- Watch for application deactivations (loss of focus)
hs.window.filter.new(kittyApp)
  :subscribe(hs.window.filter.windowFocused, function(_, appName)
    print("kittyOpen:", isKittyOpen())
    print("lastActiveApp:", lastActiveApp)
    print("appName:", appName)
    if (lastActiveApp ~= "kitty") and (appName ~= "kitty") and (isKittyOpen()) then
      closeKitty()
    end
  end)

-- Bind the toggle function to Option + T
hs.hotkey.bind({"alt"}, "T", toggleKitty)
