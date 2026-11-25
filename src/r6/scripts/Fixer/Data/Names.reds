module Fixer

// Name lists for generated people. Saves store POSITIONS in these lists, so:
//  - only ever append at the end; never reorder, remove or insert;
//  - no canon character names or handles (story characters are off limits, and a merc called "Rogue" would confuse).

public func FXFirstNames() -> array<String> {
  return [
    "Rafael", "Mika", "Tomasz", "Aiyana", "Kenji", "Lucia", "Imani", "Yusuf", "Sora", "Nadia",
    "Cormac", "Wei", "Thandi", "Arturo", "Freya", "Jun", "Malik", "Esperanza", "Bogdan", "Ines",
    "Hiro", "Amara", "Desmond", "Lena", "Oscar", "Priya", "Teodor", "Zara", "Ezequiel", "Noor",
    "Callum", "Mei", "Dario", "Ingrid", "Kofi", "Valeria", "Anton", "Rin", "Mateo", "Odessa",
    "Siddharth", "Halle", "Ruslan", "Paloma", "Idris", "Yuki", "Ferran", "Ayo", "Lorcan", "Celeste"
  ];
}

public func FXLastNames() -> array<String> {
  return [
    "Vey", "Okafor", "Lindqvist", "Moreno", "Tanaka", "Kowalczyk", "Haddad", "Reyes-Cole", "Brandt", "Achebe",
    "Novak", "Castellanos", "Ishikawa", "Mbeki", "Duarte", "Sato", "Fairweather", "Quan", "Volkov", "Abara",
    "Delacroix", "Huang", "Ferreira", "Nakamura", "Osei", "Kerrigan", "Petrova", "Salazar", "Yilmaz", "Adeyemi",
    "Marchetti", "Lund", "Okonkwo", "Varga", "Ibarra", "Kimura", "Strand", "Mensah", "Rourke", "Szabo",
    "Takeda", "Oyelaran", "Halloran", "Espinoza", "Baptiste", "Mori", "Kadyrov", "Lachance", "Nwosu", "Pell"
  ];
}

public func FXHandles() -> array<String> {
  return [
    "Rook", "Static", "Gristle", "Nine-Volt", "Lacework", "Sable", "Wire", "Ghostline", "Patch", "Tallow",
    "Sixgun", "Mako", "Hex", "Rust", "Cinder", "Pixel", "Torque", "Saint", "Glitch", "Copper",
    "Mercy", "Driftwood", "Lowkey", "Ballast", "Halfmoon", "Kestrel", "Ledger", "Ozone", "Splice", "Tinman",
    "Velvet", "Wrench", "Ashcan", "Bishop", "Choke", "Fuse", "Graveyard", "Jinx", "Moth", "Quill",
    "Ratchet", "Shiv", "Tripwire", "Umbra", "Vandal", "Whisper", "Yardbird", "Zero-Day", "Bluebird", "Crowbar"
  ];
}

public func FXNameAt(list: array<String>, i: Int32) -> String {
  let n = ArraySize(list);
  if n == 0 {
    return "";
  }
  if i < 0 || i >= n {
    return list[0];
  }
  return list[i];
}

// "Rafael 'Rook' Vey"
public func FXPersonName(p: ref<FXPerson>) -> String {
  if !IsDefined(p) {
    return "?";
  }
  let firsts = FXFirstNames();
  let lasts = FXLastNames();
  let handles = FXHandles();
  return s"\(FXNameAt(firsts, p.first)) '\(FXNameAt(handles, p.handle))' \(FXNameAt(lasts, p.last))";
}

// "Rook"
public func FXPersonHandle(p: ref<FXPerson>) -> String {
  if !IsDefined(p) {
    return "?";
  }
  let handles = FXHandles();
  return FXNameAt(handles, p.handle);
}

// Traits. Saved as Int32: only append.
public abstract class FXTrait {
  public static func Steady() -> Int32 = 0;
  public static func Greedy() -> Int32 = 1;
  public static func Loyal() -> Int32 = 2;
  public static func Reckless() -> Int32 = 3;
  public static func Cautious() -> Int32 = 4;
  public static func ExCorpo() -> Int32 = 5;
  public static func ExGang() -> Int32 = 6;
  public static func Count() -> Int32 = 7;
}
