module Fixer

// The game's gig fixers, one per district, and everything the mod knows about each, read from the game's own data:
//  - gig ids:   gigs are named sts_<district>_<sub>_NN; the gang-retaliation shards name fixer and gig together
//               (sts_dino_gang_retaliation_shard_dtn_03, sts_regina_..._kab_02, sts_wakako_..._jpn_12,
//               sts_padre_..._gle_04, sts_muamar_..._arr_11, sts_dakota_..._ina_03), which ties each prefix to its fixer.
//               Pacifica (sts_pac_) and Dogtown (sts_ep1_) are Mr. Hands' [VERIFY Pacifica in game].
//  - rewards:   the journal holds one "<district>_reward" entry per district that the game completes when every gig
//               there is done (westbrook_reward, heywood_reward and combat_zone_reward seen finished on a real save;
//               the other names are the same pattern and are only used if the journal has them).
//  - blocks:    each district's data terms that show on the world map (fasttravel/fasttravelpoints.tweak), up to
//               eight, spread over its neighbourhoods. Dogtown's only with Phantom Liberty installed.
// Saved data stores fixer INDICES: never reorder this list, only append.

public abstract class FXFixer {
  public static func Regina() -> Int32 = 0;    // Watson
  public static func Wakako() -> Int32 = 1;    // Westbrook
  public static func Dino() -> Int32 = 2;      // City Center
  public static func Padre() -> Int32 = 3;     // Heywood
  public static func Capitan() -> Int32 = 4;   // Santo Domingo (El Capitan, Muamar Reyes)
  public static func Hands() -> Int32 = 5;     // Pacifica and Dogtown
  public static func Dakota() -> Int32 = 6;    // Badlands
  public static func Count() -> Int32 = 7;
}

public func FXFixerName(game: GameInstance, k: Int32) -> String = FXText(game, s"FX-Fixer-\(Clamp(k, 0, FXFixer.Count() - 1))");
public func FXFixerTurf(game: GameInstance, k: Int32) -> String = FXText(game, s"FX-FixerTurf-\(Clamp(k, 0, FXFixer.Count() - 1))");

public func FXFixerGigPrefixes(k: Int32) -> array<String> {
  switch k {
    case FXFixer.Regina(): return ["sts_wat_"];
    case FXFixer.Wakako(): return ["sts_wbr_"];
    case FXFixer.Dino(): return ["sts_cct_"];
    case FXFixer.Padre(): return ["sts_hey_"];
    case FXFixer.Capitan(): return ["sts_std_"];
    case FXFixer.Hands(): return ["sts_pac_", "sts_ep1_"];
    case FXFixer.Dakota(): return ["sts_bls_"];
    default: return [];
  }
}

public func FXFixerRewardIds(k: Int32) -> array<String> {
  switch k {
    case FXFixer.Regina(): return ["watson_reward"];
    case FXFixer.Wakako(): return ["westbrook_reward"];
    case FXFixer.Dino(): return ["city_center_reward", "citycenter_reward"];
    case FXFixer.Padre(): return ["heywood_reward"];
    case FXFixer.Capitan(): return ["santo_domingo_reward", "santodomingo_reward"];
    case FXFixer.Hands(): return ["pacifica_reward", "combat_zone_reward", "dogtown_reward"];
    case FXFixer.Dakota(): return ["badlands_reward"];
    default: return [];
  }
}

// Which fixer a journal entry id belongs to: a gig by its prefix, a reward entry by its exact id. -1 when none.
public func FXFixerOfGigId(id: String) -> Int32 {
  let k = 0;
  while k < FXFixer.Count() {
    let prefixes = FXFixerGigPrefixes(k);
    for p in prefixes {
      if StrBeginsWith(id, p) {
        return k;
      }
    }
    k += 1;
  }
  return -1;
}

public func FXFixerOfRewardId(id: String) -> Int32 {
  let k = 0;
  while k < FXFixer.Count() {
    let ids = FXFixerRewardIds(k);
    for r in ids {
      if Equals(id, r) {
        return k;
      }
    }
    k += 1;
  }
  return -1;
}

// The fixer whose turf a district is in, walking up the district chain. -1 for places outside every turf.
public func FXFixerOfDistrict(district: wref<District_Record>) -> Int32 {
  let current = district;
  let depth = 0;
  while IsDefined(current) && depth < 8 {
    switch current.Type() {
      case gamedataDistrict.Watson: return FXFixer.Regina();
      case gamedataDistrict.Westbrook: return FXFixer.Wakako();
      case gamedataDistrict.CityCenter: return FXFixer.Dino();
      case gamedataDistrict.Heywood: return FXFixer.Padre();
      case gamedataDistrict.SantoDomingo: return FXFixer.Capitan();
      case gamedataDistrict.Pacifica: return FXFixer.Hands();
      case gamedataDistrict.Dogtown: return FXFixer.Hands();
      case gamedataDistrict.Badlands: return FXFixer.Dakota();
      case gamedataDistrict.NorthBadlands: return FXFixer.Dakota();
      case gamedataDistrict.SouthBadlands: return FXFixer.Dakota();
      default: break;
    }
    current = current.ParentDistrict();
    depth += 1;
  }
  return -1;
}

public func FXFixerBlockRecords(k: Int32) -> array<TweakDBID> {
  switch k {
    case FXFixer.Regina():
      return [
        t"FastTravelPoints.wat_kab_dataterm_01", t"FastTravelPoints.wat_kab_dataterm_02", t"FastTravelPoints.wat_kab_dataterm_04",
        t"FastTravelPoints.wat_lch_dataterm_01", t"FastTravelPoints.wat_lch_dataterm_03", t"FastTravelPoints.wat_nid_dataterm_02",
        t"FastTravelPoints.wat_nid_dataterm_05", t"FastTravelPoints.wat_awf_dataterm_01"
      ];
    case FXFixer.Wakako():
      return [
        t"FastTravelPoints.wbr_jpn_dataterm_01", t"FastTravelPoints.wbr_jpn_dataterm_03", t"FastTravelPoints.wbr_jpn_dataterm_06",
        t"FastTravelPoints.wbr_jpn_dataterm_09", t"FastTravelPoints.wbr_hil_dataterm_01", t"FastTravelPoints.wbr_hil_dataterm_03",
        t"FastTravelPoints.wbr_nok_dataterm_01", t"FastTravelPoints.wbr_nok_dataterm_03"
      ];
    case FXFixer.Dino():
      return [
        t"FastTravelPoints.cct_dtn_dataterm_01", t"FastTravelPoints.cct_dtn_dataterm_02", t"FastTravelPoints.cct_dtn_dataterm_03",
        t"FastTravelPoints.cct_dtn_dataterm_04", t"FastTravelPoints.cct_dtn_dataterm_05", t"FastTravelPoints.cct_dtn_dataterm_07",
        t"FastTravelPoints.cct_cpz_dataterm_01", t"FastTravelPoints.cct_cpz_dataterm_02"
      ];
    case FXFixer.Padre():
      return [
        t"FastTravelPoints.hey_gle_dataterm_01", t"FastTravelPoints.hey_gle_dataterm_03", t"FastTravelPoints.hey_gle_dataterm_05",
        t"FastTravelPoints.hey_rey_dataterm_01", t"FastTravelPoints.hey_rey_dataterm_03", t"FastTravelPoints.hey_rey_dataterm_05",
        t"FastTravelPoints.hey_spr_dataterm_01", t"FastTravelPoints.hey_spr_dataterm_03"
      ];
    case FXFixer.Capitan():
      return [
        t"FastTravelPoints.std_arr_dataterm_01", t"FastTravelPoints.std_arr_dataterm_03", t"FastTravelPoints.std_arr_dataterm_05",
        t"FastTravelPoints.std_arr_dataterm_07", t"FastTravelPoints.std_rcr_dataterm_01", t"FastTravelPoints.std_rcr_dataterm_03",
        t"FastTravelPoints.std_rcr_dataterm_06", t"FastTravelPoints.std_rcr_dataterm_09"
      ];
    case FXFixer.Hands():
      let blocks = [
        t"FastTravelPoints.pac_cvi_dataterm_01", t"FastTravelPoints.pac_cvi_dataterm_02", t"FastTravelPoints.pac_cvi_dataterm_04",
        t"FastTravelPoints.pac_wwd_dataterm_03"
      ];
      if IsEP1() {
        ArrayPush(blocks, t"FastTravelPoints.combat_zone_golden_pacific_dataterm_01");
        ArrayPush(blocks, t"FastTravelPoints.combat_zone_stadium_dataterm_01");
        ArrayPush(blocks, t"FastTravelPoints.combat_zone_squat_dataterm_01");
        ArrayPush(blocks, t"FastTravelPoints.combat_zone_longshore_stacks_dataterm_01");
      }
      return blocks;
    case FXFixer.Dakota():
      return [
        t"FastTravelPoints.bls_nth_dataterm_01", t"FastTravelPoints.bls_nth_dataterm_04", t"FastTravelPoints.bls_nth_dataterm_08",
        t"FastTravelPoints.bls_nth_dataterm_12", t"FastTravelPoints.bls_nth_dataterm_16", t"FastTravelPoints.bls_sth_dataterm_01",
        t"FastTravelPoints.bls_sth_dataterm_05", t"FastTravelPoints.bls_sth_dataterm_10"
      ];
    default:
      return [];
  }
}
