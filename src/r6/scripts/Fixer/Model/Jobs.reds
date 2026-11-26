module Fixer

// The rules of a job: what it is, who is good at it, what it pays, how many people it needs and the odds.
// Pure functions over plain values, so every number here can be checked by reading. Saved enums: only append.

public abstract class FXJobType {
  public static func Theft() -> Int32 = 0;
  public static func Extraction() -> Int32 = 1;
  public static func Sabotage() -> Int32 = 2;
  public static func Netrun() -> Int32 = 3;
  public static func Escort() -> Int32 = 4;
  public static func Courier() -> Int32 = 5;
  public static func Assault() -> Int32 = 6;      // NCPD clear-outs, war strikes
  public static func PsychoHunt() -> Int32 = 7;
  public static func VehicleJob() -> Int32 = 8;
  public static func Count() -> Int32 = 9;
}

// Where a job came from.
public abstract class FXJobKind {
  public static func Ally() -> Int32 = 0;         // handed over by an allied fixer, in their district; they take a cut
  public static func Street() -> Int32 = 1;       // V's own business (Dex's old clients), at a real place
  public static func Vanilla() -> Int32 = 2;      // the crew works a site of one of the game's own jobs, on V's turf
  public static func Strike() -> Int32 = 3;       // war: hit one of a rival fixer's blocks
}

public abstract class FXJobState {
  public static func Open() -> Int32 = 0;
  public static func Running() -> Int32 = 1;
  public static func Done() -> Int32 = 2;
  public static func Expired() -> Int32 = 3;
}

public abstract class FXOutcome {
  public static func None() -> Int32 = 0;
  public static func Success() -> Int32 = 1;
  public static func Partial() -> Int32 = 2;
  public static func Fail() -> Int32 = 3;
  public static func Disaster() -> Int32 = 4;
}

public abstract class FXCasualty {
  public static func None() -> Int32 = 0;
  public static func Injured() -> Int32 = 1;
  public static func Arrested() -> Int32 = 2;
  public static func Dead() -> Int32 = 3;
}

public abstract class FXJobFlag {
  public static func Arasaka() -> Int32 = 1;      // the target is Arasaka: pays more, draws Arasaka Heat
}

// ---- Who is good at what ----
public func FXJobRoleA(jobType: Int32) -> Int32 {
  switch jobType {
    case FXJobType.Theft(): return FXRole.Techie();
    case FXJobType.Extraction(): return FXRole.Solo();
    case FXJobType.Sabotage(): return FXRole.Techie();
    case FXJobType.Netrun(): return FXRole.Netrunner();
    case FXJobType.Escort(): return FXRole.Solo();
    case FXJobType.Courier(): return FXRole.Nomad();
    case FXJobType.Assault(): return FXRole.Solo();
    case FXJobType.PsychoHunt(): return FXRole.Solo();
    case FXJobType.VehicleJob(): return FXRole.Nomad();
    default: return FXRole.Solo();
  }
}

public func FXJobRoleB(jobType: Int32) -> Int32 {
  switch jobType {
    case FXJobType.Theft(): return FXRole.Netrunner();
    case FXJobType.Extraction(): return FXRole.Nomad();
    case FXJobType.Sabotage(): return FXRole.Solo();
    case FXJobType.Netrun(): return FXRole.Techie();
    case FXJobType.Escort(): return FXRole.Face();
    case FXJobType.Courier(): return FXRole.Face();
    case FXJobType.Assault(): return FXRole.Nomad();
    case FXJobType.PsychoHunt(): return FXRole.Netrunner();
    case FXJobType.VehicleJob(): return FXRole.Techie();
    default: return FXRole.Face();
  }
}

// A member's multiplier on a job: the lead role 1.35, the support role 1.2, anyone else 1.0, and a netrun is no
// place for someone who can't jack in (0.6).
public func FXRoleBonus(jobType: Int32, role: Int32) -> Float {
  if role == FXJobRoleA(jobType) {
    return 1.35;
  }
  if role == FXJobRoleB(jobType) {
    return 1.2;
  }
  if jobType == FXJobType.Netrun() {
    return 0.6;
  }
  return 1.0;
}

public func FXJobPayMult(jobType: Int32) -> Float {
  switch jobType {
    case FXJobType.Extraction(): return 1.3;
    case FXJobType.Sabotage(): return 1.1;
    case FXJobType.Netrun(): return 1.2;
    case FXJobType.Escort(): return 0.9;
    case FXJobType.Courier(): return 0.7;
    case FXJobType.Assault(): return 1.2;
    case FXJobType.PsychoHunt(): return 1.5;
    default: return 1.0;
  }
}

// What the client pays, before anyone's cut. Difficulty 1 is about 1,700 eddies, 3 about 5,500, 5 about 10,900.
public func FXJobPay(difficulty: Int32, jobType: Int32, arasaka: Bool) -> Int32 {
  let d = Cast<Float>(Clamp(difficulty, 1, 5));
  let base = 800.0 + 900.0 * PowF(d, 1.5);
  let pay = base * FXJobPayMult(jobType) * (arasaka ? 1.5 : 1.0) * FXSettingsBridge.PayMultiplier();
  return RoundF(pay / 50.0) * 50;
}

// People needed. roll is 0..99, so the two-value difficulties split evenly.
public func FXJobNeed(difficulty: Int32, roll: Int32) -> Int32 {
  switch Clamp(difficulty, 1, 5) {
    case 1: return 1;
    case 2: return roll < 50 ? 1 : 2;
    case 3: return 2;
    case 4: return roll < 50 ? 2 : 3;
    default: return roll < 50 ? 3 : 4;
  }
}

// Game hours away: 5 to 17.
public func FXJobHours(difficulty: Int32, roll: Int32) -> Int32 {
  return 3 + Clamp(difficulty, 1, 5) * 2 + Clamp(roll, 0, 4);
}

public func FXJobHeat(jobType: Int32, difficulty: Int32) -> Int32 {
  let heat = 2 + Clamp(difficulty, 1, 5) * 2;
  if jobType == FXJobType.Courier() || jobType == FXJobType.Netrun() {
    heat = heat / 2;
  }
  if jobType == FXJobType.Assault() || jobType == FXJobType.PsychoHunt() {
    heat = heat + 3;
  }
  return heat;
}

public func FXJobArasakaHeat(difficulty: Int32) -> Int32 {
  return 4 + Clamp(difficulty, 1, 5) * 3;
}

// One member's contribution: skill x role fit x loyalty (a crew that doesn't trust V holds back a little).
public func FXContribution(skill: Int32, role: Int32, loyalty: Int32, jobType: Int32) -> Float {
  let loyaltyFactor = 0.8 + Cast<Float>(Clamp(loyalty, 0, 100)) / 500.0;
  return Cast<Float>(skill) * FXRoleBonus(jobType, role) * loyaltyFactor;
}

// The odds, from BUILD.md §3.3, with the crew-size rule added: fewer than `need` people can't go at all; the best
// `need` people count in full and anyone extra counts half.
//   power    = sum of the best `need` contributions + half of the rest
//   required = difficulty x DIFF_SCALE x need
//   chance   = clamp(power / required x heat modifiers, 10%, 95%)
public func FXSuccessFromContributions(contribs: array<Float>, need: Int32, difficulty: Int32, modifier: Float) -> Float {
  let n = ArraySize(contribs);
  if n < Max(1, need) {
    return 0.0;
  }
  // Sort descending (a handful of entries: selection sort is fine).
  let sorted = contribs;
  let i = 0;
  while i < n {
    let best = i;
    let j = i + 1;
    while j < n {
      if sorted[j] > sorted[best] {
        best = j;
      }
      j += 1;
    }
    let tmp = sorted[i];
    sorted[i] = sorted[best];
    sorted[best] = tmp;
    i += 1;
  }
  let power = 0.0;
  i = 0;
  while i < n {
    power += i < need ? sorted[i] : sorted[i] * 0.5;
    i += 1;
  }
  let required = Cast<Float>(Clamp(difficulty, 1, 5)) * FXSettingsBridge.DifficultyScale() * Cast<Float>(Max(1, need));
  return ClampF(power / required * modifier, 0.10, 0.95);
}

// Outcome bands for a roll of 1..100 against a success chance (0..1):
//  roll <= chance           -> success
//  next 40% of the rest     -> partial (half pay)
//  next 40% of the rest     -> fail
//  last 20% of the rest     -> disaster (someone gets hurt, arrested or killed)
public func FXOutcomeFor(roll: Int32, chance: Float) -> Int32 {
  let s = chance * 100.0;
  let r = Cast<Float>(roll);
  if r <= s {
    return FXOutcome.Success();
  }
  let rest = 100.0 - s;
  if r <= s + rest * 0.4 {
    return FXOutcome.Partial();
  }
  if r <= s + rest * 0.8 {
    return FXOutcome.Fail();
  }
  return FXOutcome.Disaster();
}

// Loyalty change for one member after a job: the cut against a fair 30%, then the outcome, shaped by trait.
public func FXLoyaltyDelta(cut: Int32, outcome: Int32, trait: Int32) -> Int32 {
  let cutDelta = (cut - 30) / 2;
  if trait == FXTrait.Greedy() {
    cutDelta = cutDelta * 2;
  }
  let outcomeDelta = 0;
  switch outcome {
    case FXOutcome.Success(): outcomeDelta = 3; break;
    case FXOutcome.Fail(): outcomeDelta = -3; break;
    case FXOutcome.Disaster(): outcomeDelta = -6; break;
    default: outcomeDelta = 0; break;
  }
  let total = cutDelta + outcomeDelta;
  if trait == FXTrait.Loyal() && total < 0 {
    total = total / 2;
  }
  return total;
}

public func FXJobXp(difficulty: Int32, outcome: Int32) -> Int32 {
  let d = Clamp(difficulty, 1, 5);
  switch outcome {
    case FXOutcome.Success(): return d * 12;
    case FXOutcome.Partial(): return d * 6;
    default: return d * 3;
  }
}
