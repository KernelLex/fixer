module Fixer

// Real places to put jobs at, and the game's own non-story jobs as sites, read from the game each session. Nothing
// here is saved and nothing is written: jobs save the place record and coordinates they were posted with.
//
//  - Places are the fast-travel points the game knows (FastTravelSystem.GetFastTravelPoints), named and filed by
//    district from their TweakDB record, positioned by their map pin. No coordinate is hardcoded.
//  - Sites are journal quests of the non-story kinds (gigs, NCPD, psychos, vehicles, couriers) V hasn't finished,
//    positioned by their quest pin when the game has one, otherwise near a place in the same district.

public class FXPlace {
  public let record: TweakDBID;
  public let name: String;
  public let districtName: String;
  public let district: Int32;
  public let cityCenter: Bool;
  public let fixer: Int32;        // whose turf it's on (FXFixer), -1 for none
  public let subway: Bool;
  public let x: Float;
  public let y: Float;
  public let z: Float;
  public let hasPos: Bool;
}

public class FXSite {
  public let questHash: Int32;
  public let questType: Int32;    // gameJournalQuestType as Int32
  public let title: String;
  public let district: Int32;
  public let cityCenter: Bool;
  public let fixer: Int32;        // whose turf it's on (gigs: by id; other jobs: by district), -1 for none
  public let level: Int32;
  public let x: Float;
  public let y: Float;
  public let z: Float;
  public let hasPos: Bool;
  public let exactPos: Bool;      // from the quest's own pin, not a district anchor
}

public func FXPlaceName(game: GameInstance, record: TweakDBID) -> String {
  if !TDBID.IsValid(record) {
    return "";
  }
  let r = TweakDBInterface.GetFastTravelPointRecord(record);
  if !IsDefined(r) {
    return "";
  }
  return GetLocalizedText(r.DisplayName());
}

public func FXPlaceDistrictName(game: GameInstance, record: TweakDBID) -> String {
  if !TDBID.IsValid(record) {
    return "";
  }
  let r = TweakDBInterface.GetFastTravelPointRecord(record);
  if !IsDefined(r) || !IsDefined(r.District()) {
    return "";
  }
  return GetLocalizedText(r.District().LocalizedName());
}

public func FXBuildPlaces(game: GameInstance) -> array<ref<FXPlace>> {
  let out: array<ref<FXPlace>>;
  let ft = GameInstance.GetScriptableSystemsContainer(game).Get(n"FastTravelSystem") as FastTravelSystem;
  let ms = GameInstance.GetMappinSystem(game);
  if !IsDefined(ft) || !IsDefined(ms) {
    return out;
  }
  let points = ft.GetFastTravelPoints();
  let n = ArraySize(points);
  let i = 0;
  while i < n {
    let point = points[i];
    if IsDefined(point) {
      let rec = TweakDBInterface.GetFastTravelPointRecord(point.GetPointRecord());
      // Hidden points have no map pin and are often interiors: leave them out.
      if IsDefined(rec) && rec.ShowOnWorldMap() {
        let p = new FXPlace();
        p.record = point.GetPointRecord();
        p.name = GetLocalizedText(rec.DisplayName());
        let district = rec.District();
        p.fixer = -1;
        if IsDefined(district) {
          p.district = EnumInt(district.Type());
          p.cityCenter = FXIsCityCenter(district);
          p.districtName = GetLocalizedText(district.LocalizedName());
          p.fixer = FXFixerOfDistrict(district);
        }
        p.subway = rec.SubwayStation();
        let pin = ms.GetMappin(point.mappinID);
        if IsDefined(pin) {
          let pos = pin.GetWorldPosition();
          p.x = pos.X;
          p.y = pos.Y;
          p.z = pos.Z;
          p.hasPos = true;
        }
        ArrayPush(out, p);
      }
    }
    i += 1;
  }
  return out;
}

public func FXFindPlace(places: array<ref<FXPlace>>, record: TweakDBID) -> ref<FXPlace> {
  for p in places {
    if Equals(p.record, record) {
      return p;
    }
  }
  return null;
}

// A random place for a new job. Prefers places with a position (so the job shows on the map); falls back to any
// matching place, then to null (the caller then uses a turf block record).
public func FXPickPlace(game: GameInstance, places: array<ref<FXPlace>>, cityCenterOnly: Bool, label: String) -> ref<FXPlace> {
  let withPos: array<ref<FXPlace>>;
  let any: array<ref<FXPlace>>;
  for p in places {
    if !cityCenterOnly || p.cityCenter {
      ArrayPush(any, p);
      if p.hasPos {
        ArrayPush(withPos, p);
      }
    }
  }
  let pool = ArraySize(withPos) > 0 ? withPos : any;
  let n = ArraySize(pool);
  if n == 0 {
    return null;
  }
  return pool[FXRollInt(game, 0, n - 1, label)];
}

// A random place on one fixer's turf (prefers places with a position).
public func FXPickPlaceOf(game: GameInstance, places: array<ref<FXPlace>>, fixer: Int32, label: String) -> ref<FXPlace> {
  let withPos: array<ref<FXPlace>>;
  let any: array<ref<FXPlace>>;
  for p in places {
    if p.fixer == fixer {
      ArrayPush(any, p);
      if p.hasPos {
        ArrayPush(withPos, p);
      }
    }
  }
  let pool = ArraySize(withPos) > 0 ? withPos : any;
  let n = ArraySize(pool);
  if n == 0 {
    return null;
  }
  return pool[FXRollInt(game, 0, n - 1, label)];
}

// A place in the same district as a quest, to stand in for a quest without a pin of its own.
public func FXAnchorFor(places: array<ref<FXPlace>>, district: Int32, salt: Int32) -> ref<FXPlace> {
  let pool: array<ref<FXPlace>>;
  for p in places {
    if p.hasPos && p.district == district {
      ArrayPush(pool, p);
    }
  }
  let n = ArraySize(pool);
  if n == 0 {
    return null;
  }
  let k = (salt % n + n) % n;
  return pool[k];
}

public func FXIsSiteType(t: gameJournalQuestType) -> Bool {
  switch t {
    case gameJournalQuestType.StreetStory:
    case gameJournalQuestType.Contract:
    case gameJournalQuestType.CyberPsycho:
    case gameJournalQuestType.VehicleQuest:
    case gameJournalQuestType.CourierQuest:
    case gameJournalQuestType.CourierSideQuest:
      return true;
    default:
      return false;
  }
}

// The job type a crew runs at a vanilla site of a given quest kind. Gigs vary, so the quest hash picks one of the
// gig-like types, the same one every time for the same gig.
public func FXJobTypeForSite(questType: Int32, questHash: Int32) -> Int32 {
  switch IntEnum<gameJournalQuestType>(questType) {
    case gameJournalQuestType.Contract: return FXJobType.Assault();
    case gameJournalQuestType.CyberPsycho: return FXJobType.PsychoHunt();
    case gameJournalQuestType.VehicleQuest: return FXJobType.VehicleJob();
    case gameJournalQuestType.CourierQuest:
    case gameJournalQuestType.CourierSideQuest:
      return FXJobType.Courier();
    default:
      let gigTypes = [FXJobType.Theft(), FXJobType.Extraction(), FXJobType.Sabotage(), FXJobType.Netrun(), FXJobType.Escort()];
      let k = (questHash % 5 + 5) % 5;
      return gigTypes[k];
  }
}

// A gig must be a real gig (an sts_ id): the journal also files each district's completion reward as a gig.
public func FXIsRealSite(entry: wref<JournalQuest>) -> Bool {
  if Equals(entry.GetType(), gameJournalQuestType.StreetStory) {
    return StrBeginsWith(entry.GetId(), "sts_");
  }
  return true;
}

// Every non-story job V hasn't finished, as a site. Phantom Liberty entries only when it is installed.
public func FXBuildSites(game: GameInstance, places: array<ref<FXPlace>>) -> array<ref<FXSite>> {
  let out: array<ref<FXSite>>;
  let jm = GameInstance.GetJournalManager(game);
  let ms = GameInstance.GetMappinSystem(game);
  if !IsDefined(jm) || !IsDefined(ms) {
    return out;
  }
  let context: JournalRequestContext;
  context.stateFilter.inactive = true;
  context.stateFilter.active = true;
  let entries: array<wref<JournalEntry>>;
  jm.GetQuests(context, entries);
  let ep1 = IsEP1();
  let n = ArraySize(entries);
  let i = 0;
  while i < n {
    let quest = entries[i] as JournalQuest;
    if IsDefined(quest) && FXIsSiteType(quest.GetType()) && (ep1 || !jm.IsEp1Entry(quest)) && FXIsRealSite(quest) {
      let district = jm.GetDistrict(quest);
      let title = quest.GetTitle(jm);
      if StrBeginsWith(title, "LocKey#") {
        title = GetLocalizedText(title);
      }
      if IsDefined(district) && StrLen(title) > 0 {
        let s = new FXSite();
        s.questHash = jm.GetEntryHash(quest);
        s.questType = EnumInt(quest.GetType());
        s.title = title;
        s.district = EnumInt(district.Type());
        s.cityCenter = FXIsCityCenter(district);
        // A gig belongs to the fixer who gave it (its id); anything else to whoever runs the district.
        s.fixer = FXFixerOfGigId(quest.GetId());
        if s.fixer < 0 {
          s.fixer = FXFixerOfDistrict(district);
        }
        s.level = quest.GetRecommendedLevel();
        let pin = ms.GetMappinFromQuest(quest);
        if IsDefined(pin) {
          let pos = pin.GetWorldPosition();
          s.x = pos.X;
          s.y = pos.Y;
          s.z = pos.Z;
          s.hasPos = true;
          s.exactPos = true;
        } else {
          let anchor = FXAnchorFor(places, s.district, s.questHash);
          if IsDefined(anchor) {
            // Spread sites around their anchor so several in one district don't stack on one dot.
            let a = Cast<Float>((s.questHash % 360 + 360) % 360) * 0.0174533;
            s.x = anchor.x + CosF(a) * 60.0;
            s.y = anchor.y + SinF(a) * 60.0;
            s.z = anchor.z;
            s.hasPos = true;
          }
        }
        ArrayPush(out, s);
      }
    }
    i += 1;
  }
  return out;
}

// Difficulty 1..5 from the game's recommended level (1..60).
public func FXDifficultyForLevel(level: Int32) -> Int32 {
  return Clamp(1 + level / 12, 1, 5);
}
