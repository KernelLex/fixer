module Fixer

// A seeded generator, so every roll can be logged and replayed (BUILD.md §7: "every random roll is seeded/loggable").
// Park-Miller MINSTD: state' = state * 48271 mod (2^31 - 1), computed in Int64 so it never overflows.
// The state lives in FXCareerBook (saved), so a reload continues the same sequence instead of re-rolling.

public abstract class FXRng {
  private static func Modulus() -> Int64 = 2147483647l;

  // A valid state is 1..2^31-2. Anything else (0 on a fresh save, a corrupt value) becomes a seed from game time.
  public static func Sanitize(state: Int32, game: GameInstance) -> Int32 {
    if state > 0 && state < 2147483647 {
      return state;
    }
    let t = Cast<Int64>(GameInstance.GetTimeSystem(game).GetGameTimeStamp() * 1000.0);
    let seed = Cast<Int32>((t % 2147483646l + 2147483646l) % 2147483646l) + 1;
    FXLog("Rng", s"Seeded at \(seed).");
    return seed;
  }

  public static func Step(state: Int32) -> Int32 {
    let next = (Cast<Int64>(state) * 48271l) % FXRng.Modulus();
    return Cast<Int32>(next);
  }
}

// The roll helpers. They read and write the career book's state, and log every roll in debug mode with its label,
// so "why did that happen" has an answer in the log.
public func FXRollInt(game: GameInstance, minInclusive: Int32, maxInclusive: Int32, label: String) -> Int32 {
  let book = FXCareerBook.Get(game);
  if !IsDefined(book) || maxInclusive <= minInclusive {
    return minInclusive;
  }
  let state = FXRng.Step(FXRng.Sanitize(book.GetRngState(), game));
  book.SetRngState(state);
  let span = maxInclusive - minInclusive + 1;
  let value = minInclusive + (state % span);
  FXLogDebug("Rng", s"\(label): \(value) in [\(minInclusive),\(maxInclusive)]");
  return value;
}

// True with the given chance in percent (0..100).
public func FXRollChance(game: GameInstance, percent: Int32, label: String) -> Bool {
  if percent <= 0 {
    FXLogDebug("Rng", s"\(label): chance \(percent)% never passes");
    return false;
  }
  if percent >= 100 {
    return true;
  }
  let roll = FXRollInt(game, 1, 100, label);
  let pass = roll <= percent;
  FXLogDebug("Rng", s"\(label): rolled \(roll) against \(percent)% -> \(pass ? "pass" : "fail")");
  return pass;
}
