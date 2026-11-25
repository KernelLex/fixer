module Fixer

// Small reads of the world's state, in one place so every gate uses the same definition.

public func FXPlayer(game: GameInstance) -> ref<PlayerPuppet> {
  return GetPlayer(game);
}

// The player exists and is in the world. False during loads and before the player attaches.
public func FXPlayerReady(game: GameInstance) -> Bool {
  let player = GetPlayer(game);
  return IsDefined(player) && player.IsAttached();
}

// V is in a conversation, a scene or a cinematic. The game's own settings menu treats SceneTier1 as free play
// (settingsMain.script); texts and popups wait above SceneTier2, the tier quests use for walking with someone.
public func FXInScene(game: GameInstance) -> Bool {
  let player = GetPlayer(game);
  if !IsDefined(player) {
    return true;
  }
  return PlayerPuppet.GetSceneTier(player) > EnumInt(gamePSMHighLevel.SceneTier2);
}

// The game clock is stopped: a menu, photo mode, a pause.
public func FXPaused(game: GameInstance) -> Bool {
  return GameInstance.GetTimeSystem(game).IsPausedState();
}

// Game seconds since the start of the playthrough. Use for anything timed in the story ("back in 6 hours").
public func FXNow(game: GameInstance) -> Float {
  return GameInstance.GetTimeSystem(game).GetGameTimeStamp();
}

// The day on the game clock.
public func FXDay(game: GameInstance) -> Int32 {
  return GameTime.Days(GameInstance.GetTimeSystem(game).GetGameTime());
}

public func FXGameHours(hours: Float) -> Float = hours * 3600.0;
public func FXGameDays(days: Float) -> Float = days * 86400.0;

// Street Cred as the inventory screen reads it (inventoryDataManagerV2.script).
public func FXStreetCred(game: GameInstance) -> Int32 {
  let player = GetPlayer(game);
  if !IsDefined(player) {
    return 0;
  }
  return RoundF(GameInstance.GetStatsSystem(game).GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.StreetCred));
}

// Eddies, through the same item the vehicle shop and Delamain's taxis use (MarketSystem.Money()).
public func FXGiveMoney(game: GameInstance, amount: Int32) -> Bool {
  let player = GetPlayer(game);
  if !IsDefined(player) || amount <= 0 {
    return false;
  }
  return GameInstance.GetTransactionSystem(game).GiveItem(player, MarketSystem.Money(), amount);
}

public func FXMoney(game: GameInstance) -> Int32 {
  let player = GetPlayer(game);
  if !IsDefined(player) {
    return 0;
  }
  return GameInstance.GetTransactionSystem(game).GetItemQuantity(player, MarketSystem.Money());
}
